begin;
do $$
declare u uuid;
begin
  update public.app_config set value = 'true' where key = 'assume_paid';
  u := tests.user('paid_by_default');
  perform tests.assert_eq((select subscription_status from public.entitlements where user_id = u), 'active', 'interruptor: nace con suscripcion');
  perform tests.assert(public.svc_is_eligible(u), 'elegible sin trial');
  update public.app_config set value = 'false' where key = 'assume_paid';
  u := tests.user('trial_user');
  perform tests.assert_eq((select subscription_status from public.entitlements where user_id = u), 'none', 'sin interruptor: sin suscripcion');
  -- the token check fails closed when Vault is unavailable or the token is short
  perform tests.assert(not public.svc_verify_internal_token('short'), 'token corto rechazado');
end $$;
rollback;
