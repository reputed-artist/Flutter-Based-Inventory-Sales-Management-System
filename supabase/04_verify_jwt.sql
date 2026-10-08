-- =============================================================================
--  STEP 4 - verify PostgREST will accept the tokens this project mints
--
--  WHY THIS EXISTS
--  The Android build reported "Could not save. Check your connection and try
--  again" on every stock change while the same build looked fine in Chrome.
--  The cause was NOT connectivity: Chrome's CORS preflight blocked the request
--  before it left the browser, so the app silently applied the change in
--  memory and showed no error. Android has no CORS, so the request reached
--  PostgREST, which refused the operator token:
--
--      HTTP 401
--      {"code":"PGRST301",
--       "details":"None of the keys was able to decode the JWT",
--       "message":"No suitable key or wrong key type"}
--
--  PostgREST answers that way when the signing secret in Vault is not the same
--  secret PostgREST is configured with - typically because the project moved to
--  asymmetric signing keys and the legacy HS256 secret was retired.
--
--  HOW TO USE
--  1. Run this file in the SQL Editor. It is read-only: it creates nothing and
--     changes nothing.
--  2. Check query 1 - secret_present must be true and secret_length >= 16.
--  3. Copy probe_token from query 2 and paste it into the curl command below.
--
--      curl -i -X POST \
--        "https://YOUR-PROJECT.supabase.co/rest/v1/rpc/apply_stock_movement" \
--        -H "apikey: YOUR_PUBLISHABLE_KEY" \
--        -H "Authorization: Bearer <probe_token>" \
--        -H "Content-Type: application/json" \
--        -d '{"p_item_id":"item_1","p_type":"correction","p_quantity":1}'
--
--  HTTP 400 + {"code":"P0001","message":"AUTH_REQUIRED"}  -> GOOD. The token
--      was decoded successfully; AUTH_REQUIRED only means the probe's `sub`
--      does not match a real operator row. PostgREST accepted the signature.
--
--  HTTP 401 + PGRST301  -> BAD. The secrets disagree. Go back to step 1.3 and
--      store the project's *Legacy JWT Secret* (Project Settings -> API ->
--      JWT Settings -> Legacy JWT Secret -> Reveal) as `app_jwt_secret`.
--      On the dashboard, ensure the legacy HS256 secret is still enabled.
-- =============================================================================

-- 1. Is a signing secret available, and does it look like a Supabase one?
select public.jwt_secret() is not null             as secret_present,
       length(public.jwt_secret())                as secret_length,
       -- Supabase JWT secrets are base64url and well over 32 characters.
       public.jwt_secret() ~ '^[A-Za-z0-9._-]{32,}$' as looks_like_supabase_secret;

-- 2. Mint a probe token signed exactly the way operator_authenticate() does.
--    NOTE: this mirrors the claims in 001_init.sql. If you later add an `exp`
--    claim there, mirror it here too or the probe will differ from production.
with probe as (
  select public.jwt_sign(
           jsonb_build_object(
             'sub',         (select id from public.operators order by created_at limit 1),
             'role',        'authenticated',
             'app_role',    'staff',
             'session_id',  '00000000-0000-0000-0000-000000000000',
             'device_id',   'probe',
             'iat',         extract(epoch from now())::bigint
           ),
           public.jwt_secret()
         ) as probe_token
)
select probe_token from probe;

-- 3. Sanity check that the tables the app writes to actually exist.
select to_regclass('public.inventory_items')            is not null as has_items,
       to_regclass('public.inventory_transactions')      is not null as has_txns,
       to_regprocedure('public.apply_stock_movement(text,text,int,numeric,text,text)')
                                                          is not null as has_rpc;