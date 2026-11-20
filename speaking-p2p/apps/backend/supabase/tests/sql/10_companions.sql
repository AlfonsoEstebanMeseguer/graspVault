-- Companions, direct invitations and the chat lifetime (D-046).
begin;
do $$
declare a uuid; b uuid; c uuid; s uuid; s_live uuid; r jsonb; m uuid; t0 timestamptz := date_trunc('hour', now()) + interval '3 hours';
begin
  a := tests.user('cmp_a', 'B2', true); b := tests.user('cmp_b', 'B2', true); c := tests.user('cmp_c', 'B2', true);
  insert into public.exam_sessions (level, exam_id, exam_version, user_a, user_b, origin, state, ended_at)
  values ('B2', 'b2-community-life', 1, a, b, 'live', 'ended', now()) returning id into s;
  insert into public.exam_sessions (level, exam_id, exam_version, user_a, user_b, origin, state)
  values ('B2', 'b2-community-life', 1, a, c, 'live', 'part2') returning id into s_live;

  -- Inviting needs a mutual companion.
  perform tests.assert_fails(format('select public.svc_meeting_invite(%L, %L, %L, ''B2'')', a, b, t0), 'not_companion', 'sin ser companeros no se invita');

  perform tests.as_user(a);
  perform tests.assert_fails(format('select public.companion_add(%L)', s_live), 'session_not_ended', 'solo tras un examen terminado');
  perform public.companion_add(s);
  perform public.companion_add(s); -- twice is fine
  perform tests.assert_eq((select count(*)::int from public.my_companions() where i_added and not they_added), 1, 'a la ha anadido, b aun no');
  perform tests.assert_fails('select count(*) from public.companions', 'permission denied', 'la tabla no se lee directamente');
  reset role;
  perform tests.assert_fails(format('select public.svc_meeting_invite(%L, %L, %L, ''B2'')', a, b, t0), 'not_companion', 'hace falta que sea mutuo');

  perform tests.as_user(c);
  perform tests.assert_fails(format('select public.companion_add(%L)', s), 'not_found', 'un tercero no usa una sesion ajena');
  reset role;

  perform tests.as_user(b);
  perform public.companion_add(s);
  perform tests.assert_eq((select sessions_together from public.my_companions() where partner_id = a), 1, 'mutuos, con 1 examen juntos');
  reset role;

  -- Invitation: born pending with the inviter's tick; one tap from the other confirms.
  perform tests.assert_fails(format('select public.svc_meeting_invite(%L, %L, %L, ''B2'')', a, b, t0 + interval '10 minutes'), 'bad_time', 'rejilla de 30 min');
  r := public.svc_meeting_invite(a, b, t0, 'B2'); m := (r ->> 'meeting_id')::uuid;
  perform tests.assert((select status = 'pending' and origin = 'invite' and creator_confirmed and not acceptor_confirmed from public.meetings where id = m),
    'invitacion pendiente con el tick de a');
  perform tests.assert_eq((select system_code from public.chat_messages where chat_id = (r ->> 'chat_id')::uuid), 'meeting_invited', 'mensaje de invitacion');
  perform tests.assert_eq((select count(*)::int from public.notification_outbox where user_id = b and kind = 'meeting_invite'), 1, 'aviso a b');
  perform tests.assert_eq(public.svc_meeting_confirm(b, m), 'confirmed', 'b acepta con un toque');
  perform tests.assert_fails(format('select public.svc_meeting_invite(%L, %L, %L, ''B2'')', a, b, t0), 'overlap', 'sin solapes');
  perform public.svc_meeting_invite(a, b, t0 + interval '1 day', 'B2');
  perform public.svc_meeting_invite(a, b, t0 + interval '2 days', 'B2');
  perform public.svc_meeting_invite(a, b, t0 + interval '3 days', 'B2');
  perform tests.assert_fails(format('select public.svc_meeting_invite(%L, %L, %L, ''B2'')', a, b, t0 + interval '4 days'), 'too_many_invites', 'max 3 pendientes');

  -- Removing ends it for both.
  perform tests.as_user(b);
  perform public.companion_remove(a);
  reset role;
  perform tests.assert_fails(format('select public.svc_meeting_invite(%L, %L, %L, ''B2'')', b, a, t0 + interval '5 days'), 'not_companion', 'quitar deshace el vinculo');

  -- Blocking clears the companionship and cancels the invitations.
  perform tests.as_user(b); perform public.companion_add(s); reset role;
  perform tests.as_user(a);
  perform public.block_user(b);
  perform tests.assert_eq((select count(*)::int from public.my_companions()), 0, 'bloquear quita al companero');
  perform tests.assert_fails(format('select public.companion_add(%L)', s), 'bad_user', 'ni se puede volver a anadir');
  reset role;
  perform tests.assert_eq((select count(*)::int from public.meetings where origin = 'invite' and status = 'pending'), 0, 'invitaciones canceladas');
end $$;
rollback;

-- The chat lives around its meeting: writable while alive and up to 2 h after, then
-- read-only; deleted 30 days later unless a report is open.
begin;
do $$
declare a uuid; b uuid; o uuid; r jsonb; chat uuid; m uuid; r2 jsonb; t0 timestamptz := date_trunc('hour', now()) + interval '2 hours'; res jsonb;
begin
  a := tests.user('life_a'); b := tests.user('life_b');
  o := public.svc_offer_create(a, 'B2', t0, t0 + interval '2 hours');
  r := public.svc_offer_accept(b, o, t0); chat := (r ->> 'chat_id')::uuid; m := (r ->> 'meeting_id')::uuid;
  r2 := public.svc_offer_accept(tests.user('life_c'), o, t0 + interval '1 hour');

  perform tests.as_user(b);
  insert into public.chat_messages (chat_id, body, client_id) values (chat, 'nos vemos', gen_random_uuid());
  perform tests.assert_fails(format('insert into public.chat_messages (chat_id, body, client_id) values (%L, %L, gen_random_uuid())', chat, repeat('x', 501)),
    'chat_messages_user_body_short', 'mensajes de hasta 500 caracteres');
  reset role;

  update public.meetings set status = 'done', scheduled_at = now() - interval '1 hour' where id = m;
  perform tests.as_user(b);
  insert into public.chat_messages (chat_id, body, client_id) values (chat, 'gracias', gen_random_uuid());
  reset role;

  update public.meetings set scheduled_at = now() - interval '3 hours' where id = m;
  perform tests.as_user(b);
  perform tests.assert_fails(format('insert into public.chat_messages (chat_id, body, client_id) values (%L, %L, gen_random_uuid())', chat, 'hola?'),
    'row-level security', 'pasadas 2 h el chat es de solo lectura');
  reset role;

  update public.meetings set status = 'cancelled' where id = (r2 ->> 'meeting_id')::uuid;
  perform tests.as_user(a);
  perform tests.assert_fails(format('insert into public.chat_messages (chat_id, body, client_id) values (%L, %L, gen_random_uuid())', r2 ->> 'chat_id', 'hola?'),
    'row-level security', 'una reunion cancelada no deja escribir');
  reset role;

  -- 30 days later the chat is deleted, unless there is an open report about it.
  update public.meetings set scheduled_at = now() - interval '31 days' where id in (m, (r2 ->> 'meeting_id')::uuid);
  insert into public.user_reports (reporter_id, reported_id, reason, context, chat_id) values (a, tests.user('life_x'), 'spam', 'chat', (r2 ->> 'chat_id')::uuid);
  res := public.svc_cron_housekeeping();
  perform tests.assert_eq((res ->> 'old_chats')::int, 1, 'se borra un chat viejo');
  perform tests.assert_eq((select count(*)::int from public.chats where id = chat), 0, 'el chat viejo ya no existe');
  perform tests.assert_eq((select count(*)::int from public.chat_messages where chat_id = chat), 0, 'ni sus mensajes');
  perform tests.assert_eq((select count(*)::int from public.chats where id = (r2 ->> 'chat_id')::uuid), 1, 'el reportado se conserva');
end $$;
rollback;
