-- Reporting and blocking (D-044).
begin;
do $$
declare a uuid; b uuid; c uuid; o uuid; r jsonb; t0 timestamptz := now(); chat uuid; at timestamptz;
begin
  a := tests.user('blk_a', 'B2', true); b := tests.user('blk_b', 'B2', true); c := tests.user('blk_c', 'B2', true);
  at := date_trunc('hour', t0) + interval '3 hours';

  -- b has an offer; a accepts it, so they share a chat and a pending meeting.
  o := public.svc_offer_create(b, 'B2', at, at + interval '2 hours', t0);
  r := public.svc_offer_accept(a, o, at, t0);
  chat := (r ->> 'chat_id')::uuid;

  perform tests.as_user(a);
  perform public.block_user(b);
  perform public.block_user(b); -- twice is fine
  perform tests.assert_eq((select count(*)::int from public.user_blocks), 1, 'veo mi bloqueo');
  perform tests.assert_fails(format('insert into public.chat_messages (chat_id, body, client_id) values (%L, %L, gen_random_uuid())', chat, 'hola'),
                             'row-level security', 'no se escribe en el chat de un bloqueado');
  perform tests.assert_eq((select count(*)::int from public.meeting_offers where id = o), 0, 'no veo sus ofertas');
  perform tests.assert_fails(format('select public.block_user(%L)', a), 'bad_user', 'no me bloqueo a mí');
  perform public.report_user(b, 'harassment', '  insultos  ', 'chat', null, chat);
  perform tests.assert_fails('select count(*) from public.user_reports', 'permission denied', 'nadie lee los reportes');
  reset role;

  perform tests.assert_eq((select status from public.meetings where offer_id = o), 'cancelled', 'bloquear cancela la reunión');
  perform tests.assert_eq((select details from public.user_reports), 'insultos', 'el reporte se guarda limpio');

  -- The blocked side sees nothing of the block and cannot write either.
  perform tests.as_user(b);
  perform tests.assert_eq((select count(*)::int from public.user_blocks), 0, 'el bloqueado no ve el bloqueo');
  perform tests.assert_fails(format('insert into public.chat_messages (chat_id, body, client_id) values (%L, %L, gen_random_uuid())', chat, 'hola'),
                             'row-level security', 'el bloqueado tampoco escribe');
  reset role;

  -- Matchmaking never pairs a blocked pair; a third person still matches.
  perform public.svc_match_enqueue(a, 'B2', 1, t0);
  perform tests.assert_eq(public.svc_match_enqueue(b, 'B2', 1, t0) ->> 'status', 'queued', 'bloqueados no se emparejan');
  perform tests.assert_eq(public.svc_match_enqueue(c, 'B2', 1, t0) ->> 'status', 'matched', 'un tercero sí');

  perform tests.as_user(a);
  perform public.unblock_user(b);
  perform tests.assert_eq((select count(*)::int from public.user_blocks), 0, 'desbloquear');
  reset role;
end $$;
rollback;
