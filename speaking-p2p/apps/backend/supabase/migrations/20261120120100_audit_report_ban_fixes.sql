-- Security audit 2026-11 (docs/SECURITY_AUDIT_2026-11.md).
--
-- C3 report_user:p_chat-unbound-holds-chat-retention
--   p_session was bound to the reporter/reported pair but p_chat was stored as
--   given, so any user could pin another pair's chat past its 30-day deletion
--   (housekeeping keeps chats with an open report).
--   Fix: p_chat must be the chat of exactly {reporter, reported}.
--
-- C9 ban_user/self-deletion-ban-evasion
--   A reported user who deleted the account before the moderator acted left no
--   email hash, so private.ban_user failed (not_found) and the same identity
--   signed up again.
--   Fix: on deletion, while a report against the user is still open, keep
--   sha256(lower(email)) next to those reports (reported_email_hash). The
--   moderator bans it with private.ban_report(report_id, reason). The hash is
--   erased when the reports are closed without a ban (no open reports left).

-- ---------------------------------------------------------------- C3
create or replace function public.report_user(
  p_user uuid, p_reason text, p_details text, p_context text, p_session uuid default null, p_chat uuid default null
) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); s public.exam_sessions;
begin
  if me is null then perform private.fail('not_authenticated'); end if;
  if p_user is null or p_user = me then perform private.fail('bad_user'); end if;
  if p_reason in ('silent', 'quit', 'control_abuse', 'noise', 'mocking') and p_session is null then
    perform private.fail('not_in_session');
  end if;
  if p_session is not null then
    select * into s from public.exam_sessions where id = p_session;
    if not found or not ((s.user_a = me and s.user_b = p_user) or (s.user_b = me and s.user_a = p_user)) then
      perform private.fail('not_in_session');
    end if;
  end if;
  if p_chat is not null and not exists (
    select 1 from public.chats c where c.id = p_chat
      and ((c.user_a = me and c.user_b = p_user) or (c.user_b = me and c.user_a = p_user))
  ) then
    perform private.fail('not_in_chat');
  end if;
  -- Throttle: at most 10 reports a day per reporter (no flooding the review queue).
  if (select count(*) from public.user_reports where reporter_id = me and created_at > now() - interval '1 day') >= 10 then
    perform private.fail('rate_limited');
  end if;
  insert into public.user_reports (reporter_id, reported_id, reason, details, context, session_id, chat_id)
  values (me, p_user, p_reason, nullif(btrim(coalesce(p_details, '')), ''), p_context, p_session, p_chat)
  on conflict (reporter_id, reported_id, session_id) where session_id is not null do nothing;
end $$;
revoke all on function public.report_user(uuid, text, text, text, uuid, uuid) from public, anon;
grant execute on function public.report_user(uuid, text, text, text, uuid, uuid) to authenticated;

-- ---------------------------------------------------------------- C9
alter table public.user_reports add column reported_email_hash text;
comment on column public.user_reports.reported_email_hash is
  'sha256(lower(email)) of the reported user, written ONLY if that user deletes the account while the report is open, so a pending ban still applies (C9). Cleared when no open report remains.';

-- Keep the hash on the open reports before the auth row (and its email) goes.
create or replace function private.keep_reported_identity(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_email text;
begin
  select email into v_email from auth.users where id = p_user;
  if v_email is null or btrim(v_email) = '' then return; end if;
  update public.user_reports set reported_email_hash = private.email_hash(v_email)
  where reported_id = p_user and status = 'open';
end $$;
revoke all on function private.keep_reported_identity(uuid) from public, anon, authenticated;

create or replace function public.svc_account_prepare_delete(p_user uuid, p_now timestamptz default now()) returns void
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  perform private.keep_reported_identity(p_user);
  delete from public.match_queue where user_id = p_user;
  update public.meeting_offers set status = 'cancelled' where creator_id = p_user and status = 'open';
  for r in select id from public.meetings where p_user in (creator_id, acceptor_id) and status in ('pending', 'confirmed') for update loop
    update public.meetings set status = 'cancelled' where id = r.id;
    perform private.meeting_message(r.id, 'partner_deleted_account');
  end loop;
  update public.exam_sessions set state = 'aborted', abort_reason = 'left', aborted_by = p_user, ended_at = p_now
  where state not in ('ended', 'aborted') and p_user in (user_a, user_b);
  -- Recordings carry this person's voice: they go too, for the partner as well (Art. 17 RGPD).
  insert into public.storage_gc_queue (object_key, reason)
  select recording_key, 'account_deleted' from public.exam_sessions
  where recording_key is not null and p_user in (user_a, user_b);
  update public.exam_sessions set recording_key = null, recording_expires_at = null
  where recording_key is not null and p_user in (user_a, user_b);
end $$;
revoke all on function public.svc_account_prepare_delete(uuid, timestamptz) from public, anon, authenticated;
grant execute on function public.svc_account_prepare_delete(uuid, timestamptz) to service_role;

-- Moderator tool for an identity that already deleted its account:
--   select private.ban_report(42, 'harassment, reports 42 and 43');
create or replace function private.ban_report(p_report bigint, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_hash text; v_user uuid;
begin
  select reported_email_hash, reported_id into v_hash, v_user from public.user_reports where id = p_report;
  if not found then perform private.fail('not_found'); end if;
  if v_user is not null then perform private.ban_user(v_user, p_reason); return; end if;
  if v_hash is null then perform private.fail('no_identity'); end if;
  insert into public.banned_identities (email_hash, reason) values (v_hash, p_reason) on conflict (email_hash) do nothing;
  update public.user_reports set status = 'actioned', reported_email_hash = null
  where reported_email_hash = v_hash and status = 'open';
end $$;
revoke all on function private.ban_report(bigint, text) from public, anon, authenticated;

-- Data minimisation: the hash only lives while some report on it is still open.
create or replace function private.clear_reported_identity() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status <> 'open' and new.reported_email_hash is not null then
    new.reported_email_hash := null;
  end if;
  return new;
end $$;
revoke all on function private.clear_reported_identity() from public, anon, authenticated;
create trigger user_reports_clear_identity before update of status on public.user_reports
  for each row execute function private.clear_reported_identity();
