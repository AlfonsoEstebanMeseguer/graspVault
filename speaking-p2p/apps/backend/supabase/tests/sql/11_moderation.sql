-- Moderation, phase 1 (D-051): the session event log, speaking time per stretch,
-- stricter reports and the 30-day retention.
begin;
do $$
declare a uuid; b uuid; c uuid; s uuid; sess public.exam_sessions; t0 timestamptz := now(); w jsonb; n int;
begin
  a := tests.user('mod_a', 'B2', true); b := tests.user('mod_b', 'B2', true); c := tests.user('mod_c', 'B2', true);
  perform public.svc_match_enqueue(a, 'B2', 1, t0);
  s := (public.svc_match_enqueue(b, 'B2', 1, t0) ->> 'session_id')::uuid;

  -- What the server decides is logged by the trigger, whatever the path.
  perform public.svc_session_presence(s, a, true, t0);
  perform public.svc_session_presence(s, b, true, t0);
  perform public.svc_session_set_flag(s, a, 'ready', true, t0);
  perform public.svc_session_set_flag(s, a, 'recording', true, t0);
  perform public.svc_session_set_flag(s, a, 'preloaded', true, t0);
  perform public.svc_session_set_flag(s, b, 'preloaded', true, t0);
  perform public.svc_session_set_flag(s, b, 'ready', true, t0 + interval '1 second');
  perform public.svc_session_presence(s, b, false, t0 + interval '20 seconds');
  perform public.svc_session_presence(s, b, true, t0 + interval '30 seconds');
  update public.exam_sessions set last_control = jsonb_build_object('op', 'pause', 'by', a, 'at', t0) where id = s;
  perform public.svc_session_abort(s, a, 'left', t0 + interval '40 seconds');

  perform tests.assert_eq((select count(*)::int from public.session_events where session_id = s and kind = 'joined'), 2, 'entran los dos');
  perform tests.assert_eq((select count(*)::int from public.session_events where session_id = s and kind = 'ready'), 2, 'los dos listos');
  perform tests.assert_eq((select data ->> 'value' from public.session_events where session_id = s and kind = 'recording_consent'),
    'true', 'consentimiento de grabación');
  perform tests.assert_eq((select user_id from public.session_events where session_id = s and kind = 'left'), b, 'b se desconecta');
  perform tests.assert_eq((select user_id from public.session_events where session_id = s and kind = 'rejoined'), b, 'y vuelve');
  perform tests.assert_eq((select data ->> 'op' from public.session_events where session_id = s and kind = 'control'), 'pause',
    'cada control del líder queda apuntado');
  perform tests.assert_eq((select user_id from public.session_events where session_id = s and kind = 'control'), a, 'con quién lo hizo');
  perform tests.assert_eq((select data ->> 'to' from public.session_events where session_id = s and kind = 'state' order by id limit 1),
    'part1', 'empieza la parte 1');
  perform tests.assert_eq((select data from public.session_events where session_id = s and kind = 'state' order by id desc limit 1),
    '{"from":"part1","to":"aborted","reason":"left"}'::jsonb, 'abandono con la parte y el motivo');
  perform tests.assert_eq((select user_id from public.session_events where session_id = s and kind = 'state' order by id desc limit 1),
    a, 'y quién abandonó');

  -- What only the phones and LiveKit know.
  perform public.svc_session_log(s, b, 'self_mute', '{"muted":true}');
  perform tests.assert_eq((select state from public.session_events where kind = 'self_mute'), 'aborted', 'con el estado del momento');
  perform tests.assert_fails(format('select public.svc_session_log(%L, %L, ''joined'')', s, b), 'bad_kind', 'solo los tipos previstos');
  perform tests.assert_fails(format('select public.svc_session_log(%L, %L, ''self_mute'')', s, c), 'not_participant', 'solo participantes');

  -- Speaking time: bounded, idempotent, only from participants.
  w := jsonb_build_object('seg', 3, 'startedAtMs', (extract(epoch from t0) * 1000)::bigint, 'state', 'part1', 'phase', 'speak',
    'paused', false, 'micA', true, 'micB', false, 'windowMs', 30000, 'speechAMs', 21000, 'speechBMs', 0, 'overlapMs', 0);
  perform tests.assert_eq(public.svc_session_talk_stats(s, a, jsonb_build_array(w)), 1, 'una ventana');
  perform tests.assert_eq(public.svc_session_talk_stats(s, a, jsonb_build_array(w)), 0, 'reenviarla no duplica');
  perform tests.assert_eq(public.svc_session_talk_stats(s, b, jsonb_build_array(w)), 1, 'el otro móvil mide la misma ventana');
  perform tests.assert_fails(format('select public.svc_session_talk_stats(%L, %L, %L)', s, a,
    jsonb_build_array(w || '{"seg":4,"speechAMs":31000}')), 'bad_stats', 'más voz que tiempo');
  perform tests.assert_fails(format('select public.svc_session_talk_stats(%L, %L, %L)', s, a,
    jsonb_build_array(w || '{"seg":4,"speechBMs":1000,"overlapMs":2000}')), 'bad_stats', 'más solape que voz');
  perform tests.assert_fails(format('select public.svc_session_talk_stats(%L, %L, %L)', s, a,
    jsonb_build_array(w || '{"seg":4,"state":"ended"}')), 'bad_stats', 'estado imposible');
  perform tests.assert_fails(format('select public.svc_session_talk_stats(%L, %L, %L)', s, a,
    jsonb_build_array(w - 'micA' || '{"seg":4}')), 'bad_stats', 'faltan campos');
  perform tests.assert_fails(format('select public.svc_session_talk_stats(%L, %L, %L)', s, a,
    jsonb_build_array(w || jsonb_build_object('seg', 4, 'startedAtMs', (extract(epoch from t0 + interval '1 day') * 1000)::bigint))),
    'bad_stats', 'una ventana del futuro');
  perform tests.assert_fails(format('select public.svc_session_talk_stats(%L, %L, %L)', s, a,
    (select jsonb_agg(w || jsonb_build_object('seg', i)) from generate_series(1, 21) i)), 'bad_stats', 'lotes de 20 como mucho');
  perform tests.assert_fails(format('select public.svc_session_talk_stats(%L, %L, ''{}'')', s, a), 'bad_stats', 'tiene que ser una lista');
  perform tests.assert_fails(format('select public.svc_session_talk_stats(%L, %L, %L)', s, c, jsonb_build_array(w)),
    'not_participant', 'solo participantes');
  perform tests.assert_eq((select count(*)::int from public.session_talk_stats where session_id = s), 2, 'nada de lo rechazado entra');

  -- Nobody reads the evidence from the app, nor calls the service functions.
  perform tests.as_user(a);
  perform tests.assert_fails('select count(*) from public.session_events', 'permission denied', 'eventos: solo el servidor');
  perform tests.assert_fails('select count(*) from public.session_talk_stats', 'permission denied', 'tiempos: solo el servidor');
  perform tests.assert_fails(format('select public.svc_session_talk_stats(%L, %L, %L)', s, a, jsonb_build_array(w)),
    'permission denied', 'la app no escribe tiempos directamente');

  -- Reports: same function, stricter.
  perform public.report_user(b, 'silent', 'no habló', 'exam', s, null);
  perform public.report_user(b, 'mocking', 'otra vez', 'exam', s, null);
  perform tests.assert_fails(format('select public.report_user(%L, ''quit'', null, ''exam'', %L, null)', c, s),
    'not_in_session', 'no se reporta a quien no estaba');
  perform tests.assert_fails(format('select public.report_user(%L, ''silent'', null, ''exam'', null, null)', b),
    'not_in_session', 'un motivo de sabotaje necesita la sesión');
  perform public.report_user(c, 'spam', null, 'profile', null, null);
  reset role;
  perform tests.as_user(c);
  perform tests.assert_fails(format('select public.report_user(%L, ''silent'', null, ''exam'', %L, null)', a, s),
    'not_in_session', 'tampoco desde fuera de la sesión');
  reset role;
  perform tests.assert_eq((select count(*)::int from public.user_reports where reporter_id = a and session_id = s), 1,
    'un reporte por persona y sesión');
  perform tests.assert_eq((select reason from public.user_reports where reporter_id = a and session_id = s), 'silent', 'cuenta el primero');
  perform tests.assert_eq((select count(*)::int from public.user_reports where reporter_id = a and session_id is null), 1,
    'fuera de una sesión sigue como antes');
end $$;
rollback;

-- Retention: 30 days, unless a report on the session is still open.
begin;
do $$
declare a uuid; b uuid; c uuid; d uuid; s1 uuid; s2 uuid; t0 timestamptz := now(); r jsonb;
begin
  a := tests.user('ret_a', 'C1', true); b := tests.user('ret_b', 'C1', true);
  c := tests.user('ret_c', 'C1', true); d := tests.user('ret_d', 'C1', true);
  perform public.svc_match_enqueue(a, 'C1', 1, t0);
  s1 := (public.svc_match_enqueue(b, 'C1', 1, t0) ->> 'session_id')::uuid;
  perform public.svc_match_enqueue(c, 'C1', 1, t0);
  s2 := (public.svc_match_enqueue(d, 'C1', 1, t0) ->> 'session_id')::uuid;
  perform public.svc_session_presence(s1, a, true, t0);
  perform public.svc_session_presence(s2, c, true, t0);
  perform tests.as_user(c);
  perform public.report_user(d, 'noise', null, 'lobby', s2, null);
  reset role;
  update public.exam_sessions set created_at = t0 - interval '40 days' where id in (s1, s2);

  r := public.svc_cron_housekeeping(t0);
  perform tests.assert_eq((r ->> 'evidence')::int, 1, 'se borra lo de hace más de 30 días');
  perform tests.assert_eq((select count(*)::int from public.session_events where session_id = s1), 0, 'sesión sin reportes: purgada');
  perform tests.assert_eq((select count(*)::int from public.session_events where session_id = s2), 1, 'con un reporte abierto: se conserva');
  update public.user_reports set status = 'dismissed' where session_id = s2;
  perform tests.assert_eq((public.svc_cron_housekeeping(t0) ->> 'evidence')::int, 1, 'cerrado el reporte, se purga');
end $$;
rollback;
