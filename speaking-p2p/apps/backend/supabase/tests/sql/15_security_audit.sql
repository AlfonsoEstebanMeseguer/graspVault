-- Regression tests for the 2026-11 security audit fixes (docs/SECURITY_AUDIT_2026-11.md).
begin;
do $$
declare a uuid; b uuid; c uuid; d uuid; o uuid; r jsonb; t0 timestamptz; m uuid; chat uuid; s uuid; at timestamptz;
  rid bigint; x uuid; x2 uuid;
begin
  a := tests.user('sa_a', 'B2', true); b := tests.user('sa_b', 'B2', true);
  c := tests.user('sa_c', 'B2', true); d := tests.user('sa_d', 'B2', true);

  -- C15: a confirmed meeting cannot be rescheduled once it started (or has a session).
  t0 := date_trunc('hour', now()) + interval '2 hours';
  o := public.svc_offer_create(a, 'B2', t0, t0 + interval '1 hour', now());
  r := public.svc_offer_accept(b, o, t0, now());
  m := (r ->> 'meeting_id')::uuid; chat := (r ->> 'chat_id')::uuid;

  perform tests.assert_eq((select status from public.meetings where id = m), 'confirmed', 'C15 setup: confirmada');
  s := public.svc_meeting_enter(b, m, 1, t0 + interval '2 minutes');
  perform tests.assert_fails(format('select public.svc_meeting_modify(%L, %L, %L, ''B2'', %L)', a, m, t0 + interval '1 day', t0 + interval '8 minutes'),
                             'too_late', 'C15 no se reprograma una reunion empezada');
  perform tests.assert_fails(format('select public.svc_meeting_modify(%L, %L, %L, ''B2'', %L)', a, m, t0 + interval '1 day', t0 - interval '4 minutes'),
                             'too_late', 'C15 ni dentro de la ventana de entrada');
  perform public.svc_cron_agenda(t0 + interval '11 minutes');
  perform tests.assert_eq((select status from public.meetings where id = m), 'no_show', 'C15 el no-show se marca');

  -- C14: block cancels a meeting already under way; mutations refuse blocked pairs.
  at := date_trunc('hour', now()) + interval '5 hours';
  o := public.svc_offer_create(c, 'B2', at, at + interval '1 hour', now());
  r := public.svc_offer_accept(d, o, at, now());
  m := (r ->> 'meeting_id')::uuid;

  update public.meetings set scheduled_at = now() - interval '15 minutes' where id = m; -- under way
  perform tests.as_user(c);
  perform public.block_user(d);
  reset role;
  perform tests.assert_eq((select status from public.meetings where id = m), 'cancelled', 'C14 bloquear cancela la reunion en curso');
  update public.meetings set status = 'pending', scheduled_at = at where id = m; -- force a survivor
  perform tests.assert_fails(format('select public.svc_meeting_modify(%L, %L, %L, ''C1'', %L)', d, m, at + interval '1 day', now()),
                             'not_found', 'C14 el bloqueado no modifica');
  perform tests.assert_fails(format('select public.svc_meeting_confirm(%L, %L, %L)', c, m, now()),
                             'not_found', 'C14 ni se confirma');
  update public.meetings set status = 'confirmed' where id = m;
  perform tests.assert_fails(format('select public.svc_meeting_enter(%L, %L, 1, %L)', d, m, at),
                             'not_found', 'C14 ni se entra');

  -- C3: report_user only accepts the chat of the reporter/reported pair.
  perform tests.as_user(c);
  perform tests.assert_fails(format('select public.report_user(%L, ''spam'', null, ''chat'', null, %L)', d, chat),
                             'not_in_chat', 'C3 no se adjunta un chat ajeno');
  reset role;
  perform tests.as_user(b);
  perform public.report_user(a, 'harassment', 'x', 'chat', null, chat); -- own chat with a: fine
  reset role;
  perform tests.assert_eq((select count(*)::int from public.user_reports where chat_id = chat), 1, 'C3 el chat propio si');

  -- C9: a reported user who deletes the account can still be banned.
  x := tests.user('sa_x', 'B2', true);
  perform tests.as_user(b);
  perform public.report_user(x, 'harassment', null, 'profile', null, null);
  reset role;
  select id into rid from public.user_reports where reported_id = x;
  perform public.svc_account_prepare_delete(x);
  delete from auth.users where id = x;
  perform tests.assert_eq((select reported_email_hash is not null from public.user_reports where id = rid), true, 'C9 el hash queda en el reporte abierto');
  perform private.ban_report(rid, 'harassment');
  perform tests.assert_eq((select status from public.user_reports where id = rid), 'actioned', 'C9 reporte cerrado');
  perform tests.assert_eq((select reported_email_hash from public.user_reports where id = rid), null, 'C9 hash borrado tras el ban');
  insert into auth.users (email) values ('sa_x@example.com') returning id into x2;
  perform tests.assert_fails(format('select public.svc_onboarding_complete(%L, ''sa_x@example.com'', ''u_sa_x2'', array[''es''], ''B2'', date ''2000-01-01'', ''v1'')', x2),
                             'banned', 'C9 la misma identidad no vuelve');
  -- A dismissed report drops the hash (data minimisation).
  update public.user_reports set status = 'open', reported_email_hash = 'h' where id = rid;
  update public.user_reports set status = 'dismissed' where id = rid;
  perform tests.assert_eq((select reported_email_hash from public.user_reports where id = rid), null, 'C9 descartar borra el hash');
end $$;
rollback;
