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
