-- Reporting and blocking (D-044). Both stores require them in apps where
-- strangers talk to each other (App Store Review Guideline 1.2, Google Play
-- User Generated Content policy). A block is mutual in effect: the two are never
-- matched again, do not see each other's offers, cannot accept them, cannot
-- write in a shared chat, and their pending or confirmed meetings are cancelled.
-- Reports are stored for manual review (no client can read other people's).
create table public.user_blocks (
  blocker_id uuid not null references auth.users (id) on delete cascade,
  blocked_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_id)
);
create index user_blocks_by_blocked on public.user_blocks (blocked_id);

create table public.user_reports (
  id bigint generated always as identity primary key,
  reporter_id uuid references auth.users (id) on delete set null,
  reported_id uuid references auth.users (id) on delete set null,
  reason text not null,
  details text,
  context text not null,
  session_id uuid references public.exam_sessions (id) on delete set null,
  chat_id uuid references public.chats (id) on delete set null,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint user_reports_reason_valid check (reason in ('harassment', 'sexual', 'hate', 'spam', 'minor_safety', 'no_show', 'other')),
  constraint user_reports_context_valid check (context in ('chat', 'lobby', 'exam', 'feedback', 'offer', 'profile')),
  constraint user_reports_status_valid check (status in ('open', 'reviewed', 'actioned', 'dismissed')),
  constraint user_reports_details_len check (details is null or char_length(details) <= 1000)
);
create index user_reports_open on public.user_reports (created_at) where status = 'open';

alter table public.user_blocks enable row level security;
alter table public.user_reports enable row level security;
revoke all on table public.user_blocks, public.user_reports from anon, authenticated;
grant all on table public.user_blocks, public.user_reports to service_role;
grant select (blocker_id, blocked_id, created_at) on public.user_blocks to authenticated;
create policy user_blocks_own on public.user_blocks for select to authenticated using (blocker_id = (select auth.uid()));

create function private.blocked_between(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.user_blocks
                 where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a))
$$;

-- For policies (they run as the caller, who cannot use schema private): only
-- answers about the caller and one other user, so it leaks nobody else's blocks.
create function public.is_blocked_with(p_other uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.blocked_between((select auth.uid()), p_other)
$$;

-- The board hides offers of anyone in a block with me; a blocked pair cannot write in their chat.
create policy meeting_offers_not_blocked on public.meeting_offers as restrictive for select to authenticated
  using (not public.is_blocked_with(creator_id));
create policy chat_messages_not_blocked on public.chat_messages as restrictive for insert to authenticated
  with check (not exists (select 1 from public.chats c where c.id = chat_id
                          and public.is_blocked_with(case when c.user_a = (select auth.uid()) then c.user_b else c.user_a end)));

create function public.block_user(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); m record;
begin
  if me is null then perform private.fail('not_authenticated'); end if;
  if p_user is null or p_user = me then perform private.fail('bad_user'); end if;
  insert into public.user_blocks (blocker_id, blocked_id) values (me, p_user) on conflict do nothing;
  for m in
    select mt.id, c.id as chat_id from public.meetings mt join public.chats c on c.meeting_id = mt.id
    where mt.status in ('pending', 'confirmed') and mt.scheduled_at > now() - interval '10 minutes'
      and ((mt.creator_id = me and mt.acceptor_id = p_user) or (mt.creator_id = p_user and mt.acceptor_id = me))
  loop
    update public.meetings set status = 'cancelled' where id = m.id;
    perform private.system_message(m.chat_id, 'meeting_cancelled', jsonb_build_object('by', me));
  end loop;
end $$;

create function public.unblock_user(p_user uuid) returns void
language sql security definer set search_path = '' as $$
  delete from public.user_blocks where blocker_id = auth.uid() and blocked_id = p_user
$$;

create function public.report_user(
  p_user uuid, p_reason text, p_details text, p_context text, p_session uuid default null, p_chat uuid default null
) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then perform private.fail('not_authenticated'); end if;
  if p_user is null or p_user = me then perform private.fail('bad_user'); end if;
  -- Throttle: at most 10 reports a day per reporter (no flooding the review queue).
  if (select count(*) from public.user_reports where reporter_id = me and created_at > now() - interval '1 day') >= 10 then
    perform private.fail('rate_limited');
  end if;
  insert into public.user_reports (reporter_id, reported_id, reason, details, context, session_id, chat_id)
  values (me, p_user, p_reason, nullif(btrim(coalesce(p_details, '')), ''), p_context, p_session, p_chat);
end $$;

revoke all on function public.block_user(uuid), public.unblock_user(uuid),
  public.report_user(uuid, text, text, text, uuid, uuid) from public, anon;
grant execute on function public.block_user(uuid), public.unblock_user(uuid),
  public.report_user(uuid, text, text, text, uuid, uuid) to authenticated;
revoke all on function private.blocked_between(uuid, uuid) from public, anon, authenticated;
grant execute on function private.blocked_between(uuid, uuid) to service_role;
revoke all on function public.is_blocked_with(uuid) from public, anon;
grant execute on function public.is_blocked_with(uuid) to authenticated;

-- Matchmaking skips anyone in a block with me (same function as before plus the filter).
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
      and not private.blocked_between(p_user, user_id)
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

-- Accepting an offer of someone in a block with me fails like a vanished offer.
create or replace function public.svc_offer_accept(p_user uuid, p_offer uuid, p_at timestamptz, p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path = '' as $$
declare o public.meeting_offers; v_meeting uuid; v_chat uuid;
begin
  perform private.require_eligible(p_user, p_now);
  select * into o from public.meeting_offers where id = p_offer for update;
  if not found or o.status <> 'open' or o.window_end <= p_now then perform private.fail('offer_unavailable'); end if;
  if o.creator_id = p_user then perform private.fail('own_offer'); end if;
  if private.blocked_between(p_user, o.creator_id) then perform private.fail('offer_unavailable'); end if;
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
