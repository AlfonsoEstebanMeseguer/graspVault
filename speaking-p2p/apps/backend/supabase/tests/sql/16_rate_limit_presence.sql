-- Security audit 2026-11: per-user rate limit (point 12), deferred avatar GC (C8),
-- mic re-push on (re)join (C4).
begin;
do $$
declare a uuid; b uuid; r jsonb; s uuid; i int; ok boolean; t0 timestamptz := now();
begin
  a := tests.user('rl_a', 'B2', true); b := tests.user('rl_b', 'B2', true);

  -- Fixed window: 3 allowed, the 4th refused, a new window allows again.
  for i in 1..3 loop
    perform tests.assert_eq(public.svc_rate_hit(a, 'test', 3, 60, t0), true, 'dentro del limite');
  end loop;
  perform tests.assert_eq(public.svc_rate_hit(a, 'test', 3, 60, t0), false, 'el cuarto se rechaza');
  perform tests.assert_eq(public.svc_rate_hit(b, 'test', 3, 60, t0), true, 'otro usuario no comparte cubo');
  perform tests.assert_eq(public.svc_rate_hit(a, 'test', 3, 60, t0 + interval '61 seconds'), true, 'ventana nueva');
  perform tests.as_user(a);
  perform tests.assert_fails(format('select public.svc_rate_hit(%L, ''x'', 1, 1)', a), 'permission denied', 'el cliente no toca el contador');
  reset role;

  -- Deferred GC rows are not due before not_before.
  insert into public.storage_gc_queue (object_key, reason, not_before) values ('avatars/x/y.jpg', 'avatar_unconfirmed', now() + interval '1 hour');
  perform tests.assert_eq((select count(*)::int from public.storage_gc_queue where status = 'pending' and not_before <= now() and object_key = 'avatars/x/y.jpg'), 0, 'aun no toca borrar');

  -- A rejoin clears applied_key so the next tick re-pushes the mic policy.
  perform public.svc_match_enqueue(a, 'B2', 1, t0);
  r := public.svc_match_enqueue(b, 'B2', 1, t0);
  s := (r ->> 'session_id')::uuid;
  perform public.svc_session_presence(s, a, true, t0);
  perform public.svc_session_presence(s, b, true, t0);
  perform public.svc_session_set_flag(s, a, 'ready', true, t0);
  perform public.svc_session_set_flag(s, b, 'ready', true, t0);
  perform public.svc_session_set_flag(s, a, 'preloaded', true, t0);
  perform tests.assert_eq(public.svc_session_set_flag(s, b, 'preloaded', true, t0), 'part1', 'C4 setup: part1');
  t0 := t0 + interval '100 milliseconds';
  r := public.svc_session_tick(s, t0);
  perform public.svc_session_mark_applied_key(s, r ->> 'key');
  perform tests.assert_eq((public.svc_session_tick(s, t0) ->> 'needs_push')::boolean, false, 'ya aplicado');
  perform public.svc_session_presence(s, a, false, t0);
  perform public.svc_session_presence(s, a, true, t0);
  perform tests.assert_eq((public.svc_session_tick(s, t0) ->> 'needs_push')::boolean, true, 'C4 reconectar fuerza re-push');
end $$;
rollback;
