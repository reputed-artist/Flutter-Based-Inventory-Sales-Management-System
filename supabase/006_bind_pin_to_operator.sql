-- =============================================================================
--  FIX - a PIN signed the device in as ANY operator, not the one that was
--        selected on the login screen
--
--  SYMPTOM
--  The PIN screen lists the roster ("tap your name"), then asks for that
--  operator's PIN. In practice ANY seeded PIN (1111..6666) signed the device in
--  as whichever operator owned that PIN - the name that was tapped was never
--  checked, so the "select your name" step was purely cosmetic.
--
--  ROOT CAUSE
--  operator_authenticate() took no operator parameter and matched the entered
--  PIN against the WHOLE active roster:
--
--      join public.operator_pins p on p.operator_id = o.id
--      where o.is_active = true
--        and p.pin_hash = crypt(p_pin, p.pin_hash);
--
--  Identity was therefore decided by the PIN alone: one operator's PIN signed
--  you in as that operator even when a different name had been tapped.
--
--  FIX
--  operator_authenticate() now takes the selected operator's id and requires
--  the PIN to belong to that exact operator. The Flutter app now sends
--  p_operator_id, so apply this file together with the matching app build.
--
--  Safe to re-run: it drops the old 3-argument function first, then re-creates
--  and re-grants the operator-bound one.
-- =============================================================================

-- Remove the old signature so the new one cannot be resolved ambiguously.
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

  -- the PIN must belong to THE operator that was selected on the login screen
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

-- `anon` is the role the mobile app connects as before anyone is signed in.
grant execute on function public.operator_authenticate(text, text, text, text)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Verify after running this file (read-only):
--
--   select pg_get_function_arguments(p.oid) as args
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname = 'public' and p.proname = 'operator_authenticate';
--
--   -- must show the 4-argument, operator-bound version:
--   --   p_operator_id text, p_pin text, p_device_id text, p_device_label text
--
-- Then sign out and back in on the device: a PIN that belongs to a different
-- operator must now be refused with "Incorrect PIN."
-- ---------------------------------------------------------------------------