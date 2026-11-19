-- Re-acceptance of the Terms and Privacy Policy (docs/legal/ASPECTOS_A_COMPLETAR.md
-- §11, D-066). When the app ships a newer version than the one stored, it
-- shows the new documents and calls this. The date is the SERVER's: the client
-- only says which version it showed, it cannot backdate the acceptance.
create function public.accept_terms(p_version text) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then perform private.fail('not_found'); end if;
  if p_version is null or btrim(p_version) = '' or char_length(p_version) > 20 then perform private.fail('bad_version'); end if;
  update public.profiles_private set terms_version = p_version, terms_accepted_at = now() where id = me;
  if not found then perform private.fail('not_found'); end if;
end $$;
revoke all on function public.accept_terms(text) from public, anon;
grant execute on function public.accept_terms(text) to authenticated;
