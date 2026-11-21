-- Daily quotas on agenda cycles, idempotent confirm, bounded offer_taken_slots.
begin;
do $$
declare a uuid; b uuid; c uuid; s uuid; r jsonb; m uuid; o uuid; i int; n int;
  t0 timestamptz := date_trunc('hour', now()) + interval '3 hours';
begin
  a := tests.user('cyc_a', 'B2', true); b := tests.user('cyc_b', 'B2', true); c := tests.user('cyc_c', 'B2', true);
  insert into public.exam_sessions (level, exam_id, exam_version, user_a, user_b, origin, state, ended_at)
  values ('B2', 'b2-community-life', 1, a, b, 'live', 'ended', now()) returning id into s;
  perform tests.as_user(a); perform public.companion_add(s); reset role;
  perform tests.as_user(b); perform public.companion_add(s); reset role;

  -- invite -> cancel: 5 per day towards the same companion, then rate_limited.
  for i in 1..5 loop
    r := public.svc_meeting_invite(a, b, t0, 'B2');
    perform public.svc_meeting_cancel(a, (r ->> 'meeting_id')::uuid);
  end loop;
  perform tests.assert_fails(format('select public.svc_meeting_invite(%L, %L, %L, ''B2'')', a, b, t0), 'rate_limited', 'sexto ciclo invitar/cancelar');
  perform tests.assert_eq((select count(*)::int from public.notification_outbox where user_id = b and kind = 'meeting_invite'), 5, 'solo 5 pushes');
  -- A validation failure does not spend quota (the transaction rolls back).
  perform tests.assert_fails(format('select public.svc_meeting_invite(%L, %L, %L, ''B2'')', b, a, t0 + interval '7 minutes'), 'bad_time', 'hora invalida');
  r := public.svc_meeting_invite(b, a, t0, 'B2');
  m := (r ->> 'meeting_id')::uuid;

  -- Confirming twice writes one system message.
  perform tests.assert_eq(public.svc_meeting_confirm(b, m), 'pending', 'quien invita ya tenia su tick');
  perform tests.assert_eq((select count(*)::int from public.chat_messages cm join public.chats ch on ch.id = cm.chat_id
    where ch.meeting_id = m and cm.kind = 'system' and cm.system_code = 'meeting_confirmed_by'), 0, 'reconfirmar no escribe nada');

  -- modify: 10 per day on the same meeting.
  for i in 1..10 loop
    perform public.svc_meeting_modify(a, m, t0 + make_interval(hours => i), 'B2');
  end loop;
  perform tests.assert_fails(format('select public.svc_meeting_modify(%L, %L, %L, ''B2'')', a, m, t0 + interval '12 hours'), 'rate_limited', 'undecima modificacion');
  perform public.svc_meeting_modify(b, m, t0 + interval '12 hours', 'B2'); -- the partner has their own quota

  -- accept -> cancel on the same creator: 5 per day.
  o := public.svc_offer_create(c, 'B2', t0 + interval '1 day', t0 + interval '1 day 3 hours');
  for i in 1..5 loop
    r := public.svc_offer_accept(a, o, t0 + interval '1 day');
    perform public.svc_meeting_cancel(a, (r ->> 'meeting_id')::uuid);
  end loop;
  perform tests.assert_fails(format('select public.svc_offer_accept(%L, %L, %L)', a, o, t0 + interval '1 day'), 'rate_limited', 'sexta reserva al mismo creador');

  -- offer_taken_slots reads at most 100 ids.
  perform public.svc_offer_accept(b, o, t0 + interval '1 day');
  perform tests.as_user(a);
  select count(*) into n from public.offer_taken_slots(array[o]);
  perform tests.assert_eq(n, 1, 'control: la franja reservada se ve');
  select count(*) into n from public.offer_taken_slots(array_cat(array_fill('00000000-0000-0000-0000-000000000001'::uuid, array[150]), array[o]));
  perform tests.assert_eq(n, 0, 'la oferta 151 no se mira');
  reset role;

end $$;
rollback;
