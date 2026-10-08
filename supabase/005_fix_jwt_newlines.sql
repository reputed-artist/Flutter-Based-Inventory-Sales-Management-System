-- =============================================================================
--  FIX - signed JWTs contained newline characters and were rejected as "None
--        of the keys was able to decode the JWT" (HTTP 401 PGRST301)
--
--  SYMPTOM
--  On Android, every stock save failed with "Could not save. Check your
--  connection and try again." while the same build looked fine in Chrome.
--  Logging in worked, which ruled out a Vault secret problem.
--
--  ROOT CAUSE (confirmed against the live project)
--  PostgreSQL's `encode(bytea, 'base64')` wraps its output every 76 characters
--  with a newline. `b64url_from_bytes()` translated the alphabet and trimmed
--  padding but never removed those line breaks, so every token minted by
--  `operator_authenticate()` contained embedded LF bytes. PostgREST cannot
--  parse base64url containing newlines, so it answered:
--
--      HTTP 401  {"code":"PGRST301","message":"No suitable key or wrong key type"}
--
--  On top of that, RFC 7230 forbids control characters in HTTP header values,
--  so the Dart http client could not even send the header as-is on some
--  platforms / threw while sending - which is why Android reported it as a
--  "connection" failure while Chrome's CORS preflight never sent it at all.
--
--  FIX
--  Re-create the base64url helper so it strips every whitespace byte the
--  encoder may have inserted. Because the other helpers (`b64url_from_text`,
--  `jwt_sign`, `operator_authenticate`) all call this one at runtime, this
--  single change makes every freshly minted token clean and correctly signed.
--
--  Safe to re-run (create or replace). No existing data is touched.
-- =============================================================================

create or replace function public.b64url_from_bytes(p_bytes bytea)
returns text
language sql
immutable
as $$
  -- regexp_replace removes the newlines (and any other whitespace) that
  -- encode(bytea, 'base64') wraps into its output; translate converts the
  -- RFC 4648 alphabet to base64url; rtrim drops the '=' padding.
  select rtrim(
    translate(
      regexp_replace(encode(p_bytes, 'base64'), '[[:space:]]', '', 'g'),
      '+/',
      '-_'
    ),
    '='
  );
$$;

-- Re-create the text helper so the comment stays honest about what it
-- guarantees (a whitespace-free base64url string). Behaviour is unchanged.
create or replace function public.b64url_from_text(p_text text)
returns text
language sql
immutable
as $$
  select public.b64url_from_bytes(convert_to(p_text, 'UTF8'));
$$;

-- Re-create jwt_sign for the same reason: it is what builds the token string
-- and (crucially) signs `h || '.' || b`. The signature is now computed over
-- the whitespace-free strings, which is what PostgREST will verify.
-- Tokens minted before this fix were signed over corrupted input and can be
-- discarded - they were never accepted by the server anyway.
create or replace function public.jwt_sign(p_payload jsonb, p_secret text)
returns text
language sql
stable
set search_path = public, extensions
as $$
  with parts as (
    select
      public.b64url_from_text('{"alg":"HS256","typ":"JWT"}') as h,
      public.b64url_from_text(p_payload::text) as b
  )
  select p.h || '.' || p.b || '.' ||
         public.b64url_from_bytes(hmac(p.h || '.' || p.b, p_secret, 'sha256'))
  from parts p;
$$;

-- ---------------------------------------------------------------------------
-- Verify. After running this file, this must return true - the encoder no
-- longer leaves any whitespace behind:
--
--   select public.b64url_from_bytes('hello'::bytea) = 'aGVsbG8'
--     as b64url_is_clean;   -- true
--
-- Then sign out and sign back in on the device and record a stock movement.
-- ---------------------------------------------------------------------------