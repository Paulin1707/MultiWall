-- Prevent direct access to the sequence backing the private attempt log.
revoke all on sequence public.multiwall_join_attempts_id_seq from public, anon, authenticated;
