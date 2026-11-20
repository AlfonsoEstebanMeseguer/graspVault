-- Opt-out of product analytics (D-064, Privacy Policy §3 and §5): legitimate
-- interest with a switch in Settings, on by default. The choice lives here, not
-- only on the phone, so it also silences the SERVER events (analytics_outbox and
-- the direct ones) and follows the user to any device.

alter table public.profiles_private add column analytics_opt_out boolean not null default false;
grant select (analytics_opt_out), update (analytics_opt_out) on public.profiles_private to authenticated;

-- Every outbox trigger goes through here: an opted-out user is never queued.
create or replace function private.analytics_emit(p_user uuid, p_event text, p_props jsonb) returns void
language sql security definer set search_path = '' as $$
  insert into public.analytics_outbox (user_id, event, properties)
  select p_user, p_event, jsonb_strip_nulls(p_props)
  where p_user is not null
    and not exists (select 1 from public.profiles_private pp where pp.id = p_user and pp.analytics_opt_out)
$$;

-- Opting out also drops what was still waiting to be sent.
create or replace function private.analytics_opt_out_purge() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.analytics_opt_out and not old.analytics_opt_out then
    delete from public.analytics_outbox where user_id = new.id;
  end if;
  return null;
end $$;

create trigger profiles_private_analytics_opt_out after update of analytics_opt_out on public.profiles_private
for each row execute function private.analytics_opt_out_purge();

revoke all on function private.analytics_emit(uuid, text, jsonb), private.analytics_opt_out_purge()
  from public, anon, authenticated;
