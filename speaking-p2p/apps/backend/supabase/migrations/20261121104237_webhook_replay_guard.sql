-- C-H1 (docs/SECURITY_AUDIT_2026-11.md): a signed LiveKit webhook delivery stays
-- valid for 5 minutes, so a captured request could be replayed (e.g. an old
-- participant_left after a rejoin). The webhook now records each event id and
-- processes it once. Ids are useless once the token has expired: purged daily.

create table private.webhook_events (
  source text not null,
  event_id text not null,
  received_at timestamptz not null default now(),
  primary key (source, event_id),
  constraint webhook_events_id_len check (length(event_id) between 1 and 200)
);
revoke all on table private.webhook_events from public, anon, authenticated;

-- true = first delivery of this event (process it); false = replay or retry.
create or replace function public.svc_webhook_first_seen(p_source text, p_event_id text, p_now timestamptz default now())
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if p_source is null or p_event_id is null or length(p_event_id) not between 1 and 200 then return false; end if;
  insert into private.webhook_events (source, event_id, received_at) values (p_source, p_event_id, p_now)
  on conflict do nothing;
  return found;
end $$;
revoke all on function public.svc_webhook_first_seen(text, text, timestamptz) from public, anon, authenticated;
grant execute on function public.svc_webhook_first_seen(text, text, timestamptz) to service_role;

create or replace function private.purge_webhook_events(p_now timestamptz default now()) returns void
language sql security definer set search_path = '' as $$
  delete from private.webhook_events where received_at < p_now - interval '1 day';
$$;
revoke all on function private.purge_webhook_events(timestamptz) from public, anon, authenticated;

do $outer$
begin
  if not exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    raise notice 'pg_cron not available: skipping purge-webhook-events schedule';
    return;
  end if;
  perform cron.schedule('purge-webhook-events', '23 3 * * *', 'select private.purge_webhook_events()');
end $outer$;
