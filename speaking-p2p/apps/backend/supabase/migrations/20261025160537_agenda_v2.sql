-- Agenda v2 (D-046): direct booking, companions with direct invitations, and a
-- chat that only lives around its meeting. Plan: docs/plans/2026-10-25-agenda-rediseno.md §3.
--
-- * Picking a slot of an offer BOOKS it: the meeting is born confirmed. The offer
--   stays open with its remaining free slots and fills when none is left.
-- * "Cambiar hora" sends the meeting back to pending with the proposer's tick:
--   only the other person confirms.
-- * Companions: two people who finished an exam together and BOTH added each
--   other. Only companions can invite each other directly (one tap to accept).
-- * The chat can be written in while the meeting is alive and up to 2 h after its
--   time; afterwards it is read-only, and 30 days later it is deleted.
-- * Every start time sits on the 30-min UTC grid (D-028), also when modifying.

-- ---------------------------------------------------------------- meetings
alter table public.meetings add column origin text not null default 'offer';
alter table public.meetings add constraint meetings_origin_valid check (origin in ('offer', 'invite'));
grant select (origin) on public.meetings to authenticated;

-- One live booking per person and offer; a cancelled one no longer blocks booking again.
drop index public.meetings_one_acceptance_per_offer;
create unique index meetings_one_booking_per_offer on public.meetings (offer_id, acceptor_id)
  where status in ('pending', 'confirmed');

create or replace function private.valid_half_hour(p_at timestamptz) returns boolean
language sql immutable set search_path = '' as $$
  select extract(second from p_at) = 0 and extract(minute from p_at at time zone 'UTC')::int in (0, 30)
$$;

-- Does the creator still have a free 30-min slot in this offer (from now on)?
create or replace function private.offer_has_free_slot(p_offer uuid, p_now timestamptz) returns boolean
language sql stable set search_path = '' as $$
  select exists (
    select 1 from public.meeting_offers o,
      generate_series(
        to_timestamp(ceil(extract(epoch from greatest(o.window_start, p_now)) / 1800) * 1800),
        o.window_end - interval '30 minutes', interval '30 minutes') as t
    where o.id = p_offer and t > p_now
      and not private.has_overlap(o.creator_id, t, '00000000-0000-0000-0000-000000000000'))
$$;

-- ---------------------------------------------------------------- booking
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

-- Withdrawing an offer stops new bookings; meetings already booked from it stay.
create or replace function public.svc_offer_cancel(p_user uuid, p_offer uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare o public.meeting_offers;
begin
  select * into o from public.meeting_offers where id = p_offer for update;
  if not found or o.creator_id <> p_user then perform private.fail('not_found'); end if;
  if o.status <> 'open' then return; end if;
  update public.meeting_offers set status = 'cancelled' where id = p_offer;
end $$;

-- "Cambiar hora": back to pending with the proposer's tick; the other confirms.
create or replace function public.svc_meeting_modify(p_user uuid, p_meeting uuid, p_at timestamptz, p_level text, p_now timestamptz default now())
returns void language plpgsql security definer set search_path = '' as $$
declare m public.meetings;
begin
  m := private.lock_meeting(p_meeting, p_user);
  if m.status not in ('pending', 'confirmed') then perform private.fail('not_pending'); end if;
  if m.creator_id is null or m.acceptor_id is null then perform private.fail('partner_gone'); end if;
  if not private.is_level(p_level) then perform private.fail('bad_level'); end if;
  if p_at <= p_now or p_at > p_now + interval '7 days' or not private.valid_half_hour(p_at) then perform private.fail('bad_time'); end if;
  if private.has_overlap(p_user, p_at, m.id) then perform private.fail('overlap'); end if;
  update public.meetings set scheduled_at = p_at, level = p_level, status = 'pending', reminder_sent_at = null,
    creator_confirmed = p_user = m.creator_id, acceptor_confirmed = p_user = m.acceptor_id
  where id = p_meeting;
  perform private.meeting_message(p_meeting, 'meeting_modified',
    jsonb_build_object('by', p_user, 'scheduled_at', p_at, 'level', p_level));
end $$;

-- Confirming a pending meeting (an invitation or a changed time). There are no
-- competing acceptances any more, so nothing else is closed.
create or replace function public.svc_meeting_confirm(p_user uuid, p_meeting uuid, p_now timestamptz default now())
returns text language plpgsql security definer set search_path = '' as $$
declare m public.meetings; v_other uuid;
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

-- ---------------------------------------------------------------- companions
-- One row per pair (user_lo < user_hi). Active when both have added the other.
create table public.companions (
  user_lo uuid not null references auth.users (id) on delete cascade,
  user_hi uuid not null references auth.users (id) on delete cascade,
  added_lo_at timestamptz,
  added_hi_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (user_lo, user_hi),
  constraint companions_ordered check (user_lo < user_hi)
);
create index companions_by_hi on public.companions (user_hi);
alter table public.companions enable row level security;
revoke all on table public.companions from anon, authenticated;
grant all on table public.companions to service_role;

create or replace function private.are_companions(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.companions
                 where user_lo = least(a, b) and user_hi = greatest(a, b)
                   and added_lo_at is not null and added_hi_at is not null)
$$;

-- Add the partner of a finished exam (the session proves you have met).
create or replace function public.companion_add(p_session uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); s public.exam_sessions; v_other uuid;
begin
  if me is null then perform private.fail('not_authenticated'); end if;
  select * into s from public.exam_sessions where id = p_session;
  if not found or me not in (s.user_a, s.user_b) then perform private.fail('not_found'); end if;
  -- Reaching the feedback means the exam was done together ("Terminar" leaves before 'ended').
  if s.state not in ('feedback', 'ended') then perform private.fail('session_not_ended'); end if;
  v_other := case when me = s.user_a then s.user_b else s.user_a end;
  if v_other is null then perform private.fail('partner_gone'); end if;
  if private.blocked_between(me, v_other) then perform private.fail('bad_user'); end if;
  if (select count(*) from public.companions
      where (user_lo = me and added_lo_at is not null) or (user_hi = me and added_hi_at is not null)) >= 20
     and not exists (select 1 from public.companions where user_lo = least(me, v_other) and user_hi = greatest(me, v_other)
                     and case when me < v_other then added_lo_at else added_hi_at end is not null) then
    perform private.fail('too_many_companions');
  end if;
  insert into public.companions (user_lo, user_hi, added_lo_at, added_hi_at)
  values (least(me, v_other), greatest(me, v_other),
          case when me < v_other then now() end, case when me > v_other then now() end)
  on conflict (user_lo, user_hi) do update set
    added_lo_at = case when me < v_other then coalesce(public.companions.added_lo_at, now()) else public.companions.added_lo_at end,
    added_hi_at = case when me > v_other then coalesce(public.companions.added_hi_at, now()) else public.companions.added_hi_at end;
end $$;

-- Removing ends the companionship for both (my side is cleared; it was mutual).
create or replace function public.companion_remove(p_user uuid) returns void
language sql security definer set search_path = '' as $$
  update public.companions set
    added_lo_at = case when user_lo = auth.uid() then null else added_lo_at end,
    added_hi_at = case when user_hi = auth.uid() then null else added_hi_at end
  where user_lo = least(auth.uid(), p_user) and user_hi = greatest(auth.uid(), p_user)
$$;

-- My list: mutual companions, people I added and people who added me, with how
-- many exams we finished together and the last one (to add someone back). Only
-- rows about the caller.
create or replace function public.my_companions()
returns table (partner_id uuid, i_added boolean, they_added boolean, sessions_together int, last_session_id uuid, last_session_at timestamptz)
language sql stable security definer set search_path = '' as $$
  with me as (select auth.uid() as id),
  rows as (
    select case when c.user_lo = me.id then c.user_hi else c.user_lo end as partner_id,
           case when c.user_lo = me.id then c.added_lo_at else c.added_hi_at end is not null as i_added,
           case when c.user_lo = me.id then c.added_hi_at else c.added_lo_at end is not null as they_added
    from public.companions c, me where me.id in (c.user_lo, c.user_hi)
  )
  select r.partner_id, r.i_added, r.they_added,
         (select count(*)::int from public.exam_sessions s, me
          where s.state = 'ended' and ((s.user_a = me.id and s.user_b = r.partner_id) or (s.user_b = me.id and s.user_a = r.partner_id))),
         last.id, last.ended_at
  from rows r
  left join lateral (
    select s.id, s.ended_at from public.exam_sessions s, me
    where s.state = 'ended' and ((s.user_a = me.id and s.user_b = r.partner_id) or (s.user_b = me.id and s.user_a = r.partner_id))
    order by s.ended_at desc nulls last limit 1) last on true
  where (r.i_added or r.they_added) and not private.blocked_between((select id from me), r.partner_id)
$$;

-- Direct invitation to a companion: born with the inviter's tick, one tap from the other.
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
  insert into public.meetings (offer_id, creator_id, acceptor_id, level, scheduled_at, creator_confirmed, acceptor_confirmed, status, origin)
  values (null, p_user, p_partner, p_level, p_at, true, false, 'pending', 'invite') returning id into v_meeting;
  insert into public.chats (meeting_id, user_a, user_b) values (v_meeting, p_user, p_partner) returning id into v_chat;
  perform private.system_message(v_chat, 'meeting_invited', jsonb_build_object('by', p_user, 'scheduled_at', p_at, 'level', p_level));
  insert into public.notification_outbox (user_id, kind, payload)
  values (p_partner, 'meeting_invite', jsonb_build_object('meeting_id', v_meeting, 'scheduled_at', p_at));
  return jsonb_build_object('meeting_id', v_meeting, 'chat_id', v_chat);
end $$;

-- Blocking also ends the companionship (D-044 keeps cancelling the meetings).
create or replace function public.block_user(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); m record;
begin
  if me is null then perform private.fail('not_authenticated'); end if;
  if p_user is null or p_user = me then perform private.fail('bad_user'); end if;
  insert into public.user_blocks (blocker_id, blocked_id) values (me, p_user) on conflict do nothing;
  update public.companions set added_lo_at = null, added_hi_at = null
  where user_lo = least(me, p_user) and user_hi = greatest(me, p_user);
  for m in
    select mt.id, c.id as chat_id from public.meetings mt join public.chats c on c.meeting_id = mt.id
    where mt.status in ('pending', 'confirmed') and mt.scheduled_at > now() - interval '10 minutes'
      and ((mt.creator_id = me and mt.acceptor_id = p_user) or (mt.creator_id = p_user and mt.acceptor_id = me))
  loop
    update public.meetings set status = 'cancelled' where id = m.id;
    perform private.system_message(m.chat_id, 'meeting_cancelled', jsonb_build_object('by', me));
  end loop;
end $$;

-- ---------------------------------------------------------------- chat lifetime
-- Writable while the meeting is alive (or just happened) and up to 2 h after its time.
create policy chat_messages_meeting_alive on public.chat_messages as restrictive for insert to authenticated
  with check (exists (select 1 from public.chats c join public.meetings m on m.id = c.meeting_id
                      where c.id = chat_id and m.status in ('pending', 'confirmed', 'done', 'no_show')
                        and m.scheduled_at + interval '2 hours' > now()));
-- Short, organisational messages (existing longer ones stay valid).
alter table public.chat_messages add constraint chat_messages_user_body_short
  check (kind <> 'user' or char_length(body) <= 500) not valid;

-- Housekeeping also deletes chats of meetings that ended more than 30 days ago
-- (messages cascade), except those with an open report waiting for review.
create or replace function public.svc_cron_housekeeping(p_now timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_queue int; v_rec int; v_chats int;
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
  return jsonb_build_object('stale_queue', v_queue, 'recordings', v_rec, 'old_chats', v_chats);
end $$;

-- ---------------------------------------------------------------- board helper
-- Start times already taken in open offers (the creator is busy then). Only times,
-- never who: enough for the board to strike those slots out.
create or replace function public.offer_taken_slots(p_offers uuid[])
returns table (offer_id uuid, scheduled_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select o.id, m.scheduled_at
  from public.meeting_offers o
  join public.meetings m on m.status = 'confirmed' and o.creator_id in (m.creator_id, m.acceptor_id)
   and m.scheduled_at > o.window_start - interval '30 minutes' and m.scheduled_at < o.window_end
  where o.id = any (p_offers) and o.status = 'open' and o.window_end > now()
    and not public.is_blocked_with(o.creator_id)
$$;

-- ---------------------------------------------------------------- grants
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where (n.nspname = 'public' and p.proname like 'svc\_%') or n.nspname = 'private' loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
end $$;
revoke all on function public.companion_add(uuid), public.companion_remove(uuid), public.my_companions(),
  public.offer_taken_slots(uuid[]), public.block_user(uuid) from public, anon;
grant execute on function public.companion_add(uuid), public.companion_remove(uuid), public.my_companions(),
  public.offer_taken_slots(uuid[]), public.block_user(uuid) to authenticated;
