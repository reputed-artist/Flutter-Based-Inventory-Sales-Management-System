-- =============================================================================
--  DIAGNOSTIC - run in the Supabase SQL Editor. Read-only, changes nothing.
--  Paste the output back to me to confirm exactly what is missing.
-- =============================================================================

-- 1. Which tables exist?
select 'TABLE: ' || table_name as object
from information_schema.tables
where table_schema = 'public'
  and table_name in ('operators','operator_pins','data_entry_sessions',
                     'inventory_items','inventory_transactions','pin_attempts')
order by 1;

-- 2. Which functions exist? (This is the one that is failing: list_operators)
select 'FUNCTION: ' || p.proname || '(' ||
       pg_get_function_arguments(p.oid) || ') -> ' ||
       pg_get_function_result(p.oid) as object
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by 1;

-- 3. How many operators are seeded?
do $$ declare n bigint; begin
  select count(*) into n from public.operators;
  raise notice 'OPERATOR_COUNT: %', n;
exception when others then raise notice 'OPERATOR_COUNT: table missing (%)', sqlerrm; end $$;

-- 4. How many catalog items are seeded?
do $$ declare n bigint; begin
  select count(*) into n from public.inventory_items;
  raise notice 'ITEM_COUNT: %', n;
exception when others then raise notice 'ITEM_COUNT: table missing (%)', sqlerrm; end $$;

-- 5. Is pgcrypto present? (needed by operator_pins bcrypt hashes)
select 'EXTENSION pgcrypto: ' ||
       coalesce((select extversion from pg_extension where extname = 'pgcrypto'),
                'MISSING') as object;

-- 6. Is the JWT secret stored in Vault? (needed for PIN login to mint tokens)
--    The name must be exactly 'app_jwt_secret' - that is what jwt_secret()
--    in 001_init.sql looks up.
do $$
declare v_found text;
begin
  select name into v_found from vault.decrypted_secrets
  where name = 'app_jwt_secret' limit 1;
  raise notice 'VAULT app_jwt_secret: %',
    case when v_found is null then 'MISSING - login will fail' else 'PRESENT' end;
exception when others then
  raise notice 'VAULT app_jwt_secret: cannot read vault (%)', sqlerrm;
end $$;
