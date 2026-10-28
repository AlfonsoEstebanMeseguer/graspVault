-- Two plans (DECISIONS D-037): standard (8 €/month, everything so far) and pro
-- (10 €/month, + exam control). The plan only matters while the subscription is
-- active; the trial is standard. RevenueCat sends the plan as entitlement ids.

alter table public.entitlements add column plan text not null default 'standard';
alter table public.entitlements add constraint entitlements_plan_valid check (plan in ('standard', 'pro'));
grant select (plan) on public.entitlements to authenticated;

create or replace function private.has_pro(p_user uuid, p_now timestamptz) returns boolean
language sql stable set search_path = '' as $$
  select private.has_subscription(p_user, p_now)
     and coalesce((select e.plan = 'pro' from public.entitlements e where e.user_id = p_user), false)
$$;

-- While RevenueCat is postponed (D-020), new users are born with this plan.
insert into public.app_config (key, value) values ('assume_paid_plan', '"standard"') on conflict (key) do nothing;

create or replace function private.apply_assume_paid() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if coalesce((select (value)::text = 'true' from public.app_config where key = 'assume_paid'), false) then
    new.subscription_status := 'active';
    new.current_period_end := timestamptz '2100-01-01 00:00:00+00';
    new.plan := coalesce((select value #>> '{}' from public.app_config where key = 'assume_paid_plan'), 'standard');
  end if;
  return new;
end $$;

-- p_plan null = the event says nothing about the plan (keep it).
drop function public.svc_apply_rc_event(text, uuid, text, timestamptz, timestamptz);
create or replace function public.svc_apply_rc_event(
  p_event_id text, p_user uuid, p_status text, p_period_end timestamptz, p_event_at timestamptz, p_plan text default null
) returns boolean language plpgsql security definer set search_path = '' as $$
begin
  insert into public.revenuecat_events (event_id) values (p_event_id) on conflict do nothing;
  if not found then return false; end if; -- duplicate delivery
  update public.entitlements set subscription_status = p_status, current_period_end = p_period_end,
    last_rc_event_at = p_event_at, plan = coalesce(p_plan, plan)
  where user_id = p_user and (last_rc_event_at is null or last_rc_event_at <= p_event_at);
  return true;
end $$;

revoke all on function private.has_pro(uuid, timestamptz) from public, anon, authenticated;
grant execute on function private.has_pro(uuid, timestamptz) to service_role;
revoke all on function private.apply_assume_paid() from public, anon, authenticated;
revoke all on function public.svc_apply_rc_event(text, uuid, text, timestamptz, timestamptz, text) from public, anon, authenticated;
grant execute on function public.svc_apply_rc_event(text, uuid, text, timestamptz, timestamptz, text) to service_role;
