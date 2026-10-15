-- Agenda rules: offers, acceptances, the meeting card, overlaps, crons.
begin;
do $$
declare
  a uuid; b uuid; c uuid; d uuid; o uuid; o2 uuid; r1 jsonb; r2 jsonb; m_b uuid; m_c uuid; s uuid;
  t0 timestamptz := date_trunc('hour', now()) + interval '1 hour';  -- aligned start for slots
  n int; st text;
begin
  a := tests.user('creator', 'B2'); b := tests.user('acceptor', 'B2'); c := tests.user('third', 'C1'); d := tests.user('fourth', 'B2');

  -- creating offers
  perform tests.assert_fails(format('select public.svc_offer_create(%L, ''B2'', %L, %L)', a, t0, t0 + interval '20 minutes'),
    'window_too_short', 'franja minima de 30 min');
  perform tests.assert_fails(format('select public.svc_offer_create(%L, ''B2'', %L, %L)', a, t0, now() + interval '8 days'),
    'window_out_of_range', 'solo los proximos 7 dias');
  o := public.svc_offer_create(a, 'B2', t0, t0 + interval '3 hours');
  o2 := public.svc_offer_create(a, 'B2', t0 + interval '1 day', t0 + interval '1 day 2 hours');
  perform tests.assert_fails(format('select public.svc_offer_create(%L, ''B2'', %L, %L)', a, t0 + interval '2 days', t0 + interval '2 days 1 hour'),
    'too_many_offers', 'maximo 2 ofertas activas');
  perform public.svc_offer_cancel(a, o2);
  o2 := public.svc_offer_create(a, 'C1', t0 + interval '2 days', t0 + interval '2 days 1 hour');  -- cancelling frees a slot

  -- accepting
  perform tests.assert_fails(format('select public.svc_offer_accept(%L, %L, %L)', a, o, t0), 'own_offer', 'no acepto mi propia oferta');
  perform tests.assert_fails(format('select public.svc_offer_accept(%L, %L, %L)', b, o, t0 + interval '2 hours 45 minutes'),
    'bad_time', 'la reunion de 30 min tiene que caber en la franja');
  perform tests.assert_fails(format('select public.svc_offer_accept(%L, %L, %L)', b, o, t0 + interval '7 minutes'),
    'bad_time', 'horas en multiplos de 5 min');
  r1 := public.svc_offer_accept(b, o, t0 + interval '30 minutes');
  perform tests.assert_fails(format('select public.svc_offer_accept(%L, %L, %L)', b, o, t0 + interval '60 minutes'),
    'already_accepted', 'una aceptacion por persona y oferta');
  r2 := public.svc_offer_accept(c, o, t0 + interval '60 minutes');   -- C1 user can accept a B2 offer (adjacent filter)
  m_b := (r1 ->> 'meeting_id')::uuid; m_c := (r2 ->> 'meeting_id')::uuid;
  perform tests.assert(r1 ->> 'chat_id' <> r2 ->> 'chat_id', 'cada aceptacion abre su chat');
  perform tests.assert_eq((select system_code from public.chat_messages where chat_id = (r1 ->> 'chat_id')::uuid), 'meeting_proposed', 'mensaje de sistema inicial');
  perform tests.assert_eq((select status from public.meeting_offers where id = o), 'open', 'la oferta sigue abierta');

  -- modify resets confirmations
  perform public.svc_meeting_confirm(b, m_b);
  perform tests.assert((select acceptor_confirmed from public.meetings where id = m_b), 'b confirmo');
  perform public.svc_meeting_modify(a, m_b, t0 + interval '45 minutes', 'B2');
  perform tests.assert((select not acceptor_confirmed and not creator_confirmed from public.meetings where id = m_b), 'modificar reinicia las dos');
  perform tests.assert_fails(format('select public.svc_meeting_modify(%L, %L, %L, ''B2'')', d, m_b, t0), 'not_found', 'un tercero no toca la tarjeta');

  -- both confirm -> confirmed, offer filled, sibling closed with system message
  perform tests.assert_eq(public.svc_meeting_confirm(a, m_b), 'pending', 'falta el otro');
  perform tests.assert_eq(public.svc_meeting_confirm(b, m_b), 'confirmed', 'confirmada por los dos');
  perform tests.assert_eq((select status from public.meeting_offers where id = o), 'filled', 'oferta retirada del tablon');
  perform tests.assert_eq((select status from public.meetings where id = m_c), 'closed', 'la otra aceptacion queda cerrada');
  perform tests.assert_eq((select system_code from public.chat_messages where chat_id = (r2 ->> 'chat_id')::uuid order by created_at desc, id limit 1),
    'meeting_unavailable', 'la otra recibe "ya no esta disponible"');
  perform tests.assert_fails(format('select public.svc_meeting_confirm(%L, %L)', c, m_c), 'not_pending', 'no se confirma una cerrada');
  perform tests.assert_fails(format('select public.svc_offer_accept(%L, %L, %L)', d, o, t0 + interval '90 minutes'), 'offer_unavailable', 'oferta llena');

  -- overlap: b already has a confirmed meeting at t0+45; another at t0+60 overlaps the 30-min block
  o2 := public.svc_offer_create(d, 'B2', t0, t0 + interval '3 hours');
  r1 := public.svc_offer_accept(b, o2, t0 + interval '60 minutes');
  perform tests.assert_fails(format('select public.svc_meeting_confirm(%L, %L)', b, (r1 ->> 'meeting_id')), 'overlap', 'b no puede confirmar un solape');
  -- d confirms first, then b cannot; at 75 min (no overlap with 45-75) it works
  perform public.svc_meeting_modify(d, (r1 ->> 'meeting_id')::uuid, t0 + interval '75 minutes', 'B2');
  perform public.svc_meeting_confirm(d, (r1 ->> 'meeting_id')::uuid);
  perform tests.assert_eq(public.svc_meeting_confirm(b, (r1 ->> 'meeting_id')::uuid), 'confirmed', 'contiguo no es solape');

  -- open meeting check used by the 15 s prompt
  perform tests.assert(public.svc_has_open_meeting(b), 'b tiene reuniones');
  perform tests.assert(not public.svc_has_open_meeting(c), 'c no (la suya se cerro)');

  -- entering the room: window from -5 min; session is shared; attendance recorded
  perform tests.assert_fails(format('select public.svc_meeting_enter(%L, %L, 1, %L)', a, m_b, t0 + interval '30 minutes'), 'too_early', 'antes de 5 min no');
  s := public.svc_meeting_enter(a, m_b, 1, t0 + interval '41 minutes');
  perform tests.assert_eq(public.svc_meeting_enter(b, m_b, 1, t0 + interval '43 minutes'), s, 'misma sesion para los dos');
  perform tests.assert_eq((select origin from public.exam_sessions where id = s), 'meeting', 'origen meeting');
  perform tests.assert_eq((select level from public.exam_sessions where id = s), 'B2', 'nivel de la reunion');
end $$;
rollback;

-- Crons: reminder 10 min before, no-show after 10 min courtesy, expiry.
begin;
do $$
declare a uuid; b uuid; c uuid; o uuid; r jsonb; m uuid; m2 uuid; t0 timestamptz := date_trunc('hour', now()) + interval '2 hours'; res jsonb;
begin
  a := tests.user('cron_a'); b := tests.user('cron_b'); c := tests.user('cron_c');
  o := public.svc_offer_create(a, 'B2', t0, t0 + interval '1 hour');
  r := public.svc_offer_accept(b, o, t0); m := (r ->> 'meeting_id')::uuid;
  m2 := (public.svc_offer_accept(c, o, t0 + interval '30 minutes') ->> 'meeting_id')::uuid;
  perform public.svc_meeting_confirm(a, m); perform public.svc_meeting_confirm(b, m);

  res := public.svc_cron_agenda(t0 - interval '11 minutes');
  perform tests.assert_eq((res ->> 'reminders')::int, 0, 'aun no');
  res := public.svc_cron_agenda(t0 - interval '10 minutes');
  perform tests.assert_eq((res ->> 'reminders')::int, 1, 'aviso a los 10 min');
  perform tests.assert_eq((select count(*)::int from public.notification_outbox where kind = 'meeting_reminder'), 2, 'push a los dos');
  res := public.svc_cron_agenda(t0 - interval '9 minutes');
  perform tests.assert_eq((res ->> 'reminders')::int, 0, 'solo una vez');

  -- only a enters; at +10 min still courtesy, at +11 no-show
  perform public.svc_meeting_enter(a, m, 1, t0 - interval '2 minutes');
  res := public.svc_cron_agenda(t0 + interval '10 minutes');
  perform tests.assert_eq((res ->> 'no_shows')::int, 0, 'cortesia de 10 min');
  res := public.svc_cron_agenda(t0 + interval '11 minutes');
  perform tests.assert_eq((res ->> 'no_shows')::int, 1, 'no_show');
  perform tests.assert_eq((select status from public.meetings where id = m), 'no_show', 'estado no_show');
  perform tests.assert_eq((select attended from public.attendance where meeting_id = m and user_id = b), false, 'ausencia de b registrada');
  perform tests.assert_eq((select attended from public.attendance where meeting_id = m and user_id = a), true, 'a asistio');
  perform tests.assert_eq((select user_id from public.notification_outbox where kind = 'partner_no_show'), a, 'aviso al que si entro');
  perform tests.assert_eq((select state from public.exam_sessions where meeting_id = m), 'aborted', 'la sala se cierra');

  -- the offer was filled; the pending sibling was closed at confirmation already
  perform tests.assert_eq((select status from public.meetings where id = m2), 'closed', 'cerrada');
end $$;
rollback;

begin;
do $$
declare a uuid; o uuid; t0 timestamptz := date_trunc('hour', now()) + interval '2 hours';
begin
  a := tests.user('exp_a');
  o := public.svc_offer_create(a, 'B1', t0, t0 + interval '1 hour');
  perform public.svc_cron_agenda(t0 + interval '29 minutes');
  perform tests.assert_eq((select status from public.meeting_offers where id = o), 'open', 'aun cabe una reunion');
  perform public.svc_cron_agenda(t0 + interval '31 minutes');
  perform tests.assert_eq((select status from public.meeting_offers where id = o), 'expired', 'vencida');
end $$;
rollback;

-- Account deletion: chat survives anonymised, partner is told.
begin;
do $$
declare a uuid; b uuid; o uuid; r jsonb; n int;
begin
  a := tests.user('del_a'); b := tests.user('del_b');
  o := public.svc_offer_create(a, 'B2', date_trunc('hour', now()) + interval '2 hours', date_trunc('hour', now()) + interval '4 hours');
  r := public.svc_offer_accept(b, o, date_trunc('hour', now()) + interval '2 hours');
  insert into public.chat_messages (chat_id, sender_id, body) values ((r ->> 'chat_id')::uuid, a, 'hola, soy a');
  perform public.svc_account_prepare_delete(a);
  delete from auth.users where id = a;
  select count(*) into n from public.chat_messages where chat_id = (r ->> 'chat_id')::uuid and kind = 'user' and sender_id is null;
  perform tests.assert_eq(n, 1, 'el mensaje de a queda anonimizado');
  perform tests.assert_eq((select status from public.meetings where id = (r ->> 'meeting_id')::uuid), 'cancelled', 'reunion cancelada');
  perform tests.assert(exists (select 1 from public.chat_messages where chat_id = (r ->> 'chat_id')::uuid and system_code = 'partner_deleted_account'),
    'b recibe el aviso');
  -- b can no longer write into a chat with a deleted partner
  perform tests.as_user(b);
  perform tests.assert_fails(format('insert into public.chat_messages (chat_id, body) values (%L, ''?'')', r ->> 'chat_id'), 'row-level security', 'chat de solo lectura');
  reset role;
end $$;
rollback;
