-- Pro exam control (D-038/D-039/D-040). run-plain.sh passes the shared fixtures
-- as psql variables; DO blocks cannot see them, so they go through settings.
\o /dev/null
select set_config('tests.golden', :'golden', false), set_config('tests.timeline', :'timeline', false);
\o

-- 1. The pure reducer gives exactly what content/fixtures/control-golden.json
--    says (the Dart reducer is checked against the same file).
begin;
do $$
declare
  g jsonb := current_setting('tests.golden')::jsonb;
  tl jsonb := current_setting('tests.timeline')::jsonb -> 'timeline';
  st jsonb; c jsonb; i int; op text; args jsonb; ex jsonb; now_ms bigint; e bigint; total bigint; seg jsonb; state text;
  failed boolean;
begin
  st := jsonb_build_object('startedAtMs', g -> 'startedAtMs', 'pausedAtMs', null, 'pauseReason', null,
    'feedbackEndsAtMs', (g ->> 'startedAtMs')::bigint + (tl ->> 'totalMs')::bigint + 300000,
    'version', 0, 'examId', g -> 'examId', 'schedule', tl);
  for c, i in select x, o from jsonb_array_elements(g -> 'cases') with ordinality t(x, o) loop
    op := c ->> 'op'; now_ms := (c ->> 'nowMs')::bigint; ex := c -> 'expect'; args := c -> 'args';
    if op = 'switch_exam' then args := args || jsonb_build_object('schedule', tl); end if;
    if ex ? 'error' then
      failed := false;
      begin
        perform private.ctl_apply(st, op, args, now_ms);
      exception when others then
        failed := true;
        perform tests.assert_eq(sqlerrm, ex ->> 'error', format('caso %s (%s): codigo de error', i - 1, op));
      end;
      perform tests.assert(failed, format('caso %s (%s): esperaba error %s', i - 1, op, ex ->> 'error'));
      continue;
    end if;
    st := private.ctl_apply(st, op, args, now_ms);
    perform tests.assert_eq(st -> 'startedAtMs', ex -> 'startedAtMs', format('caso %s (%s): startedAtMs', i - 1, op));
    perform tests.assert_eq(st -> 'pausedAtMs', ex -> 'pausedAtMs', format('caso %s (%s): pausedAtMs', i - 1, op));
    perform tests.assert_eq(st -> 'pauseReason', ex -> 'pauseReason', format('caso %s (%s): pauseReason', i - 1, op));
    perform tests.assert_eq(st -> 'schedule' -> 'totalMs', ex -> 'totalMs', format('caso %s (%s): totalMs', i - 1, op));
    perform tests.assert_eq(st -> 'feedbackEndsAtMs', ex -> 'feedbackEndsAtMs', format('caso %s (%s): feedbackEndsAtMs', i - 1, op));
    perform tests.assert_eq(st -> 'version', ex -> 'version', format('caso %s (%s): version', i - 1, op));
    if ex ? 'examId' then perform tests.assert_eq(st -> 'examId', ex -> 'examId', format('caso %s: examId', i - 1)); end if;
    if ex ? 'durationsMs' then
      perform tests.assert_eq(to_jsonb(private.ctl_durations(st -> 'schedule')), ex -> 'durationsMs', format('caso %s: duraciones', i - 1));
    end if;
    -- state / segment at nowMs (same rule as the tick)
    e := coalesce((st ->> 'pausedAtMs')::bigint, now_ms) - (st ->> 'startedAtMs')::bigint;
    total := (st -> 'schedule' ->> 'totalMs')::bigint;
    seg := null;
    if e >= (st ->> 'feedbackEndsAtMs')::bigint - (st ->> 'startedAtMs')::bigint then state := 'ended';
    elsif e >= total then state := 'feedback';
    else
      select x into seg from jsonb_array_elements(st -> 'schedule' -> 'segments') x
      where (x ->> 'startMs')::bigint <= greatest(e, 0) order by (x ->> 'startMs')::bigint desc limit 1;
      state := 'part' || (seg ->> 'part');
    end if;
    perform tests.assert_eq(state, ex ->> 'state', format('caso %s (%s): estado', i - 1, op));
    perform tests.assert_eq(coalesce(seg -> 'index', 'null'::jsonb), ex -> 'segment', format('caso %s (%s): segmento', i - 1, op));
  end loop;
end $$;
rollback;

-- 2. Sessions: leader, permissions, pause through the tick, keyed mic push.
begin;
do $$
declare
  pro uuid; std uuid; s uuid; sess public.exam_sessions; r jsonb; t timestamptz; seg jsonb; v int; k text;
begin
  pro := tests.user('pro1', 'B2', true); std := tests.user('std1', 'B2', true);
  update public.entitlements set plan = 'pro' where user_id = pro;
  s := private.create_session('B2', pro, std, 'live', null, 1);
  perform tests.assert_eq((select leader_id from public.exam_sessions where id = s), pro, 'un solo Pro: dirige el');

  perform tests.assert_fails(format('select public.svc_session_control(%L, %L, ''switch_exam'', ''{}'')', s, std), 'not_leader', 'el otro no controla');
  perform tests.assert_fails(format('select public.svc_session_control(%L, %L, ''transfer'', ''{}'')', s, pro), 'partner_not_pro', 'ceder solo a un Pro');
  perform tests.assert_fails(format('select public.svc_session_control(%L, %L, ''pause'', ''{}'')', s, pro), 'not_started', 'en el lobby no hay pausa');

  -- choosing the exam in the lobby
  t := now();
  perform public.svc_session_presence(s, pro, true, t, 1);
  perform public.svc_session_presence(s, std, true, t, 1);
  v := (select control_version from public.exam_sessions where id = s);
  perform tests.assert_fails(format('select public.svc_session_control(%L, %L, ''switch_exam'', ''{"examId":"b2-e02-social-media-and-friendship"}'', %s)', s, pro, v + 7),
    'stale_control', 'version vieja');
  perform public.svc_session_control(s, pro, 'switch_exam', '{"examId":"b2-e02-social-media-and-friendship"}', v, t);
  select * into sess from public.exam_sessions where id = s;
  perform tests.assert_eq(sess.exam_id, 'b2-e02-social-media-and-friendship', 'examen elegido en el lobby');
  perform tests.assert_eq(sess.last_control ->> 'op', 'switch_exam', 'aviso para los dos');

  -- start: both ready and preloaded
  perform public.svc_session_set_flag(s, pro, 'ready', true, t);
  perform public.svc_session_set_flag(s, std, 'ready', true, t);
  perform public.svc_session_set_flag(s, pro, 'preloaded', true, t);
  perform tests.assert_eq(public.svc_session_set_flag(s, std, 'preloaded', true, t), 'part1', 'empieza');
  select * into sess from public.exam_sessions where id = s;
  perform tests.assert_eq(sess.schedule, (select timeline from public.exam_catalog where id = sess.exam_id), 'con la linea del examen elegido');

  -- pause in the first speaking window: clock frozen, both mics open
  select x into seg from jsonb_array_elements(sess.schedule -> 'segments') x where x ->> 'phase' = 'speak' order by (x ->> 'startMs')::bigint limit 1;
  t := sess.exam_started_at + make_interval(secs => ((seg ->> 'startMs')::bigint + 2000) / 1000.0);
  perform public.svc_session_control(s, pro, 'pause', '{}', sess.control_version, t);
  r := public.svc_session_tick(s, t + interval '2 minutes');
  perform tests.assert_eq(r ->> 'paused', 'true', 'en pausa');
  perform tests.assert_eq(r -> 'mic', '{"A":true,"B":true}'::jsonb, 'pausa: micros abiertos');
  perform tests.assert_eq(r ->> 'needs_push', 'true', 'hay que abrir los micros');
  perform public.svc_session_mark_applied_key(s, r ->> 'key');
  perform tests.assert_eq(public.svc_session_tick(s, t + interval '3 minutes') ->> 'needs_push', 'false', 'aplicado');
  perform tests.assert_eq(public.svc_session_tick(s, t + interval '3 minutes') ->> 'state', 'part1', 'sigue en la parte 1');

  -- a pause longer than 15 min resumes on its own, where it was
  r := public.svc_session_tick(s, t + interval '16 minutes');
  perform tests.assert_eq(r ->> 'paused', 'false', 'pausa maxima: se reanuda');
  perform tests.assert_eq(r ->> 'segment', seg ->> 'index', 'en el mismo turno');

  -- a jump BACK is pushed to LiveKit too (keyed by version, not monotonic)
  select * into sess from public.exam_sessions where id = s;
  t := t + interval '16 minutes';
  perform public.svc_session_control(s, pro, 'next_part', '{}', sess.control_version, t);
  r := public.svc_session_tick(s, t);
  perform public.svc_session_mark_applied_key(s, r ->> 'key');
  select * into sess from public.exam_sessions where id = s;
  perform public.svc_session_control(s, pro, 'go_to_part', '{"part":1}', sess.control_version, t + interval '1 second');
  r := public.svc_session_tick(s, t + interval '1 second');
  perform tests.assert_eq(r ->> 'segment', '0', 'vuelve a la parte 1');
  perform tests.assert_eq(r ->> 'needs_push', 'true', 'el salto atras tambien se empuja');
end $$;
rollback;

-- 3. Switching exams mid-exam waits for both downloads (or 45 s).
begin;
do $$
declare a uuid; b uuid; s uuid; sess public.exam_sessions; r jsonb; t timestamptz := now();
begin
  a := tests.user('pro2', 'B2', true); b := tests.user('pro3', 'B2', true);
  update public.entitlements set plan = 'pro' where user_id in (a, b);
  s := private.create_session('B2', a, b, 'live', null, 1);
  select * into sess from public.exam_sessions where id = s;
  perform tests.assert(sess.leader_id in (a, b), 'dos Pro: uno de los dos dirige');
  perform tests.assert(sess.pro_a and sess.pro_b, 'los dos marcados como Pro');
  perform public.svc_session_presence(s, a, true, t, 1);
  perform public.svc_session_presence(s, b, true, t, 1);
  perform public.svc_session_set_flag(s, a, 'ready', true, t);
  perform public.svc_session_set_flag(s, b, 'ready', true, t);
  perform public.svc_session_set_flag(s, a, 'preloaded', true, t);
  perform public.svc_session_set_flag(s, b, 'preloaded', true, t);
  select * into sess from public.exam_sessions where id = s;
  t := sess.exam_started_at + interval '20 seconds';

  -- content version: the partner's app is too old for the chosen exam
  update public.exam_sessions set content_version_b = 0 where id = s;
  perform tests.assert_fails(format('select public.svc_session_control(%L, %L, ''switch_exam'', ''{"examId":"b2-e03-the-impact-of-tourism"}'')', s, sess.leader_id),
    'content_missing_partner', 'el compania no tiene ese examen');
  update public.exam_sessions set content_version_b = 1 where id = s;

  perform public.svc_session_control(s, sess.leader_id, 'switch_exam', '{"examId":"b2-e03-the-impact-of-tourism"}', null, t);
  select * into sess from public.exam_sessions where id = s;
  perform tests.assert_eq(sess.pause_reason, 'switching', 'descargando');
  perform tests.assert(not sess.preloaded_a and not sess.preloaded_b, 'precarga reiniciada');
  perform tests.assert_eq((select count(*)::int from public.exam_history where session_id = s and exam_id = 'b2-e03-the-impact-of-tourism'), 2, 'historial sigue al examen');
  r := public.svc_session_tick(s, t + interval '5 seconds');
  perform tests.assert_eq(r ->> 'paused', 'true', 'espera a los dos');
  perform public.svc_session_set_flag(s, a, 'preloaded', true, t + interval '6 seconds');
  perform public.svc_session_set_flag(s, b, 'preloaded', true, t + interval '7 seconds');
  r := public.svc_session_tick(s, t + interval '8 seconds');
  perform tests.assert_eq(r ->> 'paused', 'false', 'los dos listos: arranca');
  select * into sess from public.exam_sessions where id = s;
  perform tests.assert_eq(private.to_ms(sess.exam_started_at), private.to_ms(t + interval '11 seconds'), '3 s de margen (precision de ms)');

  -- the leader goes away: after 10 s the other Pro leads
  perform public.svc_session_presence(s, sess.leader_id, false, t + interval '20 seconds');
  perform public.svc_session_tick(s, t + interval '25 seconds');
  perform tests.assert_eq((select leader_id from public.exam_sessions where id = s), sess.leader_id, 'a los 5 s sigue');
  perform public.svc_session_tick(s, t + interval '31 seconds');
  perform tests.assert((select leader_id from public.exam_sessions where id = s) is distinct from sess.leader_id, 'a los 11 s dirige el otro');
end $$;
rollback;
