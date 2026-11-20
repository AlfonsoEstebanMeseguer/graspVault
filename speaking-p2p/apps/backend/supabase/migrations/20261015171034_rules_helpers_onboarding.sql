-- Business rules that must hold under concurrency live here, in single
-- transactions, not in the Edge Functions (vault: "reglas criticas en backend,
-- comprobadas con for update en la misma transaccion").
--
-- Every svc_* function:
--   * is SECURITY DEFINER with search_path = '' (never a quoted list);
--   * takes the acting user explicitly (the Edge Function verified the JWT);
--   * is executable ONLY by service_role (PostgREST would expose it as a public RPC otherwise);
--   * takes p_now so tests can move the clock; Edge Functions never pass it.
-- Errors are raised with a stable machine code in MESSAGE and errcode P0001.
-- The Edge Function maps that code to an HTTP status and an i18n key.

alter table public.match_queue add column last_seen_at timestamptz not null default now();

-- ------------------------------------------------------------- small helpers
create or replace function private.fail(code text) returns void
language plpgsql as $$ begin raise exception '%', code using errcode = 'P0001'; end $$;

create or replace function private.lock_user(u uuid) returns void
language sql as $$ select pg_advisory_xact_lock(hashtextextended('user:' || u::text, 0)) $$;

-- Always lock two users in the same order, or two transactions deadlock.
create or replace function private.lock_users(a uuid, b uuid) returns void
language plpgsql as $$
begin
  if a::text < b::text then perform private.lock_user(a); perform private.lock_user(b);
  else perform private.lock_user(b); perform private.lock_user(a); end if;
end $$;

create or replace function private.has_subscription(p_user uuid, p_now timestamptz) returns boolean
language sql stable set search_path = '' as $$
  select coalesce((
    select e.subscription_status in ('active', 'grace', 'billing_issue', 'cancelled')
       and e.current_period_end > p_now
    from public.entitlements e where e.user_id = p_user), false)
$$;

create or replace function public.svc_is_eligible(p_user uuid, p_now timestamptz default now()) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.has_subscription(p_user, p_now)
      or coalesce((select e.trial_used_at is null from public.entitlements e where e.user_id = p_user), false)
$$;

create or replace function private.require_eligible(p_user uuid, p_now timestamptz) returns void
language plpgsql set search_path = '' as $$
begin
  if not public.svc_is_eligible(p_user, p_now) then perform private.fail('not_eligible'); end if;
end $$;

create or replace function private.active_session_of(p_user uuid) returns uuid
language sql stable set search_path = '' as $$
  select s.id from public.exam_sessions s
  where s.state not in ('ended', 'aborted') and p_user in (s.user_a, s.user_b)
  order by s.created_at desc limit 1
$$;

create or replace function private.system_message(p_chat uuid, p_code text, p_args jsonb default '{}') returns void
language sql set search_path = '' as $$
  insert into public.chat_messages (chat_id, sender_id, kind, system_code, system_args)
  values (p_chat, null, 'system', p_code, p_args)
$$;

create or replace function private.meeting_message(p_meeting uuid, p_code text, p_args jsonb default '{}') returns void
language sql set search_path = '' as $$
  select private.system_message(c.id, p_code, p_args) from public.chats c where c.meeting_id = p_meeting
$$;

-- ------------------------------------------------------------- onboarding
-- sha256() is a core function since PG 11: no extension needed.
create or replace function private.email_hash(p_email text) returns text
language sql immutable as $$
  select encode(sha256(convert_to(lower(btrim(coalesce(p_email, ''))), 'UTF8')), 'hex')
$$;

create or replace function public.svc_onboarding_complete(
  p_user uuid, p_email text, p_username text, p_languages text[], p_level text,
  p_birth_date date, p_phone text, p_terms_version text, p_now timestamptz default now()
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_claimed timestamptz;
begin
  if exists (select 1 from public.profiles where id = p_user) then perform private.fail('already_onboarded'); end if;
  if exists (select 1 from public.profiles where username = p_username) then perform private.fail('username_taken'); end if;
  insert into public.profiles (id, username, languages, target_level)
  values (p_user, p_username, p_languages, p_level);
  insert into public.profiles_private (id, birth_date, phone, terms_version, terms_accepted_at)
  values (p_user, p_birth_date, nullif(btrim(coalesce(p_phone, '')), ''), p_terms_version, p_now);
  -- A Google account that already burnt its trial (and deleted the account) gets no new one.
  select claimed_at into v_claimed from public.trial_claims
  where email_hash = private.email_hash(p_email);
  insert into public.entitlements (user_id, trial_used_at) values (p_user, v_claimed);
  return jsonb_build_object('trial_available', v_claimed is null);
end $$;



-- ------------------------------------------------------------- lock down
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname like 'svc\_%' loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
  for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'private' loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
end $$;
