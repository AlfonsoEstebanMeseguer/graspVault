-- Business rules that must hold under concurrency live here, in single
-- transactions, not in the Edge Functions (vault: "reglas criticas en backend,
-- comprobadas con for update en la misma transaccion").
--
-- Every svc_* function:
--   * is SECURITY DEFINER with search_path = '' (never a quoted list);
--   * takes the acting user explicitly (the Edge Function verified the JWT);
--   * is executable ONLY by service_role (PostgREST would expose it as a public RPC otherwise);
--   * takes p_now so tests can move the clock; Edge Functions never pass it.
-- Errors are raised with a stable machine code in MESSAGE and errcode P0001.
-- The Edge Function maps that code to an HTTP status and an i18n key.

alter table public.match_queue add column last_seen_at timestamptz not null default now();

-- ------------------------------------------------------------- small helpers
create or replace function private.fail(code text) returns void
language plpgsql as $$ begin raise exception '%', code using errcode = 'P0001'; end $$;

create or replace function private.lock_user(u uuid) returns void
language sql as $$ select pg_advisory_xact_lock(hashtextextended('user:' || u::text, 0)) $$;

-- Always lock two users in the same order, or two transactions deadlock.
create or replace function private.lock_users(a uuid, b uuid) returns void
language plpgsql as $$
begin
  if a::text < b::text then perform private.lock_user(a); perform private.lock_user(b);
  else perform private.lock_user(b); perform private.lock_user(a); end if;
end $$;

create or replace function private.has_subscription(p_user uuid, p_now timestamptz) returns boolean
language sql stable set search_path = '' as $$
  select coalesce((
    select e.subscription_status in ('active', 'grace', 'billing_issue', 'cancelled')
       and e.current_period_end > p_now
    from public.entitlements e where e.user_id = p_user), false)
$$;

create or replace function public.svc_is_eligible(p_user uuid, p_now timestamptz default now()) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.has_subscription(p_user, p_now)
      or coalesce((select e.trial_used_at is null from public.entitlements e where e.user_id = p_user), false)
$$;

create or replace function private.require_eligible(p_user uuid, p_now timestamptz) returns void
language plpgsql set search_path = '' as $$
begin
  if not public.svc_is_eligible(p_user, p_now) then perform private.fail('not_eligible'); end if;
end $$;

create or replace function private.active_session_of(p_user uuid) returns uuid
language sql stable set search_path = '' as $$
  select s.id from public.exam_sessions s
  where s.state not in ('ended', 'aborted') and p_user in (s.user_a, s.user_b)
  order by s.created_at desc limit 1
$$;

create or replace function private.system_message(p_chat uuid, p_code text, p_args jsonb default '{}') returns void
language sql set search_path = '' as $$
  insert into public.chat_messages (chat_id, sender_id, kind, system_code, system_args)
  values (p_chat, null, 'system', p_code, p_args)
$$;

create or replace function private.meeting_message(p_meeting uuid, p_code text, p_args jsonb default '{}') returns void
language sql set search_path = '' as $$
  select private.system_message(c.id, p_code, p_args) from public.chats c where c.meeting_id = p_meeting
$$;

-- ------------------------------------------------------------- onboarding
-- sha256() is a core function since PG 11: no extension needed.
create or replace function private.email_hash(p_email text) returns text
language sql immutable as $$
  select encode(sha256(convert_to(lower(btrim(coalesce(p_email, ''))), 'UTF8')), 'hex')
$$;

create or replace function public.svc_onboarding_complete(
  p_user uuid, p_email text, p_username text, p_languages text[], p_level text,
  p_birth_date date, p_phone text, p_terms_version text, p_now timestamptz default now()
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_claimed timestamptz;
begin
  if exists (select 1 from public.profiles where id = p_user) then perform private.fail('already_onboarded'); end if;
  if exists (select 1 from public.profiles where username = p_username) then perform private.fail('username_taken'); end if;
  insert into public.profiles (id, username, languages, target_level)
  values (p_user, p_username, p_languages, p_level);
  insert into public.profiles_private (id, birth_date, phone, terms_version, terms_accepted_at)
  values (p_user, p_birth_date, nullif(btrim(coalesce(p_phone, '')), ''), p_terms_version, p_now);
  -- A Google account that already burnt its trial (and deleted the account) gets no new one.
  select claimed_at into v_claimed from public.trial_claims
  where email_hash = private.email_hash(p_email);
  insert into public.entitlements (user_id, trial_used_at) values (p_user, v_claimed);
  return jsonb_build_object('trial_available', v_claimed is null);
end $$;


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

-- ------------------------------------------------------------- live matchmaking
-- Atomic FIFO per exact level. The per-level advisory lock serialises two
-- simultaneous enqueuers so neither inserts without seeing the other.
-- Clients call it every ~10 s while searching (heartbeat); stale rows never match.
create or replace function public.svc_match_enqueue(p_user uuid, p_level text, p_content_version int, p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_partner public.match_queue; v_session uuid; v_existing uuid;
begin
  if not private.is_level(p_level) then perform private.fail('bad_level'); end if;
  perform private.lock_user(p_user);
  v_existing := private.active_session_of(p_user);
  if v_existing is not null then
    delete from public.match_queue where user_id = p_user;
    return jsonb_build_object('status', 'matched', 'session_id', v_existing);
  end if;
  perform private.require_eligible(p_user, p_now);
  perform pg_advisory_xact_lock(hashtextextended('queue:' || p_level, 0));
  delete from public.match_queue where user_id = p_user and level <> p_level;

  loop
    select * into v_partner from public.match_queue
    where level = p_level and user_id <> p_user and last_seen_at > p_now - interval '25 seconds'
    order by enqueued_at limit 1 for update;
    exit when not found;
    delete from public.match_queue where user_id = v_partner.user_id;
    -- The partner's eligibility may have lapsed while waiting.
    if public.svc_is_eligible(v_partner.user_id, p_now) and private.active_session_of(v_partner.user_id) is null then
      delete from public.match_queue where user_id = p_user;
      v_session := private.create_session(p_level, p_user, v_partner.user_id, 'live', null,
                                          least(p_content_version, v_partner.content_version));
      return jsonb_build_object('status', 'matched', 'session_id', v_session);
    end if;
  end loop;

  insert into public.match_queue (user_id, level, content_version, enqueued_at, last_seen_at)
  values (p_user, p_level, p_content_version, p_now, p_now)
  on conflict (user_id) do update set last_seen_at = p_now, content_version = excluded.content_version;
  return jsonb_build_object('status', 'queued');
end $$;

create or replace function public.svc_match_cancel(p_user uuid) returns void
language sql security definer set search_path = '' as $$
  delete from public.match_queue where user_id = p_user
$$;

-- For the 15 s prompt: does the user have an open meeting (created or accepted)?
create or replace function public.svc_has_open_meeting(p_user uuid, p_now timestamptz default now()) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.meeting_offers o where o.creator_id = p_user and o.status = 'open' and o.window_end > p_now)
      or exists (select 1 from public.meetings m where p_user in (m.creator_id, m.acceptor_id)
                 and m.status in ('pending', 'confirmed') and m.scheduled_at > p_now - interval '10 minutes')
$$;

-- ------------------------------------------------------------- agenda
create or replace function public.svc_offer_create(p_user uuid, p_level text, p_start timestamptz, p_end timestamptz, p_now timestamptz default now())
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  perform private.require_eligible(p_user, p_now);
  if not private.is_level(p_level) then perform private.fail('bad_level'); end if;
  if p_start < p_now - interval '1 minute' or p_end > p_now + interval '7 days' then perform private.fail('window_out_of_range'); end if;
  if p_end < p_start + interval '30 minutes' then perform private.fail('window_too_short'); end if;
  perform private.lock_user(p_user);
  if (select count(*) from public.meeting_offers where creator_id = p_user and status = 'open' and window_end > p_now) >= 2 then
    perform private.fail('too_many_offers');
  end if;
  insert into public.meeting_offers (creator_id, level, window_start, window_end)
  values (p_user, p_level, p_start, p_end) returning id into v_id;
  return v_id;
end $$;

create or replace function public.svc_offer_cancel(p_user uuid, p_offer uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare o public.meeting_offers; m record;
begin
  select * into o from public.meeting_offers where id = p_offer for update;
  if not found or o.creator_id <> p_user then perform private.fail('not_found'); end if;
  if o.status <> 'open' then return; end if;
  update public.meeting_offers set status = 'cancelled' where id = p_offer;
  for m in select id from public.meetings where offer_id = p_offer and status = 'pending' loop
    update public.meetings set status = 'closed' where id = m.id;
    perform private.meeting_message(m.id, 'meeting_unavailable');
  end loop;
end $$;

create or replace function private.valid_slot(p_at timestamptz) returns boolean
language sql immutable as $$
  select extract(second from p_at) = 0 and extract(minute from p_at)::int % 5 = 0
$$;

create or replace function public.svc_offer_accept(p_user uuid, p_offer uuid, p_at timestamptz, p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path = '' as $$
declare o public.meeting_offers; v_meeting uuid; v_chat uuid;
begin
  perform private.require_eligible(p_user, p_now);
  select * into o from public.meeting_offers where id = p_offer for update;
  if not found or o.status <> 'open' or o.window_end <= p_now then perform private.fail('offer_unavailable'); end if;
  if o.creator_id = p_user then perform private.fail('own_offer'); end if;
  if p_at < o.window_start or p_at > o.window_end - interval '30 minutes' or p_at <= p_now or not private.valid_slot(p_at) then
    perform private.fail('bad_time');
  end if;
  if exists (select 1 from public.meetings where offer_id = p_offer and acceptor_id = p_user) then
    perform private.fail('already_accepted');
  end if;
  insert into public.meetings (offer_id, creator_id, acceptor_id, level, scheduled_at)
  values (p_offer, o.creator_id, p_user, o.level, p_at) returning id into v_meeting;
  insert into public.chats (meeting_id, user_a, user_b) values (v_meeting, o.creator_id, p_user) returning id into v_chat;
  perform private.system_message(v_chat, 'meeting_proposed',
    jsonb_build_object('by', p_user, 'scheduled_at', p_at, 'level', o.level));
  return jsonb_build_object('meeting_id', v_meeting, 'chat_id', v_chat);
end $$;

create or replace function private.lock_meeting(p_meeting uuid, p_user uuid) returns public.meetings
language plpgsql set search_path = '' as $$
declare m public.meetings;
begin
  select * into m from public.meetings where id = p_meeting for update;
  if not found or p_user is null or p_user not in (m.creator_id, m.acceptor_id) then perform private.fail('not_found'); end if;
  return m;
end $$;

-- Only pending meetings can be modified (a confirmed one is cancelled instead). Resets both confirmations.
create or replace function public.svc_meeting_modify(p_user uuid, p_meeting uuid, p_at timestamptz, p_level text, p_now timestamptz default now())
returns void language plpgsql security definer set search_path = '' as $$
declare m public.meetings;
begin
  m := private.lock_meeting(p_meeting, p_user);
  if m.status <> 'pending' then perform private.fail('not_pending'); end if;
  if not private.is_level(p_level) then perform private.fail('bad_level'); end if;
  if p_at <= p_now or p_at > p_now + interval '7 days' or not private.valid_slot(p_at) then perform private.fail('bad_time'); end if;
  update public.meetings set scheduled_at = p_at, level = p_level, creator_confirmed = false, acceptor_confirmed = false
  where id = p_meeting;
  perform private.meeting_message(p_meeting, 'meeting_modified',
    jsonb_build_object('by', p_user, 'scheduled_at', p_at, 'level', p_level));
end $$;

create or replace function private.has_overlap(p_user uuid, p_at timestamptz, p_except uuid) returns boolean
language sql stable set search_path = '' as $$
  select exists (
    select 1 from public.meetings m
    where m.status = 'confirmed' and m.id <> p_except and p_user in (m.creator_id, m.acceptor_id)
      and tstzrange(m.scheduled_at, m.scheduled_at + interval '30 minutes')
       && tstzrange(p_at, p_at + interval '30 minutes'))
$$;

create or replace function public.svc_meeting_confirm(p_user uuid, p_meeting uuid, p_now timestamptz default now())
returns text language plpgsql security definer set search_path = '' as $$
declare m public.meetings; v_other uuid; s record;
begin
  m := private.lock_meeting(p_meeting, p_user);
  v_other := case when p_user = m.creator_id then m.acceptor_id else m.creator_id end;
  if v_other is null then perform private.fail('partner_gone'); end if;
  perform private.lock_users(p_user, v_other);
  if m.status <> 'pending' then perform private.fail('not_pending'); end if;
  if m.scheduled_at <= p_now then perform private.fail('in_the_past'); end if;
  perform private.require_eligible(p_user, p_now);
  if private.has_overlap(p_user, m.scheduled_at, m.id) then perform private.fail('overlap'); end if;

  update public.meetings set
    creator_confirmed = creator_confirmed or p_user = m.creator_id,
    acceptor_confirmed = acceptor_confirmed or p_user = m.acceptor_id
  where id = p_meeting returning * into m;
  perform private.meeting_message(p_meeting, 'meeting_confirmed_by', jsonb_build_object('by', p_user));
  if not (m.creator_confirmed and m.acceptor_confirmed) then return 'pending'; end if;

  -- Second confirmation: the partner may have filled that slot meanwhile.
  if private.has_overlap(v_other, m.scheduled_at, m.id) then
    update public.meetings set creator_confirmed = p_user = m.creator_id, acceptor_confirmed = p_user = m.acceptor_id
    where id = p_meeting;
    perform private.meeting_message(p_meeting, 'meeting_partner_overlap', jsonb_build_object('user', v_other));
    return 'pending';
  end if;
  if m.offer_id is not null then
    perform 1 from public.meeting_offers where id = m.offer_id and status = 'open' for update;
    if not found then perform private.fail('offer_unavailable'); end if;
    update public.meeting_offers set status = 'filled' where id = m.offer_id;
    for s in select id from public.meetings where offer_id = m.offer_id and id <> p_meeting and status = 'pending' loop
      update public.meetings set status = 'closed' where id = s.id;
      perform private.meeting_message(s.id, 'meeting_unavailable');
    end loop;
  end if;
  update public.meetings set status = 'confirmed' where id = p_meeting;
  perform private.meeting_message(p_meeting, 'meeting_confirmed');
  return 'confirmed';
end $$;

create or replace function public.svc_meeting_cancel(p_user uuid, p_meeting uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare m public.meetings;
begin
  m := private.lock_meeting(p_meeting, p_user);
  if m.status not in ('pending', 'confirmed') then return; end if;
  update public.meetings set status = 'cancelled' where id = p_meeting;
  perform private.meeting_message(p_meeting, 'meeting_cancelled', jsonb_build_object('by', p_user));
end $$;

-- "Entrar a la sala": from 5 min before until the end of the 10 min courtesy.
create or replace function public.svc_meeting_enter(p_user uuid, p_meeting uuid, p_content_version int, p_now timestamptz default now())
returns uuid language plpgsql security definer set search_path = '' as $$
declare m public.meetings; v_session uuid;
begin
  m := private.lock_meeting(p_meeting, p_user);
  if m.status <> 'confirmed' then perform private.fail('not_confirmed'); end if;
  if p_now < m.scheduled_at - interval '5 minutes' then perform private.fail('too_early'); end if;
  select id into v_session from public.exam_sessions where meeting_id = p_meeting;
  if v_session is null then
    if p_now > m.scheduled_at + interval '10 minutes' then perform private.fail('too_late'); end if;
    v_session := private.create_session(m.level, m.creator_id, m.acceptor_id, 'meeting', p_meeting, p_content_version);
  end if;
  insert into public.attendance (meeting_id, user_id, attended) values (p_meeting, p_user, true)
  on conflict (meeting_id, user_id) do update set attended = true;
  return v_session;
end $$;

-- ------------------------------------------------------------- crons (pure SQL part)
create or replace function public.svc_cron_agenda(p_now timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r record; v_expired int := 0; v_reminders int := 0; v_no_shows int := 0;
begin
  -- 1. Offers whose last possible 30-min slot has passed.
  for r in select id from public.meeting_offers where status = 'open' and window_end - interval '30 minutes' < p_now for update loop
    update public.meeting_offers set status = 'expired' where id = r.id;
    v_expired := v_expired + 1;
  end loop;
  for r in select id from public.meetings where status = 'pending' and scheduled_at < p_now for update loop
    update public.meetings set status = 'closed' where id = r.id;
    perform private.meeting_message(r.id, 'meeting_expired');
  end loop;

  -- 2. Push 10 min before (outbox; the cron Edge Function delivers it).
  for r in select * from public.meetings where status = 'confirmed' and reminder_sent_at is null
           and scheduled_at between p_now and p_now + interval '10 minutes' for update loop
    insert into public.notification_outbox (user_id, kind, payload)
    select u, 'meeting_reminder', jsonb_build_object('meeting_id', r.id, 'scheduled_at', r.scheduled_at)
    from unnest(array[r.creator_id, r.acceptor_id]) u where u is not null;
    update public.meetings set reminder_sent_at = p_now where id = r.id;
    v_reminders := v_reminders + 1;
  end loop;

  -- 3. No-shows after the 10 min courtesy.
  for r in select m.*, s.id as session_id, s.joined_a_at, s.joined_b_at, s.state as session_state
           from public.meetings m left join public.exam_sessions s on s.meeting_id = m.id
           where m.status = 'confirmed' and m.scheduled_at + interval '10 minutes' < p_now for update of m loop
    if r.session_id is not null and r.joined_a_at is not null and r.joined_b_at is not null then
      continue; -- both showed up; the session itself will mark the meeting done
    end if;
    update public.meetings set status = 'no_show' where id = r.id;
    insert into public.attendance (meeting_id, user_id, attended)
    select r.id, u, false from unnest(array[r.creator_id, r.acceptor_id]) u where u is not null
    on conflict (meeting_id, user_id) do nothing;
    insert into public.notification_outbox (user_id, kind, payload)
    select a.user_id, 'partner_no_show', jsonb_build_object('meeting_id', r.id)
    from public.attendance a where a.meeting_id = r.id and a.attended;
    if r.session_id is not null and r.session_state = 'lobby' then
      update public.exam_sessions set state = 'aborted', abort_reason = 'no_show', ended_at = p_now where id = r.session_id;
    end if;
    v_no_shows := v_no_shows + 1;
  end loop;
  return jsonb_build_object('expired', v_expired, 'reminders', v_reminders, 'no_shows', v_no_shows);
end $$;

create or replace function public.svc_cron_housekeeping(p_now timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_queue int; v_rec int;
begin
  delete from public.match_queue where last_seen_at < p_now - interval '60 seconds';
  get diagnostics v_queue = row_count;
  insert into public.storage_gc_queue (object_key, reason)
  select recording_key, 'recording_expired' from public.exam_sessions
  where recording_key is not null and recording_expires_at < p_now;
  get diagnostics v_rec = row_count;
  update public.exam_sessions set recording_key = null
  where recording_key is not null and recording_expires_at < p_now;
  return jsonb_build_object('stale_queue', v_queue, 'recordings', v_rec);
end $$;

create or replace function public.svc_active_sessions() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select id from public.exam_sessions where state not in ('ended', 'aborted')
$$;

-- ------------------------------------------------------------- RevenueCat
create or replace function public.svc_apply_rc_event(
  p_event_id text, p_user uuid, p_status text, p_period_end timestamptz, p_event_at timestamptz
) returns boolean language plpgsql security definer set search_path = '' as $$
begin
  insert into public.revenuecat_events (event_id) values (p_event_id) on conflict do nothing;
  if not found then return false; end if; -- duplicate delivery
  update public.entitlements set subscription_status = p_status, current_period_end = p_period_end, last_rc_event_at = p_event_at
  where user_id = p_user and (last_rc_event_at is null or last_rc_event_at <= p_event_at);
  return true;
end $$;

-- ------------------------------------------------------------- account deletion
-- Runs before auth.admin.deleteUser: tells partners, frees slots, stops sessions.
create or replace function public.svc_account_prepare_delete(p_user uuid, p_now timestamptz default now()) returns void
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  delete from public.match_queue where user_id = p_user;
  update public.meeting_offers set status = 'cancelled' where creator_id = p_user and status = 'open';
  for r in select id from public.meetings where p_user in (creator_id, acceptor_id) and status in ('pending', 'confirmed') for update loop
    update public.meetings set status = 'cancelled' where id = r.id;
    perform private.meeting_message(r.id, 'partner_deleted_account');
  end loop;
  update public.exam_sessions set state = 'aborted', abort_reason = 'left', aborted_by = p_user, ended_at = p_now
  where state not in ('ended', 'aborted') and p_user in (user_a, user_b);
  -- Recordings carry this person's voice: they go too, for the partner as well (Art. 17 RGPD).
  insert into public.storage_gc_queue (object_key, reason)
  select recording_key, 'account_deleted' from public.exam_sessions
  where recording_key is not null and p_user in (user_a, user_b);
  update public.exam_sessions set recording_key = null, recording_expires_at = null
  where recording_key is not null and p_user in (user_a, user_b);
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
