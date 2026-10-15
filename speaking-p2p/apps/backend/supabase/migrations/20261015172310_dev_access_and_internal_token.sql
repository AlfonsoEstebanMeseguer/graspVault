-- 1. "Everyone has paid" switch (DECISIONS D-020). RevenueCat is postponed: while
--    app_config.assume_paid is true, every NEW user is born with an active
--    subscription. The trial / paywall logic stays intact and tested; switching the
--    flag off restores it for new users without touching code.
-- 2. Internal token verified against Supabase Vault (DECISIONS D-021): the
--    cron-worker asks the database instead of keeping a copied hash in its env.
--    No secret is ever copied by hand between systems.

create table public.app_config (
  key text primary key,
  value jsonb not null
);
alter table public.app_config enable row level security;
revoke all on table public.app_config from anon, authenticated;
grant all on table public.app_config to service_role;
insert into public.app_config (key, value) values ('assume_paid', 'true');

create or replace function private.apply_assume_paid() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if coalesce((select (value)::text = 'true' from public.app_config where key = 'assume_paid'), false) then
    new.subscription_status := 'active';
    new.current_period_end := timestamptz '2100-01-01 00:00:00+00';
  end if;
  return new;
end $$;
create trigger entitlements_assume_paid before insert on public.entitlements
for each row execute function private.apply_assume_paid();
revoke all on function private.apply_assume_paid() from public, anon, authenticated;

-- Constant-time-ish comparison of hashes, so timing does not leak the token.
create or replace function public.svc_verify_internal_token(p_token text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare v_secret text;
begin
  if p_token is null or length(p_token) < 32 then return false; end if;
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'internal_cron_token';
  if v_secret is null then return false; end if; -- fail closed
  return encode(sha256(convert_to(p_token, 'UTF8')), 'hex') = encode(sha256(convert_to(v_secret, 'UTF8')), 'hex');
end $$;
revoke all on function public.svc_verify_internal_token(text) from public, anon, authenticated;
grant execute on function public.svc_verify_internal_token(text) to service_role;
