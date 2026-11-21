-- Security audit 2026-11, hardening notes (docs/SECURITY_AUDIT_2026-11.md §6):
--  * invite -> cancel, accept -> cancel and modify cycles each write a system
--    message and/or a notification_outbox row to the partner, without limit:
--    a script could flood someone's chat and pushes. Daily per-user quotas now
--    cap them (svc_rate_hit buckets, purged with the rate limits).
--  * Confirming again after one's own tick wrote a new system message every time:
--    it is now a no-op.
--  * offer_taken_slots accepted any array size (20,000 ids in the sandbox): it now
--    reads at most the 100 offers the board shows.
-- Ceilings are far above what a person does through the app.

-- Raises rate_limited (429 in the Edge Functions) once the daily quota is spent.
-- Called right before the write, so failed validations never count; when it
-- fails, the transaction rolls back and the counter stays at the limit.
create or replace function private.agenda_quota(p_user uuid, p_bucket text, p_limit int, p_now timestamptz)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.svc_rate_hit(p_user, p_bucket, p_limit, 86400, p_now) then
    perform private.fail('rate_limited');
  end if;
end $$;
revoke all on function private.agenda_quota(uuid, text, int, timestamptz) from public, anon, authenticated;

-- ---------------------------------------------------------------- offers
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
  perform private.agenda_quota(p_user, 'agenda_offer', 20, p_now);
  insert into public.meeting_offers (creator_id, level, window_start, window_end)
  values (p_user, p_level, p_start, p_end) returning id into v_id;
  return v_id;
end $$;

create or replace function public.svc_offer_accept(p_user uuid, p_offer uuid, p_at timestamptz, p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path = '' as $$
declare o public.meeting_offers; v_meeting uuid; v_chat uuid; v_none constant uuid := '00000000-0000-0000-0000-000000000000';
begin
  perform private.require_eligible(p_user, p_now);
  select * into o from public.meeting_offers where id = p_offer for update;
  if not found or o.status <> 'open' or o.window_end <= p_now then perform private.fail('offer_unavailable'); end if;
  if o.creator_id = p_user then perform private.fail('own_offer'); end if;
  if private.blocked_between(p_user, o.creator_id) then perform private.fail('offer_unavailable'); end if;
  if p_at < o.window_start or p_at > o.window_end - interval '30 minutes' or p_at <= p_now or not private.valid_half_hour(p_at) then
    perform private.fail('bad_time');
  end if;
  if exists (select 1 from public.meetings where offer_id = p_offer and acceptor_id = p_user and status in ('pending', 'confirmed')) then
    perform private.fail('already_accepted');
  end if;
  perform private.lock_users(p_user, o.creator_id);
  if private.has_overlap(p_user, p_at, v_none) then perform private.fail('overlap'); end if;
  if private.has_overlap(o.creator_id, p_at, v_none) then perform private.fail('slot_taken'); end if;
  -- accept -> cancel -> accept on the same creator pushes them every time.
  perform private.agenda_quota(p_user, 'agenda_book:' || o.creator_id, 5, p_now);
  perform private.agenda_quota(p_user, 'agenda_book', 30, p_now);

  insert into public.meetings (offer_id, creator_id, acceptor_id, level, scheduled_at, creator_confirmed, acceptor_confirmed, status, origin)
  values (p_offer, o.creator_id, p_user, o.level, p_at, true, true, 'confirmed', 'offer') returning id into v_meeting;
  insert into public.chats (meeting_id, user_a, user_b) values (v_meeting, o.creator_id, p_user) returning id into v_chat;
  perform private.system_message(v_chat, 'meeting_booked', jsonb_build_object('by', p_user, 'scheduled_at', p_at, 'level', o.level));
  insert into public.notification_outbox (user_id, kind, payload)
  values (o.creator_id, 'meeting_booked', jsonb_build_object('meeting_id', v_meeting, 'scheduled_at', p_at));
  if not private.offer_has_free_slot(p_offer, p_now) then
    update public.meeting_offers set status = 'filled' where id = p_offer;
  end if;
  return jsonb_build_object('meeting_id', v_meeting, 'chat_id', v_chat);
end $$;

-- ---------------------------------------------------------------- invites
create or replace function public.svc_meeting_invite(p_user uuid, p_partner uuid, p_at timestamptz, p_level text, p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_meeting uuid; v_chat uuid; v_none constant uuid := '00000000-0000-0000-0000-000000000000';
begin
  perform private.require_eligible(p_user, p_now);
  if not private.is_level(p_level) then perform private.fail('bad_level'); end if;
  if p_partner is null or p_partner = p_user or not private.are_companions(p_user, p_partner)
     or private.blocked_between(p_user, p_partner) then
    perform private.fail('not_companion');
  end if;
  if p_at <= p_now or p_at > p_now + interval '7 days' or not private.valid_half_hour(p_at) then perform private.fail('bad_time'); end if;
  perform private.lock_users(p_user, p_partner);
  if private.has_overlap(p_user, p_at, v_none) then perform private.fail('overlap'); end if;
  if (select count(*) from public.meetings where creator_id = p_user and origin = 'invite' and status = 'pending' and scheduled_at > p_now) >= 3 then
    perform private.fail('too_many_invites');
  end if;
  -- invite -> cancel cycles push the companion every time.
  perform private.agenda_quota(p_user, 'agenda_invite:' || p_partner, 5, p_now);
  perform private.agenda_quota(p_user, 'agenda_invite', 20, p_now);
  insert into public.meetings (offer_id, creator_id, acceptor_id, level, scheduled_at, creator_confirmed, acceptor_confirmed, status, origin)
  values (null, p_user, p_partner, p_level, p_at, true, false, 'pending', 'invite') returning id into v_meeting;
  insert into public.chats (meeting_id, user_a, user_b) values (v_meeting, p_user, p_partner) returning id into v_chat;
  perform private.system_message(v_chat, 'meeting_invited', jsonb_build_object('by', p_user, 'scheduled_at', p_at, 'level', p_level));
  insert into public.notification_outbox (user_id, kind, payload)
  values (p_partner, 'meeting_invite', jsonb_build_object('meeting_id', v_meeting, 'scheduled_at', p_at));
  return jsonb_build_object('meeting_id', v_meeting, 'chat_id', v_chat);
end $$;

-- ---------------------------------------------------------------- meeting card
create or replace function public.svc_meeting_modify(p_user uuid, p_meeting uuid, p_at timestamptz, p_level text, p_now timestamptz default now())
returns void language plpgsql security definer set search_path = '' as $$
declare m public.meetings;
begin
  m := private.lock_meeting(p_meeting, p_user);
  if m.status not in ('pending', 'confirmed') then perform private.fail('not_pending'); end if;
  if m.creator_id is null or m.acceptor_id is null then perform private.fail('partner_gone'); end if;
  if private.blocked_between(m.creator_id, m.acceptor_id) then perform private.fail('not_found'); end if;
  if m.status = 'confirmed' and p_now >= m.scheduled_at - interval '5 minutes' then perform private.fail('too_late'); end if;
  if exists (select 1 from public.exam_sessions where meeting_id = m.id) then perform private.fail('too_late'); end if;
  if not private.is_level(p_level) then perform private.fail('bad_level'); end if;
  if p_at <= p_now or p_at > p_now + interval '7 days' or not private.valid_half_hour(p_at) then perform private.fail('bad_time'); end if;
  if private.has_overlap(p_user, p_at, m.id) then perform private.fail('overlap'); end if;
  perform private.agenda_quota(p_user, 'agenda_modify:' || p_meeting, 10, p_now);
  perform private.agenda_quota(p_user, 'agenda_modify', 50, p_now);
  update public.meetings set scheduled_at = p_at, level = p_level, status = 'pending', reminder_sent_at = null,
    creator_confirmed = p_user = m.creator_id, acceptor_confirmed = p_user = m.acceptor_id
  where id = p_meeting;
  perform private.meeting_message(p_meeting, 'meeting_modified',
    jsonb_build_object('by', p_user, 'scheduled_at', p_at, 'level', p_level));
end $$;

create or replace function public.svc_meeting_confirm(p_user uuid, p_meeting uuid, p_now timestamptz default now())
returns text language plpgsql security definer set search_path = '' as $$
declare m public.meetings; v_other uuid;
begin
  m := private.lock_meeting(p_meeting, p_user);
  v_other := case when p_user = m.creator_id then m.acceptor_id else m.creator_id end;
  if v_other is null then perform private.fail('partner_gone'); end if;
  if private.blocked_between(p_user, v_other) then perform private.fail('not_found'); end if;
  perform private.lock_users(p_user, v_other);
  if m.status <> 'pending' then perform private.fail('not_pending'); end if;
  if m.scheduled_at <= p_now then perform private.fail('in_the_past'); end if;
  -- Already ticked: nothing changes, so no new system message either.
  if (p_user = m.creator_id and m.creator_confirmed) or (p_user = m.acceptor_id and m.acceptor_confirmed) then
    return 'pending';
  end if;
  perform private.require_eligible(p_user, p_now);
  if private.has_overlap(p_user, m.scheduled_at, m.id) then perform private.fail('overlap'); end if;

  update public.meetings set
    creator_confirmed = creator_confirmed or p_user = m.creator_id,
    acceptor_confirmed = acceptor_confirmed or p_user = m.acceptor_id
  where id = p_meeting returning * into m;
  perform private.meeting_message(p_meeting, 'meeting_confirmed_by', jsonb_build_object('by', p_user));
  if not (m.creator_confirmed and m.acceptor_confirmed) then return 'pending'; end if;

  -- The partner may have filled that slot meanwhile.
  if private.has_overlap(v_other, m.scheduled_at, m.id) then
    update public.meetings set creator_confirmed = p_user = m.creator_id, acceptor_confirmed = p_user = m.acceptor_id
    where id = p_meeting;
    perform private.meeting_message(p_meeting, 'meeting_partner_overlap', jsonb_build_object('user', v_other));
    return 'pending';
  end if;
  update public.meetings set status = 'confirmed' where id = p_meeting;
  perform private.meeting_message(p_meeting, 'meeting_confirmed');
  return 'confirmed';
end $$;

-- ---------------------------------------------------------------- board
-- The board shows at most 100 offers (agenda_repository.dart): read no more.
create or replace function public.offer_taken_slots(p_offers uuid[])
returns table (offer_id uuid, scheduled_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select o.id, m.scheduled_at
  from public.meeting_offers o
  join public.meetings m on m.status = 'confirmed' and o.creator_id in (m.creator_id, m.acceptor_id)
   and m.scheduled_at > o.window_start - interval '30 minutes' and m.scheduled_at < o.window_end
  where o.id = any (p_offers[1:100]) and o.status = 'open' and o.window_end > now()
    and not public.is_blocked_with(o.creator_id)
$$;
