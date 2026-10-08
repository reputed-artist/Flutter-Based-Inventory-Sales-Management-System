-- =============================================================================
--  STEP 3 - store the JWT signing secret (required for PIN login)
--
--  WHY: operator_authenticate() mints a session JWT so that PostgREST can
--       resolve auth.uid() inside your RLS policies. It signs that token with
--       YOUR project's JWT secret, read from Vault under the name
--       'app_jwt_secret'. Without it, login fails with
--       "Server JWT secret is not configured".
--
--  WHERE TO FIND THE SECRET:
--    Dashboard -> Project Settings -> API -> JWT Settings
--    -> "Legacy JWT Secret"  -> click Reveal -> copy it.
--    (Newer projects hide it behind a reveal button; that value is correct.)
--
--  HOW TO USE:
--    1. Copy the secret below and paste it in place of the placeholder.
--    2. Run this file in the SQL Editor.
--    3. It is safe to re-run: it replaces any previous value.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- OPTION A (recommended): store it in Supabase Vault.
--
-- Replace PASTE_YOUR_JWT_SECRET_HERE below with your real secret (keep the
-- quotes). The delete-then-create makes this safe to re-run; without it,
-- create_secret() errors with "secret already exists" on the second attempt.
-- ---------------------------------------------------------------------------
do $$
declare
  v_secret text := 'PASTE_YOUR_JWT_SECRET_HERE';
  v_id     uuid;
begin
  select id into v_id from vault.secrets where name = 'app_jwt_secret' limit 1;
  if v_id is not null then
    perform vault.update_secret(v_id, v_secret);
  else
    perform vault.create_secret(
      v_secret, 'app_jwt_secret',
      'Ink & Machine Sync session-token signing key'
    );
  end if;
end $$;

-- Verify: must return true, and length() must be 16 or more.
select public.jwt_secret() is not null as secret_ok,
       length(public.jwt_secret())   as secret_length;

-- ---------------------------------------------------------------------------
-- OPTION B (fallback) - if vault.create_secret errors with
-- "extension vault is not available", enable the extension first:
--
--   create extension if not exists vault with schema vault;
--
-- then re-run this file.
-- ---------------------------------------------------------------------------
