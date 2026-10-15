-- Test helpers (plain SQL suite). Loaded after the migrations and the catalog seed.
create schema if not exists tests;

create or replace function tests.assert(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ASSERT FAILED: %', msg; end if;
end $$;

create or replace function tests.assert_eq(actual anyelement, expected anyelement, msg text) returns void language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'ASSERT FAILED: % (expected %, got %)', msg, expected, actual;
  end if;
end $$;

-- Runs SQL and asserts it fails with a message containing `expected`. Asserting the
-- MESSAGE, not just the SQLSTATE: 42501 is the same code for "RLS said no" and for
-- "the policy cannot be evaluated for anyone" (vault, RLS point 18).
create or replace function tests.assert_fails(sql text, expected text, msg text) returns void language plpgsql as $$
begin
  begin
    execute sql;
  exception when others then
    if position(expected in sqlerrm) = 0 then
      raise exception 'ASSERT FAILED: % (expected error containing "%", got "%")', msg, expected, sqlerrm;
    end if;
    return;
  end;
  raise exception 'ASSERT FAILED: % (expected an error containing "%", got success)', msg, expected;
end $$;

-- Creates an auth user + onboarded profile with an entitlement row.
create or replace function tests.user(p_name text, p_level text default 'B2', p_sub boolean default false) returns uuid
language plpgsql as $$
declare v uuid;
begin
  insert into auth.users (email) values (p_name || '@example.com') returning id into v;
  perform public.svc_onboarding_complete(v, p_name || '@example.com', 'u_' || p_name, array['es', 'en'], p_level,
                                         date '2000-01-01', '+34612345678', 'v1');
  if p_sub then
    update public.entitlements set subscription_status = 'active', current_period_end = now() + interval '30 days' where user_id = v;
  end if;
  return v;
end $$;

-- Impersonation. `set local role` lasts the whole TRANSACTION, so always call
-- tests.as_service() (or reset role) before going back to admin work.
create or replace function tests.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p::text, ''), true);
  execute 'set local role authenticated';
end $$;
create or replace function tests.as_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  execute 'set local role anon';
end $$;
grant usage on schema tests to anon, authenticated, service_role;
grant execute on all functions in schema tests to anon, authenticated, service_role;
