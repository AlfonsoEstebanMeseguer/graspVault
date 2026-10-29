-- "Previous question" control (D-039): same reducer plus 'prev_step', mirrored
-- in control.dart and pinned by content/fixtures/control-golden.json.
create or replace function private.ctl_apply(p jsonb, p_op text, p_args jsonb, p_now bigint) returns jsonb
language plpgsql set search_path = '' as $$
declare
  sched jsonb := p -> 'schedule';
  segs jsonb := p -> 'schedule' -> 'segments';
  start_ms bigint := (p ->> 'startedAtMs')::bigint;
  paused bigint := (p ->> 'pausedAtMs')::bigint;
  reason text := p ->> 'pauseReason';
  fb_end bigint := (p ->> 'feedbackEndsAtMs')::bigint;
  total bigint := (p -> 'schedule' ->> 'totalMs')::bigint;
  ver int := coalesce((p ->> 'version')::int, 0) + 1;
  e bigint; idx int := -1; seg jsonb; fb_len bigint; target bigint; k int; dur bigint[]; delta bigint;
  v_ms bigint; ref jsonb; ref_dur bigint; new_sched jsonb; changed int[] := '{}'; v_step text;
begin
  if p_op = 'finish_switch' then
    if reason is distinct from 'switching' then perform private.fail('not_switching'); end if;
    start_ms := p_now + 3000;
    return p || jsonb_build_object('startedAtMs', start_ms, 'pausedAtMs', null, 'pauseReason', null,
      'feedbackEndsAtMs', start_ms + total + 300000, 'version', ver);
  end if;
  if reason = 'switching' then perform private.fail('switching'); end if;

  e := coalesce(paused, p_now) - start_ms;
  if e >= fb_end - start_ms then perform private.fail('not_in_exam'); end if;
  fb_len := fb_end - start_ms - total;
  if e < total then
    select (x ->> 'index')::int, x into idx, seg from jsonb_array_elements(segs) x
    where (x ->> 'startMs')::bigint <= greatest(e, 0) order by (x ->> 'startMs')::bigint desc limit 1;
  end if;

  case p_op
  when 'pause' then
    if idx < 0 then perform private.fail('not_in_part'); end if;
    if paused is not null then perform private.fail('already_paused'); end if;
    if e < 0 then perform private.fail('not_started'); end if;
    if seg ->> 'phase' <> 'speak' then perform private.fail('reader_speaking'); end if;
    return p || jsonb_build_object('pausedAtMs', p_now, 'pauseReason', 'leader', 'version', ver);
  when 'resume' then
    if reason is distinct from 'leader' then perform private.fail('not_paused'); end if;
    return p || jsonb_build_object('startedAtMs', start_ms + (p_now - paused), 'feedbackEndsAtMs', fb_end + (p_now - paused),
      'pausedAtMs', null, 'pauseReason', null, 'version', ver);
  when 'skip_reader' then
    if idx < 0 then perform private.fail('not_in_part'); end if;
    if seg ->> 'phase' <> 'reader' then perform private.fail('not_reader'); end if;
    target := (seg ->> 'endMs')::bigint;
  when 'next_step' then
    if idx < 0 then perform private.fail('not_in_part'); end if;
    select min((x ->> 'startMs')::bigint) into target from jsonb_array_elements(segs) x
    where (x ->> 'index')::int > idx and x ->> 'stepId' <> seg ->> 'stepId';
    target := coalesce(target, total);
  when 'next_part' then
    if idx < 0 then perform private.fail('not_in_part'); end if;
    select min((x ->> 'startMs')::bigint) into target from jsonb_array_elements(segs) x
    where (x ->> 'index')::int > idx and (x ->> 'part')::int > (seg ->> 'part')::int;
    target := coalesce(target, total);
  when 'prev_step' then
    -- back to the previous question; from the feedback, to the last one
    if idx < 0 then
      select x ->> 'stepId' into v_step from jsonb_array_elements(segs) x order by (x ->> 'index')::int desc limit 1;
    else
      select min((x ->> 'index')::int) into k from jsonb_array_elements(segs) x where x ->> 'stepId' = seg ->> 'stepId';
      if k = 0 then perform private.fail('out_of_range'); end if;
      v_step := segs -> (k - 1) ->> 'stepId';
    end if;
    select min((x ->> 'startMs')::bigint) into target from jsonb_array_elements(segs) x where x ->> 'stepId' = v_step;
  when 'end_exam' then
    if idx < 0 then perform private.fail('not_in_part'); end if;
    target := total;
  when 'repeat_step' then
    if idx < 0 then perform private.fail('not_in_part'); end if;
    select min((x ->> 'startMs')::bigint) into target from jsonb_array_elements(segs) x where x ->> 'stepId' = seg ->> 'stepId';
  when 'go_to_part' then
    select min((x ->> 'startMs')::bigint) into target from jsonb_array_elements(segs) x
    where (x ->> 'part')::int = (p_args ->> 'part')::int;
    if target is null then perform private.fail('out_of_range'); end if;
  when 'extend' then
    delta := (p_args ->> 'deltaMs')::bigint;
    if delta is null or delta not in (-30000, 30000, 60000, 120000) then perform private.fail('bad_delta'); end if;
    if idx < 0 then
      if fb_len + delta > 1200000 or fb_end + delta - coalesce(paused, p_now) < 5000 then perform private.fail('out_of_range'); end if;
      return p || jsonb_build_object('feedbackEndsAtMs', fb_end + delta, 'version', ver);
    end if;
    k := private.ctl_speak_target(segs, idx);
    dur := private.ctl_durations(sched);
    dur[k + 1] := dur[k + 1] + delta;
    changed := array[k];
  when 'set_part_speak' then
    if idx < 0 then perform private.fail('not_in_part'); end if;
    v_ms := (p_args ->> 'ms')::bigint;
    k := private.ctl_speak_target(segs, idx);
    ref := segs -> k;
    ref_dur := (ref ->> 'endMs')::bigint - (ref ->> 'startMs')::bigint;
    dur := private.ctl_durations(sched);
    select coalesce(array_agg((x ->> 'index')::int), '{}') into changed from jsonb_array_elements(segs) x
    where (x ->> 'index')::int >= k and x ->> 'part' = ref ->> 'part' and x ->> 'phase' = 'speak'
      and x ->> 'kind' = ref ->> 'kind' and (x ->> 'endMs')::bigint - (x ->> 'startMs')::bigint = ref_dur;
    for i in 1 .. coalesce(array_length(changed, 1), 0) loop dur[changed[i] + 1] := v_ms; end loop;
  when 'switch_exam' then
    if e < 0 then perform private.fail('not_started'); end if;
    new_sched := p_args -> 'schedule';
    return p || jsonb_build_object('examId', p_args ->> 'examId', 'schedule', new_sched, 'startedAtMs', p_now,
      'pausedAtMs', p_now, 'pauseReason', 'switching',
      'feedbackEndsAtMs', p_now + (new_sched ->> 'totalMs')::bigint + 300000, 'version', ver);
  else
    perform private.fail('bad_op');
  end case;

  if p_op in ('extend', 'set_part_speak') then
    for i in 1 .. coalesce(array_length(changed, 1), 0) loop
      k := changed[i];
      if dur[k + 1] < 10000 or dur[k + 1] > 900000 then perform private.fail('out_of_range'); end if;
      -- the running window may shrink, but must not end in the past
      if k = idx and (segs -> k ->> 'startMs')::bigint + dur[k + 1] <= e + 1000 then perform private.fail('out_of_range'); end if;
    end loop;
    new_sched := private.ctl_with_durations(sched, dur);
    return p || jsonb_build_object('schedule', new_sched,
      'feedbackEndsAtMs', fb_end + ((new_sched ->> 'totalMs')::bigint - total), 'version', ver);
  end if;

  -- a jump: clears any pause and keeps the feedback length
  start_ms := p_now - target;
  return p || jsonb_build_object('startedAtMs', start_ms, 'pausedAtMs', null, 'pauseReason', null,
    'feedbackEndsAtMs', start_ms + total + fb_len, 'version', ver);
end $$;

revoke all on function private.ctl_apply(jsonb, text, jsonb, bigint) from public, anon, authenticated;
grant execute on function private.ctl_apply(jsonb, text, jsonb, bigint) to service_role;
