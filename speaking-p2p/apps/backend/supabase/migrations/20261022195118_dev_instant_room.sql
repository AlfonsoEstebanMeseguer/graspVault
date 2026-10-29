-- Debug "instant room" (DECISIONS D-029). While app_config.dev_instant_rooms is
-- true, either member of a pending/confirmed meeting can open a room right now,
-- skipping the -5/+10 min window. The session is a plain 'live' one with no
-- meeting attached, so the meeting card never turns into done/no_show and the
-- button can be pressed again after a session ends. The second member who
-- presses it within 5 minutes joins the same lobby. Switch the flag off before
-- launch: the function then fails closed.

insert into public.app_config (key, value) values ('dev_instant_rooms', 'true')
on conflict (key) do nothing;

create or replace function public.svc_meeting_enter_now(p_user uuid, p_meeting uuid, p_content_version int, p_now timestamptz default now())
returns uuid language plpgsql security definer set search_path = '' as $$
declare m public.meetings; v_session uuid;
begin
  if not coalesce((select (value)::text = 'true' from public.app_config where key = 'dev_instant_rooms'), false) then
    perform private.fail('not_found');
  end if;
  m := private.lock_meeting(p_meeting, p_user);
  if m.status not in ('pending', 'confirmed') then perform private.fail('not_confirmed'); end if;
  select s.id into v_session from public.exam_sessions s
   where s.origin = 'live' and s.state = 'lobby' and s.created_at > p_now - interval '5 minutes'
     and ((s.user_a = m.creator_id and s.user_b = m.acceptor_id) or (s.user_a = m.acceptor_id and s.user_b = m.creator_id))
   order by s.created_at desc limit 1;
  if v_session is null then
    v_session := private.create_session(m.level, m.creator_id, m.acceptor_id, 'live', null, p_content_version);
  end if;
  return v_session;
end $$;

revoke all on function public.svc_meeting_enter_now(uuid, uuid, int, timestamptz) from public, anon, authenticated;
grant execute on function public.svc_meeting_enter_now(uuid, uuid, int, timestamptz) to service_role;
