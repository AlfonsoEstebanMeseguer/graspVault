-- Edge Function quota (free plan: 500k invocations/month). The four worker crons
-- called cron-worker unconditionally, ~13k invocations/day while idle (measured
-- 2026-11-21: 77,954 in the first 6 days of the billing period). Each cron now
-- asks the database first and only invokes the function when its task has work.
-- The predicates mirror what cron-worker selects for each task.

create or replace function private.cron_has_work(p_task text, p_now timestamptz default now())
returns boolean language sql stable security definer set search_path = '' as $$
  select case p_task
    when 'sessions' then exists (
      select 1 from public.exam_sessions where state not in ('ended', 'aborted'))
    when 'outbox' then exists (
      select 1 from public.notification_outbox where sent_at is null and attempts < 5)
    when 'storage_gc' then exists (
      select 1 from public.storage_gc_queue where status = 'pending' and not_before <= p_now)
    -- The worker also drops rows older than 7 days, sent or not.
    when 'analytics' then exists (
      select 1 from public.analytics_outbox where attempts < 5 or created_at < p_now - interval '7 days')
    else false
  end
$$;
revoke all on function private.cron_has_work(text, timestamptz) from public, anon, authenticated;

do $outer$
begin
  if not exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    raise notice 'pg_cron not available: skipping cron schedules';
    return;
  end if;
  -- cron.schedule with an existing job name replaces its schedule and command.
  perform cron.schedule('sessions', '10 seconds',
    'select private.invoke_worker(''sessions'') where private.cron_has_work(''sessions'')');
  perform cron.schedule('outbox', '30 seconds',
    'select private.invoke_worker(''outbox'') where private.cron_has_work(''outbox'')');
  perform cron.schedule('storage-gc', '*/5 * * * *',
    'select private.invoke_worker(''storage_gc'') where private.cron_has_work(''storage_gc'')');
  -- Analytics is not latency-sensitive: every 5 minutes instead of every minute.
  perform cron.schedule('analytics', '*/5 * * * *',
    'select private.invoke_worker(''analytics'') where private.cron_has_work(''analytics'')');
end
$outer$;
