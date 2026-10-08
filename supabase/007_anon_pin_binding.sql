-- ============================================================================
-- 007_anon_pin_binding.sql - PIN login on ES256 (JWT Signing Keys) projects
-- WHY: operator_authenticate() mints HS256, but this project verifies ES256,
-- so PostgREST answers 401 PGRST301 "No suitable key or wrong key type".
-- FIX: app signs in ANONYMOUSLY (real ES256 session from GoTrue), then calls
-- operator_bind_session() which verifies the PIN and binds auth.uid() to the
-- operator. current_*() resolve through that binding. PIN UX is unchanged.
-- PREREQ: Dashboard -> Authentication -> Sign In/Up -> Allow anonymous ON.
-- Run ONCE in SQL Editor. Safe to re-run. Requires 001 + 002 applied.
-- ============================================================================

-- 1. Binding: which Supabase auth user operates as which operator ------------
create table if not exists public.operator_auth_bindings (
  auth_uid    uuid primary key,
  operator_id text not null references public.operators(id) on delete cascade,
  device_id   text,
  session_id  uuid references public.data_entry_sessions(id) on delete set null,
  created_at  timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index if not exists operator_auth_bindings_operator_idx
  on public.operator_auth_bindings (operator_id);

-- Clients never touch the binding table directly: only the SECURITY DEFINER
-- functions below read/write it, so RLS is enabled with no policies and all
-- grants are revoked at the bottom of this file (defence in depth).
alter table public.operator_auth_bindings enable row level security;

-- 2. Identity: binding first, legacy self-minted JWT validated --------------
create or replace function public.current_operator_id()
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid    uuid;
  v_op     text;
  v_legacy text;
begin
  begin
    v_uid := auth.uid();
  exception when others then
    v_uid := null;
  end;

  if v_uid is not null then
    select operator_id into v_op
    from public.operator_auth_bindings
    where auth_uid = v_uid;
    if v_op is not null then
      return v_op;
    end if;
  end if;

  -- Fallback ONLY for legacy self-minted HS256 tokens: the 'sub' claim is
  -- honoured when - and only when - it names a real active operator. An
  -- anonymous GoTrue user's UUID can therefore never be mistaken for an
  -- operator id before a PIN binding exists.
  begin
    v_legacy := nullif(
      current_setting('request.jwt.claims', true)::jsonb ->> 'sub', ''
    );
  exception when others then
    v_legacy := null;
  end;

  if v_legacy is not null then
    select id into v_op
    from public.operators
    where id = v_legacy and is_active = true;
    if v_op is not null then
      return v_op;
    end if;
  end if;

  return null;
end;
$$;

create or replace function public.current_session_id()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_sid uuid;
begin
  begin
    v_uid := auth.uid();
  exception when others then
    v_uid := null;
  end;
  if v_uid is not null then
    select session_id into v_sid
    from public.operator_auth_bindings
    where auth_uid = v_uid;
    if v_sid is not null then
      return v_sid;
    end if;
  end if;
  begin
    return nullif(
      (current_setting('request.jwt.claims', true)::jsonb ->> 'session_id'), ''
    )::uuid;
  exception when others then
    return null;
  end;
end;
$$;
-- 3. whoami: validate a resumed SDK session --------------------------------
create or replace function public.operator_whoami()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_op_id text;
  v_op    record;
begin
  v_op_id := public.current_operator_id();
  if v_op_id is null then
    return jsonb_build_object('ok', false);
  end if;
  select id, name, role, device_label, avatar_color
    into v_op
  from public.operators
  where id = v_op_id and is_active = true;
  if not found then
    return jsonb_build_object('ok', false);
  end if;
  return jsonb_build_object(
    'ok', true,
    'operator', jsonb_build_object(
      'id', v_op.id,
      'name', v_op.name,
      'role', v_op.role,
      'deviceLabel', v_op.device_label,
      'avatarColor', v_op.avatar_color
    )
  );
end;
$$;

-- 4. PIN login WITHOUT minting any token (no 'token' field in the reply) ----
-- The old HS256-minting RPC is retired: applying this file removes it (and
-- its grants) so the app has only operator_bind_session() to log in with.
drop function if exists public.operator_authenticate(text, text, text);
drop function if exists public.operator_authenticate(text, text, text, text);

create or replace function public.operator_bind_session(
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
  v_uid        uuid;
  v_op         record;
  v_failures   int;
  v_session_id uuid;
begin
  begin
    v_uid := auth.uid();
  exception when others then
    v_uid := null;
  end;
  if v_uid is null then
    return jsonb_build_object(
      'ok', false,
      'error', 'Not signed in. Enable anonymous sign-ins and update the app.'
    );
  end if;
  if p_operator_id is null or length(btrim(p_operator_id)) = 0 then
    return jsonb_build_object('ok', false, 'error', 'No operator selected.');
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{4}$' then
    return jsonb_build_object('ok', false, 'error', 'PIN must be 4 digits.');
  end if;
  select count(*) into v_failures
  from public.pin_attempts
  where device_id = p_device_id
    and success = false
    and created_at > now() - interval '15 minutes';
  if v_failures >= 5 then
    return jsonb_build_object(
      'ok', false, 'error', 'Too many failed attempts. Locked 15 minutes.'
    );
  end if;
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
  update public.data_entry_sessions
     set ended_at = now(), end_reason = 'new_login', is_active = false
   where device_id = p_device_id and is_active = true;
  insert into public.data_entry_sessions(operator_id, device_id)
  values (v_op.id, p_device_id)
  returning id into v_session_id;
  insert into public.pin_attempts(operator_id, device_id, success)
  values (v_op.id, p_device_id, true);
  insert into public.operator_auth_bindings(auth_uid, operator_id, device_id, session_id)
  values (v_uid, v_op.id, p_device_id, v_session_id)
  on conflict (auth_uid) do update
    set operator_id  = excluded.operator_id,
        device_id    = excluded.device_id,
        session_id   = excluded.session_id,
        last_seen_at = now();
  return jsonb_build_object(
    'ok', true,
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

-- 5. Session lifecycle follows the binding -----------------------------------
create or replace function public.operator_heartbeat()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sid uuid;
begin
  v_sid := public.current_session_id();
  if v_sid is null then
    return;
  end if;
  update public.data_entry_sessions
     set last_seen_at = now()
   where id = v_sid and is_active = true;
  update public.operator_auth_bindings
     set last_seen_at = now()
   where session_id = v_sid;
end;
$$;

create or replace function public.operator_signout()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_sid uuid;
begin
  begin
    v_uid := auth.uid();
  exception when others then
    v_uid := null;
  end;
  v_sid := public.current_session_id();
  if v_sid is not null then
    update public.data_entry_sessions
       set ended_at = now(), end_reason = 'logout', is_active = false
     where id = v_sid and is_active = true;
  end if;
  if v_uid is not null then
    delete from public.operator_auth_bindings where auth_uid = v_uid;
  end if;
end;
$$;

-- 6. apply_stock_movement: device comes from the session row ---------------
-- (the old body read device_id from the self-minted JWT, which is gone)
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
  v_session_id uuid;
begin
  v_op_id := public.current_operator_id();
  if v_op_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  select name into v_op_name from public.operators where id = v_op_id;
  v_session_id := public.current_session_id();
  if v_session_id is not null then
    select device_id into v_device
    from public.data_entry_sessions
    where id = v_session_id;
  end if;
  if p_quantity is null or p_quantity < 0 then
    raise exception 'INVALID_QUANTITY';
  end if;
  select * into v_item
  from public.inventory_items
  where id = p_item_id
  for update;
  if not found then
    raise exception 'ITEM_NOT_FOUND';
  end if;
  v_prev := v_item.left_count;
  if p_type = 'in' then
    v_new := v_prev + p_quantity;
    v_total_in := v_item.total_in + p_quantity;
    v_total_sold := v_item.total_sold;
  elsif p_type = 'sold' then
    if v_prev < p_quantity then
      raise exception 'INSUFFICIENT_STOCK';
    end if;
    v_new := v_prev - p_quantity;
    v_total_in := v_item.total_in;
    v_total_sold := v_item.total_sold + p_quantity;
  elsif p_type = 'correction' then
    v_new := p_quantity;
    v_total_in := v_item.total_in;
    v_total_sold := v_item.total_sold;
  else
    raise exception 'UNSUPPORTED_TYPE';
  end if;
  v_price := coalesce(
    p_unit_price,
    case when p_type = 'in' then v_item.unit_cost_price
         when p_type = 'sold' then v_item.unit_selling_price
         else 0 end
  );
  update public.inventory_items
     set left_count = v_new,
         total_in = v_total_in,
         total_sold = v_total_sold,
         last_updated = now(),
         last_updated_by = v_op_name
   where id = p_item_id;
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
    v_item.id, v_item.name, v_item.sku, p_type, p_quantity,
    v_prev, v_new, v_price, v_price * p_quantity,
    p_client, p_notes, v_op_name, v_op_id,
    v_device, v_session_id, now()
  );
  return jsonb_build_object(
    'ok', true,
    'item_id', v_item.id,
    'left_count', v_new,
    'total_in', v_total_in,
    'total_sold', v_total_sold,
    'last_updated_by', v_op_name,
    'txn_id', v_txn_id
  );
end;
$$;

-- 7. Grants: anon before PIN, authenticated (anon session) after ------------
grant usage on schema public to anon, authenticated;
grant execute on function public.operator_bind_session(text, text, text, text) to authenticated;
grant execute on function public.operator_whoami() to anon, authenticated;
grant execute on function public.operator_heartbeat() to authenticated;
grant execute on function public.operator_signout() to authenticated;
grant execute on function public.list_operators() to anon, authenticated;
grant execute on function public.apply_stock_movement(text, text, int, numeric, text, text)
  to authenticated;
grant select, insert, update on public.inventory_items to authenticated;
grant select on public.operators to authenticated;
grant select on public.data_entry_sessions to authenticated;
grant insert, select on public.inventory_transactions to authenticated;
revoke update, delete on public.inventory_transactions from anon, authenticated;
revoke select, insert, update, delete on public.operator_pins from anon, authenticated;
revoke select, insert, update, delete on public.operator_auth_bindings from anon, authenticated;

