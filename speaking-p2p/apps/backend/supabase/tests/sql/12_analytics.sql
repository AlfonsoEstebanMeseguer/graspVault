-- Server-side analytics outbox (D-063): one row per user and per fact, written by
-- triggers in the same transaction, closed to every client.
begin;
create function pg_temp.n(p_user uuid, p_event text) returns int language sql as $$
  select count(*)::int from public.analytics_outbox where user_id = p_user and event = p_event
$$;
do $$
declare a uuid; b uuid; s uuid; t0 timestamptz := now(); r jsonb; props jsonb;
begin
  a := tests.user('an_a', 'B2'); b := tests.user('an_b', 'B2');
  perform tests.assert_eq((select count(*)::int from public.analytics_outbox), 0, 'onboarding: nada en la cola (signup va directo)');

  -- live match: both users, once
  perform public.svc_match_enqueue(a, 'B2', 1, t0);
  s := (public.svc_match_enqueue(b, 'B2', 1, t0) ->> 'session_id')::uuid;
  perform public.svc_match_enqueue(a, 'B2', 1, t0 + interval '1 second');   -- heartbeat after the match
  perform tests.assert_eq(pg_temp.n(a, 'matchmaking_matched') + pg_temp.n(b, 'matchmaking_matched'), 2, 'un matched por usuario');
  select properties into props from public.analytics_outbox where user_id = a and event = 'matchmaking_matched';
  perform tests.assert_eq(props, '{"level": "B2", "origin": "live"}'::jsonb, 'solo nivel y origen');

  -- lobby: first join only
  perform public.svc_session_presence(s, a, true, t0);
  perform public.svc_session_presence(s, b, true, t0);
  perform public.svc_session_presence(s, a, false, t0 + interval '5 seconds');
  perform public.svc_session_presence(s, a, true, t0 + interval '6 seconds');
  perform tests.assert_eq(pg_temp.n(a, 'exam_lobby_entered'), 1, 'reconectar no repite exam_lobby_entered');
  perform tests.assert_eq(pg_temp.n(b, 'exam_lobby_entered'), 1, 'b entra al lobby');

  -- part 1 starts once, however many ticks
  perform public.svc_session_set_flag(s, a, 'preloaded', true, t0 + interval '7 seconds');
  perform public.svc_session_set_flag(s, b, 'preloaded', true, t0 + interval '7 seconds');
  perform public.svc_session_set_flag(s, a, 'ready', true, t0 + interval '8 seconds');
  perform public.svc_session_set_flag(s, b, 'ready', true, t0 + interval '8 seconds');
  r := public.svc_session_tick(s, t0 + interval '20 seconds');
  r := public.svc_session_tick(s, t0 + interval '21 seconds');
  perform tests.assert_eq(r ->> 'state', 'part1', 'examen en la parte 1');
  perform tests.assert_eq(pg_temp.n(a, 'exam_part_started'), 1, 'part 1 una sola vez pese a dos ticks');
  select properties into props from public.analytics_outbox where user_id = b and event = 'exam_part_started';
  perform tests.assert_eq((props ->> 'part')::int, 1, 'lleva la parte');

  -- b leaves: both get exam_aborted, by_me tells who
  perform public.svc_session_abort(s, b, 'left', t0 + interval '30 seconds');
  select properties into props from public.analytics_outbox where user_id = b and event = 'exam_aborted';
  perform tests.assert_eq(props ->> 'by_me', 'true', 'b abandono');
  perform tests.assert_eq(props ->> 'at', 'part1', 'en que parte');
  select properties into props from public.analytics_outbox where user_id = a and event = 'exam_aborted';
  perform tests.assert_eq(props ->> 'by_me', 'false', 'a no abandono');
  perform tests.assert_eq(pg_temp.n(a, 'exam_completed'), 0, 'abortado no es completado');

  -- closed to clients
  perform tests.as_user(a);
  perform tests.assert_fails('select 1 from public.analytics_outbox', 'permission denied', 'authenticated no lee la cola');
  perform tests.assert_fails('insert into public.analytics_outbox (user_id, event) values (auth.uid(), ''exam_completed'')',
    'permission denied', 'ni puede inventarse eventos');
  perform tests.assert_fails(format('select private.analytics_emit(%L, ''exam_completed'', ''{}'')', a), 'permission denied', 'ni llamar al emisor');
  reset role;
end $$;
rollback;

-- Agenda: offer, acceptance (born confirmed), no-show.
begin;
create function pg_temp.n(p_user uuid, p_event text) returns int language sql as $$
  select count(*)::int from public.analytics_outbox where user_id = p_user and event = p_event
$$;
do $$
declare a uuid; b uuid; o uuid; r jsonb; m uuid; at timestamptz := date_trunc('hour', now()) + interval '2 hours';
begin
  a := tests.user('ag_a'); b := tests.user('ag_b');
  o := public.svc_offer_create(a, 'B2', now() + interval '1 hour', now() + interval '3 hours');
  perform tests.assert_eq(pg_temp.n(a, 'meeting_offer_created'), 1, 'oferta creada');
  r := public.svc_offer_accept(b, o, at);
  perform tests.assert_eq(pg_temp.n(b, 'meeting_accepted'), 1, 'b acepta');
  perform tests.assert_eq(pg_temp.n(a, 'meeting_accepted'), 0, 'a no acepta nada');
  perform tests.assert_eq(pg_temp.n(a, 'meeting_confirmed') + pg_temp.n(b, 'meeting_confirmed'), 2, 'confirmada para los dos');

  -- nobody shows up: the agenda cron marks the no-show for both
  perform public.svc_cron_agenda(at + interval '11 minutes');
  perform tests.assert_eq(pg_temp.n(a, 'meeting_no_show') + pg_temp.n(b, 'meeting_no_show'), 2, 'no_show de los dos');
  perform tests.assert_eq(pg_temp.n(a, 'meeting_confirmed'), 1, 'el no_show no repite confirmed');
end $$;
rollback;

-- Opt-out (D-064): nothing is queued, pending rows are dropped, only the owner flips it.
begin;
do $$
declare a uuid; b uuid; o uuid; n int;
begin
  a := tests.user('oo_a'); b := tests.user('oo_b');
  o := public.svc_offer_create(a, 'B2', now() + interval '1 hour', now() + interval '3 hours');
  perform tests.assert_eq((select count(*)::int from public.analytics_outbox where user_id = a), 1, 'antes del opt-out: encolado');

  perform tests.as_user(a);
  update public.profiles_private set analytics_opt_out = true where id = a;
  update public.profiles_private set analytics_opt_out = true where id = b;   -- RLS: 0 rows
  select analytics_opt_out::int into n from public.profiles_private where id = a;
  perform tests.assert_eq(n, 1, 'el usuario lee su propia preferencia');
  reset role;

  perform tests.assert_eq((select count(*)::int from public.analytics_outbox where user_id = a), 0, 'el opt-out borra lo pendiente');
  perform tests.assert_eq((select analytics_opt_out from public.profiles_private where id = b), false, 'nadie cambia la preferencia de otro');
  o := public.svc_offer_create(a, 'B2', now() + interval '4 hours', now() + interval '6 hours');
  perform tests.assert_eq((select count(*)::int from public.analytics_outbox where user_id = a), 0, 'tras el opt-out: nada se encola');
  perform public.svc_offer_create(b, 'B2', now() + interval '1 hour', now() + interval '3 hours');
  perform tests.assert_eq((select count(*)::int from public.analytics_outbox where user_id = b), 1, 'los demas siguen contando');
end $$;
rollback;
