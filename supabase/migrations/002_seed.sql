-- =============================================================================
--  SEED DATA - run AFTER 001_init.sql
--  CHANGE THE PINs BEFORE GOING LIVE. Bcrypt hashes below are for the PINs
--  written in the comment on each line.
-- =============================================================================

-- Make sure pgcrypto (crypt / gen_salt) resolves whether it lives in `public`
-- or in Supabase's `extensions` schema.
set search_path = public, extensions;

insert into public.operators (id, name, role, device_label, avatar_color)
values
  ('user_1', 'Rajesh Sharma', 'Warehouse Manager', 'Galaxy Tab A9 (Main Floor)',  '#0284c7'),
  ('user_2', 'Amit Patel',    'Dispatch & Sales',  'Pixel 7 (Dispatch Desk)',   '#10b981'),
  ('user_3', 'Sunil Verma',   'Field Technician',  'OnePlus 11 (Site Mobile)',  '#f59e0b'),
  ('user_4', 'Priya Nair',    'Accounts',          'Galaxy Tab A9 (Accounts)', '#a855f7'),
  ('user_5', 'Imran Sheikh',  'Dispatch & Sales',  'Redmi Note 13 (Dispatch)',  '#ef4444'),
  ('user_6', 'Kavya Rao',     'Field Technician',  'Galaxy A54 (Site Mobile)', '#ec4899')
on conflict (id) do update set
  name         = excluded.name,
  role         = excluded.role,
  device_label = excluded.device_label,
  avatar_color = excluded.avatar_color;

-- PINs: user_1=1111  user_2=2222  user_3=3333
--       user_4=4444  user_5=5555  user_6=6666
-- *** CHANGE THESE before real warehouse use. ***
insert into public.operator_pins (operator_id, pin_hash)
values
  ('user_1', crypt('1111', gen_salt('bf', 10))),
  ('user_2', crypt('2222', gen_salt('bf', 10))),
  ('user_3', crypt('3333', gen_salt('bf', 10))),
  ('user_4', crypt('4444', gen_salt('bf', 10))),
  ('user_5', crypt('5555', gen_salt('bf', 10))),
  ('user_6', crypt('6666', gen_salt('bf', 10)))
on conflict (operator_id) do update
  set pin_hash = excluded.pin_hash, updated_at = now();

-- -----------------------------------------------------------------------------
-- CATALOG  (mirrors lib/data/initial_data.dart so the app has data on day one)
-- -----------------------------------------------------------------------------
insert into public.inventory_items
  (id, sku, name, category, unit, description, total_in, total_sold, left_count,
   min_stock_alert, unit_cost_price, unit_selling_price, location, barcode, last_updated_by)
values
  ('item_hp_2580', 'HP-B3F58B', 'HP 2580 Black Solvent Cartridge', 'hp_cartridges', 'Cartridge',
   'Original HP solvent ink cartridge for non-porous surfaces (foil, blister, metal).',
   120, 78, 42, 15, 3200, 4500, 'Rack A-1 (Inks)', '884962829101', 'Rajesh Sharma'),

  ('item_hp_2590', 'HP-WS2829', 'HP 2590 Fast-Dry Solvent Black', 'hp_cartridges', 'Cartridge',
   'Specialty quick-dry cartridge for high-speed pharmaceutical PVC printing.',
   80, 65, 15, 10, 3600, 5100, 'Rack A-2 (Inks)', '884962829102', 'Amit Patel'),

  ('item_hp_45si', 'HP-45SI-AQ', 'HP 45si Aqueous Black Ink Cartridge', 'hp_cartridges', 'Cartridge',
   'Water-based ink for corrugated cartons and porous carton boxes.',
   60, 42, 18, 8, 2400, 3400, 'Rack A-3 (Inks)', '884962829103', 'Sunil Verma'),

  ('item_hp_handy_127', 'HND-TIJ-127', 'Handy TIJ 12.7mm Mobile Batch Coder', 'handy_printer', 'Kit',
   'Handheld battery operated thermal inkjet coder with 4.3" touch display and positioning plate.',
   25, 18, 7, 4, 14500, 22000, 'Shelf B-1 (Printers)', '884962829201', 'Rajesh Sharma'),

  ('item_hp_handy_254', 'HND-TIJ-254', 'Handy 25.4mm Wide-Format Portable Coder', 'handy_printer', 'Kit',
   '1-inch large character portable coder for sacks, drums and heavy cartons.',
   18, 11, 7, 3, 21000, 31500, 'Shelf B-2 (Printers)', '884962829202', 'Sunil Verma'),

  ('item_rg_2000', 'RYN-RG-2000', 'Rynan SoluMark 2000 Online Coding System', 'online_printer', 'System',
   'Continuous industrial inkjet coder with 4 printheads for cartons and pouches.',
   12, 7, 5, 2, 68000, 95000, 'Machine Floor M-1', '884962829301', 'Rajesh Sharma'),

  ('item_docod_350', 'DOC-DP350', 'Docod DirectMark 350 Thermal Printer', 'docod_printer', 'Unit',
   'Direct thermal desktop printer for shipping labels and compliance marking.',
   20, 14, 6, 4, 8500, 12900, 'Shelf C-1 (Printers)', '884962829401', 'Amit Patel'),

  ('item_rynan_solv_bk', 'RYN-SOL-BK90', 'Rynan SoluMark BK90 Fast Dry Cartridge', 'rynan_cartridges', 'Cartridge',
   'Fast-dry solvent ink cartridge for non-porous film and aluminium packaging.',
   60, 26, 34, 12, 3100, 4400, 'Rack A-5 (Inks)', '884962829501', 'Rajesh Sharma'),

  ('item_rynan_wtr_blk', 'RYN-WTR-BLK', 'Rynan AquaBlack Water-Based Cartridge', 'rynan_cartridges', 'Cartridge',
   'Water-based dye ink cartridge for corrugated and paperboard substrates.',
   45, 30, 15, 10, 2200, 3200, 'Rack A-6 (Inks)', '884962829502', 'Amit Patel'),

  ('item_mach_conveyor', 'MCH-CNV-15M', 'Anti-Static Conveyor Belt 1.5m', 'packaging_machines', 'Machine',
   'Variable speed anti-static conveyor belt with custom brackets for online TIJ printers.',
   10, 6, 4, 2, 28000, 42000, 'Machine Floor M-1', '884962829601', 'Rajesh Sharma'),

  ('item_mach_band_sealer', 'MCH-BND-FR900', 'Continuous Nitrogen Flush Band Sealer', 'packaging_machines', 'Machine',
   'Heavy duty horizontal pouch sealing machine with built-in solid ink coder.',
   8, 5, 3, 2, 38000, 56000, 'Machine Floor M-2', '884962829602', 'Amit Patel')
on conflict (id) do nothing;
