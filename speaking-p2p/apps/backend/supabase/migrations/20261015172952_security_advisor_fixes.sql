-- Fixes from the Supabase security advisor (2026-10-15).
--
-- 1. public_profiles becomes SECURITY INVOKER. The column grants on profiles
--    (id, username, avatar_key, languages, target_level) plus the select policy
--    already give exactly the same rows/columns to `authenticated`, so the view
--    does not need its owner's rights: strictly safer, same result.
alter view public.public_profiles set (security_invoker = true);

-- 2. Pin search_path on the remaining helpers (they only use pg_catalog, which is
--    always searched; pinning removes any dependency on the caller's path).
alter function private.is_level(text) set search_path = '';
alter function private.lock_user(uuid) set search_path = '';
alter function private.lock_users(uuid, uuid) set search_path = '';
alter function private.fail(text) set search_path = '';
alter function private.email_hash(text) set search_path = '';
alter function private.session_role(public.exam_sessions, uuid) set search_path = '';
alter function private.mic_for(public.exam_sessions, int) set search_path = '';

-- 3. public.rls_auto_enable() is created by Supabase (the "enable RLS on new
--    tables" project setting) and fired by the event trigger ensure_rls. Nobody
--    must call it through /rest/v1/rpc; event triggers run as the owner anyway.
do $$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public' and p.proname = 'rls_auto_enable') then
    revoke all on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end $$;
