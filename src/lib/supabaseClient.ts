import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { InventoryItem, Transaction } from '../types';

const STORAGE_KEY_URL = 'inv_supabase_url';
const STORAGE_KEY_KEY = 'inv_supabase_key';

export function getStoredSupabaseCredentials(): { url: string; anonKey: string } {
  const envUrl = (import.meta as unknown as { env?: Record<string, string> }).env?.VITE_SUPABASE_URL || '';
  const envKey = (import.meta as unknown as { env?: Record<string, string> }).env?.VITE_SUPABASE_ANON_KEY || '';

  const storedUrl = localStorage.getItem(STORAGE_KEY_URL) || envUrl;
  const storedKey = localStorage.getItem(STORAGE_KEY_KEY) || envKey;

  return {
    url: storedUrl.trim(),
    anonKey: storedKey.trim(),
  };
}

export function saveStoredSupabaseCredentials(url: string, anonKey: string) {
  localStorage.setItem(STORAGE_KEY_URL, url.trim());
  localStorage.setItem(STORAGE_KEY_KEY, anonKey.trim());
}

export function clearStoredSupabaseCredentials() {
  localStorage.removeItem(STORAGE_KEY_URL);
  localStorage.removeItem(STORAGE_KEY_KEY);
}

let cachedClient: SupabaseClient | null = null;
let currentConfigKey = '';

export function getSupabaseClient(customUrl?: string, customKey?: string): SupabaseClient | null {
  const creds = (customUrl && customKey)
    ? { url: customUrl, anonKey: customKey }
    : getStoredSupabaseCredentials();

  if (!creds.url || !creds.anonKey) {
    return null;
  }

  const configKey = `${creds.url}___${creds.anonKey}`;
  if (cachedClient && currentConfigKey === configKey) {
    return cachedClient;
  }

  try {
    cachedClient = createClient(creds.url, creds.anonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
      },
      realtime: {
        params: {
          eventsPerSecond: 10,
        },
      },
    });
    currentConfigKey = configKey;
    return cachedClient;
  } catch (err) {
    console.error('Failed to create Supabase client:', err);
    return null;
  }
}

export async function testSupabaseConnection(url: string, anonKey: string): Promise<{ success: boolean; message: string }> {
  try {
    const tempClient = createClient(url.trim(), anonKey.trim(), {
      auth: { persistSession: false },
    });

    // Try a lightweight query
    const { error } = await tempClient.from('inventory_items').select('id').limit(1);

    if (error) {
      // If table does not exist, credentials are valid but table is missing
      if (error.code === '42P01' || error.message.includes('relation "inventory_items" does not exist')) {
        return {
          success: true,
          message: 'Connected to Supabase! (Note: Tables are not created yet. Please run the SQL setup script).',
        };
      }
      // If RLS blocked without permissions or invalid key
      if (error.message.includes('Invalid API key') || error.code === 'PGRST301') {
        return { success: false, message: 'Invalid Supabase Anon Key or Project URL.' };
      }
      return { success: true, message: `Connected! Note: ${error.message}` };
    }

    return { success: true, message: 'Successfully connected and verified Supabase inventory tables!' };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    return { success: false, message: `Connection failed: ${msg}` };
  }
}

export const SUPABASE_SQL_SETUP_SCRIPT = `-- SUPABASE REALTIME INVENTORY & SALES MANAGEMENT SCHEMA
-- Run this in your Supabase Project -> SQL Editor to initialize tables and Realtime

-- 1. Create inventory_items table
CREATE TABLE IF NOT EXISTS inventory_items (
  id TEXT PRIMARY KEY,
  sku TEXT NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  description TEXT,
  unit TEXT DEFAULT 'pcs',
  total_in NUMERIC DEFAULT 0,
  total_sold NUMERIC DEFAULT 0,
  left_count NUMERIC DEFAULT 0,
  min_stock_alert NUMERIC DEFAULT 5,
  unit_cost_price NUMERIC DEFAULT 0,
  unit_selling_price NUMERIC DEFAULT 0,
  location TEXT,
  barcode TEXT,
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  last_updated_by TEXT DEFAULT 'Operator',
  created_date TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create inventory_transactions table for sales, stock ins, and count audits
CREATE TABLE IF NOT EXISTS inventory_transactions (
  id TEXT PRIMARY KEY,
  item_id TEXT REFERENCES inventory_items(id) ON DELETE CASCADE,
  item_sku TEXT NOT NULL,
  item_name TEXT NOT NULL,
  category TEXT NOT NULL,
  type TEXT NOT NULL, -- 'STOCK_IN', 'SOLD', 'COUNT_UPDATE', 'ITEM_CREATED'
  quantity_change NUMERIC NOT NULL,
  previous_left_count NUMERIC NOT NULL,
  new_left_count NUMERIC NOT NULL,
  unit_price NUMERIC,
  total_amount NUMERIC,
  customer_or_supplier TEXT,
  reference_no TEXT,
  notes TEXT,
  operator_name TEXT NOT NULL,
  device_id TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Enable Row Level Security (RLS) with open policies for multi-device warehouse sync
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read on inventory_items" 
  ON inventory_items FOR SELECT USING (true);
CREATE POLICY "Allow public insert/update on inventory_items" 
  ON inventory_items FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Allow public read on inventory_transactions" 
  ON inventory_transactions FOR SELECT USING (true);
CREATE POLICY "Allow public insert on inventory_transactions" 
  ON inventory_transactions FOR ALL USING (true) WITH CHECK (true);

-- 4. Enable Realtime Publications for instant multi-user synchronization across all devices
ALTER PUBLICATION supabase_realtime ADD TABLE inventory_items;
ALTER PUBLICATION supabase_realtime ADD TABLE inventory_transactions;
`;
