-- Baseline schema for Speaking P2P.
-- Conventions inherited from the Grasp vault (docs/VAULT_NOTES.md):
--   * RLS on every table, deny by default; policies AND column GRANTs (RLS filters rows, GRANT filters columns).
--   * Every table starts with `revoke all` from anon/authenticated (Supabase default privileges grant ALL)
--     and an explicit grant to service_role (BYPASSRLS is not BYPASSGRANT).
--   * Bytes never in Postgres: rows keep the R2 object key only.
--   * Tombstone tables (outlive the row that created them) carry no FK to auth.users.
--   * Timestamps only where something reads them.
-- Rollback: drop schema-owned objects in reverse order (see docs/DECISIONS.md D-010).

create extension if not exists pgcrypto;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ---------------------------------------------------------------- helpers
create or replace function private.is_level(v text) returns boolean
language sql immutable as $$ select v in ('B1', 'B2', 'C1') $$;

-- NOTE: CHECK constraints are written inline, never as calls to private.*:
-- a CHECK runs with the privileges of whoever writes the row, and the client
-- has no EXECUTE on the private schema (found by tests/sql/01, DECISIONS D-011).
-- Languages are ISO 639-1 codes; 'Otro' in the UI maps to any valid code.

-- ---------------------------------------------------------------- profiles
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null,
  avatar_key text,
  languages text[] not null,
  target_level text not null,
  created_at timestamptz not null default now(),
  constraint profiles_username_format check (username ~ '^[a-z0-9_.]{3,20}$'),
  constraint profiles_languages_valid check (cardinality(languages) between 1 and 10
    and array_to_string(languages, ',') ~ '^[a-z]{2}(,[a-z]{2})*$'),
  constraint profiles_target_level_valid check (target_level in ('B1', 'B2', 'C1')),
  constraint profiles_avatar_key_format check (avatar_key is null or avatar_key ~ '^avatars/[0-9a-f-]{36}/[0-9a-f-]{36}\.(webp|jpg)$')
);
create unique index profiles_username_key on public.profiles (username);
comment on column public.profiles.avatar_key is 'R2 object key, never a URL. Signed GET URLs come from an Edge Function.';

-- ---------------------------------------------------------------- private profile
-- email is NOT duplicated here: it already lives in auth.users (data minimisation, DECISIONS D-006).
create table public.profiles_private (
  id uuid primary key references auth.users (id) on delete cascade,
  birth_date date not null,
  phone text,
  terms_version text not null,
  terms_accepted_at timestamptz not null,
  constraint profiles_private_phone_format check (phone is null or phone ~ '^\+[0-9]{7,15}$'),
  constraint profiles_private_terms_version_nonempty check (btrim(terms_version) <> '')
);

-- Minimum age lives on the WRITE path, as a trigger because a CHECK cannot read current_date.
create or replace function private.enforce_min_age() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.birth_date > (current_date - interval '14 years')::date then
    raise exception 'underage' using errcode = '23514';
  end if;
  if new.birth_date < date '1900-01-01' then
    raise exception 'birth_date_out_of_range' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger profiles_private_min_age before insert or update of birth_date on public.profiles_private
for each row execute function private.enforce_min_age();

create view public.public_profiles with (security_invoker = false) as
  select id, username, avatar_key, languages, target_level from public.profiles;
comment on view public.public_profiles is 'Enumerates the public columns. Adding a column here IS granting a permission.';

-- ---------------------------------------------------------------- access / entitlements
create table public.entitlements (
  user_id uuid primary key references auth.users (id) on delete cascade,
  trial_used_at timestamptz,
  trial_session_id uuid,
  subscription_status text not null default 'none',
  current_period_end timestamptz,
  last_rc_event_at timestamptz,
  constraint entitlements_status_valid check (subscription_status in ('none', 'active', 'grace', 'billing_issue', 'cancelled', 'expired'))
);
comment on column public.entitlements.last_rc_event_at is 'Newest RevenueCat event applied; older events arriving late are ignored.';

-- Tombstone: survives account deletion so deleting and re-creating the same
-- Google account does not mint a new trial. No FK on purpose.
create table public.trial_claims (
  email_hash text primary key,
  claimed_at timestamptz not null default now()
);
comment on table public.trial_claims is 'sha256(lower(email)). Tombstone without FK: must outlive auth.users rows.';

create table public.revenuecat_events (
  event_id text primary key,
  received_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- content catalog
-- The exam JSON ships in the app bundle; the server only needs id/level/version
-- and the precomputed timeline to drive the session. Seeded by scripts/content/sync-catalog.ts.
create table public.exam_catalog (
  id text primary key,
  level text not null,
  version int not null,
  content_version int not null,
  timeline jsonb not null,
  total_ms int not null,
  active boolean not null default true,
  constraint exam_catalog_level_valid check (level in ('B1', 'B2', 'C1'))
);

-- ---------------------------------------------------------------- meetings (agenda)
create table public.meeting_offers (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references auth.users (id) on delete cascade,
  level text not null,
  window_start timestamptz not null,
  window_end timestamptz not null,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  constraint meeting_offers_level_valid check (level in ('B1', 'B2', 'C1')),
  constraint meeting_offers_status_valid check (status in ('open', 'filled', 'cancelled', 'expired')),
  constraint meeting_offers_window_valid check (window_end >= window_start + interval '30 minutes')
);
create index meeting_offers_board_idx on public.meeting_offers (level, window_end) where status = 'open';

create table public.meetings (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid references public.meeting_offers (id) on delete set null,
  creator_id uuid references auth.users (id) on delete set null,
  acceptor_id uuid references auth.users (id) on delete set null,
  level text not null,
  scheduled_at timestamptz not null,
  creator_confirmed boolean not null default false,
  acceptor_confirmed boolean not null default false,
  status text not null default 'pending',
  reminder_sent_at timestamptz,
  created_at timestamptz not null default now(),
  constraint meetings_level_valid check (level in ('B1', 'B2', 'C1')),
  constraint meetings_status_valid check (status in ('pending', 'confirmed', 'cancelled', 'closed', 'done', 'no_show'))
);
create unique index meetings_one_acceptance_per_offer on public.meetings (offer_id, acceptor_id);
create index meetings_confirmed_by_time on public.meetings (scheduled_at) where status = 'confirmed';

create table public.attendance (
  meeting_id uuid not null references public.meetings (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  attended boolean not null,
  primary key (meeting_id, user_id)
);

-- ---------------------------------------------------------------- chat
create table public.chats (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null unique references public.meetings (id) on delete cascade,
  user_a uuid references auth.users (id) on delete set null,
  user_b uuid references auth.users (id) on delete set null,
  last_message_at timestamptz not null default now()
);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats (id) on delete cascade,
  -- set null on account deletion = anonymised message (CLAUDE.md §3)
  sender_id uuid default auth.uid() references auth.users (id) on delete set null,
  kind text not null default 'user',
  body text,
  system_code text,
  system_args jsonb,
  client_id uuid,
  -- clock_timestamp, not now(): several system messages can be written in one
  -- transaction and the chat must still show them in order.
  created_at timestamptz not null default clock_timestamp(),
  constraint chat_messages_kind_valid check (kind in ('user', 'system')),
  constraint chat_messages_user_body check (kind <> 'user' or (body is not null and char_length(btrim(body)) between 1 and 2000)),
  constraint chat_messages_system_shape check (kind <> 'system' or (sender_id is null and system_code is not null))
);
create unique index chat_messages_idempotency on public.chat_messages (chat_id, client_id) where client_id is not null;
create index chat_messages_by_chat on public.chat_messages (chat_id, created_at desc);

-- The whole effect of a message lives in the trigger, in the same transaction.
create or replace function private.chat_touch() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.chats set last_message_at = new.created_at where id = new.chat_id;
  return new;
end $$;
create trigger chat_messages_touch after insert on public.chat_messages
for each row execute function private.chat_touch();

-- ---------------------------------------------------------------- live matchmaking
create table public.match_queue (
  user_id uuid primary key references auth.users (id) on delete cascade,
  level text not null,
  content_version int not null,
  enqueued_at timestamptz not null default now(),
  constraint match_queue_level_valid check (level in ('B1', 'B2', 'C1'))
);
create index match_queue_fifo on public.match_queue (level, enqueued_at);

-- ---------------------------------------------------------------- exam sessions
create table public.exam_sessions (
  id uuid primary key default gen_random_uuid(),
  level text not null,
  exam_id text not null references public.exam_catalog (id),
  exam_version int not null,
  user_a uuid references auth.users (id) on delete set null,
  user_b uuid references auth.users (id) on delete set null,
  origin text not null,
  meeting_id uuid references public.meetings (id) on delete set null,
  state text not null default 'lobby',
  created_at timestamptz not null default now(),
  joined_a_at timestamptz,
  joined_b_at timestamptz,
  disconnected_a_at timestamptz,
  disconnected_b_at timestamptz,
  lobby_deadline timestamptz,
  ready_a boolean not null default false,
  ready_b boolean not null default false,
  preloaded_a boolean not null default false,
  preloaded_b boolean not null default false,
  recording_consent_a boolean not null default false,
  recording_consent_b boolean not null default false,
  exam_started_at timestamptz,
  schedule jsonb,
  step_index int,
  step_started_at timestamptz,
  applied_segment int not null default -1,
  feedback_ends_at timestamptz,
  ended_at timestamptz,
  aborted_by uuid,
  abort_reason text,
  recording_key text,
  recording_expires_at timestamptz,
  constraint exam_sessions_level_valid check (level in ('B1', 'B2', 'C1')),
  constraint exam_sessions_origin_valid check (origin in ('live', 'meeting')),
  constraint exam_sessions_state_valid check (state in ('lobby', 'part1', 'part2', 'part3', 'part4', 'feedback', 'ended', 'aborted')),
  constraint exam_sessions_abort_reason_valid check (abort_reason is null or abort_reason in ('left', 'disconnected', 'no_show', 'ineligible', 'content_missing')),
  constraint exam_sessions_distinct_users check (user_a is distinct from user_b or user_a is null)
);
create index exam_sessions_active on public.exam_sessions (state) where state not in ('ended', 'aborted');
create index exam_sessions_user_a on public.exam_sessions (user_a);
create index exam_sessions_user_b on public.exam_sessions (user_b);
create unique index exam_sessions_one_per_meeting on public.exam_sessions (meeting_id) where meeting_id is not null;

create table public.exam_history (
  user_id uuid not null references auth.users (id) on delete cascade,
  exam_id text not null references public.exam_catalog (id),
  session_id uuid not null references public.exam_sessions (id) on delete cascade,
  started_at timestamptz not null default now(),
  completed boolean not null default false,
  primary key (user_id, session_id)
);
create index exam_history_by_user_exam on public.exam_history (user_id, exam_id);

-- ---------------------------------------------------------------- push + outbox
create table public.push_tokens (
  token text primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  platform text not null,
  updated_at timestamptz not null default now(),
  constraint push_tokens_platform_valid check (platform in ('ios', 'android'))
);

create table public.notification_outbox (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null,
  payload jsonb not null default '{}',
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  attempts int not null default 0,
  last_error text
);
create index notification_outbox_pending on public.notification_outbox (id) where sent_at is null;

-- ---------------------------------------------------------------- R2 deletion queue (tombstone)
create table public.storage_gc_queue (
  id bigint generated always as identity primary key,
  object_key text not null,
  reason text not null,
  status text not null default 'pending',
  attempts int not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  constraint storage_gc_queue_status_valid check (status in ('pending', 'done', 'failed'))
);
comment on table public.storage_gc_queue is 'Tombstone without FK: rows are inserted during the cascade that deletes the owner.';

create or replace function private.enqueue_avatar_gc() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE' and old.avatar_key is not null then
    insert into public.storage_gc_queue (object_key, reason) values (old.avatar_key, 'profile_deleted');
  elsif tg_op = 'UPDATE' and old.avatar_key is not null and old.avatar_key is distinct from new.avatar_key then
    insert into public.storage_gc_queue (object_key, reason) values (old.avatar_key, 'avatar_replaced');
  end if;
  return coalesce(new, old);
end $$;
create trigger profiles_avatar_gc before update of avatar_key or delete on public.profiles
for each row execute function private.enqueue_avatar_gc();

create or replace function private.enqueue_recording_gc() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.recording_key is not null then
    insert into public.storage_gc_queue (object_key, reason) values (old.recording_key, 'session_deleted');
  end if;
  return old;
end $$;
create trigger exam_sessions_recording_gc before delete on public.exam_sessions
for each row execute function private.enqueue_recording_gc();

-- ================================================================ RLS + GRANTS
do $$
declare t text;
begin
  foreach t in array array['profiles', 'profiles_private', 'entitlements', 'trial_claims', 'revenuecat_events',
    'exam_catalog', 'meeting_offers', 'meetings', 'attendance', 'chats', 'chat_messages', 'match_queue',
    'exam_sessions', 'exam_history', 'push_tokens', 'notification_outbox', 'storage_gc_queue']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from anon, authenticated', t);
    execute format('grant all on table public.%I to service_role', t);
  end loop;
end $$;
revoke all on public.public_profiles from anon, authenticated;
grant select on public.public_profiles to authenticated, service_role;
grant usage on schema private to service_role;
grant execute on all functions in schema private to service_role;

-- profiles: public columns readable by any signed-in user; owner edits user-owned columns only.
grant select (id, username, avatar_key, languages, target_level) on public.profiles to authenticated;
grant update (username, languages, target_level) on public.profiles to authenticated;
create policy profiles_read on public.profiles for select to authenticated using (true);
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- profiles_private: owner only. Inserted by onboarding-complete (service_role).
grant select (id, birth_date, phone, terms_version, terms_accepted_at) on public.profiles_private to authenticated;
grant update (phone) on public.profiles_private to authenticated;
create policy profiles_private_own_read on public.profiles_private for select to authenticated using (id = (select auth.uid()));
create policy profiles_private_own_update on public.profiles_private for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- entitlements: owner reads; only the RevenueCat webhook and session start write.
grant select (user_id, trial_used_at, subscription_status, current_period_end) on public.entitlements to authenticated;
create policy entitlements_own_read on public.entitlements for select to authenticated using (user_id = (select auth.uid()));

-- meeting_offers: the board (open, not expired) plus my own offers.
grant select (id, creator_id, level, window_start, window_end, status, created_at) on public.meeting_offers to authenticated;
create policy meeting_offers_read on public.meeting_offers for select to authenticated
  using ((status = 'open' and window_end > now()) or creator_id = (select auth.uid()));

-- meetings / chats: participants only. Writes go through meeting-actions.
grant select (id, offer_id, creator_id, acceptor_id, level, scheduled_at, creator_confirmed, acceptor_confirmed, status, created_at)
  on public.meetings to authenticated;
create policy meetings_participants on public.meetings for select to authenticated
  using ((select auth.uid()) in (creator_id, acceptor_id));

grant select (id, meeting_id, user_a, user_b, last_message_at) on public.chats to authenticated;
create policy chats_participants on public.chats for select to authenticated
  using ((select auth.uid()) in (user_a, user_b));

grant select (id, chat_id, sender_id, kind, body, system_code, system_args, client_id, created_at) on public.chat_messages to authenticated;
grant insert (chat_id, body, client_id) on public.chat_messages to authenticated;
create policy chat_messages_read on public.chat_messages for select to authenticated
  using (exists (select 1 from public.chats c where c.id = chat_id and (select auth.uid()) in (c.user_a, c.user_b)));
create policy chat_messages_send on public.chat_messages for insert to authenticated
  with check (
    kind = 'user' and sender_id = (select auth.uid())
    and exists (select 1 from public.chats c where c.id = chat_id
                and (select auth.uid()) in (c.user_a, c.user_b)
                and c.user_a is not null and c.user_b is not null)
  );

-- exam_sessions: participants read (recording_key never leaves the backend).
grant select (id, level, exam_id, exam_version, user_a, user_b, origin, meeting_id, state, created_at,
  joined_a_at, joined_b_at, lobby_deadline, ready_a, ready_b, preloaded_a, preloaded_b,
  recording_consent_a, recording_consent_b, exam_started_at, schedule, step_index, step_started_at,
  feedback_ends_at, ended_at, aborted_by, abort_reason, recording_expires_at)
  on public.exam_sessions to authenticated;
create policy exam_sessions_participants on public.exam_sessions for select to authenticated
  using ((select auth.uid()) in (user_a, user_b));

grant select (user_id, exam_id, session_id, started_at, completed) on public.exam_history to authenticated;
create policy exam_history_own on public.exam_history for select to authenticated using (user_id = (select auth.uid()));

-- push_tokens: the device registers / removes its own token.
grant select (token, platform, updated_at), insert (token, platform), delete on public.push_tokens to authenticated;
create policy push_tokens_own_read on public.push_tokens for select to authenticated using (user_id = (select auth.uid()));
create policy push_tokens_own_insert on public.push_tokens for insert to authenticated with check (user_id = (select auth.uid()));
create policy push_tokens_own_delete on public.push_tokens for delete to authenticated using (user_id = (select auth.uid()));

-- trial_claims, revenuecat_events, exam_catalog, attendance, match_queue, notification_outbox,
-- storage_gc_queue: no client grants at all (service_role only).

-- ================================================================ Realtime
-- Silent failure if forgotten: perfect RLS and no events (vault, invariant 14c).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.exam_sessions, public.chat_messages, public.meetings, public.chats;
  end if;
end $$;
