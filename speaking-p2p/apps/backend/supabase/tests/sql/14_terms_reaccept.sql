-- Re-acceptance (D-066): the owner records a new version with the server's clock.
begin;
do $$
declare a uuid; b uuid; t timestamptz;
begin
  a := tests.user('tr_a'); b := tests.user('tr_b');
  update public.profiles_private set terms_accepted_at = now() - interval '30 days' where id in (a, b);

  perform tests.as_user(a);
  perform public.accept_terms('2026-12-01');
  reset role;
  select terms_accepted_at into t from public.profiles_private where id = a;
  perform tests.assert_eq((select terms_version from public.profiles_private where id = a), '2026-12-01', 'version nueva guardada');
  perform tests.assert(t > now() - interval '1 minute', 'fecha del servidor');
  perform tests.assert_eq((select terms_version from public.profiles_private where id = b), 'v1', 'solo la propia');

  perform tests.as_user(a);
  perform tests.assert_fails('select public.accept_terms('''')', 'bad_version', 'version vacia');
  perform tests.assert_fails('update public.profiles_private set terms_accepted_at = now() - interval ''1 year''', 'permission denied', 'la fecha no se toca a mano');
  reset role;
  perform tests.as_anon();
  perform tests.assert_fails('select public.accept_terms(''x'')', 'permission denied', 'anon no acepta');
  reset role;
end $$;
rollback;
