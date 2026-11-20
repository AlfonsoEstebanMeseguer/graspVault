-- Pegar ENTERO en Supabase > SQL Editor > Run. Aplica las 3 migraciones pendientes
-- en una sola transacción y las registra en el historial con el mismo version que
-- el fichero local (así 'list_migrations' y el repo coinciden). Idempotente: si ya
-- están registradas, no hace nada.
begin;
do $guard$ begin
  if exists (select 1 from supabase_migrations.schema_migrations where version = '20261015180000') then
    raise exception 'already applied: nothing to do';
  end if;
end $guard$;

-- ===== 20261015180000_rules_matchmaking_agenda
-- Part of the business rules (split in four so each migration fits one apply call).
-- Conventions: see the header of the first part.

-- ------------------------------------------------------------- live matchmaking
-- Atomic FIFO per exact level. The per-level advisory lock serialises two
-- simultaneous enqueuers so neither inserts without seeing the other.
-- Clients call it every ~10 s while searching (heartbeat); stale rows never match.
create or replace function public.svc_match_enqueue(p_user uuid, p_level text, p_content_version int, p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_partner public.match_queue; v_session uuid; v_existing uuid;
begin
  if not private.is_level(p_level) then perform private.fail('bad_level'); end if;
  perform private.lock_user(p_user);
  v_existing := private.active_session_of(p_user);
  if v_existing is not null then
    delete from public.match_queue where user_id = p_user;
    return jsonb_build_object('status', 'matched', 'session_id', v_existing);
  end if;
  perform private.require_eligible(p_user, p_now);
  perform pg_advisory_xact_lock(hashtextextended('queue:' || p_level, 0));
  delete from public.match_queue where user_id = p_user and level <> p_level;

  loop
    select * into v_partner from public.match_queue
    where level = p_level and user_id <> p_user and last_seen_at > p_now - interval '25 seconds'
    order by enqueued_at limit 1 for update;
    exit when not found;
    delete from public.match_queue where user_id = v_partner.user_id;
    -- The partner's eligibility may have lapsed while waiting.
    if public.svc_is_eligible(v_partner.user_id, p_now) and private.active_session_of(v_partner.user_id) is null then
      delete from public.match_queue where user_id = p_user;
      v_session := private.create_session(p_level, p_user, v_partner.user_id, 'live', null,
                                          least(p_content_version, v_partner.content_version));
      return jsonb_build_object('status', 'matched', 'session_id', v_session);
    end if;
  end loop;

  insert into public.match_queue (user_id, level, content_version, enqueued_at, last_seen_at)
  values (p_user, p_level, p_content_version, p_now, p_now)
  on conflict (user_id) do update set last_seen_at = p_now, content_version = excluded.content_version;
  return jsonb_build_object('status', 'queued');
end $$;

create or replace function public.svc_match_cancel(p_user uuid) returns void
language sql security definer set search_path = '' as $$
  delete from public.match_queue where user_id = p_user
$$;

-- For the 15 s prompt: does the user have an open meeting (created or accepted)?
create or replace function public.svc_has_open_meeting(p_user uuid, p_now timestamptz default now()) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.meeting_offers o where o.creator_id = p_user and o.status = 'open' and o.window_end > p_now)
      or exists (select 1 from public.meetings m where p_user in (m.creator_id, m.acceptor_id)
                 and m.status in ('pending', 'confirmed') and m.scheduled_at > p_now - interval '10 minutes')
$$;

-- ------------------------------------------------------------- agenda
create or replace function public.svc_offer_create(p_user uuid, p_level text, p_start timestamptz, p_end timestamptz, p_now timestamptz default now())
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  perform private.require_eligible(p_user, p_now);
  if not private.is_level(p_level) then perform private.fail('bad_level'); end if;
  if p_start < p_now - interval '1 minute' or p_end > p_now + interval '7 days' then perform private.fail('window_out_of_range'); end if;
  if p_end < p_start + interval '30 minutes' then perform private.fail('window_too_short'); end if;
  perform private.lock_user(p_user);
  if (select count(*) from public.meeting_offers where creator_id = p_user and status = 'open' and window_end > p_now) >= 2 then
    perform private.fail('too_many_offers');
  end if;
  insert into public.meeting_offers (creator_id, level, window_start, window_end)
  values (p_user, p_level, p_start, p_end) returning id into v_id;
  return v_id;
end $$;

create or replace function public.svc_offer_cancel(p_user uuid, p_offer uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare o public.meeting_offers; m record;
begin
  select * into o from public.meeting_offers where id = p_offer for update;
  if not found or o.creator_id <> p_user then perform private.fail('not_found'); end if;
  if o.status <> 'open' then return; end if;
  update public.meeting_offers set status = 'cancelled' where id = p_offer;
  for m in select id from public.meetings where offer_id = p_offer and status = 'pending' loop
    update public.meetings set status = 'closed' where id = m.id;
    perform private.meeting_message(m.id, 'meeting_unavailable');
  end loop;
end $$;

create or replace function private.valid_slot(p_at timestamptz) returns boolean
language sql immutable as $$
  select extract(second from p_at) = 0 and extract(minute from p_at)::int % 5 = 0
$$;

create or replace function public.svc_offer_accept(p_user uuid, p_offer uuid, p_at timestamptz, p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path = '' as $$
declare o public.meeting_offers; v_meeting uuid; v_chat uuid;
begin
  perform private.require_eligible(p_user, p_now);
  select * into o from public.meeting_offers where id = p_offer for update;
  if not found or o.status <> 'open' or o.window_end <= p_now then perform private.fail('offer_unavailable'); end if;
  if o.creator_id = p_user then perform private.fail('own_offer'); end if;
  if p_at < o.window_start or p_at > o.window_end - interval '30 minutes' or p_at <= p_now or not private.valid_slot(p_at) then
    perform private.fail('bad_time');
  end if;
  if exists (select 1 from public.meetings where offer_id = p_offer and acceptor_id = p_user) then
    perform private.fail('already_accepted');
  end if;
  insert into public.meetings (offer_id, creator_id, acceptor_id, level, scheduled_at)
  values (p_offer, o.creator_id, p_user, o.level, p_at) returning id into v_meeting;
  insert into public.chats (meeting_id, user_a, user_b) values (v_meeting, o.creator_id, p_user) returning id into v_chat;
  perform private.system_message(v_chat, 'meeting_proposed',
    jsonb_build_object('by', p_user, 'scheduled_at', p_at, 'level', o.level));
  return jsonb_build_object('meeting_id', v_meeting, 'chat_id', v_chat);
end $$;

create or replace function private.lock_meeting(p_meeting uuid, p_user uuid) returns public.meetings
language plpgsql set search_path = '' as $$
declare m public.meetings;
begin
  select * into m from public.meetings where id = p_meeting for update;
  if not found or p_user is null or p_user not in (m.creator_id, m.acceptor_id) then perform private.fail('not_found'); end if;
  return m;
end $$;

-- Only pending meetings can be modified (a confirmed one is cancelled instead). Resets both confirmations.
create or replace function public.svc_meeting_modify(p_user uuid, p_meeting uuid, p_at timestamptz, p_level text, p_now timestamptz default now())
returns void language plpgsql security definer set search_path = '' as $$
declare m public.meetings;
begin
  m := private.lock_meeting(p_meeting, p_user);
  if m.status <> 'pending' then perform private.fail('not_pending'); end if;
  if not private.is_level(p_level) then perform private.fail('bad_level'); end if;
  if p_at <= p_now or p_at > p_now + interval '7 days' or not private.valid_slot(p_at) then perform private.fail('bad_time'); end if;
  update public.meetings set scheduled_at = p_at, level = p_level, creator_confirmed = false, acceptor_confirmed = false
  where id = p_meeting;
  perform private.meeting_message(p_meeting, 'meeting_modified',
    jsonb_build_object('by', p_user, 'scheduled_at', p_at, 'level', p_level));
end $$;

create or replace function private.has_overlap(p_user uuid, p_at timestamptz, p_except uuid) returns boolean
language sql stable set search_path = '' as $$
  select exists (
    select 1 from public.meetings m
    where m.status = 'confirmed' and m.id <> p_except and p_user in (m.creator_id, m.acceptor_id)
      and tstzrange(m.scheduled_at, m.scheduled_at + interval '30 minutes')
       && tstzrange(p_at, p_at + interval '30 minutes'))
$$;

create or replace function public.svc_meeting_confirm(p_user uuid, p_meeting uuid, p_now timestamptz default now())
returns text language plpgsql security definer set search_path = '' as $$
declare m public.meetings; v_other uuid; s record;
begin
  m := private.lock_meeting(p_meeting, p_user);
  v_other := case when p_user = m.creator_id then m.acceptor_id else m.creator_id end;
  if v_other is null then perform private.fail('partner_gone'); end if;
  perform private.lock_users(p_user, v_other);
  if m.status <> 'pending' then perform private.fail('not_pending'); end if;
  if m.scheduled_at <= p_now then perform private.fail('in_the_past'); end if;
  perform private.require_eligible(p_user, p_now);
  if private.has_overlap(p_user, m.scheduled_at, m.id) then perform private.fail('overlap'); end if;

  update public.meetings set
    creator_confirmed = creator_confirmed or p_user = m.creator_id,
    acceptor_confirmed = acceptor_confirmed or p_user = m.acceptor_id
  where id = p_meeting returning * into m;
  perform private.meeting_message(p_meeting, 'meeting_confirmed_by', jsonb_build_object('by', p_user));
  if not (m.creator_confirmed and m.acceptor_confirmed) then return 'pending'; end if;

  -- Second confirmation: the partner may have filled that slot meanwhile.
  if private.has_overlap(v_other, m.scheduled_at, m.id) then
    update public.meetings set creator_confirmed = p_user = m.creator_id, acceptor_confirmed = p_user = m.acceptor_id
    where id = p_meeting;
    perform private.meeting_message(p_meeting, 'meeting_partner_overlap', jsonb_build_object('user', v_other));
    return 'pending';
  end if;
  if m.offer_id is not null then
    perform 1 from public.meeting_offers where id = m.offer_id and status = 'open' for update;
    if not found then perform private.fail('offer_unavailable'); end if;
    update public.meeting_offers set status = 'filled' where id = m.offer_id;
    for s in select id from public.meetings where offer_id = m.offer_id and id <> p_meeting and status = 'pending' loop
      update public.meetings set status = 'closed' where id = s.id;
      perform private.meeting_message(s.id, 'meeting_unavailable');
    end loop;
  end if;
  update public.meetings set status = 'confirmed' where id = p_meeting;
  perform private.meeting_message(p_meeting, 'meeting_confirmed');
  return 'confirmed';
end $$;

create or replace function public.svc_meeting_cancel(p_user uuid, p_meeting uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare m public.meetings;
begin
  m := private.lock_meeting(p_meeting, p_user);
  if m.status not in ('pending', 'confirmed') then return; end if;
  update public.meetings set status = 'cancelled' where id = p_meeting;
  perform private.meeting_message(p_meeting, 'meeting_cancelled', jsonb_build_object('by', p_user));
end $$;

-- "Entrar a la sala": from 5 min before until the end of the 10 min courtesy.
create or replace function public.svc_meeting_enter(p_user uuid, p_meeting uuid, p_content_version int, p_now timestamptz default now())
returns uuid language plpgsql security definer set search_path = '' as $$
declare m public.meetings; v_session uuid;
begin
  m := private.lock_meeting(p_meeting, p_user);
  if m.status <> 'confirmed' then perform private.fail('not_confirmed'); end if;
  if p_now < m.scheduled_at - interval '5 minutes' then perform private.fail('too_early'); end if;
  select id into v_session from public.exam_sessions where meeting_id = p_meeting;
  if v_session is null then
    if p_now > m.scheduled_at + interval '10 minutes' then perform private.fail('too_late'); end if;
    v_session := private.create_session(m.level, m.creator_id, m.acceptor_id, 'meeting', p_meeting, p_content_version);
  end if;
  insert into public.attendance (meeting_id, user_id, attended) values (p_meeting, p_user, true)
  on conflict (meeting_id, user_id) do update set attended = true;
  return v_session;
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

-- ===== 20261015180100_rules_crons_accounts
-- Part of the business rules (split in four so each migration fits one apply call).
-- Conventions: see the header of the first part.

-- ------------------------------------------------------------- crons (pure SQL part)
create or replace function public.svc_cron_agenda(p_now timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r record; v_expired int := 0; v_reminders int := 0; v_no_shows int := 0;
begin
  -- 1. Offers whose last possible 30-min slot has passed.
  for r in select id from public.meeting_offers where status = 'open' and window_end - interval '30 minutes' < p_now for update loop
    update public.meeting_offers set status = 'expired' where id = r.id;
    v_expired := v_expired + 1;
  end loop;
  for r in select id from public.meetings where status = 'pending' and scheduled_at < p_now for update loop
    update public.meetings set status = 'closed' where id = r.id;
    perform private.meeting_message(r.id, 'meeting_expired');
  end loop;

  -- 2. Push 10 min before (outbox; the cron Edge Function delivers it).
  for r in select * from public.meetings where status = 'confirmed' and reminder_sent_at is null
           and scheduled_at between p_now and p_now + interval '10 minutes' for update loop
    insert into public.notification_outbox (user_id, kind, payload)
    select u, 'meeting_reminder', jsonb_build_object('meeting_id', r.id, 'scheduled_at', r.scheduled_at)
    from unnest(array[r.creator_id, r.acceptor_id]) u where u is not null;
    update public.meetings set reminder_sent_at = p_now where id = r.id;
    v_reminders := v_reminders + 1;
  end loop;

  -- 3. No-shows after the 10 min courtesy.
  for r in select m.*, s.id as session_id, s.joined_a_at, s.joined_b_at, s.state as session_state
           from public.meetings m left join public.exam_sessions s on s.meeting_id = m.id
           where m.status = 'confirmed' and m.scheduled_at + interval '10 minutes' < p_now for update of m loop
    if r.session_id is not null and r.joined_a_at is not null and r.joined_b_at is not null then
      continue; -- both showed up; the session itself will mark the meeting done
    end if;
    update public.meetings set status = 'no_show' where id = r.id;
    insert into public.attendance (meeting_id, user_id, attended)
    select r.id, u, false from unnest(array[r.creator_id, r.acceptor_id]) u where u is not null
    on conflict (meeting_id, user_id) do nothing;
    insert into public.notification_outbox (user_id, kind, payload)
    select a.user_id, 'partner_no_show', jsonb_build_object('meeting_id', r.id)
    from public.attendance a where a.meeting_id = r.id and a.attended;
    if r.session_id is not null and r.session_state = 'lobby' then
      update public.exam_sessions set state = 'aborted', abort_reason = 'no_show', ended_at = p_now where id = r.session_id;
    end if;
    v_no_shows := v_no_shows + 1;
  end loop;
  return jsonb_build_object('expired', v_expired, 'reminders', v_reminders, 'no_shows', v_no_shows);
end $$;

create or replace function public.svc_cron_housekeeping(p_now timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_queue int; v_rec int;
begin
  delete from public.match_queue where last_seen_at < p_now - interval '60 seconds';
  get diagnostics v_queue = row_count;
  insert into public.storage_gc_queue (object_key, reason)
  select recording_key, 'recording_expired' from public.exam_sessions
  where recording_key is not null and recording_expires_at < p_now;
  get diagnostics v_rec = row_count;
  update public.exam_sessions set recording_key = null
  where recording_key is not null and recording_expires_at < p_now;
  return jsonb_build_object('stale_queue', v_queue, 'recordings', v_rec);
end $$;

create or replace function public.svc_active_sessions() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select id from public.exam_sessions where state not in ('ended', 'aborted')
$$;

-- ------------------------------------------------------------- RevenueCat
create or replace function public.svc_apply_rc_event(
  p_event_id text, p_user uuid, p_status text, p_period_end timestamptz, p_event_at timestamptz
) returns boolean language plpgsql security definer set search_path = '' as $$
begin
  insert into public.revenuecat_events (event_id) values (p_event_id) on conflict do nothing;
  if not found then return false; end if; -- duplicate delivery
  update public.entitlements set subscription_status = p_status, current_period_end = p_period_end, last_rc_event_at = p_event_at
  where user_id = p_user and (last_rc_event_at is null or last_rc_event_at <= p_event_at);
  return true;
end $$;

-- ------------------------------------------------------------- account deletion
-- Runs before auth.admin.deleteUser: tells partners, frees slots, stops sessions.
create or replace function public.svc_account_prepare_delete(p_user uuid, p_now timestamptz default now()) returns void
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
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

-- ===== 20261015180200_crons
-- Crons, scheduled from a migration (vault: config.toml `schedule` is silently ignored).
--
-- Two kinds:
--   * pure SQL (agenda, housekeeping): pg_cron calls the svc_* function directly;
--   * needs the outside world (LiveKit mic pushes, FCM, R2 deletes): pg_cron -> pg_net ->
--     Edge Function `cron-worker`, authenticated with a DEDICATED token. The token lives in
--     Supabase Vault (`internal_cron_token`); the function checks it through
--     svc_verify_internal_token (D-021). Never verify_jwt, never the service_role key (vault ADR 0011).
--
-- Setup once per environment (not in git, see docs/SETUP.md):
--   select vault.create_secret('<random 48 bytes, base64>', 'internal_cron_token');
--   select vault.create_secret('https://<ref>.supabase.co', 'project_url');
--
-- Verification is NOT "the job says succeeded" (pg_net is async):
--   select status, return_message, start_time from cron.job_run_details order by start_time desc limit 5;
--   select id, status_code, left(content::text, 200) from net._http_response order by id desc limit 5;
--
-- On environments without pg_cron (plain Postgres for the SQL suite) this migration is a no-op.

do $outer$
begin
  if not exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    raise notice 'pg_cron not available: skipping cron schedules';
    return;
  end if;

  create extension if not exists pg_cron;
  create extension if not exists pg_net;

  create or replace function private.invoke_worker(p_task text) returns void
  language plpgsql security definer set search_path = '' as $fn$
  declare v_url text; v_token text;
  begin
    select decrypted_secret into v_url from vault.decrypted_secrets where name = 'project_url';
    select decrypted_secret into v_token from vault.decrypted_secrets where name = 'internal_cron_token';
    if v_url is null or v_token is null then
      raise warning 'cron-worker not configured (vault secrets missing)';
      return;
    end if;
    perform net.http_post(
      url := v_url || '/functions/v1/cron-worker',
      headers := jsonb_build_object('Content-Type', 'application/json', 'X-Internal-Token', v_token),
      body := jsonb_build_object('task', p_task),
      timeout_milliseconds := 8000);
  end $fn$;
  revoke all on function private.invoke_worker(text) from public, anon, authenticated;

  perform cron.schedule('agenda', '* * * * *', 'select public.svc_cron_agenda()');
  perform cron.schedule('housekeeping', '*/5 * * * *', 'select public.svc_cron_housekeeping()');
  -- Backstop for the session state machine; clients tick at every boundary themselves.
  perform cron.schedule('sessions', '10 seconds', 'select private.invoke_worker(''sessions'')');
  perform cron.schedule('outbox', '30 seconds', 'select private.invoke_worker(''outbox'')');
  perform cron.schedule('storage-gc', '*/5 * * * *', 'select private.invoke_worker(''storage_gc'')');
end
$outer$;

insert into supabase_migrations.schema_migrations (version, name) values
  ('20261015180000', 'rules_matchmaking_agenda'),
  ('20261015180100', 'rules_crons_accounts'),
  ('20261015180200', 'crons');
commit;
