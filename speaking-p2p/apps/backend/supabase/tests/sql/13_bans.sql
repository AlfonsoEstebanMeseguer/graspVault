-- Permanent expulsion (D-065): only the email hash survives, and it blocks a new sign-up.
begin;
do $$
declare a uuid; b uuid; c uuid; o uuid;
begin
  a := tests.user('ban_a'); b := tests.user('ban_b');
  insert into public.user_reports (reporter_id, reported_id, reason, context)
  values (b, a, 'harassment', 'chat');
  o := public.svc_offer_create(a, 'B2', now() + interval '1 hour', now() + interval '3 hours');

  perform private.ban_user(a, 'harassment, report from ban_b');

  perform tests.assert(not exists (select 1 from auth.users where id = a), 'la cuenta se borra');
  perform tests.assert(not exists (select 1 from public.profiles where id = a), 'el perfil se borra');
  perform tests.assert(not exists (select 1 from public.meeting_offers where id = o and status = 'open'), 'sus ofertas dejan el tablon');
  perform tests.assert_eq((select count(*)::int from public.banned_identities), 1, 'queda una sola huella');
  perform tests.assert_eq((select email_hash from public.banned_identities), private.email_hash('ban_a@example.com'), 'solo el hash del email');
  perform tests.assert_eq((select status from public.user_reports where reporter_id = b), 'actioned', 'el reporte queda resuelto');

  -- Same email (any case) cannot sign up again; a different one can.
  insert into auth.users (email) values ('Ban_A@Example.com') returning id into c;
  perform tests.assert_fails(format($q$select public.svc_onboarding_complete(%L, 'Ban_A@Example.com', 'back_again', array['es'], 'B2',
      date '2000-01-01', 'v1')$q$, c), 'banned', 'el expulsado no vuelve a registrarse');
  perform tests.user('ban_c');

  -- Closed to clients.
  perform tests.as_user(b);
  perform tests.assert_fails('select 1 from public.banned_identities', 'permission denied', 'nadie lee la lista');
  perform tests.assert_fails(format('select private.ban_user(%L, ''x'')', b), 'permission denied', 'ni expulsa a nadie');
  reset role;
end $$;
rollback;
