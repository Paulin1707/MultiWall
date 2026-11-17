import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

const credentialTtlSeconds = 4 * 60 * 60;
const rateWindowMs = 10 * 60 * 1000;
const actorRateLimit = 6;
const ipRateLimit = 30;
const rateBuckets = new Map<string, number[]>();

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function parseKeyMap(raw: string | undefined): Record<string, string> {
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

function takeRateLimit(key: string, limit: number): boolean {
  const now = Date.now();
  const recent = (rateBuckets.get(key) ?? []).filter((time) => now - time < rateWindowMs);
  if (recent.length >= limit) {
    rateBuckets.set(key, recent);
    return false;
  }
  recent.push(now);
  rateBuckets.set(key, recent);

  // Keep the best-effort per-isolate limiter bounded.
  if (rateBuckets.size > 5000) {
    for (const [bucketKey, timestamps] of rateBuckets) {
      if (timestamps.every((time) => now - time >= rateWindowMs)) {
        rateBuckets.delete(bucketKey);
      }
      if (rateBuckets.size <= 4000) break;
    }
  }
  return true;
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Méthode non autorisée" }, 405);

  const publishableKeys = parseKeyMap(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS"));
  const acceptedApiKeys = Object.values(publishableKeys);
  const legacyAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (legacyAnonKey) acceptedApiKeys.push(legacyAnonKey);

  const suppliedApiKey = request.headers.get("apikey");
  if (!suppliedApiKey || !acceptedApiKeys.includes(suppliedApiKey)) {
    return json({ error: "Accès refusé" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const secretKeys = parseKeyMap(Deno.env.get("SUPABASE_SECRET_KEYS"));
  const adminKey = secretKeys["default"] ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !adminKey) {
    return json({ error: "Configuration serveur incomplète" }, 503);
  }

  let body: Record<string, unknown>;
  try {
    const raw = await request.text();
    if (raw.length > 4096) return json({ error: "Requête trop volumineuse" }, 413);
    body = JSON.parse(raw);
  } catch {
    return json({ error: "Requête JSON invalide" }, 400);
  }

  const sessionId = body.session_id;
  const ownerToken = typeof body.owner_token === "string" ? body.owner_token : "";
  const participantId = body.participant_id;
  const isOwnerRequest = ownerToken.length >= 32 && ownerToken.length <= 256;
  const isParticipantRequest = isUuid(participantId);

  if (!isUuid(sessionId) || isOwnerRequest === isParticipantRequest) {
    return json({ error: "Identifiants de session invalides" }, 400);
  }

  const ownerHash = isOwnerRequest ? await sha256Hex(ownerToken) : "";
  const actorKey = isOwnerRequest
    ? "owner:" + sessionId + ":" + ownerHash
    : "participant:" + participantId;

  if (!takeRateLimit(actorKey, actorRateLimit)) {
    return json({ error: "Trop de demandes de relais. Réessayez dans 10 minutes." }, 429);
  }

  const ip = request.headers.get("cf-connecting-ip") ??
    request.headers.get("x-forwarded-for")?.split(",")[0].trim();
  if (ip && !takeRateLimit("ip:" + ip, ipRateLimit)) {
    return json({ error: "Trop de demandes depuis cette connexion." }, 429);
  }

  const supabaseAdmin = createClient(supabaseUrl, adminKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: session, error: sessionError } = await supabaseAdmin
    .from("sessions")
    .select("id, status, expires_at, owner_token_hash")
    .eq("id", sessionId)
    .maybeSingle();

  if (sessionError) {
    return json({ error: "Vérification de session impossible" }, 500);
  }
  if (!session || session.status !== "active" ||
      new Date(session.expires_at).getTime() <= Date.now()) {
    return json({ error: "Session introuvable ou expirée" }, 403);
  }

  if (isOwnerRequest) {
    if (session.owner_token_hash !== ownerHash) {
      return json({ error: "Autorisation refusée" }, 403);
    }
  } else {
    const { data: participant, error: participantError } = await supabaseAdmin
      .from("session_participants")
      .select("id")
      .eq("id", participantId)
      .eq("session_id", sessionId)
      .eq("status", "accepted")
      .maybeSingle();

    if (participantError) {
      return json({ error: "Vérification du participant impossible" }, 500);
    }
    if (!participant) return json({ error: "Participant non autorisé" }, 403);
  }

  const turnKeyId = Deno.env.get("CLOUDFLARE_TURN_KEY_ID");
  const turnApiToken = Deno.env.get("CLOUDFLARE_TURN_API_TOKEN");
  if (!turnKeyId || !turnApiToken) {
    return json({ error: "Le service TURN n'est pas encore configuré" }, 503);
  }

  let cloudflareResponse: Response;
  try {
    cloudflareResponse = await fetch(
      "https://rtc.live.cloudflare.com/v1/turn/keys/" +
        encodeURIComponent(turnKeyId) +
        "/credentials/generate-ice-servers",
      {
        method: "POST",
        headers: {
          "Authorization": "Bearer " + turnApiToken,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ ttl: credentialTtlSeconds }),
      },
    );
  } catch {
    return json({ error: "Service TURN temporairement indisponible" }, 502);
  }

  if (!cloudflareResponse.ok) {
    // Do not log or return provider credentials or response bodies.
    console.error("Cloudflare TURN credential request failed:", cloudflareResponse.status);
    return json({ error: "Impossible de générer les identifiants TURN" }, 502);
  }

  let providerData: Record<string, unknown>;
  try {
    providerData = await cloudflareResponse.json();
  } catch {
    return json({ error: "Réponse TURN invalide" }, 502);
  }

  const iceServers = Array.isArray(providerData.iceServers)
    ? providerData.iceServers.filter((server) => {
      if (!server || typeof server !== "object") return false;
      const item = server as Record<string, unknown>;
      const rawUrls = item.urls;
      const urls = typeof rawUrls === "string"
        ? [rawUrls]
        : Array.isArray(rawUrls)
          ? rawUrls
          : [];
      const hasTurnUrl = urls.some((url) =>
        typeof url === "string" &&
        (url.startsWith("turn:") || url.startsWith("turns:"))
      );
      return hasTurnUrl &&
        typeof item.username === "string" &&
        item.username.length > 0 &&
        typeof item.credential === "string" &&
        item.credential.length > 0;
    })
    : [];

  if (iceServers.length === 0) {
    return json({ error: "Aucun serveur relais TURN valide reçu" }, 502);
  }

  return json({
    iceServers: providerData.iceServers,
    expiresIn: credentialTtlSeconds,
  });
});
