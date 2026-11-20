-- Feedback rubric (D-042): only a participant rates, always the OTHER one, and
-- only the person rated (or the rater) reads it.
begin;
do $$
declare a uuid; b uuid; c uuid; s uuid; lobby uuid; ex text;
begin
  a := tests.user('rate_a'); b := tests.user('rate_b'); c := tests.user('rate_c');
  ex := (select id from public.exam_catalog where level = 'B2' limit 1);
  insert into public.exam_sessions (level, exam_id, exam_version, user_a, user_b, origin, state, exam_started_at)
  values ('B2', ex, 1, a, b, 'live', 'feedback', now() - interval '15 minutes') returning id into s;
  insert into public.exam_sessions (level, exam_id, exam_version, user_a, user_b, origin, state)
  values ('B2', ex, 1, a, b, 'live', 'lobby') returning id into lobby;

  perform tests.as_user(a);
  perform public.rate_partner(s, 4::smallint, 3::smallint, null, null);
  perform public.rate_partner(s, 4::smallint, 3::smallint, 5::smallint, 2::smallint); -- editing upserts
  perform tests.assert_eq((select count(*)::int from public.peer_ratings), 1, 'una fila por evaluador y sesión');
  perform tests.assert_eq((select ratee_id from public.peer_ratings), b, 'se valora siempre al otro');
  perform tests.assert_fails(format('select public.rate_partner(%L, 6::smallint, null, null, null)', s), 'peer_ratings_range', 'fuera de 1..5');
  perform tests.assert_fails(format('select public.rate_partner(%L, 3::smallint, null, null, null)', lobby), 'not_started', 'antes del examen no');
  perform tests.assert_fails('insert into public.peer_ratings (session_id, rater_id, ratee_id) values (gen_random_uuid(), auth.uid(), auth.uid())',
                             'permission denied', 'sin escritura directa');

  perform tests.as_user(c);
  perform tests.assert_fails(format('select public.rate_partner(%L, 3::smallint, null, null, null)', s), 'not_participant', 'un tercero no valora');
  perform tests.assert_eq((select count(*)::int from public.peer_ratings), 0, 'un tercero no ve nada');

  perform tests.as_user(b);
  perform tests.assert_eq((select pronunciation from public.peer_ratings where ratee_id = b), 5::smallint, 'el valorado lo ve');
  reset role;
end $$;
rollback;
