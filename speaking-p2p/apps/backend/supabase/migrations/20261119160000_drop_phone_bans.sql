-- D-065 (docs/legal/ASPECTOS_A_COMPLETAR.md §5 and §14).
--
-- 1. The phone goes: it was asked for and stored but never used (data
--    minimisation, Art. 5.1.c GDPR). The stored numbers are erased with it.
-- 2. Banned identities: a permanent expulsion keeps ONLY sha256(lower(email)),
--    the same tombstone as trial_claims, so the same Google/Apple account cannot
--    sign up again. Privacy Policy §4 says so.

-- ---------------------------------------------------------------- 1. phone
update public.profiles_private set phone = null where phone is not null;
alter table public.profiles_private drop column phone;  -- its format check and column grants go with it

drop function public.svc_onboarding_complete(uuid, text, text, text[], text, date, text, text, timestamptz);

-- ---------------------------------------------------------------- 2. bans
create table public.banned_identities (
  email_hash text primary key,
  banned_at timestamptz not null default now(),
  reason text not null,
  constraint banned_identities_reason_len check (char_length(reason) between 1 and 500)
);
comment on table public.banned_identities is
  'sha256(lower(email)) of permanently expelled accounts. Tombstone without FK: must outlive auth.users rows.';
alter table public.banned_identities enable row level security;
revoke all on table public.banned_identities from anon, authenticated;
grant all on table public.banned_identities to service_role;

create function public.svc_onboarding_complete(
  p_user uuid, p_email text, p_username text, p_languages text[], p_level text,
  p_birth_date date, p_terms_version text, p_now timestamptz default now()
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_claimed timestamptz;
begin
  if exists (select 1 from public.banned_identities where email_hash = private.email_hash(p_email)) then
    perform private.fail('banned');
  end if;
  if exists (select 1 from public.profiles where id = p_user) then perform private.fail('already_onboarded'); end if;
  if exists (select 1 from public.profiles where username = p_username) then perform private.fail('username_taken'); end if;
  insert into public.profiles (id, username, languages, target_level)
  values (p_user, p_username, p_languages, p_level);
  insert into public.profiles_private (id, birth_date, terms_version, terms_accepted_at)
  values (p_user, p_birth_date, p_terms_version, p_now);
  -- A Google account that already burnt its trial (and deleted the account) gets no new one.
  select claimed_at into v_claimed from public.trial_claims
  where email_hash = private.email_hash(p_email);
  insert into public.entitlements (user_id, trial_used_at) values (p_user, v_claimed);
  return jsonb_build_object('trial_available', v_claimed is null);
end $$;
revoke all on function public.svc_onboarding_complete(uuid, text, text, text[], text, date, text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.svc_onboarding_complete(uuid, text, text, text[], text, date, text, timestamptz)
  to service_role;

-- The moderator's tool (no admin panel yet: run it from the SQL editor).
--   select private.ban_user('<uuid>', 'harassment, reports 12 and 15');
-- Records the email hash, closes the open reports against the user and deletes
-- the account through the same path as a voluntary deletion (meetings and
-- sessions closed, recordings and avatar queued for R2 removal, chat anonymised).
-- Terms §10.2: tell the user, with the reasons, BEFORE running it.
create function private.ban_user(p_user uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_email text;
begin
  select email into v_email from auth.users where id = p_user;
  if not found then perform private.fail('not_found'); end if;
  if v_email is null or btrim(v_email) = '' then perform private.fail('no_email'); end if;
  insert into public.banned_identities (email_hash, reason)
  values (private.email_hash(v_email), p_reason)
  on conflict (email_hash) do nothing;
  update public.user_reports set status = 'actioned' where reported_id = p_user and status = 'open';
  perform public.svc_account_prepare_delete(p_user);
  delete from auth.users where id = p_user;
end $$;
revoke all on function private.ban_user(uuid, text) from public, anon, authenticated;
