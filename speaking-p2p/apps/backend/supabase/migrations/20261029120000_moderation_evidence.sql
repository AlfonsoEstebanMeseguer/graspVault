-- Moderation, phase 1: evidence only, no sanctions (docs/plans/2026-10-29-plan-fase1-moderacion.md, D-051).
-- Every session leaves an objective trail without audio: an event log and the
-- speaking time of each candidate per stretch of the exam. Nobody reads either
-- from a client; the reviewer uses the service role (Supabase Studio).

-- ---------------------------------------------------------------- event log
create table public.session_events (
  id bigint generated always as identity primary key,
  session_id uuid not null references public.exam_sessions (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  kind text not null,
  state text,
  at timestamptz not null default now(),
  data jsonb not null default '{}',
  constraint session_events_kind_valid check (kind in (
    'joined', 'left', 'rejoined', 'ready', 'recording_consent', 'state', 'control',
    'self_mute', 'track_published', 'track_unpublished'))
);
create index session_events_by_session on public.session_events (session_id, at);

-- ---------------------------------------------------------------- speaking time
-- One row per stretch (segment, lobby or feedback) and per phone that measured it.
-- The figures come from LiveKit's active speakers (computed by the media server),
-- so both phones should agree; a disagreement is itself a signal.
create table public.session_talk_stats (
  session_id uuid not null references public.exam_sessions (id) on delete cascade,
  reporter_id uuid not null references auth.users (id) on delete cascade,
  seg_index int not null,
  started_at timestamptz not null,
  state text not null,
  phase text,
  paused boolean not null,
  mic_a boolean not null,
  mic_b boolean not null,
  window_ms int not null,
  speech_a_ms int not null,
  speech_b_ms int not null,
  overlap_ms int not null,
  received_at timestamptz not null default now(),
  primary key (session_id, reporter_id, seg_index, started_at),
  constraint session_talk_stats_state_valid check (state in ('lobby', 'part1', 'part2', 'part3', 'part4', 'feedback')),
  constraint session_talk_stats_phase_valid check (phase is null or phase in ('reader', 'speak')),
  constraint session_talk_stats_seg_valid check (seg_index between -1 and 500),
  constraint session_talk_stats_window_valid check (window_ms between 1000 and 1200000),
  constraint session_talk_stats_speech_valid check (
    speech_a_ms between 0 and window_ms and speech_b_ms between 0 and window_ms
    and overlap_ms between 0 and least(speech_a_ms, speech_b_ms))
);

alter table public.session_events enable row level security;
alter table public.session_talk_stats enable row level security;
revoke all on table public.session_events, public.session_talk_stats from anon, authenticated;
grant all on table public.session_events, public.session_talk_stats to service_role;

-- ---------------------------------------------------------------- what the server already decides
-- Logged from the row itself, so every path (presence, flags, tick, abort, the
-- leader's controls) is covered without touching ctl_apply or its golden contract.
create or replace function private.log_session_changes() returns trigger
language plpgsql security definer set search_path = '' as $$
declare st text := new.state;
begin
  if new.joined_a_at is distinct from old.joined_a_at and new.joined_a_at is not null then
    insert into public.session_events (session_id, user_id, kind, state) values (new.id, new.user_a, 'joined', st);
  end if;
  if new.joined_b_at is distinct from old.joined_b_at and new.joined_b_at is not null then
    insert into public.session_events (session_id, user_id, kind, state) values (new.id, new.user_b, 'joined', st);
  end if;
  if new.disconnected_a_at is distinct from old.disconnected_a_at then
    insert into public.session_events (session_id, user_id, kind, state)
    values (new.id, new.user_a, case when new.disconnected_a_at is null then 'rejoined' else 'left' end, st);
  end if;
  if new.disconnected_b_at is distinct from old.disconnected_b_at then
    insert into public.session_events (session_id, user_id, kind, state)
    values (new.id, new.user_b, case when new.disconnected_b_at is null then 'rejoined' else 'left' end, st);
  end if;
  if new.ready_a and not old.ready_a then
    insert into public.session_events (session_id, user_id, kind, state) values (new.id, new.user_a, 'ready', st);
  end if;
  if new.ready_b and not old.ready_b then
    insert into public.session_events (session_id, user_id, kind, state) values (new.id, new.user_b, 'ready', st);
  end if;
  if new.recording_consent_a is distinct from old.recording_consent_a then
    insert into public.session_events (session_id, user_id, kind, state, data)
    values (new.id, new.user_a, 'recording_consent', st, jsonb_build_object('value', new.recording_consent_a));
  end if;
  if new.recording_consent_b is distinct from old.recording_consent_b then
    insert into public.session_events (session_id, user_id, kind, state, data)
    values (new.id, new.user_b, 'recording_consent', st, jsonb_build_object('value', new.recording_consent_b));
  end if;
  if new.state is distinct from old.state then
    insert into public.session_events (session_id, user_id, kind, state, data)
    values (new.id, new.aborted_by, 'state', st,
            jsonb_strip_nulls(jsonb_build_object('from', old.state, 'to', new.state, 'reason', new.abort_reason)));
  end if;
  if new.last_control is distinct from old.last_control and new.last_control is not null then
    insert into public.session_events (session_id, user_id, kind, state, data)
    values (new.id, (new.last_control ->> 'by')::uuid, 'control', st, new.last_control);
  end if;
  return null;
end $$;

create trigger exam_sessions_log after update on public.exam_sessions
for each row execute function private.log_session_changes();

-- ---------------------------------------------------------------- what only the phones and LiveKit know
create or replace function public.svc_session_log(p_session uuid, p_user uuid, p_kind text, p_data jsonb default '{}',
  p_now timestamptz default now())
returns void language plpgsql security definer set search_path = '' as $$
declare s public.exam_sessions;
begin
  if p_kind not in ('self_mute', 'track_published', 'track_unpublished') then perform private.fail('bad_kind'); end if;
  select * into s from public.exam_sessions where id = p_session;
  if not found then perform private.fail('session_not_found'); end if;
  perform private.session_role(s, p_user);
  -- A noisy or hostile client cannot flood the log.
  if (select count(*) from public.session_events where session_id = p_session and user_id = p_user
        and kind in ('self_mute', 'track_published', 'track_unpublished')) >= 500 then
    return;
  end if;
  insert into public.session_events (session_id, user_id, kind, state, at, data)
  values (p_session, p_user, p_kind, s.state, p_now, coalesce(p_data, '{}'::jsonb));
end $$;

-- Windows: [{seg, startedAtMs, state, phase, paused, micA, micB, windowMs, speechAMs, speechBMs, overlapMs}]
create or replace function public.svc_session_talk_stats(p_session uuid, p_user uuid, p_windows jsonb,
  p_now timestamptz default now())
returns int language plpgsql security definer set search_path = '' as $$
declare s public.exam_sessions; w jsonb; v_at timestamptz; v_n int := 0; v_rows int;
begin
  select * into s from public.exam_sessions where id = p_session;
  if not found then perform private.fail('session_not_found'); end if;
  perform private.session_role(s, p_user);
  -- Nested: SQL does not promise to evaluate an "or" left to right.
  if jsonb_typeof(p_windows) is distinct from 'array' then perform private.fail('bad_stats'); end if;
  if jsonb_array_length(p_windows) not between 1 and 20 then perform private.fail('bad_stats'); end if;
  if (select count(*) from public.session_talk_stats where session_id = p_session and reporter_id = p_user) >= 1000 then
    return 0;
  end if;
  for w in select * from jsonb_array_elements(p_windows) loop
    begin
      v_at := private.from_ms((w ->> 'startedAtMs')::bigint);
      if v_at < s.created_at - interval '1 minute' or v_at > p_now + interval '1 minute' then
        perform private.fail('bad_stats');
      end if;
      insert into public.session_talk_stats (session_id, reporter_id, seg_index, started_at, state, phase, paused,
        mic_a, mic_b, window_ms, speech_a_ms, speech_b_ms, overlap_ms)
      values (p_session, p_user, coalesce((w ->> 'seg')::int, -1), v_at, w ->> 'state', w ->> 'phase',
        (w ->> 'paused')::boolean, (w ->> 'micA')::boolean, (w ->> 'micB')::boolean, (w ->> 'windowMs')::int,
        (w ->> 'speechAMs')::int, (w ->> 'speechBMs')::int, (w ->> 'overlapMs')::int)
      on conflict do nothing;
    exception when check_violation or not_null_violation or invalid_text_representation or numeric_value_out_of_range then
      perform private.fail('bad_stats');
    end;
    get diagnostics v_rows = row_count;
    v_n := v_n + v_rows;
  end loop;
  return v_n;
end $$;

-- ---------------------------------------------------------------- reports
alter table public.user_reports drop constraint user_reports_reason_valid;
alter table public.user_reports add constraint user_reports_reason_valid check (reason in (
  'harassment', 'sexual', 'hate', 'spam', 'minor_safety', 'no_show', 'other',
  'silent', 'quit', 'control_abuse', 'noise', 'mocking'));
create unique index user_reports_once_per_session on public.user_reports (reporter_id, reported_id, session_id)
  where session_id is not null;

-- Same signature as D-044 (the app keeps working). New: a session report only
-- counts if both people were in that session, sabotage reasons need a session,
-- and a second report on the same person in the same session changes nothing.
create or replace function public.report_user(
  p_user uuid, p_reason text, p_details text, p_context text, p_session uuid default null, p_chat uuid default null
) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); s public.exam_sessions;
begin
  if me is null then perform private.fail('not_authenticated'); end if;
  if p_user is null or p_user = me then perform private.fail('bad_user'); end if;
  if p_reason in ('silent', 'quit', 'control_abuse', 'noise', 'mocking') and p_session is null then
    perform private.fail('not_in_session');
  end if;
  if p_session is not null then
    select * into s from public.exam_sessions where id = p_session;
    if not found or not ((s.user_a = me and s.user_b = p_user) or (s.user_b = me and s.user_a = p_user)) then
      perform private.fail('not_in_session');
    end if;
  end if;
  -- Throttle: at most 10 reports a day per reporter (no flooding the review queue).
  if (select count(*) from public.user_reports where reporter_id = me and created_at > now() - interval '1 day') >= 10 then
    perform private.fail('rate_limited');
  end if;
  insert into public.user_reports (reporter_id, reported_id, reason, details, context, session_id, chat_id)
  values (me, p_user, p_reason, nullif(btrim(coalesce(p_details, '')), ''), p_context, p_session, p_chat)
  on conflict (reporter_id, reported_id, session_id) where session_id is not null do nothing;
end $$;

-- ---------------------------------------------------------------- retention (30 days, longer while a report is open)
create or replace function public.svc_cron_housekeeping(p_now timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_queue int; v_rec int; v_chats int; v_ev int; v_talk int;
begin
  delete from public.match_queue where last_seen_at < p_now - interval '60 seconds';
  get diagnostics v_queue = row_count;
  insert into public.storage_gc_queue (object_key, reason)
  select recording_key, 'recording_expired' from public.exam_sessions
  where recording_key is not null and recording_expires_at < p_now;
  get diagnostics v_rec = row_count;
  update public.exam_sessions set recording_key = null
  where recording_key is not null and recording_expires_at < p_now;
  delete from public.chats c using public.meetings m
  where m.id = c.meeting_id and m.status not in ('pending', 'confirmed') and m.scheduled_at < p_now - interval '30 days'
    and not exists (select 1 from public.user_reports r where r.chat_id = c.id and r.status = 'open');
  get diagnostics v_chats = row_count;
  delete from public.session_events e using public.exam_sessions s
  where s.id = e.session_id and s.created_at < p_now - interval '30 days'
    and not exists (select 1 from public.user_reports r where r.session_id = s.id and r.status = 'open');
  get diagnostics v_ev = row_count;
  delete from public.session_talk_stats t using public.exam_sessions s
  where s.id = t.session_id and s.created_at < p_now - interval '30 days'
    and not exists (select 1 from public.user_reports r where r.session_id = s.id and r.status = 'open');
  get diagnostics v_talk = row_count;
  return jsonb_build_object('stale_queue', v_queue, 'recordings', v_rec, 'old_chats', v_chats,
                            'evidence', v_ev + v_talk);
end $$;

-- ---------------------------------------------------------------- grants
revoke all on function public.svc_session_log(uuid, uuid, text, jsonb, timestamptz),
  public.svc_session_talk_stats(uuid, uuid, jsonb, timestamptz), private.log_session_changes()
  from public, anon, authenticated;
grant execute on function public.svc_session_log(uuid, uuid, text, jsonb, timestamptz),
  public.svc_session_talk_stats(uuid, uuid, jsonb, timestamptz) to service_role;
revoke all on function public.report_user(uuid, text, text, text, uuid, uuid) from public, anon;
grant execute on function public.report_user(uuid, text, text, text, uuid, uuid) to authenticated;
