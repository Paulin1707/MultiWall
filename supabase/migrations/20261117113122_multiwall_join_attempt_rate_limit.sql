-- Per-installation throttling for failed session-code attempts.
-- Only SHA-256 hashes are stored; raw codes and client identifiers are never persisted.

create table public.multiwall_join_attempts (
  id bigserial primary key,
  code_hash bytea not null,
  client_key_hash bytea not null,
  attempted_at timestamptz not null default now()
);

create index idx_multiwall_join_attempts_pair_time
  on public.multiwall_join_attempts (code_hash, client_key_hash, attempted_at);
create index idx_multiwall_join_attempts_time
  on public.multiwall_join_attempts (attempted_at);

alter table public.multiwall_join_attempts enable row level security;
revoke all on table public.multiwall_join_attempts from public, anon, authenticated;

drop function if exists public.request_multiwall_join(text, text, text);

create function public.request_multiwall_join(
  p_code text,
  p_device_name text,
  p_client_key text,
  p_device_type text default 'unknown'
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'extensions'
as $function$
declare
  v_session public.sessions%rowtype;
  v_participant_id uuid;
  v_participant_count integer;
  v_attempt_count integer;
  v_code text;
  v_code_hash bytea;
  v_client_key_hash bytea;
begin
  if p_device_name is null
     or length(trim(p_device_name)) = 0
     or length(p_device_name) > 80 then
    raise exception 'Nom appareil invalide';
  end if;

  if p_device_type is null
     or p_device_type not in ('phone', 'tablet', 'computer', 'unknown') then
    raise exception 'Type appareil invalide';
  end if;

  if p_client_key is null
     or length(p_client_key) < 32
     or length(p_client_key) > 128
     or p_client_key !~ '^[A-Za-z0-9_-]+$' then
    raise exception 'Identifiant de cette installation invalide';
  end if;

  v_code := coalesce(trim(p_code), '');
  if v_code !~ '^[0-9]{6}$' then
    raise exception 'Le code doit contenir exactement 6 chiffres';
  end if;

  v_code_hash := extensions.digest(convert_to(v_code, 'UTF8'), 'sha256');
  v_client_key_hash := extensions.digest(convert_to(p_client_key, 'UTF8'), 'sha256');

  -- Serialize attempts from the same app installation against the same code.
  perform pg_advisory_xact_lock(
    hashtextextended(
      encode(v_code_hash, 'hex') || ':' || encode(v_client_key_hash, 'hex'),
      0
    )
  );

  -- Bound cleanup work while removing expired records for this installation/code.
  delete from public.multiwall_join_attempts
   where code_hash = v_code_hash
     and client_key_hash = v_client_key_hash
     and attempted_at < now() - interval '10 minutes';

  delete from public.multiwall_join_attempts
   where id in (
     select id
       from public.multiwall_join_attempts
      where attempted_at < now() - interval '1 day'
      order by attempted_at
      limit 200
   );

  select count(*)::integer
    into v_attempt_count
    from public.multiwall_join_attempts
   where code_hash = v_code_hash
     and client_key_hash = v_client_key_hash
     and attempted_at >= now() - interval '10 minutes';

  if v_attempt_count >= 5 then
    raise exception 'Trop de codes incorrects. Réessayez dans 10 minutes.';
  end if;

  select *
    into v_session
    from public.sessions
   where code = v_code
     and status = 'active'
     and expires_at > now()
   for update;

  if not found then
    insert into public.multiwall_join_attempts (
      code_hash,
      client_key_hash
    ) values (
      v_code_hash,
      v_client_key_hash
    );

    return jsonb_build_object(
      'status', 'error',
      'message', 'Session introuvable ou expirée'
    );
  end if;

  -- A correct code is not penalized by earlier failed guesses.
  delete from public.multiwall_join_attempts
   where code_hash = v_code_hash
     and client_key_hash = v_client_key_hash;

  select count(*)::integer
    into v_participant_count
    from public.session_participants
   where session_id = v_session.id
     and status in ('pending', 'accepted');

  if v_participant_count >= v_session.max_participants then
    raise exception 'Session complète';
  end if;

  insert into public.session_participants (
    session_id,
    device_name,
    device_type,
    status
  ) values (
    v_session.id,
    trim(p_device_name),
    p_device_type,
    'pending'
  )
  returning id into v_participant_id;

  return jsonb_build_object(
    'participant_id', v_participant_id,
    'session_id', v_session.id,
    'status', 'pending',
    'message', 'Demande envoyée au propriétaire'
  );
end;
$function$;

revoke all on function public.request_multiwall_join(text, text, text, text)
  from public, authenticated;
grant execute on function public.request_multiwall_join(text, text, text, text)
  to anon, service_role;

notify pgrst, 'reload schema';
