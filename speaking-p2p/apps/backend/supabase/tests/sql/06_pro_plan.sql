-- Plan Pro (D-037): only an ACTIVE subscription with plan 'pro' is Pro.
begin;
do $$
declare u uuid; v uuid;
begin
  u := tests.user('std_user', 'B2', true);
  perform tests.assert(not private.has_pro(u, now()), 'estandar no es pro');
  update public.entitlements set plan = 'pro' where user_id = u;
  perform tests.assert(private.has_pro(u, now()), 'pro activo');
  update public.entitlements set current_period_end = now() - interval '1 day' where user_id = u;
  perform tests.assert(not private.has_pro(u, now()), 'pro caducado no es pro');

  v := tests.user('trialist');
  update public.entitlements set plan = 'pro' where user_id = v;
  perform tests.assert(not private.has_pro(v, now()), 'sin suscripcion (test de prueba) no es pro');

  -- RevenueCat: the plan comes with the event; an event without plan keeps it.
  perform public.svc_apply_rc_event('ev-pro-1', v, 'active', now() + interval '30 days', now(), 'pro');
  perform tests.assert(private.has_pro(v, now()), 'el webhook activa pro');
  perform public.svc_apply_rc_event('ev-pro-2', v, 'active', now() + interval '30 days', now() + interval '1 second', null);
  perform tests.assert_eq((select plan from public.entitlements where user_id = v), 'pro', 'evento sin plan no lo cambia');
  perform public.svc_apply_rc_event('ev-pro-3', v, 'active', now() + interval '30 days', now() + interval '2 seconds', 'standard');
  perform tests.assert(not private.has_pro(v, now()), 'bajar a estandar');

  -- Dev switch (D-020): new users born with the configured plan.
  update public.app_config set value = 'true' where key = 'assume_paid';
  update public.app_config set value = '"pro"' where key = 'assume_paid_plan';
  -- (two statements: has_pro is STABLE and would not see a row inserted by the same statement)
  u := tests.user('born_pro');
  perform tests.assert(private.has_pro(u, now()), 'nace pro con el interruptor');
  update public.app_config set value = '"standard"' where key = 'assume_paid_plan';
  u := tests.user('born_std');
  perform tests.assert(not private.has_pro(u, now()), 'nace estandar por defecto');
  update public.app_config set value = 'false' where key = 'assume_paid';
end $$;
rollback;
