-- D-066: minimum age 16 (was 14). 16 is the highest age of digital consent in
-- the EU (Art. 8 GDPR), so it holds in every member state, and it fits the
-- 16+ rating that open voice calls between strangers usually get in the stores.
-- Applies to new sign-ups and to birth-date edits; nobody signed up today is under 16.
create or replace function private.enforce_min_age() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.birth_date > (current_date - interval '16 years')::date then
    raise exception 'underage' using errcode = '23514';
  end if;
  if new.birth_date < date '1900-01-01' then
    raise exception 'birth_date_out_of_range' using errcode = '23514';
  end if;
  return new;
end $$;
revoke all on function private.enforce_min_age() from public, anon, authenticated;
