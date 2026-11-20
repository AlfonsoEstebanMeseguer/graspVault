-- Part of the business rules (split in four so each migration fits one apply call).
-- Conventions: see the header of the first part.

-- ------------------------------------------------------------- sessions
create or replace function private.pick_exam(p_level text, p_a uuid, p_b uuid, p_content_version int) returns text
language sql volatile set search_path = '' as $$
  -- Never done by either first (NULLS FIRST); otherwise the one whose most
  -- recent use by either of the two is the oldest.
  select c.id from public.exam_catalog c
  where c.level = p_level and c.active and c.content_version <= p_content_version
  order by (select max(h.started_at) from public.exam_history h
            where h.exam_id = c.id and h.user_id in (p_a, p_b)) asc nulls first,
           random()
  limit 1
$$;

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
  return v_id;
end $$;

create or replace function private.session_role(s public.exam_sessions, p_user uuid) returns text
language plpgsql immutable as $$
begin
  if p_user = s.user_a then return 'A'; end if;
  if p_user = s.user_b then return 'B'; end if;
  raise exception 'not_participant' using errcode = 'P0001';
end $$;

create or replace function private.lock_session(p_session uuid) returns public.exam_sessions
language plpgsql set search_path = '' as $$
declare s public.exam_sessions;
begin
  select * into s from public.exam_sessions where id = p_session for update;
  if not found then perform private.fail('session_not_found'); end if;
  return s;
end $$;

-- Presence. Called when the client asks for its voice token and by the LiveKit webhook.
-- The 5-minute lobby clock starts when BOTH are in the room (DECISIONS D-008).
create or replace function public.svc_session_presence(p_session uuid, p_user uuid, p_present boolean, p_now timestamptz default now())
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
      disconnected_b_at = case when r = 'B' then null else disconnected_b_at end
    where id = p_session;
    update public.exam_sessions set lobby_deadline = p_now + interval '5 minutes'
    where id = p_session and lobby_deadline is null and joined_a_at is not null and joined_b_at is not null;
  else
    update public.exam_sessions set
      disconnected_a_at = case when r = 'A' then coalesce(disconnected_a_at, p_now) else disconnected_a_at end,
      disconnected_b_at = case when r = 'B' then coalesce(disconnected_b_at, p_now) else disconnected_b_at end
    where id = p_session;
  end if;
end $$;

-- Lobby toggles: 'ready', 'preloaded', 'recording'. Recording only if BOTH consent.
create or replace function public.svc_session_set_flag(p_session uuid, p_user uuid, p_flag text, p_value boolean, p_now timestamptz default now())
returns text language plpgsql security definer set search_path = '' as $$
declare s public.exam_sessions; r text;
begin
  s := private.lock_session(p_session);
  r := private.session_role(s, p_user);
  if s.state <> 'lobby' then perform private.fail('not_in_lobby'); end if;
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
  return private.try_start(p_session, p_now);
end $$;

-- Starts Part 1 when both are ready AND preloaded, or when the lobby deadline passed.
-- This is where the trial is consumed (CLAUDE.md §3: at the start of Part 1, not in the lobby).
create or replace function private.try_start(p_session uuid, p_now timestamptz) returns text
language plpgsql set search_path = '' as $$
declare
  s public.exam_sessions; c public.exam_catalog; u uuid; v_start timestamptz;
begin
  s := private.lock_session(p_session);
  if s.state <> 'lobby' then return s.state; end if;
  if s.joined_a_at is null or s.joined_b_at is null then return s.state; end if;
  if not ((s.ready_a and s.ready_b and s.preloaded_a and s.preloaded_b)
          or (s.lobby_deadline is not null and p_now >= s.lobby_deadline)) then
    return s.state;
  end if;
  -- Pass 1: both must still be eligible. Check before consuming anything.
  perform 1 from public.entitlements where user_id in (s.user_a, s.user_b) for update;
  foreach u in array array[s.user_a, s.user_b] loop
    if u is null or not public.svc_is_eligible(u, p_now) then
      update public.exam_sessions set state = 'aborted', abort_reason = 'ineligible', aborted_by = u, ended_at = p_now
      where id = p_session;
      return 'aborted';
    end if;
  end loop;
  -- Pass 2: consume the trial of whoever has no subscription.
  foreach u in array array[s.user_a, s.user_b] loop
    if not private.has_subscription(u, p_now) then
      update public.entitlements set trial_used_at = p_now, trial_session_id = p_session where user_id = u;
      insert into public.trial_claims (email_hash, claimed_at)
      select private.email_hash(au.email), p_now
      from auth.users au where au.id = u and au.email is not null
      on conflict do nothing;
    end if;
  end loop;
  select * into c from public.exam_catalog where id = s.exam_id;
  -- 3 s of lead so both clients receive the change before the reader starts.
  v_start := p_now + interval '3 seconds';
  update public.exam_sessions set
    state = 'part1', exam_started_at = v_start, schedule = c.timeline, step_index = 0, step_started_at = v_start,
    feedback_ends_at = v_start + make_interval(secs => (c.total_ms + 300000) / 1000.0)
  where id = p_session;
  insert into public.exam_history (user_id, exam_id, session_id, started_at)
  values (s.user_a, s.exam_id, p_session, p_now), (s.user_b, s.exam_id, p_session, p_now);
  return 'part1';
end $$;

-- Mic index space shared with applied_segment:
--   -1 = lobby (both open), 0..n-1 = timeline segments, n = feedback (both open), n+1 = closed.
create or replace function private.mic_for(s public.exam_sessions, p_idx int) returns jsonb
language plpgsql immutable as $$
declare n int;
begin
  if s.state in ('ended', 'aborted') then return '{"A":false,"B":false}'; end if;
  if p_idx = -1 then return '{"A":true,"B":true}'; end if;
  n := jsonb_array_length(s.schedule -> 'segments');
  if p_idx >= n then return '{"A":true,"B":true}'; end if;
  return s.schedule -> 'segments' -> p_idx -> 'mic';
end $$;

-- The state machine. Idempotent: calling it twice at the same instant changes nothing.
-- Clients call it at every boundary; a cron calls it as a backstop.
create or replace function public.svc_session_tick(p_session uuid, p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  s public.exam_sessions; v_elapsed bigint; v_total bigint; v_idx int; v_seg jsonb; v_n int; v_state text;
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
    end if;
    s := private.lock_session(p_session);
  end if;

  if s.state = 'lobby' then
    v_state := private.try_start(p_session, p_now);
    s := private.lock_session(p_session);
  end if;

  if s.state in ('lobby', 'ended', 'aborted') then
    v_idx := case when s.state = 'lobby' then -1 else coalesce(jsonb_array_length(s.schedule -> 'segments'), 0) + 1 end;
    return jsonb_build_object('state', s.state, 'segment', v_idx, 'mic', private.mic_for(s, v_idx),
      'needs_push', s.state <> 'lobby' and s.applied_segment < v_idx and s.exam_started_at is not null,
      'server_now', p_now, 'abort_reason', s.abort_reason);
  end if;

  v_elapsed := floor(extract(epoch from (p_now - s.exam_started_at)) * 1000);
  v_total := (s.schedule ->> 'totalMs')::bigint;
  v_n := jsonb_array_length(s.schedule -> 'segments');

  if v_elapsed >= v_total + 300000 then
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
  return jsonb_build_object('state', v_state, 'segment', v_idx, 'mic', private.mic_for(s, v_idx),
    'needs_push', s.applied_segment < v_idx, 'server_now', p_now, 'abort_reason', null);
end $$;

-- Compare-and-set after the Edge Function pushed the mic policy to LiveKit.
create or replace function public.svc_session_mark_applied(p_session uuid, p_idx int) returns void
language sql security definer set search_path = '' as $$
  update public.exam_sessions set applied_segment = greatest(applied_segment, p_idx) where id = p_session
$$;

create or replace function public.svc_session_abort(p_session uuid, p_user uuid, p_reason text default 'left', p_now timestamptz default now())
returns void language plpgsql security definer set search_path = '' as $$
declare s public.exam_sessions;
begin
  s := private.lock_session(p_session);
  perform private.session_role(s, p_user);
  if s.state in ('ended', 'aborted') then return; end if;
  if p_reason not in ('left', 'content_missing') then perform private.fail('bad_reason'); end if;
  -- The trial stays consumed if Part 1 had started (CLAUDE.md §6): nothing to refund here.
  update public.exam_sessions set state = 'aborted', abort_reason = p_reason, aborted_by = p_user, ended_at = p_now
  where id = p_session;
end $$;


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
