# Ink & Machine Inventory Sync (Flutter Android App)

A real-time, multi-device mobile inventory management application built in **Flutter (Dart)** for Android devices (smartphones, barcode scanners, and warehouse tablets).

## Supported Inventory Categories
- **HP Cartridges** (HP 2580 Solvent, HP 2590 Fast-Dry, HP 45si Aqueous, etc.)
- **Handy Printers** (TIJ 12.7mm portable coders, 25.4mm wide format)
- **Online Printers** (Dual-head conveyor batch coders, CIJ machines)
- **Docod Printers** (Docod S100 TIJ, Docod T200 continuous inkjet)
- **Rynan Cartridges** (SoluMark BK90, high-contrast white solvent)
- **Packaging Machines** (Motorized conveyors, continuous band sealers)

## Core Features
1. **Multi-Device Realtime Synchronization via Supabase**:
   - Every **Stock In (+)**, **Sold Out (-)**, and **Physical Count Correction** triggers instant websocket updates across all connected Android devices.
   - Built-in table schema generator and real-time subscription channels.
2. **Offline Fallback & Instant Local Persistence**:
   - Functions offline if network drops, syncing transactions automatically when reconnected.
3. **Multi-Operator Profiles & Audit Watermarking**:
   - Easily switch operators (e.g., Rajesh Sharma, Amit Patel, Sunil Verma).
   - Every transaction records the operator name, device name, and exact timestamp.
4. **Barcode & SKU Scanner**:
   - Integrated camera scanning with fallback quick-search.
5. **Comprehensive Sales & Stock Reports**:
   - Real-time valuation of stock assets.
   - Total sales revenue and unit dispatch counts.
   - Category-wise breakdown and top 5 dispatched SKUs.
   - CSV export capability.

## How to Build & Run on Android

### Prerequisites
- Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.0.0 or higher)
- Install [Android Studio](https://developer.android.com/studio) with Android SDK and USB debugging enabled.

### Quick Start Commands
```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run directly on connected Android device or emulator
flutter run

# 3. Build release APK for Android
flutter build apk --release
# Generated APK will be in: build/app/outputs/flutter-apk/app-release.apk

# 4. Build Android App Bundle (for Google Play Store)
flutter build appbundle --release
```

## Supabase Realtime Setup
Run the following in your Supabase SQL Editor:
```sql
create table if not exists inventory_items (
  id text primary key,
  sku text not null,
  name text not null,
  category text not null,
  unit text not null,
  description text,
  total_in int default 0,
  total_sold int default 0,
  left_count int default 0,
  min_stock_alert int default 5,
  unit_cost_price numeric default 0,
  unit_selling_price numeric default 0,
  location text,
  barcode text,
  last_updated timestamptz default now(),
  last_updated_by text
);

create table if not exists inventory_transactions (
  id text primary key,
  item_id text not null,
  item_name text not null,
  item_sku text not null,
  type text not null,
  quantity int not null,
  previous_left_count int not null,
  new_left_count int not null,
  unit_price numeric,
  total_amount numeric,
  client_or_supplier text,
  notes text,
  operator_name text,
  device_id text,
  timestamp timestamptz default now()
);

alter publication supabase_realtime add table inventory_items;
alter publication supabase_realtime add table inventory_transactions;
```
