-- Worker crons only invoke cron-worker when their task has work (Edge Function quota).
begin;
do $$
declare a uuid; b uuid; r jsonb; t0 timestamptz := now();
begin
  delete from public.notification_outbox;
  delete from public.storage_gc_queue;
  delete from public.analytics_outbox;
  update public.exam_sessions set state = 'ended' where state not in ('ended', 'aborted');

  perform tests.assert_eq(private.cron_has_work('sessions'), false, 'sin sesiones activas');
  perform tests.assert_eq(private.cron_has_work('outbox'), false, 'outbox vacio');
  perform tests.assert_eq(private.cron_has_work('storage_gc'), false, 'gc vacio');
  perform tests.assert_eq(private.cron_has_work('analytics'), false, 'analytics vacio');
  perform tests.assert_eq(private.cron_has_work('otra'), false, 'tarea desconocida');

  a := tests.user('cw_a', 'B2', true); b := tests.user('cw_b', 'B2', true);
  perform public.svc_match_enqueue(a, 'B2', 1, t0);
  r := public.svc_match_enqueue(b, 'B2', 1, t0);
  perform tests.assert_eq(private.cron_has_work('sessions'), true, 'sesion en lobby');
  update public.exam_sessions set state = 'aborted' where id = (r ->> 'session_id')::uuid;
  perform tests.assert_eq(private.cron_has_work('sessions'), false, 'sesion abortada');

  insert into public.notification_outbox (user_id, kind, attempts) values (a, 'x', 5);
  perform tests.assert_eq(private.cron_has_work('outbox'), false, 'agotados los reintentos');
  insert into public.notification_outbox (user_id, kind, sent_at) values (a, 'x', now());
  perform tests.assert_eq(private.cron_has_work('outbox'), false, 'ya enviado');
  insert into public.notification_outbox (user_id, kind) values (a, 'x');
  perform tests.assert_eq(private.cron_has_work('outbox'), true, 'pendiente');

  insert into public.storage_gc_queue (object_key, reason, not_before) values ('k1', 'r', now() + interval '1 hour');
  perform tests.assert_eq(private.cron_has_work('storage_gc'), false, 'aun no toca borrar');
  perform tests.assert_eq(private.cron_has_work('storage_gc', now() + interval '2 hours'), true, 'ya toca borrar');
  insert into public.storage_gc_queue (object_key, reason, status) values ('k2', 'r', 'failed');
  perform tests.assert_eq(private.cron_has_work('storage_gc'), false, 'fallido no cuenta');

  delete from public.analytics_outbox; -- the match above emitted events
  insert into public.analytics_outbox (user_id, event, attempts) values (a, 'exam_completed', 5);
  perform tests.assert_eq(private.cron_has_work('analytics'), false, 'agotado y reciente');
  perform tests.assert_eq(private.cron_has_work('analytics', now() + interval '8 days'), true, 'viejo: hay que purgar');
  insert into public.analytics_outbox (user_id, event) values (a, 'exam_completed');
  perform tests.assert_eq(private.cron_has_work('analytics'), true, 'pendiente de enviar');

  perform tests.as_user(a);
  perform tests.assert_fails('select private.cron_has_work(''outbox'')', 'permission denied', 'el cliente no lo llama');
  reset role;
end $$;
rollback;
