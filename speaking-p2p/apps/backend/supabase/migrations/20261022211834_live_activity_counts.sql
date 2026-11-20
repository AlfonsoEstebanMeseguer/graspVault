-- "People searching now" on Home (DECISIONS D-032). Only aggregate counts leave the
-- database: who is searching stays private (match_queue has no grant to clients).
-- Searching = a heartbeat in the last 25 s, the same window the matcher uses.
create or replace function public.live_activity()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'searching', jsonb_build_object(
      'B1', count(*) filter (where q.level = 'B1'),
      'B2', count(*) filter (where q.level = 'B2'),
      'C1', count(*) filter (where q.level = 'C1')),
    'in_exam', (select count(*) from public.exam_sessions s
                where s.state in ('lobby', 'part1', 'part2', 'part3', 'part4', 'feedback')
                  and s.created_at > now() - interval '2 hours'))
  from public.match_queue q
  where q.last_seen_at > now() - interval '25 seconds'
$$;

revoke all on function public.live_activity() from public, anon;
grant execute on function public.live_activity() to authenticated;
