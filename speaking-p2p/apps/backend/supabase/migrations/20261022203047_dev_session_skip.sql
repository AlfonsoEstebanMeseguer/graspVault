-- Debug "skip" inside a session (DECISIONS D-031). While app_config.dev_session_skip
-- is true, either participant can jump to the next boundary: lobby -> Part 1,
-- segment -> next segment, last segment -> feedback, feedback -> ended.
-- The exam clock is (now - exam_started_at), so skipping = moving exam_started_at
-- back by what is left of the current segment. Both clients see the new value
-- through Realtime and rebuild their engine; the tick that follows pushes the mic
-- policy to LiveKit as usual. Switch the flag off before launch: it fails closed.

insert into public.app_config (key, value) values ('dev_session_skip', 'true')
on conflict (key) do nothing;

create or replace function public.svc_session_debug_skip(p_session uuid, p_user uuid, p_now timestamptz default now())
returns void language plpgsql security definer set search_path = '' as $$
declare s public.exam_sessions; v_elapsed bigint; v_total bigint; v_target bigint; v_shift interval;
begin
  if not coalesce((select (value)::text = 'true' from public.app_config where key = 'dev_session_skip'), false) then
    perform private.fail('not_found');
  end if;
  s := private.lock_session(p_session);
  perform private.session_role(s, p_user);
  if s.state in ('ended', 'aborted') then return; end if;

  if s.state = 'lobby' then
    -- try_start honours the deadline (it still needs both in the room).
    update public.exam_sessions set lobby_deadline = p_now where id = p_session;
    return;
  end if;

  v_elapsed := floor(extract(epoch from (p_now - s.exam_started_at)) * 1000);
  v_total := (s.schedule ->> 'totalMs')::bigint;
  if v_elapsed >= v_total then
    v_target := v_total + 300000;                -- feedback -> ended
  else
    select min((seg ->> 'startMs')::bigint) into v_target
    from jsonb_array_elements(s.schedule -> 'segments') seg
    where (seg ->> 'startMs')::bigint > v_elapsed;
    v_target := coalesce(v_target, v_total);    -- last segment -> feedback
  end if;

  v_shift := make_interval(secs => (v_target - v_elapsed) / 1000.0);
  update public.exam_sessions set
    exam_started_at = exam_started_at - v_shift,
    feedback_ends_at = feedback_ends_at - v_shift
  where id = p_session;
end $$;

revoke all on function public.svc_session_debug_skip(uuid, uuid, timestamptz) from public, anon, authenticated;
grant execute on function public.svc_session_debug_skip(uuid, uuid, timestamptz) to service_role;
