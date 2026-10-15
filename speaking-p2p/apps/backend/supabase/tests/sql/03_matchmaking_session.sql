-- Live matchmaking (exact level, FIFO, eligibility on the server) and the session state machine.
begin;
do $$
declare a uuid; b uuid; c uuid; d uuid; poor uuid; r jsonb; s uuid; t0 timestamptz := now();
begin
  a := tests.user('a1', 'B2'); b := tests.user('b1', 'B2'); c := tests.user('c1', 'C1'); d := tests.user('d1', 'B2');
  poor := tests.user('poor', 'B2');
  update public.entitlements set trial_used_at = t0 where user_id = poor;

  perform tests.assert_fails(format('select public.svc_match_enqueue(%L, ''B2'', 1)', poor), 'not_eligible', 'sin trial ni suscripcion: fuera de la cola');
  perform tests.assert_eq(public.svc_match_enqueue(a, 'B2', 1, t0) ->> 'status', 'queued', 'a espera');
  perform tests.assert_eq(public.svc_match_enqueue(a, 'B2', 1, t0 + interval '1 second') ->> 'status', 'queued', 'heartbeat idempotente');
  perform tests.assert_eq(public.svc_match_enqueue(c, 'C1', 1, t0 + interval '2 seconds') ->> 'status', 'queued', 'nivel exacto: C1 no casa con B2');
  perform tests.assert_eq(public.svc_match_enqueue(d, 'B2', 1, t0 + interval '3 seconds') ->> 'status', 'matched', 'd casa con a (FIFO)');
  s := private.active_session_of(a);
  perform tests.assert(s is not null and s = private.active_session_of(d), 'a y d comparten sesion');
  perform tests.assert_eq(public.svc_match_enqueue(b, 'B2', 1, t0 + interval '4 seconds') ->> 'status', 'queued', 'b ya no encuentra a nadie');
  perform tests.assert_eq(public.svc_match_enqueue(a, 'B2', 1, t0 + interval '5 seconds') ->> 'session_id', s::text, 'a en sesion vuelve a su sesion');
  -- stale entries (no heartbeat for >25 s) never match
  perform tests.assert_eq(public.svc_match_enqueue(c, 'C1', 1, t0 + interval '60 seconds') ->> 'status', 'queued', 'c renueva');
  perform tests.assert_eq((select count(*)::int from public.match_queue), 2, 'b y c en cola');
end $$;
rollback;

begin;
do $$
declare a uuid; b uuid; t0 timestamptz := now();
begin
  a := tests.user('ghost', 'B1'); b := tests.user('late', 'B1');
  perform public.svc_match_enqueue(a, 'B1', 1, t0);
  perform tests.assert_eq(public.svc_match_enqueue(b, 'B1', 1, t0 + interval '26 seconds') ->> 'status', 'queued',
    'sin heartbeat en 25 s, a es un fantasma y no se empareja');
  perform tests.assert_eq(public.svc_match_enqueue(a, 'B1', 1, t0 + interval '27 seconds') ->> 'status', 'matched',
    'a vuelve a latir y casa con b');
end $$;
rollback;

begin;
do $$
declare a uuid; b uuid; s uuid; sess public.exam_sessions; r jsonb; t0 timestamptz := now(); t timestamptz; total bigint; n int;
begin
  a := tests.user('a2', 'C1'); b := tests.user('b2', 'C1', true);   -- b has a subscription, a uses the trial
  perform public.svc_match_enqueue(a, 'C1', 1, t0);
  s := (public.svc_match_enqueue(b, 'C1', 1, t0) ->> 'session_id')::uuid;
  select * into sess from public.exam_sessions where id = s;
  perform tests.assert_eq(sess.state, 'lobby', 'empieza en lobby');
  perform tests.assert_eq(sess.exam_id, 'c1-work-and-technology', 'examen del nivel');

  -- ghost: only one joins, live session aborts as no_show after 90 s
  perform public.svc_session_presence(s, a, true, t0);
  r := public.svc_session_tick(s, t0 + interval '30 seconds');
  perform tests.assert_eq(r ->> 'state', 'lobby', 'aun esperando');
  perform tests.assert_eq(r -> 'mic', '{"A":true,"B":true}'::jsonb, 'lobby: llamada libre');
  perform public.svc_session_presence(s, b, true, t0 + interval '40 seconds');
  select * into sess from public.exam_sessions where id = s;
  perform tests.assert_eq(sess.lobby_deadline, t0 + interval '40 seconds' + interval '5 minutes', 'el reloj del lobby arranca con los dos dentro');

  -- ready without preload does not start; trial not consumed in the lobby
  perform public.svc_session_set_flag(s, a, 'ready', true, t0 + interval '50 seconds');
  perform tests.assert_eq(public.svc_session_set_flag(s, b, 'ready', true, t0 + interval '50 seconds'), 'lobby', 'listos pero sin precarga');
  perform tests.assert((select trial_used_at from public.entitlements where user_id = a) is null, 'el trial no se gasta en el lobby');
  perform public.svc_session_set_flag(s, a, 'recording', true, t0 + interval '55 seconds');
  perform public.svc_session_set_flag(s, a, 'preloaded', true, t0 + interval '60 seconds');
  t := t0 + interval '61 seconds';
  perform tests.assert_eq(public.svc_session_set_flag(s, b, 'preloaded', true, t), 'part1', 'listos y precargados: parte 1');
  select * into sess from public.exam_sessions where id = s;
  perform tests.assert_eq(sess.exam_started_at, t + interval '3 seconds', '3 s de margen');
  perform tests.assert(case when sess.user_a = a then sess.recording_consent_a and not sess.recording_consent_b
                            else sess.recording_consent_b and not sess.recording_consent_a end, 'grabacion: solo a consintio (los roles son aleatorios)');
  perform tests.assert_eq((select trial_used_at from public.entitlements where user_id = a), t, 'trial de a consumido al empezar la parte 1');
  perform tests.assert((select trial_used_at from public.entitlements where user_id = b) is null, 'b con suscripcion conserva su trial');
  perform tests.assert_fails(format('select public.svc_session_set_flag(%L, %L, ''ready'', false)', s, a), 'not_in_lobby', 'flags solo en el lobby');
  perform tests.assert_eq((select count(*)::int from public.exam_history where session_id = s), 2, 'historial de los dos');

  -- walk the timeline: reader segment mutes both, turn opens only the target
  total := (sess.schedule ->> 'totalMs')::bigint;
  r := public.svc_session_tick(s, sess.exam_started_at - interval '1 second');
  perform tests.assert_eq(r ->> 'segment', '0', 'antes del arranque: segmento 0');
  perform tests.assert_eq(r -> 'mic', '{"A":false,"B":false}'::jsonb, 'lector: micros cerrados');
  perform tests.assert_eq(r ->> 'needs_push', 'true', 'hay que empujar el silencio a LiveKit');
  perform public.svc_session_mark_applied(s, 0);
  perform tests.assert_eq(public.svc_session_tick(s, sess.exam_started_at) ->> 'needs_push', 'false', 'ya aplicado');
  -- first 'speak' segment of Part 1 is candidate A's turn
  select (seg ->> 'startMs')::bigint, (seg ->> 'index')::int into total, n from jsonb_array_elements(sess.schedule -> 'segments') seg
  where seg ->> 'phase' = 'speak' order by (seg ->> 'index')::int limit 1;
  r := public.svc_session_tick(s, sess.exam_started_at + make_interval(secs => total / 1000.0 + 0.1));
  perform tests.assert_eq(r ->> 'state', 'part1', 'parte 1');
  perform tests.assert_eq((r ->> 'segment')::int, n, 'segmento de habla');
  perform tests.assert_eq(r -> 'mic', '{"A":true,"B":false}'::jsonb, 'turno de A: solo A');
  -- part 3 is open for both after the reader
  select (seg ->> 'startMs')::bigint into total from jsonb_array_elements(sess.schedule -> 'segments') seg
  where seg ->> 'part' = '3' and seg ->> 'phase' = 'speak' order by (seg ->> 'index')::int limit 1;
  r := public.svc_session_tick(s, sess.exam_started_at + make_interval(secs => total / 1000.0 + 1));
  perform tests.assert_eq(r ->> 'state', 'part3', 'parte 3');
  perform tests.assert_eq(r -> 'mic', '{"A":true,"B":true}'::jsonb, 'parte 3: los dos');

  -- disconnection: 59 s is fine, 60 s aborts
  perform public.svc_session_presence(s, b, false, sess.exam_started_at + interval '400 seconds');
  perform tests.assert_eq(public.svc_session_tick(s, sess.exam_started_at + interval '459 seconds') ->> 'state', 'part3', 'gracia de 60 s');
  perform public.svc_session_presence(s, b, true, sess.exam_started_at + interval '459 seconds');
  perform tests.assert(public.svc_session_tick(s, sess.exam_started_at + interval '600 seconds') ->> 'state' <> 'aborted', 'reconecto a tiempo: sigue viva');

  -- feedback then ended
  total := (sess.schedule ->> 'totalMs')::bigint;
  r := public.svc_session_tick(s, sess.exam_started_at + make_interval(secs => total / 1000.0));
  perform tests.assert_eq(r ->> 'state', 'feedback', 'feedback');
  perform tests.assert_eq(r -> 'mic', '{"A":true,"B":true}'::jsonb, 'feedback: micros abiertos');
  r := public.svc_session_tick(s, sess.exam_started_at + make_interval(secs => total / 1000.0 + 300));
  perform tests.assert_eq(r ->> 'state', 'ended', 'ended a los 5 min');
  perform tests.assert_eq(r -> 'mic', '{"A":false,"B":false}'::jsonb, 'cuelga');
  perform tests.assert((select bool_and(completed) from public.exam_history where session_id = s), 'historial completado');
  perform tests.assert(private.active_session_of(a) is null, 'a libre');
  perform tests.assert(not public.svc_is_eligible(a), 'a ya no tiene trial');
end $$;
rollback;

-- Disconnection abort, ineligible at start, abandon, rotation.
begin;
do $$
declare a uuid; b uuid; s uuid; sess public.exam_sessions; t0 timestamptz := now(); i int; ex text;
begin
  a := tests.user('a3', 'B1', true); b := tests.user('b3', 'B1', true);
  perform public.svc_match_enqueue(a, 'B1', 1, t0);
  s := (public.svc_match_enqueue(b, 'B1', 1, t0) ->> 'session_id')::uuid;
  perform public.svc_session_presence(s, a, true, t0); perform public.svc_session_presence(s, b, true, t0);
  -- nobody presses ready: the lobby deadline starts the exam anyway (even without preload)
  perform tests.assert_eq(public.svc_session_tick(s, t0 + interval '299 seconds') ->> 'state', 'lobby', '4:59 en lobby');
  perform tests.assert_eq(public.svc_session_tick(s, t0 + interval '300 seconds') ->> 'state', 'part1', 'a los 5 min empieza solo');
  perform public.svc_session_presence(s, a, false, t0 + interval '320 seconds');
  perform tests.assert_eq(public.svc_session_tick(s, t0 + interval '380 seconds') ->> 'state', 'aborted', '60 s sin volver: aborted');
  select * into sess from public.exam_sessions where id = s;
  perform tests.assert_eq(sess.abort_reason, 'disconnected', 'motivo');
  perform tests.assert_eq(sess.aborted_by, a, 'quien se cayo');
  perform tests.assert_eq((select completed from public.exam_history where session_id = s and user_id = b), false, 'no completado');

  -- rotation: with two B1 exams, the next session picks the one neither has done
  insert into public.exam_catalog (id, level, version, content_version, timeline, total_ms)
  select 'b1-second', 'B1', 1, 1, timeline, total_ms from public.exam_catalog where id = 'b1-weekend-city';
  insert into public.exam_catalog (id, level, version, content_version, timeline, total_ms)
  select 'b1-future', 'B1', 1, 99, timeline, total_ms from public.exam_catalog where id = 'b1-weekend-city';
  for i in 1..5 loop
    ex := private.pick_exam('B1', a, b, 1);
    perform tests.assert_eq(ex, 'b1-second', 'el que ninguno ha hecho (y nunca uno de contenido mas nuevo que la app)');
  end loop;
  insert into public.exam_sessions (level, exam_id, exam_version, user_a, user_b, origin, state)
  values ('B1', 'b1-second', 1, a, b, 'live', 'ended') returning id into s;
  insert into public.exam_history (user_id, exam_id, session_id, started_at) values (b, 'b1-second', s, t0 + interval '1 hour');
  perform tests.assert_eq(private.pick_exam('B1', a, b, 1), 'b1-weekend-city', 'todos hechos: el mas antiguo para ambos');
end $$;
rollback;

begin;
do $$
declare a uuid; b uuid; s uuid; t0 timestamptz := now();
begin
  a := tests.user('a4', 'B2'); b := tests.user('b4', 'B2');
  perform public.svc_match_enqueue(a, 'B2', 1, t0);
  s := (public.svc_match_enqueue(b, 'B2', 1, t0) ->> 'session_id')::uuid;
  perform public.svc_session_presence(s, a, true, t0); perform public.svc_session_presence(s, b, true, t0);
  -- b spends the trial elsewhere meanwhile: at start, the session aborts and a keeps the trial
  update public.entitlements set trial_used_at = t0 where user_id = b;
  perform tests.assert_eq(public.svc_session_tick(s, t0 + interval '5 minutes') ->> 'state', 'aborted', 'b ya no es elegible');
  perform tests.assert_eq((select abort_reason from public.exam_sessions where id = s), 'ineligible', 'motivo ineligible');
  perform tests.assert((select trial_used_at from public.entitlements where user_id = a) is null, 'a no pierde su trial');

  -- abandon during the exam keeps the trial consumed
  update public.entitlements set trial_used_at = null where user_id = b;
  perform public.svc_match_enqueue(a, 'B2', 1, t0);
  s := (public.svc_match_enqueue(b, 'B2', 1, t0) ->> 'session_id')::uuid;
  perform public.svc_session_presence(s, a, true, t0); perform public.svc_session_presence(s, b, true, t0);
  perform public.svc_session_tick(s, t0 + interval '5 minutes');
  perform public.svc_session_abort(s, a);
  perform tests.assert_eq((select state from public.exam_sessions where id = s), 'aborted', 'abandono');
  perform tests.assert(not public.svc_is_eligible(a), 'el trial sigue consumido tras abandonar en la parte 1');
  perform tests.assert_fails(format('select public.svc_session_abort(%L, gen_random_uuid())', s), 'not_participant', 'solo participantes');
end $$;
rollback;
