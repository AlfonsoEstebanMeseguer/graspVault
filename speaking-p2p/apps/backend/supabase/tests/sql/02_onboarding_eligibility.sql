begin;
do $$
declare u uuid; v uuid; r jsonb;
begin
  insert into auth.users (email) values ('kid@example.com') returning id into u;
  perform tests.assert_fails(format($q$select public.svc_onboarding_complete(%L, 'kid@example.com', 'kid', array['es'], 'B1',
      (current_date - interval '13 years')::date, null, 'v1')$q$, u), 'underage', 'menor de 14 bloqueado');
  perform tests.assert_fails(format($q$select public.svc_onboarding_complete(%L, 'kid@example.com', 'Bad Name!', array['es'], 'B1',
      date '2000-01-01', null, 'v1')$q$, u), 'profiles_username_format', 'username con formato invalido');
  perform tests.assert_fails(format($q$select public.svc_onboarding_complete(%L, 'kid@example.com', 'kiddo', array['español'], 'B1',
      date '2000-01-01', null, 'v1')$q$, u), 'profiles_languages_valid', 'idiomas en ISO 639-1');
  perform tests.assert_fails(format($q$select public.svc_onboarding_complete(%L, 'kid@example.com', 'kiddo', array['es'], 'B1',
      date '2000-01-01', '612', 'v1')$q$, u), 'profiles_private_phone_format', 'telefono E.164');

  r := public.svc_onboarding_complete(u, 'Kid@Example.com', 'kiddo', array['es'], 'B1', (current_date - interval '14 years')::date, null, 'v1');
  perform tests.assert_eq(r ->> 'trial_available', 'true', '14 justos: alta con trial');
  perform tests.assert(public.svc_is_eligible(u), 'trial sin usar = elegible');
  perform tests.assert_eq((select terms_version from public.profiles_private where id = u), 'v1', 'version de terminos guardada');
  perform tests.assert((select terms_accepted_at from public.profiles_private where id = u) is not null, 'fecha de aceptacion guardada');

  insert into auth.users (email) values ('other@example.com') returning id into v;
  perform tests.assert_fails(format($q$select public.svc_onboarding_complete(%L, 'other@example.com', 'kiddo', array['es'], 'B1',
      date '2000-01-01', null, 'v1')$q$, v), 'username_taken', 'username unico');

  -- trial used -> not eligible; subscription -> eligible; expired subscription -> not
  update public.entitlements set trial_used_at = now() where user_id = u;
  perform tests.assert(not public.svc_is_eligible(u), 'trial usado y sin suscripcion');
  update public.entitlements set subscription_status = 'active', current_period_end = now() + interval '1 day' where user_id = u;
  perform tests.assert(public.svc_is_eligible(u), 'suscripcion activa');
  update public.entitlements set subscription_status = 'cancelled' where user_id = u;
  perform tests.assert(public.svc_is_eligible(u), 'cancelada pero dentro del periodo pagado');
  update public.entitlements set current_period_end = now() - interval '1 minute' where user_id = u;
  perform tests.assert(not public.svc_is_eligible(u), 'periodo vencido');

  -- RevenueCat: idempotent and ignores out-of-order events
  perform tests.assert(public.svc_apply_rc_event('ev1', u, 'active', now() + interval '30 days', now()), 'evento aplicado');
  perform tests.assert(not public.svc_apply_rc_event('ev1', u, 'expired', now(), now()), 'duplicado ignorado');
  perform public.svc_apply_rc_event('ev0', u, 'expired', now() - interval '1 day', now() - interval '1 hour');
  perform tests.assert_eq((select subscription_status from public.entitlements where user_id = u), 'active', 'evento antiguo no pisa uno nuevo');
end $$;
rollback;

-- The trial tombstone survives account deletion (delete from auth.users = the real GDPR path).
begin;
do $$
declare a uuid; b uuid; s uuid; r jsonb;
begin
  a := tests.user('ana', 'B1'); b := tests.user('ben', 'B1');
  s := (public.svc_match_enqueue(a, 'B1', 1) || public.svc_match_enqueue(b, 'B1', 1)) ->> 'session_id';
  perform public.svc_session_presence(s, a, true); perform public.svc_session_presence(s, b, true);
  perform public.svc_session_set_flag(s, a, 'ready', true); perform public.svc_session_set_flag(s, b, 'ready', true);
  perform public.svc_session_set_flag(s, a, 'preloaded', true);
  perform tests.assert_eq(public.svc_session_set_flag(s, b, 'preloaded', true), 'part1', 'empieza');
  perform public.svc_account_prepare_delete(a);
  delete from auth.users where id = a;
  perform tests.assert((select count(*) from public.profiles where id = a) = 0, 'perfil borrado en cascada');
  insert into auth.users (email) values ('ana@example.com') returning id into a;
  r := public.svc_onboarding_complete(a, 'ana@example.com', 'ana2', array['es'], 'B1', date '2000-01-01', null, 'v1');
  perform tests.assert_eq(r ->> 'trial_available', 'false', 'misma cuenta de Google no recupera el trial');
  perform tests.assert(not public.svc_is_eligible(a), 'y no es elegible');
end $$;
rollback;
