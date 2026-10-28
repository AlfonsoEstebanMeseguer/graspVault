-- Security advisor (2026-10-24): pin search_path on the helpers added for the Pro
-- control and on mic_for, which lost its setting when it was re-created.
alter function private.to_ms(timestamptz) set search_path = '';
alter function private.from_ms(bigint) set search_path = '';
alter function private.ctl_with_durations(jsonb, bigint[]) set search_path = '';
alter function private.ctl_durations(jsonb) set search_path = '';
alter function private.ctl_state(public.exam_sessions) set search_path = '';
alter function private.mic_for(public.exam_sessions, int) set search_path = '';
alter function private.valid_slot(timestamptz) set search_path = '';
