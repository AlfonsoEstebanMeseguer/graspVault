-- Guided feedback rubric (Design 2.0 §9.2 #4, D-042): after the exam each
-- candidate privately scores the other 1–5 on the four Cambridge speaking
-- criteria. Only the person rated (and the rater, to edit it) can read it.
-- Writes go through rate_partner(), which derives who is rated from the
-- session: a client can never rate someone it did not take the exam with.
create table public.peer_ratings (
  session_id uuid not null references public.exam_sessions (id) on delete cascade,
  rater_id uuid not null references auth.users (id) on delete cascade,
  ratee_id uuid not null references auth.users (id) on delete cascade,
  grammar smallint,
  discourse smallint,
  pronunciation smallint,
  interaction smallint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (session_id, rater_id),
  constraint peer_ratings_not_self check (rater_id <> ratee_id),
  constraint peer_ratings_range check (
    coalesce(grammar, 1) between 1 and 5 and coalesce(discourse, 1) between 1 and 5
    and coalesce(pronunciation, 1) between 1 and 5 and coalesce(interaction, 1) between 1 and 5)
);
create index peer_ratings_by_ratee on public.peer_ratings (ratee_id, created_at desc);

alter table public.peer_ratings enable row level security;
revoke all on table public.peer_ratings from anon, authenticated;
grant all on table public.peer_ratings to service_role;
grant select (session_id, rater_id, ratee_id, grammar, discourse, pronunciation, interaction, created_at, updated_at)
  on public.peer_ratings to authenticated;
create policy peer_ratings_read on public.peer_ratings for select to authenticated
  using ((select auth.uid()) in (ratee_id, rater_id));

create function public.rate_partner(
  p_session uuid,
  p_grammar smallint,
  p_discourse smallint,
  p_pronunciation smallint,
  p_interaction smallint
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  s public.exam_sessions;
  other uuid;
begin
  if me is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;
  select * into s from public.exam_sessions where id = p_session;
  if not found or me is distinct from s.user_a and me is distinct from s.user_b then
    raise exception 'not_participant' using errcode = 'P0001';
  end if;
  if s.exam_started_at is null then
    raise exception 'not_started' using errcode = 'P0001';
  end if;
  other := case when me = s.user_a then s.user_b else s.user_a end;
  if other is null then
    raise exception 'partner_gone' using errcode = 'P0001';
  end if;
  insert into public.peer_ratings (session_id, rater_id, ratee_id, grammar, discourse, pronunciation, interaction)
  values (p_session, me, other, p_grammar, p_discourse, p_pronunciation, p_interaction)
  on conflict (session_id, rater_id) do update
    set grammar = excluded.grammar,
        discourse = excluded.discourse,
        pronunciation = excluded.pronunciation,
        interaction = excluded.interaction,
        updated_at = now();
end;
$$;
revoke all on function public.rate_partner(uuid, smallint, smallint, smallint, smallint) from public, anon;
grant execute on function public.rate_partner(uuid, smallint, smallint, smallint, smallint) to authenticated;
