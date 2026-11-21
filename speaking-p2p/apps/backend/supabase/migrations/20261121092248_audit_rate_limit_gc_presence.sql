-- Security audit 2026-11 (docs/SECURITY_AUDIT_2026-11.md).
--
-- Point 12 (rate limiting): no Edge Function had a per-user limit, so one
--   account could fire hundreds of calls at paid paths (LiveKit, R2). A fixed
--   window counter per (user, bucket) lives here; Edge Functions call
--   svc_rate_hit before doing work and answer 429 rate_limited when it says no.
-- C8 avatar-unconfirmed-upload-no-gc: avatar-upload-url now queues the new key
--   for deletion one hour later (not_before); avatar-confirm cancels that row.
--   An upload that is never confirmed is therefore removed by storage_gc.
-- C4 session-actions/stale-livekit-token-canpublish-not-reconciled-on-rejoin:
--   a (re)join now clears applied_key, so the next tick re-pushes the current
--   mic policy to the new LiveKit connection instead of trusting its token.

-- ---------------------------------------------------------------- rate limit
create table private.rate_limits (
  user_id uuid not null,
  bucket text not null,
  window_start timestamptz not null,
  hits int not null default 0,
  primary key (user_id, bucket)
);
revoke all on table private.rate_limits from public, anon, authenticated;

-- true = allowed. Fixed window of p_window_sec seconds; one row per (user, bucket).
create or replace function public.svc_rate_hit(p_user uuid, p_bucket text, p_limit int, p_window_sec int, p_now timestamptz default now())
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_hits int;
begin
  if p_user is null or p_limit < 1 or p_window_sec < 1 then return false; end if;
  insert into private.rate_limits as r (user_id, bucket, window_start, hits)
  values (p_user, p_bucket, p_now, 1)
  on conflict (user_id, bucket) do update set
    hits = case when r.window_start <= p_now - make_interval(secs => p_window_sec) then 1 else r.hits + 1 end,
    window_start = case when r.window_start <= p_now - make_interval(secs => p_window_sec) then p_now else r.window_start end
  returning hits into v_hits;
  return v_hits <= p_limit;
end $$;
revoke all on function public.svc_rate_hit(uuid, text, int, int, timestamptz) from public, anon, authenticated;
grant execute on function public.svc_rate_hit(uuid, text, int, int, timestamptz) to service_role;

-- Old windows are useless after a day.
create or replace function private.purge_rate_limits(p_now timestamptz default now()) returns void
language sql security definer set search_path = '' as $$
  delete from private.rate_limits where window_start < p_now - interval '1 day';
$$;
revoke all on function private.purge_rate_limits(timestamptz) from public, anon, authenticated;
do $outer$
begin
  if not exists (select 1 from pg_namespace where nspname = 'cron') then
    raise notice 'pg_cron not available: skipping purge-rate-limits schedule';
    return;
  end if;
  perform cron.schedule('purge-rate-limits', '17 3 * * *', 'select private.purge_rate_limits()');
end $outer$;

-- ---------------------------------------------------------------- deferred GC (C8)
alter table public.storage_gc_queue add column not_before timestamptz not null default now();
create index storage_gc_queue_pending_due on public.storage_gc_queue (not_before) where status = 'pending';

-- ---------------------------------------------------------------- presence (C4)
create or replace function public.svc_session_presence(p_session uuid, p_user uuid, p_present boolean,
  p_now timestamptz default now(), p_content_version int default null)
returns void language plpgsql security definer set search_path = '' as $$
declare s public.exam_sessions; r text;
begin
  s := private.lock_session(p_session);
  r := private.session_role(s, p_user);
  if s.state in ('ended', 'aborted') then return; end if;
  if p_present then
    update public.exam_sessions set
      joined_a_at = case when r = 'A' then coalesce(joined_a_at, p_now) else joined_a_at end,
      joined_b_at = case when r = 'B' then coalesce(joined_b_at, p_now) else joined_b_at end,
      disconnected_a_at = case when r = 'A' then null else disconnected_a_at end,
      disconnected_b_at = case when r = 'B' then null else disconnected_b_at end,
      content_version_a = case when r = 'A' then coalesce(p_content_version, content_version_a) else content_version_a end,
      content_version_b = case when r = 'B' then coalesce(p_content_version, content_version_b) else content_version_b end,
      -- A new LiveKit connection gets its grants from its token: force a re-push (C4).
      applied_key = null
    where id = p_session;
    update public.exam_sessions set lobby_deadline = p_now + interval '5 minutes'
    where id = p_session and lobby_deadline is null and joined_a_at is not null and joined_b_at is not null;
  else
    update public.exam_sessions set
      disconnected_a_at = case when r = 'A' then coalesce(disconnected_a_at, p_now) else disconnected_a_at end,
      disconnected_b_at = case when r = 'B' then coalesce(disconnected_b_at, p_now) else disconnected_b_at end
    where id = p_session;
  end if;
  perform private.assign_leader(p_session, p_now);
end $$;
revoke all on function public.svc_session_presence(uuid, uuid, boolean, timestamptz, int) from public, anon, authenticated;
grant execute on function public.svc_session_presence(uuid, uuid, boolean, timestamptz, int) to service_role;
