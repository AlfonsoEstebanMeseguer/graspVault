-- Security audit 2026-11 (docs/SECURITY_AUDIT_2026-11.md).
--
-- C14 speaking-p2p/meetings:svc_meeting_modify-missing-blocked_between
--   A block was enforced once, inside block_user, and only for meetings scheduled
--   after now()-10 min. A meeting already under way survived the block and the
--   blocked user could modify it (back to pending, system messages in the
--   blocker's chat) or it could be confirmed/entered again.
--   Fix: block_user cancels every pending/confirmed meeting of the pair, and
--   modify/confirm/enter refuse a blocked pair (same answer as a missing meeting).
--
-- C15 speaking-p2p/meetings:svc_meeting_modify-accepts-started-meeting
--   modify accepted a confirmed meeting after its start, putting it back to
--   pending: the no-show sweep (confirmed only) skipped it, the partner's lobby
--   session was never aborted and the partner got no notice.
--   Fix: a confirmed meeting cannot be rescheduled once its entry window opened
--   (scheduled_at - 5 min) or once a session exists for it.

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

create or replace function public.svc_meeting_enter(p_user uuid, p_meeting uuid, p_content_version int, p_now timestamptz default now())
returns uuid language plpgsql security definer set search_path = '' as $$
declare m public.meetings; v_session uuid;
begin
  m := private.lock_meeting(p_meeting, p_user);
  if m.status <> 'confirmed' then perform private.fail('not_confirmed'); end if;
  if m.creator_id is null or m.acceptor_id is null then perform private.fail('partner_gone'); end if;
  if private.blocked_between(m.creator_id, m.acceptor_id) then perform private.fail('not_found'); end if;
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

-- Blocking ends every pending/confirmed meeting of the pair, also one under way.
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
    where mt.status in ('pending', 'confirmed')
      and ((mt.creator_id = me and mt.acceptor_id = p_user) or (mt.creator_id = p_user and mt.acceptor_id = me))
  loop
    update public.meetings set status = 'cancelled' where id = m.id;
    perform private.system_message(m.chat_id, 'meeting_cancelled', jsonb_build_object('by', me));
  end loop;
end $$;

-- create or replace keeps the existing grants; re-assert them anyway.
revoke all on function public.svc_meeting_modify(uuid, uuid, timestamptz, text, timestamptz) from public, anon, authenticated;
revoke all on function public.svc_meeting_confirm(uuid, uuid, timestamptz) from public, anon, authenticated;
revoke all on function public.svc_meeting_enter(uuid, uuid, int, timestamptz) from public, anon, authenticated;
grant execute on function public.svc_meeting_modify(uuid, uuid, timestamptz, text, timestamptz) to service_role;
grant execute on function public.svc_meeting_confirm(uuid, uuid, timestamptz) to service_role;
grant execute on function public.svc_meeting_enter(uuid, uuid, int, timestamptz) to service_role;
revoke all on function public.block_user(uuid) from public, anon;
grant execute on function public.block_user(uuid) to authenticated;
