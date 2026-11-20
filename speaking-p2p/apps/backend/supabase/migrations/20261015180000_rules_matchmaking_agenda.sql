-- Part of the business rules (split in four so each migration fits one apply call).
-- Conventions: see the header of the first part.

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
