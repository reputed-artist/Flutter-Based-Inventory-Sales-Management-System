# Attaching the Supabase backend

This repo has **two clients** and they use **two different backend schemas**.
Pick the one you actually want to run.

| Client | Folder | Backend | Auth |
|--------|--------|---------|------|
| **Flutter Android app** (primary) | `lib/` | `supabase/migrations/*.sql` | PIN login → signed JWT + RLS |
| **React/Vite PWA** (AI Studio demo) | `src/` | the SQL shown in *Settings & DB → SQL Schema* | none (open policies) |

> ⚠️ Do **not** point both clients at the same Supabase project: the Flutter app
> enables Row Level Security that an anonymous PWA cannot satisfy, and the two
> use different `category` and transaction `type` values. Use a separate
> project if you want to run both.

---

## 1. Flutter app (recommended)

### 1.0 This build is already connected
The project coordinates are compiled into the app as defaults, so **no setup is
needed to connect** - the app calls `Supabase.initialize()` before the first
frame is drawn:

| | |
|---|---|
| Project URL | `https://edkeoeevdldytggiisxb.supabase.co` |
| Publishable key | `sb_publishable_mud9BiBIUG94TCJlnXIiJw_3g9dXnid` |

Resolution order at startup:
1. values saved in the in-app **Configure Supabase Database** dialog
2. `--dart-define` overrides
3. the defaults above

A publishable key is safe to embed: it is public by design, and Row Level
Security — not the key — is what protects the data.

### 1.1 Create the project
1. <https://supabase.com/dashboard> → **New project**. Note the DB password.
2. **Project Settings → API**: copy the **Project URL** and the
   **anon / publishable key**.
3. (Optional) **Project Settings → API → JWT Settings**: if your project still
   shows a **Legacy JWT Secret**, leave legacy verification enabled so any old
   self-minted tokens can be decoded during the migration. The app no longer
   uses this secret (see 1.3).

### 1.2 Create the schema
Open **SQL Editor** and run, in order:

1. Paste the whole of `supabase/migrations/001_init.sql` → **Run**.
2. Paste the whole of `supabase/migrations/002_seed.sql` → **Run**.
3. Paste and run `supabase/005_fix_jwt_newlines.sql` (clean JWT signing).
4. Paste and run `supabase/006_bind_pin_to_operator.sql` (binds each PIN to its
   own operator, so a PIN can no longer sign in as a different operator).
5. Paste and run `supabase/007_anon_pin_binding.sql` — **required** on ES256
   (JWT Signing Keys) projects; replaces the self-minted JWT with a real
   Supabase Auth session + PIN binding (see section 5).

**Authentication settings (one-time, dashboard):** open
**Authentication → Sign In / Up → anonymous sign-ins** and switch **Allow
anonymous sign-ins** **ON**. The app signs in anonymously first, so the token
PostgREST verifies is signed by Supabase itself rather than minted by the app.

`002_seed.sql` creates 6 demo operators (PINs `1111`…`6666`) and 11 catalog
items. **Change the PINs before real use.**

### 1.3 Store the JWT secret (NOT needed by the current app)
The current build does **not** sign its own tokens. `operator_bind_session`
(007) verifies the PIN and binds the Supabase Auth user to the operator;
Supabase Auth issues the real session/refresh tokens. The Vault secret used by
the old design is ignored, so **skip this step entirely**.

### 1.4 Point the app at the project
Either **A)** run/relaunch the app and tap
**"Configure Supabase Database"** on the PIN screen, then paste the URL + anon
key; or **B)** bake the credentials into the build:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

Both paths feed `SupabaseService.initFromStorage()`.

### 1.5 Sign in
Pick an operator (e.g. *Rajesh Sharma*) and enter that operator's PIN. The app
creates a Supabase Auth (anonymous) session, then calls `operator_bind_session`,
which verifies the bcrypt PIN **for the selected operator** (a wrong PIN can
never sign in as someone else) and binds the session to that operator. Every
stock change is written by the `apply_stock_movement` RPC inside a single
transaction (row-locked), so 5–6 devices never overwrite each other, and each
row is stamped with the real operator id resolved from the session binding.

**Sign out** (app bar or the operator chip menu) ends the session server-side
and returns the device to the PIN screen.

---

## 2. React/Vite PWA

```bash
npm install
# put your URL + anon key in .env (see .env.example)
npm run dev
```

Then open **Settings & DB → SQL Schema**, copy the script, and run it once in
your Supabase SQL Editor. Use a **separate** project from the Flutter app.

---

## 3. Security model (Flutter schema)

- PINs are stored **only** as bcrypt hashes (`crypt`/`gen_salt`).
- 5 failed PIN attempts lock the device for 15 minutes (`pin_attempts`).
- All tables have RLS enabled; `anon` can only call `list_operators`. Everything
  else needs a real Supabase Auth session (`role=authenticated`) bound to an
  operator with a PIN (`operator_bind_session`).
- `inventory_transactions` is append-only: clients can insert but can never
  update or delete history.
- Operator identity in a transaction is forced from the JWT by a trigger
  (`stamp_transaction`), so the audit trail cannot be forged.

---

## 4. Troubleshooting

| Symptom | Fix |
|---|---|
| **"Database schema is missing"** (PostgREST `PGRST202`) | The migrations were never applied. Run `001_init.sql` then `002_seed.sql` in the SQL Editor. Confirm with `supabase/00_check.sql`. |
| Login screen says *"No operators found"* | `002_seed.sql` was not run, or RLS blocks `list_operators` (re-run `001_init.sql`). |
| *"Anonymous sign-in is disabled"* (login error) | Turn **ON** *Allow anonymous sign-ins* under **Authentication → Sign In / Up**, then relaunch (see 1.2). |
| Login succeeds but reads/writes are refused (`PGRST301`) | The database still uses the old self-minted-token schema. In the SQL Editor run `supabase/007_anon_pin_binding.sql`, then rebuild/relaunch the app so login uses `operator_bind_session` (section 5). |
| Error text says `No suitable key or wrong key type` | Signing-key mismatch caused by an outdated app build. Rebuild with the current app (which uses the Supabase Auth ES256 session) and make sure 007 is applied. |
| **"Could not save" on Android but fine in Chrome** | Almost certainly *not* a connectivity problem. Chrome's CORS preflight blocks the request before it leaves the browser, so the app applied the change in memory and showed no error — **nothing was saved**. Android has no CORS, so it reaches the server and reports the real refusal, which was `PGRST301` because the operator JWT contained newlines. Fix the server error it names. |
| Realtime not updating | Ensure `001_init.sql` section 12 ran (adds tables to the `supabase_realtime` publication). Channels are (re)opened on sign-in, so sign in first. |
| Android build has no network/camera | Confirm `INTERNET` + `CAMERA` permissions in `android/app/src/main/AndroidManifest.xml`. |

### Quickest way to see the state of your project
Run `supabase/00_check.sql` (read-only) in the SQL Editor. It reports which
tables, which functions, how many operators and items exist, and whether the
Vault JWT secret is present — so you never have to guess which step is missing.
---

## 5. Why the sign-in token is rejected: the project uses ES256 signing keys

The Data API (PostgREST) verifies every `Authorization: Bearer <token>` against
the project's JWT verification key. You can read that key set publicly:

```
GET https://<your-project-ref>.supabase.co/auth/v1/.well-known/jwks.json
```

For this project it returns a **single asymmetric key**:

```json
{ "kty": "EC", "crv": "P-256", "alg": "ES256", "use": "sig", "key_ops": ["verify"] }
```

This is Supabase's **JWT Signing Keys** system (Project Settings → API → JWT
Settings). There is no symmetric (`oct`) key in the set, so a token signed with
**HS256** and the shared secret can never be verified — PostgREST answers:

```
HTTP 401  {"code":"PGRST301",
           "message":"No suitable key or wrong key type",
           "details":"None of the keys was able to decode the JWT"}
```

`operator_authenticate()` mints exactly such an HS256 token from the Vault
secret. **No change to the app or to the Vault secret can make that token
acceptable** — the signatures are of incompatible key types. This is the real
reason login succeeds but every authenticated read/write is refused, and why the
earlier newline fix (`005`) and secret fix (`1.3`) did not help.

### The fix (implemented)

The app no longer mints tokens in SQL. This is what the repo now does, without
any Edge Function:

1. The app signs in **anonymously** with GoTrue, getting a real **ES256**-signed
   session that PostgREST can verify against the key set above. *Requires*
   **Allow anonymous sign-ins** ON in Auth settings (step 1.2).
2. `operator_bind_session(operator_id, pin, device…)` verifies the bcrypt PIN
   **for the selected operator** and binds the Supabase auth user to it
   (`auth.uid() → operators.id` in `operator_auth_bindings`).
3. RLS keeps working unchanged: `current_operator_id()` / `current_session_id()`
   now resolve through that binding (SECURITY DEFINER) before falling back to
   the old `sub` claim.
4. The SDK attaches the session to REST + Realtime automatically — all manual
   `Authorization` header plumbing has been deleted.
5. `apply_stock_movement` reads the device id from the session row instead of a
   JWT claim, and `operator_signout()` deletes the binding so a signed-out
   device can never keep writing.

Apply `supabase/007_anon_pin_binding.sql` once in the SQL Editor (idempotent),
then rebuild the app. This design survives Supabase's signing-key rotation:
the token always comes from Supabase Auth.
