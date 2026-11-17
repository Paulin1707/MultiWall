-- MultiWall signaling compatibility and hardening.
-- Applied to Supabase project cerzkniqycnggirvfzqv on 2026-11-17.
-- Keep this migration in source control so future environments match production.

ALTER TABLE public.signaling_messages
  DROP CONSTRAINT signaling_messages_message_type_check;

ALTER TABLE public.signaling_messages
  ADD CONSTRAINT signaling_messages_message_type_check
  CHECK (message_type = ANY (ARRAY[
    'offer'::text,
    'answer'::text,
    'ice_candidate'::text,
    'bye'::text,
    'pointer'::text,
    'wall_layout'::text,
    'reconnect_request'::text
  ]));

CREATE OR REPLACE FUNCTION public.send_multiwall_signal(
  p_session_id uuid,
  p_owner_token text,
  p_sender_participant_id uuid,
  p_recipient_participant_id uuid,
  p_message_type text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'extensions'
AS $function$
DECLARE
  v_session public.sessions%ROWTYPE;
BEGIN
  IF p_message_type NOT IN (
    'offer', 'answer', 'ice_candidate', 'bye',
    'pointer', 'wall_layout', 'reconnect_request'
  ) THEN
    RAISE EXCEPTION 'Type de message invalide';
  END IF;

  IF octet_length(COALESCE(p_payload, '{}'::jsonb)::text) > 262144 THEN
    RAISE EXCEPTION 'Message trop volumineux';
  END IF;

  SELECT * INTO v_session
  FROM public.sessions
  WHERE id = p_session_id
    AND status = 'active'
    AND expires_at > now();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Session introuvable ou expirée';
  END IF;

  IF p_owner_token IS NOT NULL THEN
    IF encode(
      extensions.digest(convert_to(p_owner_token, 'UTF8'), 'sha256'),
      'hex'
    ) <> v_session.owner_token_hash THEN
      RAISE EXCEPTION 'Jeton propriétaire invalide';
    END IF;

    IF p_sender_participant_id IS NOT NULL
       OR p_recipient_participant_id IS NULL THEN
      RAISE EXCEPTION 'Destinataire invalide';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM public.session_participants
      WHERE id = p_recipient_participant_id
        AND session_id = p_session_id
        AND status = 'accepted'
    ) THEN
      RAISE EXCEPTION 'Appareil non autorisé';
    END IF;
  ELSE
    IF p_sender_participant_id IS NULL
       OR p_recipient_participant_id IS NOT NULL THEN
      RAISE EXCEPTION 'Expéditeur invalide';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM public.session_participants
      WHERE id = p_sender_participant_id
        AND session_id = p_session_id
        AND status = 'accepted'
    ) THEN
      RAISE EXCEPTION 'Participant non autorisé';
    END IF;
  END IF;

  INSERT INTO public.signaling_messages (
    session_id,
    sender_participant_id,
    recipient_participant_id,
    message_type,
    payload
  )
  VALUES (
    p_session_id,
    p_sender_participant_id,
    p_recipient_participant_id,
    p_message_type,
    COALESCE(p_payload, '{}'::jsonb)
  );

  RETURN jsonb_build_object('success', true);
END;
$function$;

ALTER FUNCTION public.get_multiwall_signals(uuid, text, uuid)
  SET search_path TO 'pg_catalog', 'extensions';
