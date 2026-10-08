-- =============================================================================
--  Ink & Machine Sync - Supabase backend bootstrap  (corrected v2)
--  Run ONCE in the Supabase SQL Editor. Safe to re-run (idempotent).
--
--  Requires only pgcrypto (enabled below) - no pgjwt, no app.settings GUCs.
--  Order matters: tables -> helper fns -> RPCs -> RLS -> realtime -> grants.
--  After this file, run 002_seed.sql, then see SUPABASE_SETUP.md to store the
--  JWT secret in Vault so PIN login can mint session tokens.
-- =============================================================================

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- 1. OPERATORS
-- -----------------------------------------------------------------------------
create table if not exists public.operators (
  id            text primary key,
  name          text not null,
  role          text not null default 'Warehouse Staff',
  device_label  text not null default 'Android Device',
  avatar_color  text not null default '#0284c7',
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

-- PIN is stored ONLY as a bcrypt hash. Plain PINs are never persisted.
create table if not exists public.operator_pins (
  operator_id  text primary key references public.operators(id) on delete cascade,
  pin_hash     text not null,
  updated_at   timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- 2. DATA ENTRY SESSIONS  (who was logged in, on which device, since when)
-- -----------------------------------------------------------------------------
create table if not exists public.data_entry_sessions (
  id             uuid primary key default gen_random_uuid(),
  operator_id    text not null references public.operators(id) on delete cascade,
  device_id      text not null,
  started_at     timestamptz not null default now(),
  last_seen_at   timestamptz not null default now(),
  ended_at       timestamptz,
  end_reason     text,
  is_active      boolean not null default true
);

create index if not exists sessions_operator_idx
  on public.data_entry_sessions (operator_id, started_at desc);

-- -----------------------------------------------------------------------------
-- 3. INVENTORY  (column names match InventoryItem.toJson exactly)
-- -----------------------------------------------------------------------------
create table if not exists public.inventory_items (
  id                 text primary key,
  sku                text not null,
  name               text not null,
  category           text not null,
  unit               text not null default 'units',
  description        text,
  total_in           int not null default 0,
  total_sold         int not null default 0,
  left_count         int not null default 0,
  min_stock_alert    int not null default 5,
  unit_cost_price    numeric not null default 0,
  unit_selling_price numeric not null default 0,
  location           text,
  barcode            text,
  last_updated       timestamptz not null default now(),
  last_updated_by    text,
  constraint inventory_items_category_chk check (
    category in ('hp_cartridges','handy_printer','online_printer',
                 'docod_printer','rynan_cartridges','packaging_machines')
  ),
  constraint inventory_items_left_count_chk check (left_count >= 0)
);

create unique index if not exists inventory_items_sku_key
  on public.inventory_items (lower(sku));

-- -----------------------------------------------------------------------------
-- 4. TRANSACTIONS  (column names match InventoryTransaction.toJson exactly)
-- -----------------------------------------------------------------------------
create table if not exists public.inventory_transactions (
  id                    text primary key,
  item_id               text not null,
  item_name             text not null,
  item_sku              text not null,
  type                  text not null,
  quantity              int  not null,
  previous_left_count   int  not null,
  new_left_count        int  not null,
  unit_price            numeric,
  total_amount          numeric,
  client_or_supplier    text,
  notes                 text,
  operator_name         text,
  operator_id           text,
  device_id             text,
  session_id            uuid references public.data_entry_sessions(id) on delete set null,
  timestamp             timestamptz not null default now(),
  constraint inventory_transactions_type_chk
    check (type in ('in','sold','correction','transfer'))
);

create index if not exists inventory_transactions_item_idx
  on public.inventory_transactions (item_id, timestamp desc);
create index if not exists inventory_transactions_ts_idx
  on public.inventory_transactions (timestamp desc);

-- -----------------------------------------------------------------------------
-- 5. PIN ATTEMPT LOG  (drives the 15-minute lockout)
--    Declared here so it exists before any function/policy references it.
-- -----------------------------------------------------------------------------
create table if not exists public.pin_attempts (
  id          bigserial primary key,
  operator_id text,
  device_id   text not null,
  success     boolean not null,
  created_at  timestamptz not null default now()
);

create index if not exists pin_attempts_lookup
  on public.pin_attempts (operator_id, device_id, created_at desc);

-- -----------------------------------------------------------------------------
-- 6. JWT HELPERS  (self-contained HS256 signing using pgcrypto only)
--    Supabase removed `app.settings.jwt_secret` (Nov 2024) and `pgjwt` is
--    deprecated on Postgres 17, so we sign the token ourselves and read the
--    secret from Vault (recommended) or the `app.settings.jwt_secret` GUC.
-- -----------------------------------------------------------------------------
-- Reads the JWT signing secret. Prefers Supabase Vault (recommended); falls
-- back to the `app.settings.jwt_secret` GUC. plpgsql so it still loads on a
-- database without the Vault extension.
create or replace function public.jwt_secret()
returns text
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_secret text;
begin
  begin
    select decrypted_secret into v_secret
    from vault.decrypted_secrets
    where name = 'app_jwt_secret'
    limit 1;
  exception when others then
    v_secret := null;
  end;

  if v_secret is null or v_secret = '' then
    v_secret := current_setting('app.settings.jwt_secret', true);
  end if;

  return v_secret;
end;
$$;

-- base64url (RFC 7515): pgcrypto's base64 alphabet uses '+'/'/' and padding
-- which are not allowed in a JWT, so translate them here.
create or replace function public.b64url_from_bytes(p_bytes bytea)
returns text
language sql
immutable
as $$
  select rtrim(translate(encode(p_bytes, 'base64'), '+/', '-_'), '=');
$$;

create or replace function public.b64url_from_text(p_text text)
returns text
language sql
immutable
as $$
  select public.b64url_from_bytes(convert_to(p_text, 'UTF8'));
$$;

-- Sign a claim set as an HS256 JWT, byte-compatible with PostgREST.
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

-- Who is calling? Reads the 'sub' claim out of the signed JWT.
create or replace function public.current_operator_id()
returns text
language sql
stable
as $$
  select nullif(
    current_setting('request.jwt.claims', true)::jsonb ->> 'sub', ''
  );
$$;

create or replace function public.current_session_id()
returns uuid
language plpgsql
stable
as $$
begin
  return nullif(
    (current_setting('request.jwt.claims', true)::jsonb ->> 'session_id'), ''
  )::uuid;
exception when others then return null; end;
$$;

-- -----------------------------------------------------------------------------
-- 7. PIN LOGIN  (bcrypt verify + signed JWT + lockout + session row)
--    Returns { ok, token, operator, session_id, error }
--
--    The PIN is bound to the operator selected on the login screen: the id is
--    passed in and the entered PIN must belong to that operator. Databases
--    created before this change should also run
--    supabase/006_bind_pin_to_operator.sql, which applies the same definition.
-- -----------------------------------------------------------------------------

-- Drop the old 3-argument version so the operator-bound one below can never be
-- resolved ambiguously (a pre-fix database still has it).
drop function if exists public.operator_authenticate(text, text, text);

create or replace function public.operator_authenticate(
  p_operator_id  text,
  p_pin          text,
  p_device_id    text,
  p_device_label text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_op         record;
  v_failures   int;
  v_session_id uuid;
  v_secret     text;
  v_token      text;
  v_app_role   text;
begin
  if p_operator_id is null or length(btrim(p_operator_id)) = 0 then
    return jsonb_build_object('ok', false, 'error', 'No operator selected.');
  end if;

  if p_pin is null or p_pin !~ '^[0-9]{4}$' then
    return jsonb_build_object('ok', false, 'error', 'PIN must be exactly 4 digits.');
  end if;

  -- device-wide lockout: 5 failures against any operator in 15 minutes
  select count(*) into v_failures
  from public.pin_attempts
  where device_id = p_device_id
    and success = false
    and created_at > now() - interval '15 minutes';
  if v_failures >= 5 then
    return jsonb_build_object(
      'ok', false, 'error', 'Too many failed attempts. Locked for 15 minutes.'
    );
  end if;

  -- find the active operator whose bcrypt hash matches this PIN AND who is the
  -- operator that was selected on the login screen
  select o.id, o.name, o.role, o.device_label, o.avatar_color
    into v_op
  from public.operators o
  join public.operator_pins p on p.operator_id = o.id
  where o.id = p_operator_id
    and o.is_active = true
    and p.pin_hash = crypt(p_pin, p.pin_hash);

  if not found then
    insert into public.pin_attempts(operator_id, device_id, success)
    values (p_operator_id, p_device_id, false);
    return jsonb_build_object('ok', false, 'error', 'Incorrect PIN.');
  end if;

  -- per-operator lockout on this device
  select count(*) into v_failures
  from public.pin_attempts
  where operator_id = v_op.id
    and device_id = p_device_id
    and success = false
    and created_at > now() - interval '15 minutes';
  if v_failures >= 5 then
    return jsonb_build_object(
      'ok', false, 'error', 'Operator locked for 15 minutes.'
    );
  end if;

  -- close any stale session on this device
  update public.data_entry_sessions
     set ended_at = now(), end_reason = 'new_login', is_active = false
   where device_id = p_device_id and is_active = true;

  insert into public.data_entry_sessions(operator_id, device_id)
  values (v_op.id, p_device_id)
  returning id into v_session_id;

  insert into public.pin_attempts(operator_id, device_id, success)
  values (v_op.id, p_device_id, true);

  v_app_role := case
    when lower(v_op.role) like '%manager%' then 'manager'
    when lower(v_op.role) like '%admin%'   then 'admin'
    else 'staff'
  end;

  v_secret := public.jwt_secret();
  if v_secret is null or length(v_secret) < 16 then
    return jsonb_build_object(
      'ok', false,
      'error', 'Server JWT secret is not configured. See SUPABASE_SETUP.md.'
    );
  end if;

  v_token := public.jwt_sign(
    jsonb_build_object(
      'sub', v_op.id,
      'role', 'authenticated',
      'app_role', v_app_role,
      'session_id', v_session_id::text,
      'device_id', p_device_id,
      'iat', extract(epoch from now())::bigint
    ),
    v_secret
  );

  return jsonb_build_object(
    'ok', true,
    'token', v_token,
    'session_id', v_session_id,
    'operator', jsonb_build_object(
      'id', v_op.id,
      'name', v_op.name,
      'role', v_op.role,
      'deviceLabel', coalesce(p_device_label, v_op.device_label),
      'avatarColor', v_op.avatar_color
    )
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- 8. SESSION LIFECYCLE
-- -----------------------------------------------------------------------------
-- Keep the session row fresh so idle sessions can be closed server-side.
create or replace function public.operator_heartbeat()
returns void
language sql
security definer
set search_path = public
as $$
  update public.data_entry_sessions
     set last_seen_at = now()
   where id = public.current_session_id() and is_active = true;
$$;

create or replace function public.operator_signout()
returns void
language sql
security definer
set search_path = public
as $$
  update public.data_entry_sessions
     set ended_at = now(), end_reason = 'logout', is_active = false
   where id = public.current_session_id() and is_active = true;
$$;

-- -----------------------------------------------------------------------------
-- 9. ATOMIC STOCK MOVEMENT
--    Server-side arithmetic + row lock + audit row in ONE transaction.
--    Fixes the lost-update race when 5-6 devices edit the same SKU at once.
-- -----------------------------------------------------------------------------
create or replace function public.apply_stock_movement(
  p_item_id    text,
  p_type       text,
  p_quantity   int,
  p_unit_price numeric default null,
  p_client     text default null,
  p_notes      text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item       public.inventory_items%rowtype;
  v_prev       int;
  v_new        int;
  v_total_in   int;
  v_total_sold int;
  v_op_id      text;
  v_op_name    text;
  v_device     text;
  v_price      numeric;
  v_txn_id     text;
begin
  v_op_id := public.current_operator_id();
  if v_op_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select name into v_op_name from public.operators where id = v_op_id;
  v_device := current_setting('request.jwt.claims', true)::jsonb ->> 'device_id';

  if p_quantity is null or p_quantity < 0 then
    raise exception 'INVALID_QUANTITY';
  end if;

  -- row-level lock: concurrent devices serialise here instead of overwriting
  select * into v_item
  from public.inventory_items
  where id = p_item_id
  for update;

  if not found then
    raise exception 'ITEM_NOT_FOUND';
  end if;

  v_prev := v_item.left_count;

  if p_type = 'in' then
    v_new        := v_prev + p_quantity;
    v_total_in   := v_item.total_in + p_quantity;
    v_total_sold := v_item.total_sold;
  elsif p_type = 'sold' then
    if v_prev < p_quantity then
      raise exception 'INSUFFICIENT_STOCK';
    end if;
    v_new        := v_prev - p_quantity;
    v_total_in   := v_item.total_in;
    v_total_sold := v_item.total_sold + p_quantity;
  elsif p_type = 'correction' then
    -- for corrections p_quantity is the PHYSICAL COUNT, not a delta
    v_new        := p_quantity;
    v_total_in   := v_item.total_in;
    v_total_sold := v_item.total_sold;
  else
    raise exception 'UNSUPPORTED_TYPE';
  end if;

  v_price := coalesce(
    p_unit_price,
    case when p_type = 'in'   then v_item.unit_cost_price
         when p_type = 'sold' then v_item.unit_selling_price
         else 0 end
  );

  update public.inventory_items
     set left_count      = v_new,
         total_in        = v_total_in,
         total_sold      = v_total_sold,
         last_updated    = now(),
         last_updated_by = v_op_name
   where id = p_item_id;

  -- uuid suffix prevents ID collisions across simultaneous devices
  v_txn_id := 'txn_' ||
    extract(epoch from clock_timestamp())::bigint::text || '_' ||
    substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);

  insert into public.inventory_transactions(
    id, item_id, item_name, item_sku, type, quantity,
    previous_left_count, new_left_count, unit_price, total_amount,
    client_or_supplier, notes, operator_name, operator_id,
    device_id, session_id, timestamp
  ) values (
    v_txn_id,
    v_item.id, v_item.name, v_item.sku,
    p_type,
    case when p_type = 'correction' then abs(v_new - v_prev) else p_quantity end,
    v_prev,
    v_new,
    v_price,
    case when p_type = 'correction' then 0 else v_price * p_quantity end,
    p_client,
    coalesce(p_notes,
      case when p_type = 'correction' then 'Physical count adjustment'
           else null end),
    v_op_name, v_op_id, v_device, public.current_session_id(), now()
  );

  return jsonb_build_object(
    'ok', true,
    'item_id', v_item.id,
    'left_count', v_new,
    'total_in', v_total_in,
    'total_sold', v_total_sold,
    'last_updated_by', v_op_name,
    'transaction_id', v_txn_id
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- 10. AUDIT STAMPING
--     Direct inserts into inventory_transactions are allowed for signed-in
--     operators, but caller identity is always taken from the JWT (never from
--     the client payload) so the audit trail cannot be forged.
-- -----------------------------------------------------------------------------
create or replace function public.stamp_transaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.operator_id := public.current_operator_id();
  new.session_id  := public.current_session_id();
  if new.operator_name is null then
    select name into new.operator_name
    from public.operators where id = new.operator_id;
  end if;
  if new.timestamp is null then
    new.timestamp := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_stamp_transaction on public.inventory_transactions;
create trigger trg_stamp_transaction
  before insert on public.inventory_transactions
  for each row execute function public.stamp_transaction();

-- Read-only list of operators for the login screen.
-- SECURITY DEFINER is required here: this runs BEFORE anyone is signed in, so
-- the `operators` RLS policy (which demands a JWT) would otherwise return zero
-- rows and the login screen would be empty.
create or replace function public.list_operators()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', o.id, 'name', o.name, 'role', o.role,
      'deviceLabel', o.device_label, 'avatarColor', o.avatar_color
    ) order by o.name
  ), '[]'::jsonb)
  from public.operators o
  where o.is_active = true;
$$;

-- -----------------------------------------------------------------------------
-- 11. ROW LEVEL SECURITY
-- -----------------------------------------------------------------------------
alter table public.operators              enable row level security;
alter table public.operator_pins          enable row level security;
alter table public.data_entry_sessions    enable row level security;
alter table public.inventory_items        enable row level security;
alter table public.inventory_transactions enable row level security;
alter table public.pin_attempts           enable row level security;

-- operators: readable by any signed-in operator, never writable by the app
drop policy if exists operators_select on public.operators;
create policy operators_select on public.operators
  for select using (public.current_operator_id() is not null);

-- PIN hashes are never exposed to clients
drop policy if exists pins_none on public.operator_pins;
create policy pins_none on public.operator_pins for select using (false);

-- sessions: read/update only your own
drop policy if exists sessions_select_own on public.data_entry_sessions;
create policy sessions_select_own on public.data_entry_sessions
  for select using (operator_id = public.current_operator_id());

drop policy if exists sessions_update_own on public.data_entry_sessions;
create policy sessions_update_own on public.data_entry_sessions
  for update using (operator_id = public.current_operator_id());

-- shared company stock: all authenticated operators read and edit
drop policy if exists items_select_auth on public.inventory_items;
create policy items_select_auth on public.inventory_items
  for select using (public.current_operator_id() is not null);

drop policy if exists items_write_auth on public.inventory_items;
create policy items_write_auth on public.inventory_items
  for all using (public.current_operator_id() is not null)
       with check (public.current_operator_id() is not null);

-- transactions: readable by staff, append-only, stamped with the caller's id
drop policy if exists txns_select_auth on public.inventory_transactions;
create policy txns_select_auth on public.inventory_transactions
  for select using (public.current_operator_id() is not null);

drop policy if exists txns_insert_own on public.inventory_transactions;
create policy txns_insert_own on public.inventory_transactions
  for insert with check (public.current_operator_id() is not null);

-- history cannot be rewritten or deleted by clients
drop policy if exists txns_no_update on public.inventory_transactions;
create policy txns_no_update on public.inventory_transactions
  for update using (false);

drop policy if exists txns_no_delete on public.inventory_transactions;
create policy txns_no_delete on public.inventory_transactions
  for delete using (false);

-- failed-login log stays server-side
drop policy if exists attempts_none on public.pin_attempts;
create policy attempts_none on public.pin_attempts for select using (false);

-- -----------------------------------------------------------------------------
-- 12. REALTIME  (keeps 5-6 devices in sync live)
-- -----------------------------------------------------------------------------
do $$
begin
  begin
    alter publication supabase_realtime add table public.inventory_items;
  exception when duplicate_object then null; end;
  begin
    alter publication supabase_realtime add table public.inventory_transactions;
  exception when duplicate_object then null; end;
  begin
    alter publication supabase_realtime add table public.data_entry_sessions;
  exception when duplicate_object then null; end;
end $$;

-- -----------------------------------------------------------------------------
-- 13. GRANTS
--     `anon` is the role the mobile app connects as. It may call the login
--     and listing functions; every other path is gated by RLS / RPC.
-- -----------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;

grant execute on function public.operator_authenticate(text, text, text, text) to anon, authenticated;
grant execute on function public.list_operators() to anon, authenticated;
grant execute on function public.operator_heartbeat() to authenticated;
grant execute on function public.operator_signout() to authenticated;
grant execute on function public.apply_stock_movement(text, text, int, numeric, text, text)
  to authenticated;

grant select, insert, update on public.inventory_items to authenticated;
grant select on public.operators to authenticated;
grant select on public.data_entry_sessions to authenticated;

-- Audit history is append-only: clients may insert their own rows but can
-- never rewrite or remove what is already recorded.
grant insert, select on public.inventory_transactions to authenticated;
revoke update, delete on public.inventory_transactions from anon, authenticated;

-- PIN hashes are write-only from the database admin's point of view.
revoke select, insert, update, delete on public.operator_pins from anon, authenticated;





