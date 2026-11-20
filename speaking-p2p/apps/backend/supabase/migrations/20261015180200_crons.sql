-- Crons, scheduled from a migration (vault: config.toml `schedule` is silently ignored).
--
-- Two kinds:
--   * pure SQL (agenda, housekeeping): pg_cron calls the svc_* function directly;
--   * needs the outside world (LiveKit mic pushes, FCM, R2 deletes): pg_cron -> pg_net ->
--     Edge Function `cron-worker`, authenticated with a DEDICATED token. The token lives in
--     Supabase Vault (`internal_cron_token`); the function checks it through
--     svc_verify_internal_token (D-021). Never verify_jwt, never the service_role key (vault ADR 0011).
--
-- Setup once per environment (not in git, see docs/SETUP.md):
--   select vault.create_secret('<random 48 bytes, base64>', 'internal_cron_token');
--   select vault.create_secret('https://<ref>.supabase.co', 'project_url');
--
-- Verification is NOT "the job says succeeded" (pg_net is async):
--   select status, return_message, start_time from cron.job_run_details order by start_time desc limit 5;
--   select id, status_code, left(content::text, 200) from net._http_response order by id desc limit 5;
--
-- On environments without pg_cron (plain Postgres for the SQL suite) this migration is a no-op.

do $outer$
begin
  if not exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    raise notice 'pg_cron not available: skipping cron schedules';
    return;
  end if;

  create extension if not exists pg_cron;
  create extension if not exists pg_net;

  create or replace function private.invoke_worker(p_task text) returns void
  language plpgsql security definer set search_path = '' as $fn$
  declare v_url text; v_token text;
  begin
    select decrypted_secret into v_url from vault.decrypted_secrets where name = 'project_url';
    select decrypted_secret into v_token from vault.decrypted_secrets where name = 'internal_cron_token';
    if v_url is null or v_token is null then
      raise warning 'cron-worker not configured (vault secrets missing)';
      return;
    end if;
    perform net.http_post(
      url := v_url || '/functions/v1/cron-worker',
      headers := jsonb_build_object('Content-Type', 'application/json', 'X-Internal-Token', v_token),
      body := jsonb_build_object('task', p_task),
      timeout_milliseconds := 8000);
  end $fn$;
  revoke all on function private.invoke_worker(text) from public, anon, authenticated;

  perform cron.schedule('agenda', '* * * * *', 'select public.svc_cron_agenda()');
  perform cron.schedule('housekeeping', '*/5 * * * *', 'select public.svc_cron_housekeeping()');
  -- Backstop for the session state machine; clients tick at every boundary themselves.
  perform cron.schedule('sessions', '10 seconds', 'select private.invoke_worker(''sessions'')');
  perform cron.schedule('outbox', '30 seconds', 'select private.invoke_worker(''outbox'')');
  perform cron.schedule('storage-gc', '*/5 * * * *', 'select private.invoke_worker(''storage_gc'')');
end
$outer$;
