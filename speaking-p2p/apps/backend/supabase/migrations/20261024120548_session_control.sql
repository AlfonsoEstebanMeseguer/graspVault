-- Pro exam control (DECISIONS D-038 leader, D-039 clock, D-040 exam switch).
-- The rule stays "the exam is a function of the clock": pausing freezes it
-- (paused_at), jumping moves exam_started_at, changing minutes rewrites the
-- session's own schedule (never exam_catalog).
-- private.ctl_apply is PURE (json in, json out) and mirrors
-- apps/mobile/lib/domain/exam/control.dart; both are pinned by
-- content/fixtures/control-golden.json.

alter table public.exam_sessions
  add column leader_id uuid references auth.users (id) on delete set null,
  add column pro_a boolean not null default false,
  add column pro_b boolean not null default false,
  add column paused_at timestamptz,
  add column pause_reason text,
  add column control_version int not null default 0,
  add column last_control jsonb,
  add column control_request_at timestamptz,
  add column content_version_a int,
  add column content_version_b int,
  add column applied_key text,
  add constraint exam_sessions_pause_reason_valid check (pause_reason is null or pause_reason in ('leader', 'switching'));

-- Being Pro inside a session is not private: the partner needs it to offer "hand control".
grant select (leader_id, pro_a, pro_b, paused_at, pause_reason, control_version, last_control, control_request_at)
  on public.exam_sessions to authenticated;

-- ------------------------------------------------------------- ms helpers
create or replace function private.to_ms(t timestamptz) returns bigint
language sql immutable as $$ select floor(extract(epoch from t) * 1000)::bigint $$;
create or replace function private.from_ms(ms bigint) returns timestamptz
language sql immutable as $$ select to_timestamp(ms / 1000.0) $$;

-- Same segments, new durations, laid out back to back from 0.
create or replace function private.ctl_with_durations(p_schedule jsonb, p_dur bigint[]) returns jsonb
language sql immutable as $$
  with seg as (select s, o from jsonb_array_elements(p_schedule -> 'segments') with ordinality x(s, o)),
  c as (select s, o, (sum(p_dur[o]) over (order by o))::bigint as e from seg)
  select jsonb_build_object(
    'segments', coalesce(jsonb_agg(s || jsonb_build_object('startMs', e - p_dur[o], 'endMs', e) order by o), '[]'::jsonb),
    'totalMs', coalesce(max(e), 0))
  from c
$$;

create or replace function private.ctl_durations(p_schedule jsonb) returns bigint[]
language sql immutable as $$
  select array_agg((s ->> 'endMs')::bigint - (s ->> 'startMs')::bigint order by o)
  from jsonb_array_elements(p_schedule -> 'segments') with ordinality x(s, o)
$$;

-- The speaking window the time controls act on: the current one, or the one
-- that follows the reader of the same step. A narration has none.
create or replace function private.ctl_speak_target(segs jsonb, idx int) returns int
language plpgsql set search_path = '' as $$
begin
  if segs -> idx ->> 'phase' = 'speak' then return idx; end if;
  if idx + 1 < jsonb_array_length(segs) and segs -> (idx + 1) ->> 'stepId' = segs -> idx ->> 'stepId' then return idx + 1; end if;
  perform private.fail('out_of_range');
end $$;

-- ------------------------------------------------------------- the reducer
-- p: {startedAtMs, pausedAtMs, pauseReason, feedbackEndsAtMs, version, examId, schedule}
-- Raises the same codes as control.dart (private.fail -> P0001 with the code).
create or replace function private.ctl_apply(p jsonb, p_op text, p_args jsonb, p_now bigint) returns jsonb
language plpgsql set search_path = '' as $$
declare
  sched jsonb := p -> 'schedule';
  segs jsonb := p -> 'schedule' -> 'segments';
  start_ms bigint := (p ->> 'startedAtMs')::bigint;
  paused bigint := (p ->> 'pausedAtMs')::bigint;
  reason text := p ->> 'pauseReason';
  fb_end bigint := (p ->> 'feedbackEndsAtMs')::bigint;
  total bigint := (p -> 'schedule' ->> 'totalMs')::bigint;
  ver int := coalesce((p ->> 'version')::int, 0) + 1;
  e bigint; idx int := -1; seg jsonb; fb_len bigint; target bigint; k int; dur bigint[]; delta bigint;
  v_ms bigint; ref jsonb; ref_dur bigint; new_sched jsonb; changed int[] := '{}';
begin
  if p_op = 'finish_switch' then
    if reason is distinct from 'switching' then perform private.fail('not_switching'); end if;
    start_ms := p_now + 3000;
    return p || jsonb_build_object('startedAtMs', start_ms, 'pausedAtMs', null, 'pauseReason', null,
      'feedbackEndsAtMs', start_ms + total + 300000, 'version', ver);
  end if;
  if reason = 'switching' then perform private.fail('switching'); end if;

  e := coalesce(paused, p_now) - start_ms;
  if e >= fb_end - start_ms then perform private.fail('not_in_exam'); end if;
  fb_len := fb_end - start_ms - total;
  if e < total then
    select (x ->> 'index')::int, x into idx, seg from jsonb_array_elements(segs) x
    where (x ->> 'startMs')::bigint <= greatest(e, 0) order by (x ->> 'startMs')::bigint desc limit 1;
  end if;

  case p_op
  when 'pause' then
    if idx < 0 then perform private.fail('not_in_part'); end if;
    if paused is not null then perform private.fail('already_paused'); end if;
    if e < 0 then perform private.fail('not_started'); end if;
    if seg ->> 'phase' <> 'speak' then perform private.fail('reader_speaking'); end if;
    return p || jsonb_build_object('pausedAtMs', p_now, 'pauseReason', 'leader', 'version', ver);
  when 'resume' then
    if reason is distinct from 'leader' then perform private.fail('not_paused'); end if;
    return p || jsonb_build_object('startedAtMs', start_ms + (p_now - paused), 'feedbackEndsAtMs', fb_end + (p_now - paused),
      'pausedAtMs', null, 'pauseReason', null, 'version', ver);
  when 'skip_reader' then
    if idx < 0 then perform private.fail('not_in_part'); end if;
    if seg ->> 'phase' <> 'reader' then perform private.fail('not_reader'); end if;
    target := (seg ->> 'endMs')::bigint;
  when 'next_step' then
    if idx < 0 then perform private.fail('not_in_part'); end if;
    select min((x ->> 'startMs')::bigint) into target from jsonb_array_elements(segs) x
    where (x ->> 'index')::int > idx and x ->> 'stepId' <> seg ->> 'stepId';
    target := coalesce(target, total);
  when 'next_part' then
    if idx < 0 then perform private.fail('not_in_part'); end if;
    select min((x ->> 'startMs')::bigint) into target from jsonb_array_elements(segs) x
    where (x ->> 'index')::int > idx and (x ->> 'part')::int > (seg ->> 'part')::int;
    target := coalesce(target, total);
  when 'end_exam' then
    if idx < 0 then perform private.fail('not_in_part'); end if;
    target := total;
  when 'repeat_step' then
    if idx < 0 then perform private.fail('not_in_part'); end if;
    select min((x ->> 'startMs')::bigint) into target from jsonb_array_elements(segs) x where x ->> 'stepId' = seg ->> 'stepId';
  when 'go_to_part' then
    select min((x ->> 'startMs')::bigint) into target from jsonb_array_elements(segs) x
    where (x ->> 'part')::int = (p_args ->> 'part')::int;
    if target is null then perform private.fail('out_of_range'); end if;
  when 'extend' then
    delta := (p_args ->> 'deltaMs')::bigint;
    if delta is null or delta not in (-30000, 30000, 60000, 120000) then perform private.fail('bad_delta'); end if;
    if idx < 0 then
      if fb_len + delta > 1200000 or fb_end + delta - coalesce(paused, p_now) < 5000 then perform private.fail('out_of_range'); end if;
      return p || jsonb_build_object('feedbackEndsAtMs', fb_end + delta, 'version', ver);
    end if;
    k := private.ctl_speak_target(segs, idx);
    dur := private.ctl_durations(sched);
    dur[k + 1] := dur[k + 1] + delta;
    changed := array[k];
  when 'set_part_speak' then
    if idx < 0 then perform private.fail('not_in_part'); end if;
    v_ms := (p_args ->> 'ms')::bigint;
    k := private.ctl_speak_target(segs, idx);
    ref := segs -> k;
    ref_dur := (ref ->> 'endMs')::bigint - (ref ->> 'startMs')::bigint;
    dur := private.ctl_durations(sched);
    select coalesce(array_agg((x ->> 'index')::int), '{}') into changed from jsonb_array_elements(segs) x
    where (x ->> 'index')::int >= k and x ->> 'part' = ref ->> 'part' and x ->> 'phase' = 'speak'
      and x ->> 'kind' = ref ->> 'kind' and (x ->> 'endMs')::bigint - (x ->> 'startMs')::bigint = ref_dur;
    for i in 1 .. coalesce(array_length(changed, 1), 0) loop dur[changed[i] + 1] := v_ms; end loop;
  when 'switch_exam' then
    if e < 0 then perform private.fail('not_started'); end if;
    new_sched := p_args -> 'schedule';
    return p || jsonb_build_object('examId', p_args ->> 'examId', 'schedule', new_sched, 'startedAtMs', p_now,
      'pausedAtMs', p_now, 'pauseReason', 'switching',
      'feedbackEndsAtMs', p_now + (new_sched ->> 'totalMs')::bigint + 300000, 'version', ver);
  else
    perform private.fail('bad_op');
  end case;

  if p_op in ('extend', 'set_part_speak') then
    for i in 1 .. coalesce(array_length(changed, 1), 0) loop
      k := changed[i];
      if dur[k + 1] < 10000 or dur[k + 1] > 900000 then perform private.fail('out_of_range'); end if;
      -- the running window may shrink, but must not end in the past
      if k = idx and (segs -> k ->> 'startMs')::bigint + dur[k + 1] <= e + 1000 then perform private.fail('out_of_range'); end if;
    end loop;
    new_sched := private.ctl_with_durations(sched, dur);
    return p || jsonb_build_object('schedule', new_sched,
      'feedbackEndsAtMs', fb_end + ((new_sched ->> 'totalMs')::bigint - total), 'version', ver);
  end if;

  -- a jump: clears any pause and keeps the feedback length
  start_ms := p_now - target;
  return p || jsonb_build_object('startedAtMs', start_ms, 'pausedAtMs', null, 'pauseReason', null,
    'feedbackEndsAtMs', start_ms + total + fb_len, 'version', ver);
end $$;

-- ------------------------------------------------------------- leader (D-038)
create or replace function private.assign_leader(p_session uuid, p_now timestamptz) returns void
language plpgsql set search_path = '' as $$
declare s public.exam_sessions; pa boolean; pb boolean; here_a boolean; here_b boolean; v uuid;
begin
  select * into s from public.exam_sessions where id = p_session for update;
  if s.state in ('ended', 'aborted') then return; end if;
  pa := s.user_a is not null and private.has_pro(s.user_a, p_now);
  pb := s.user_b is not null and private.has_pro(s.user_b, p_now);
  -- away = disconnected for more than 10 s
  here_a := s.disconnected_a_at is null or p_now - s.disconnected_a_at < interval '10 seconds';
  here_b := s.disconnected_b_at is null or p_now - s.disconnected_b_at < interval '10 seconds';
  v := s.leader_id;
  -- coalesce: with no leader yet (v null) the comparisons are null, not false.
  if not coalesce((v = s.user_a and pa and here_a) or (v = s.user_b and pb and here_b), false) then
    if pa and here_a and pb and here_b then v := case when random() < 0.5 then s.user_a else s.user_b end;
    elsif pa and here_a then v := s.user_a;
    elsif pb and here_b then v := s.user_b;
    elsif not coalesce((v = s.user_a and pa) or (v = s.user_b and pb), false) then v := null; -- away, but nobody else can lead: keep
    end if;
  end if;
  if v is distinct from s.leader_id then
    update public.exam_sessions set leader_id = v, pro_a = pa, pro_b = pb, control_version = control_version + 1,
      last_control = case when s.leader_id is null then last_control
                          else jsonb_build_object('op', 'transfer', 'by', v, 'at', p_now) end
    where id = p_session;
  elsif pa is distinct from s.pro_a or pb is distinct from s.pro_b then
    update public.exam_sessions set pro_a = pa, pro_b = pb where id = p_session;
  end if;
end $$;

create or replace function private.create_session(
  p_level text, p_u1 uuid, p_u2 uuid, p_origin text, p_meeting uuid, p_content_version int
) returns uuid
language plpgsql set search_path = '' as $$
declare
  v_a uuid; v_b uuid; v_exam text; v_id uuid;
begin
  -- Roles A/B are random (CLAUDE.md §4).
  if random() < 0.5 then v_a := p_u1; v_b := p_u2; else v_a := p_u2; v_b := p_u1; end if;
  v_exam := private.pick_exam(p_level, v_a, v_b, p_content_version);
  if v_exam is null then perform private.fail('no_exam_available'); end if;
  insert into public.exam_sessions (level, exam_id, exam_version, user_a, user_b, origin, meeting_id)
  select p_level, c.id, c.version, v_a, v_b, p_origin, p_meeting from public.exam_catalog c where c.id = v_exam
  returning id into v_id;
  perform private.assign_leader(v_id, now());
  return v_id;
end $$;

-- ------------------------------------------------------------- presence (+ content version)
drop function public.svc_session_presence(uuid, uuid, boolean, timestamptz);
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
      content_version_b = case when r = 'B' then coalesce(p_content_version, content_version_b) else content_version_b end
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

-- 'preloaded' is also accepted while switching exams (D-040).
create or replace function public.svc_session_set_flag(p_session uuid, p_user uuid, p_flag text, p_value boolean, p_now timestamptz default now())
returns text language plpgsql security definer set search_path = '' as $$
declare s public.exam_sessions; r text;
begin
  s := private.lock_session(p_session);
  r := private.session_role(s, p_user);
  if s.state <> 'lobby' and not (p_flag = 'preloaded' and s.pause_reason = 'switching') then
    perform private.fail('not_in_lobby');
  end if;
  if p_flag = 'ready' then
    update public.exam_sessions set ready_a = case when r = 'A' then p_value else ready_a end,
                                    ready_b = case when r = 'B' then p_value else ready_b end where id = p_session;
  elsif p_flag = 'preloaded' then
    update public.exam_sessions set preloaded_a = case when r = 'A' then p_value else preloaded_a end,
                                    preloaded_b = case when r = 'B' then p_value else preloaded_b end where id = p_session;
  elsif p_flag = 'recording' then
    update public.exam_sessions set recording_consent_a = case when r = 'A' then p_value else recording_consent_a end,
                                    recording_consent_b = case when r = 'B' then p_value else recording_consent_b end where id = p_session;
  else
    perform private.fail('unknown_flag');
  end if;
  if s.state <> 'lobby' then return s.state; end if;
  return private.try_start(p_session, p_now);
end $$;

-- ------------------------------------------------------------- mic policy
-- -2 = paused (both open, a pause is free conversation).
create or replace function private.mic_for(s public.exam_sessions, p_idx int) returns jsonb
language plpgsql immutable as $$
declare n int;
begin
  if s.state in ('ended', 'aborted') then return '{"A":false,"B":false}'; end if;
  if p_idx in (-1, -2) then return '{"A":true,"B":true}'; end if;
  n := jsonb_array_length(s.schedule -> 'segments');
  if p_idx >= n then return '{"A":true,"B":true}'; end if;
  return s.schedule -> 'segments' -> p_idx -> 'mic';
end $$;

-- Session row <-> reducer state.
create or replace function private.ctl_state(s public.exam_sessions) returns jsonb
language sql immutable as $$
  select jsonb_build_object('startedAtMs', private.to_ms(s.exam_started_at), 'pausedAtMs', private.to_ms(s.paused_at),
    'pauseReason', s.pause_reason, 'feedbackEndsAtMs', private.to_ms(s.feedback_ends_at), 'version', s.control_version,
    'examId', s.exam_id, 'schedule', s.schedule)
$$;

create or replace function private.ctl_store(p_session uuid, j jsonb, p_last jsonb) returns void
language sql set search_path = '' as $$
  update public.exam_sessions set
    exam_started_at = private.from_ms((j ->> 'startedAtMs')::bigint),
    paused_at = private.from_ms((j ->> 'pausedAtMs')::bigint),
    pause_reason = j ->> 'pauseReason',
    feedback_ends_at = private.from_ms((j ->> 'feedbackEndsAtMs')::bigint),
    schedule = j -> 'schedule',
    control_version = (j ->> 'version')::int,
    last_control = coalesce(p_last, last_control)
  where id = p_session
$$;

-- ------------------------------------------------------------- the leader's actions
create or replace function public.svc_session_control(p_session uuid, p_user uuid, p_op text, p_args jsonb default '{}',
  p_expected_version int default null, p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  s public.exam_sessions; r text; v_other uuid; c public.exam_catalog; cur public.exam_catalog; v_cv int; v_level text;
  v_exam text; j jsonb; v_last jsonb;
begin
  s := private.lock_session(p_session);
  r := private.session_role(s, p_user);
  if s.state in ('ended', 'aborted') then perform private.fail('session_closed'); end if;
  if s.leader_id is distinct from p_user then perform private.fail('not_leader'); end if;
  if not private.has_pro(p_user, p_now) then perform private.fail('not_pro'); end if;
  if p_expected_version is not null and p_expected_version <> s.control_version then perform private.fail('stale_control'); end if;
  v_last := jsonb_build_object('op', p_op, 'by', p_user, 'at', p_now, 'args', coalesce(p_args, '{}'::jsonb) - 'schedule');

  if p_op = 'transfer' then
    v_other := case when r = 'A' then s.user_b else s.user_a end;
    if v_other is null or not private.has_pro(v_other, p_now) then perform private.fail('partner_not_pro'); end if;
    update public.exam_sessions set leader_id = v_other, control_version = control_version + 1, last_control = v_last
    where id = p_session;
    return jsonb_build_object('version', s.control_version + 1);
  end if;

  if p_op = 'switch_exam' then
    select * into cur from public.exam_catalog where id = s.exam_id;
    v_cv := least(coalesce(s.content_version_a, cur.content_version), coalesce(s.content_version_b, cur.content_version));
    v_level := coalesce(p_args ->> 'level', s.level);
    v_exam := coalesce(p_args ->> 'examId', private.pick_exam(v_level, s.user_a, s.user_b, v_cv));
    select * into c from public.exam_catalog where id = v_exam and active;
    if not found then perform private.fail('not_found'); end if;
    if c.content_version > v_cv then perform private.fail('content_missing_partner'); end if;
    if c.id = s.exam_id then perform private.fail('out_of_range'); end if;
    v_last := v_last || jsonb_build_object('args', jsonb_build_object('examId', c.id));
    if s.state = 'lobby' then
      update public.exam_sessions set exam_id = c.id, exam_version = c.version, level = c.level,
        preloaded_a = false, preloaded_b = false, control_version = control_version + 1, last_control = v_last
      where id = p_session;
      return jsonb_build_object('version', s.control_version + 1);
    end if;
    j := private.ctl_apply(private.ctl_state(s), 'switch_exam', jsonb_build_object('examId', c.id, 'schedule', c.timeline),
                           private.to_ms(p_now));
    perform private.ctl_store(p_session, j, v_last);
    update public.exam_sessions set exam_id = c.id, exam_version = c.version, level = c.level,
      preloaded_a = false, preloaded_b = false, state = 'part1', step_index = 0
    where id = p_session;
    -- exam_history is one row per (user, session): it follows the exam being done.
    update public.exam_history set exam_id = c.id where session_id = p_session;
    return jsonb_build_object('version', (j ->> 'version')::int);
  end if;

  if s.state = 'lobby' then perform private.fail('not_started'); end if;
  j := private.ctl_apply(private.ctl_state(s), p_op, coalesce(p_args, '{}'::jsonb), private.to_ms(p_now));
  perform private.ctl_store(p_session, j, v_last);
  return jsonb_build_object('version', (j ->> 'version')::int);
end $$;

-- ------------------------------------------------------------- the state machine
-- Same contract as before (D-003), plus: pause (frozen clock, both mics open),
-- feedback end read from feedback_ends_at, exam switch completion, automatic
-- leader handover, caps (15 min pause, 3 h session) and the mic push keyed by
-- (control_version, segment) so a jump BACK is pushed too.
create or replace function public.svc_session_tick(p_session uuid, p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  s public.exam_sessions; v_elapsed bigint; v_total bigint; v_idx int; v_seg jsonb; v_n int; v_state text; v_key text;
begin
  s := private.lock_session(p_session);

  -- Disconnection grace: 60 s, then aborted.
  if s.state not in ('ended', 'aborted') then
    if s.disconnected_a_at is not null and p_now - s.disconnected_a_at >= interval '60 seconds' then
      update public.exam_sessions set state = 'aborted', abort_reason = 'disconnected', aborted_by = s.user_a, ended_at = p_now where id = p_session;
    elsif s.disconnected_b_at is not null and p_now - s.disconnected_b_at >= interval '60 seconds' then
      update public.exam_sessions set state = 'aborted', abort_reason = 'disconnected', aborted_by = s.user_b, ended_at = p_now where id = p_session;
    elsif s.state = 'lobby' and s.origin = 'live' and (s.joined_a_at is null or s.joined_b_at is null)
          and p_now - s.created_at >= interval '90 seconds' then
      -- A ghost from the live queue never showed up.
      update public.exam_sessions set state = 'aborted', abort_reason = 'no_show',
        aborted_by = case when s.joined_a_at is null then s.user_a else s.user_b end, ended_at = p_now where id = p_session;
    elsif s.state <> 'lobby' and p_now - s.created_at >= interval '3 hours' then
      update public.exam_sessions set state = 'ended', ended_at = p_now, step_index = null where id = p_session;
    end if;
    s := private.lock_session(p_session);
  end if;

  if s.state = 'lobby' then
    v_state := private.try_start(p_session, p_now);
    s := private.lock_session(p_session);
  end if;

  if s.state in ('lobby', 'ended', 'aborted') then
    v_idx := case when s.state = 'lobby' then -1 else coalesce(jsonb_array_length(s.schedule -> 'segments'), 0) + 1 end;
    v_key := s.control_version || ':' || v_idx;
    return jsonb_build_object('state', s.state, 'segment', v_idx, 'mic', private.mic_for(s, v_idx),
      'needs_push', s.state <> 'lobby' and s.exam_started_at is not null and s.applied_key is distinct from v_key,
      'key', v_key, 'paused', false, 'server_now', p_now, 'abort_reason', s.abort_reason);
  end if;

  perform private.assign_leader(p_session, p_now);
  s := private.lock_session(p_session);

  -- Both phones have the new exam (or 45 s passed): it starts with a 3 s lead.
  if s.pause_reason = 'switching' and ((s.preloaded_a and s.preloaded_b) or p_now - s.paused_at >= interval '45 seconds') then
    perform private.ctl_store(p_session, private.ctl_apply(private.ctl_state(s), 'finish_switch', '{}', private.to_ms(p_now)), null);
    s := private.lock_session(p_session);
  elsif s.pause_reason = 'leader' and p_now - s.paused_at >= interval '15 minutes' then
    perform private.ctl_store(p_session, private.ctl_apply(private.ctl_state(s), 'resume', '{}', private.to_ms(p_now)),
      jsonb_build_object('op', 'resume', 'by', null, 'at', p_now));
    s := private.lock_session(p_session);
  end if;

  v_elapsed := floor(extract(epoch from (coalesce(s.paused_at, p_now) - s.exam_started_at)) * 1000);
  v_total := (s.schedule ->> 'totalMs')::bigint;
  v_n := jsonb_array_length(s.schedule -> 'segments');

  -- paused_at, not now: a long pause near the end must not close the session.
  if coalesce(s.paused_at, p_now) >= s.feedback_ends_at then
    update public.exam_sessions set state = 'ended', ended_at = p_now, step_index = null where id = p_session;
    update public.exam_history set completed = true where session_id = p_session;
    update public.meetings set status = 'done' where id = s.meeting_id and status = 'confirmed';
    v_idx := v_n + 1; v_state := 'ended';
  elsif v_elapsed >= v_total then
    update public.exam_sessions set state = 'feedback', step_index = null,
      step_started_at = s.exam_started_at + make_interval(secs => v_total / 1000.0) where id = p_session;
    v_idx := v_n; v_state := 'feedback';
  else
    select (seg ->> 'index')::int, seg into v_idx, v_seg
    from jsonb_array_elements(s.schedule -> 'segments') seg
    where (seg ->> 'startMs')::bigint <= greatest(v_elapsed, 0)
    order by (seg ->> 'startMs')::bigint desc limit 1;
    v_state := 'part' || (v_seg ->> 'part');
    update public.exam_sessions set state = v_state, step_index = v_idx,
      step_started_at = s.exam_started_at + make_interval(secs => (v_seg ->> 'startMs')::bigint / 1000.0)
    where id = p_session;
  end if;
  s := private.lock_session(p_session);
  if s.paused_at is not null and v_state <> 'ended' then v_idx := -2; end if;
  v_key := s.control_version || ':' || v_idx;
  return jsonb_build_object('state', v_state, 'segment', v_idx, 'mic', private.mic_for(s, v_idx),
    'needs_push', s.applied_key is distinct from v_key, 'key', v_key, 'paused', s.paused_at is not null,
    'server_now', p_now, 'abort_reason', null);
end $$;

-- Compare-and-set by key: never overwrites the mark of a newer control version.
create or replace function public.svc_session_mark_applied_key(p_session uuid, p_key text) returns void
language sql security definer set search_path = '' as $$
  update public.exam_sessions set applied_key = p_key
  where id = p_session and control_version = split_part(p_key, ':', 1)::int
$$;

-- ------------------------------------------------------------- lock down
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname like 'svc\_%' loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
  for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'private' loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
end $$;
