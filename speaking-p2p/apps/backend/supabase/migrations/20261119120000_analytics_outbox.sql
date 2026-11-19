-- Product analytics from the server (D-063, docs/OBSERVABILITY.md).
--
-- The facts we trust (exam state, matches, meetings) change in many places: tick,
-- abort, the leader's controls, the agenda cron. Instead of a PostHog call in each
-- of them, triggers on the rows write ONE outbox row per user and per fact, inside
-- the same transaction: a fact that rolls back never reaches PostHog, and one
-- that commits is sent exactly once. cron-worker (task `analytics`) drains it.
--
-- No personal content ever goes in `properties`: only levels, parts and reasons.
-- `user_id` cascades, so deleting an account also drops its pending events.

create table public.analytics_outbox (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  event text not null,
  properties jsonb not null default '{}',
  created_at timestamptz not null default now(),
  attempts int not null default 0,
  constraint analytics_outbox_event_valid check (event in (
    'matchmaking_matched', 'exam_lobby_entered', 'exam_part_started', 'exam_completed', 'exam_aborted',
    'meeting_offer_created', 'meeting_accepted', 'meeting_confirmed', 'meeting_no_show'))
);
create index analytics_outbox_pending on public.analytics_outbox (id) where attempts < 5;

alter table public.analytics_outbox enable row level security;
revoke all on table public.analytics_outbox from anon, authenticated;
grant all on table public.analytics_outbox to service_role;

create or replace function private.analytics_emit(p_user uuid, p_event text, p_props jsonb) returns void
language sql security definer set search_path = '' as $$
  insert into public.analytics_outbox (user_id, event, properties)
  select p_user, p_event, jsonb_strip_nulls(p_props) where p_user is not null
$$;

-- ---------------------------------------------------------------- exam sessions
create or replace function private.analytics_sessions() returns trigger
language plpgsql security definer set search_path = '' as $$
declare u uuid; v_props jsonb := jsonb_build_object('level', new.level, 'origin', new.origin);
begin
  if tg_op = 'INSERT' then
    if new.origin = 'live' then
      foreach u in array array[new.user_a, new.user_b] loop
        perform private.analytics_emit(u, 'matchmaking_matched', v_props);
      end loop;
    end if;
    return null;
  end if;

  if new.joined_a_at is not null and old.joined_a_at is null then
    perform private.analytics_emit(new.user_a, 'exam_lobby_entered', v_props);
  end if;
  if new.joined_b_at is not null and old.joined_b_at is null then
    perform private.analytics_emit(new.user_b, 'exam_lobby_entered', v_props);
  end if;

  if new.state is distinct from old.state then
    foreach u in array array[new.user_a, new.user_b] loop
      if new.state in ('part1', 'part2', 'part3', 'part4') then
        perform private.analytics_emit(u, 'exam_part_started',
          v_props || jsonb_build_object('part', right(new.state, 1)::int));
      elsif new.state = 'ended' and old.state = 'feedback' then
        perform private.analytics_emit(u, 'exam_completed', v_props);
      elsif new.state = 'aborted' then
        perform private.analytics_emit(u, 'exam_aborted', v_props || jsonb_build_object(
          'at', old.state, 'reason', new.abort_reason,
          'by_me', case when new.aborted_by is null then null else new.aborted_by = u end));
      end if;
    end loop;
  end if;
  return null;
end $$;

create trigger exam_sessions_analytics after insert or update on public.exam_sessions
for each row execute function private.analytics_sessions();

-- ---------------------------------------------------------------- agenda
create or replace function private.analytics_offers() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform private.analytics_emit(new.creator_id, 'meeting_offer_created', jsonb_build_object('level', new.level));
  return null;
end $$;

create trigger meeting_offers_analytics after insert on public.meeting_offers
for each row execute function private.analytics_offers();

create or replace function private.analytics_meetings() returns trigger
language plpgsql security definer set search_path = '' as $$
declare u uuid; v_props jsonb := jsonb_build_object('level', new.level, 'origin', new.origin);
begin
  if tg_op = 'INSERT' and new.origin = 'offer' then
    perform private.analytics_emit(new.acceptor_id, 'meeting_accepted', v_props);
  end if;
  if new.status = 'confirmed' and (tg_op = 'INSERT' or old.status is distinct from 'confirmed') then
    foreach u in array array[new.creator_id, new.acceptor_id] loop
      perform private.analytics_emit(u, 'meeting_confirmed', v_props);
    end loop;
  end if;
  return null;
end $$;

create trigger meetings_analytics after insert or update of status on public.meetings
for each row execute function private.analytics_meetings();

-- The agenda cron writes attended = false for whoever did not show up.
create or replace function private.analytics_attendance() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not new.attended then
    perform private.analytics_emit(new.user_id, 'meeting_no_show', '{}');
  end if;
  return null;
end $$;

create trigger attendance_analytics after insert on public.attendance
for each row execute function private.analytics_attendance();

revoke all on function private.analytics_emit(uuid, text, jsonb), private.analytics_sessions(),
  private.analytics_offers(), private.analytics_meetings(), private.analytics_attendance()
  from public, anon, authenticated;

-- ---------------------------------------------------------------- drain
do $outer$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'pg_cron not available: skipping the analytics schedule';
    return;
  end if;
  perform cron.schedule('analytics', '* * * * *', 'select private.invoke_worker(''analytics'')');
end
$outer$;
