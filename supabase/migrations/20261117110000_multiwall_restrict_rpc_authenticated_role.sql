-- MultiWall RPC access policy.
-- MultiWall uses Supabase's anon key and owner/participant capability tokens;
-- signed-in role does not need direct execution of these RPCs.
-- Anonymous execution remains enabled and each function must validate its
-- owner token or accepted participant identity internally.

REVOKE EXECUTE ON FUNCTION public.create_multiwall_session(text,text,integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.request_multiwall_join(text,text,text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.decide_multiwall_join(uuid,text,uuid,boolean) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.close_multiwall_session(uuid,text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_multiwall_participants(uuid,text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.send_multiwall_signal(uuid,text,uuid,uuid,text,jsonb) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_multiwall_signals(uuid,text,uuid) FROM authenticated;

GRANT EXECUTE ON FUNCTION public.create_multiwall_session(text,text,integer) TO anon, service_role;
GRANT EXECUTE ON FUNCTION public.request_multiwall_join(text,text,text) TO anon, service_role;
GRANT EXECUTE ON FUNCTION public.decide_multiwall_join(uuid,text,uuid,boolean) TO anon, service_role;
GRANT EXECUTE ON FUNCTION public.close_multiwall_session(uuid,text) TO anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_multiwall_participants(uuid,text) TO anon, service_role;
GRANT EXECUTE ON FUNCTION public.send_multiwall_signal(uuid,text,uuid,uuid,text,jsonb) TO anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_multiwall_signals(uuid,text,uuid) TO anon, service_role;
