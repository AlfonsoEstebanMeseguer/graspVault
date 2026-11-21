-- Security audit 2026-11, C1 + C2 (docs/SECURITY_AUDIT_2026-11.md, D-070).
-- The debug switches were seeded 'true' by 20261022195118 and 20261022203047 and
-- were still on in production (switched off by hand on 2026-11-21). A database
-- rebuilt from migrations must not come up with them on: any user could open
-- unlimited LiveKit rooms/recordings (enter_now) or skip exam segments (skip).
-- To use them in development, turn them on by hand in that database only.
update public.app_config set value = 'false' where key in ('dev_instant_rooms', 'dev_session_skip');
