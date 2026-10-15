-- Deny by default, audited role by role (anon, authenticated) against the real grants.
begin;
do $$
declare a uuid; b uuid; c uuid; o uuid; r jsonb; n int;
begin
  a := tests.user('alice'); b := tests.user('bob'); c := tests.user('carol');
  o := public.svc_offer_create(a, 'B2', now() + interval '1 hour', now() + interval '3 hours');
  r := public.svc_offer_accept(b, o, date_trunc('hour', now()) + interval '2 hours');

  -- anon sees nothing and can call nothing
  perform tests.as_anon();
  perform tests.assert_fails('select 1 from public.profiles', 'permission denied', 'anon no lee profiles');
  perform tests.assert_fails('select 1 from public.public_profiles', 'permission denied', 'anon no lee public_profiles');
  perform tests.assert_fails('select public.svc_is_eligible(gen_random_uuid())', 'permission denied', 'anon no ejecuta svc_*');
  reset role;

  perform tests.as_user(c);
  -- public columns yes; private table only own row
  select count(*) into n from public.profiles; perform tests.assert_eq(n, 3, 'profiles publicos visibles');
  select count(*) into n from public.public_profiles; perform tests.assert_eq(n, 3, 'vista public_profiles');
  select count(*) into n from public.profiles_private; perform tests.assert_eq(n, 1, 'solo mi fila privada');
  perform tests.assert_fails('select created_at from public.profiles', 'permission denied', 'created_at no esta concedida');
  perform tests.assert_fails('select public.svc_is_eligible(gen_random_uuid())', 'permission denied', 'authenticated no ejecuta svc_*');
  perform tests.assert_fails('select public.svc_session_tick(gen_random_uuid())', 'permission denied', 'ni la maquina de estados');
  perform tests.assert_fails('select private.fail(''x'')', 'permission denied', 'ni el esquema private');
  -- entitlements: read own, never write
  select count(*) into n from public.entitlements; perform tests.assert_eq(n, 1, 'solo mi entitlement');
  perform tests.assert_fails('update public.entitlements set subscription_status = ''active''', 'permission denied', 'no me regalo la suscripcion');
  perform tests.assert_fails('update public.entitlements set trial_used_at = null', 'permission denied', 'no reinicio el trial');
  -- profiles: only user-owned columns, only own row
  perform tests.assert_fails('update public.profiles set avatar_key = null', 'permission denied', 'avatar_key solo via Edge Function');
  update public.profiles set languages = array['fr'] where id = a;   -- RLS filters: 0 rows
  update public.profiles set target_level = 'C1' where id = c;
  -- service-only tables
  perform tests.assert_fails('select 1 from public.match_queue', 'permission denied', 'match_queue cerrada');
  perform tests.assert_fails('select 1 from public.trial_claims', 'permission denied', 'trial_claims cerrada');
  perform tests.assert_fails('select 1 from public.attendance', 'permission denied', 'attendance cerrada');
  perform tests.assert_fails('select recording_key from public.exam_sessions', 'permission denied', 'recording_key nunca sale');
  -- carol is not in the chat
  select count(*) into n from public.chat_messages; perform tests.assert_eq(n, 0, 'carol no ve mensajes ajenos');
  select count(*) into n from public.meetings; perform tests.assert_eq(n, 0, 'carol no ve reuniones ajenas');
  perform tests.assert_fails(format('insert into public.chat_messages (chat_id, body) values (%L, ''hola'')', r ->> 'chat_id'),
    'row-level security', 'carol no escribe en chat ajeno');
  -- the board shows alice's open offer
  select count(*) into n from public.meeting_offers; perform tests.assert_eq(n, 1, 'tablon visible');
  reset role;

  perform tests.assert_eq((select languages from public.profiles where id = a), array['es', 'en'], 'carol no edito a alice');
  perform tests.assert_eq((select target_level from public.profiles where id = c), 'C1', 'carol edito su nivel');

  -- bob in his chat: can write as himself, cannot spoof sender or system messages
  perform tests.as_user(b);
  insert into public.chat_messages (chat_id, body, client_id) values ((r ->> 'chat_id')::uuid, 'hola', '00000000-0000-0000-0000-000000000001');
  perform tests.assert_fails(format('insert into public.chat_messages (chat_id, body, sender_id) values (%L, ''x'', %L)', r ->> 'chat_id', a),
    'permission denied', 'no se puede fijar sender_id');
  perform tests.assert_fails(format('insert into public.chat_messages (chat_id, body, kind) values (%L, ''x'', ''system'')', r ->> 'chat_id'),
    'permission denied', 'no se puede fingir un mensaje de sistema');
  perform tests.assert_fails(format('insert into public.chat_messages (chat_id, body) values (%L, ''   '')', r ->> 'chat_id'),
    'chat_messages_user_body', 'mensaje en blanco rechazado');
  select count(*) into n from public.chat_messages; perform tests.assert_eq(n, 2, 'bob ve sistema + su mensaje');
  select count(*) into n from public.meetings; perform tests.assert_eq(n, 1, 'bob ve su reunion');
  reset role;
end $$;
rollback;
