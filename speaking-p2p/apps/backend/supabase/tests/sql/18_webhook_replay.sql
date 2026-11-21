-- C-H1: each webhook event id is processed once; old ids are purged.
begin;
do $$
declare a uuid;
begin
  perform tests.assert_eq(public.svc_webhook_first_seen('livekit', 'EV_1'), true, 'primera entrega');
  perform tests.assert_eq(public.svc_webhook_first_seen('livekit', 'EV_1'), false, 'replay rechazado');
  perform tests.assert_eq(public.svc_webhook_first_seen('otro', 'EV_1'), true, 'otro origen no comparte ids');
  perform tests.assert_eq(public.svc_webhook_first_seen('livekit', ''), false, 'id vacio');
  perform tests.assert_eq(public.svc_webhook_first_seen('livekit', repeat('x', 201)), false, 'id demasiado largo');
  perform tests.assert_eq(public.svc_webhook_first_seen('livekit', 'EV_old', now() - interval '2 days'), true, 'evento viejo');
  perform private.purge_webhook_events();
  perform tests.assert_eq((select count(*)::int from private.webhook_events where event_id = 'EV_old'), 0, 'purgado');
  perform tests.assert_eq((select count(*)::int from private.webhook_events where event_id = 'EV_1'), 2, 'reciente se conserva');

  a := tests.user('wh_a', 'B2', true);
  perform tests.as_user(a);
  perform tests.assert_fails('select public.svc_webhook_first_seen(''livekit'', ''x'')', 'permission denied', 'el cliente no lo llama');
  reset role;
end $$;
rollback;
