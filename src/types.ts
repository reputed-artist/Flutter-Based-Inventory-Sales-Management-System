export type InventoryCategory =
  | 'hp_cartridges'
  | 'handy_printer'
  | 'online_printer'
  | 'docod_printer'
  | 'rynan_cartridges'
  | 'machines'
  | 'accessories_spare';

export interface CategoryMeta {
  id: InventoryCategory;
  name: string;
  icon: string;
  color: string;
  description: string;
}

export interface InventoryItem {
  id: string;
  sku: string;
  name: string;
  category: InventoryCategory;
  description?: string;
  unit: string; // 'pcs', 'cartridges', 'units', 'sets', 'boxes'
  totalIn: number; // Cumulative total stock received / entered
  totalSold: number; // Cumulative total units sold / dispatched
  leftCount: number; // Current verified available stock
  minStockAlert: number; // Minimum reorder threshold
  unitCostPrice: number; // Cost price per unit
  unitSellingPrice: number; // Selling price per unit
  location?: string; // Warehouse rack or storage location
  barcode?: string;
  lastUpdated: string; // ISO timestamp
  lastUpdatedBy: string; // Operator name
  createdDate: string;
}

export type TransactionType = 'STOCK_IN' | 'SOLD' | 'COUNT_UPDATE' | 'ITEM_CREATED' | 'ITEM_UPDATED';

export interface Transaction {
  id: string;
  itemId: string;
  itemSku: string;
  itemName: string;
  category: InventoryCategory;
  type: TransactionType;
  quantityChange: number; // Positive for Stock In, negative for Sold, delta for Count Update
  previousLeftCount: number;
  newLeftCount: number;
  unitPrice?: number; // Sale price or cost price
  totalAmount?: number; // quantity * unitPrice
  customerOrSupplier?: string; // Customer name (if sold) or Supplier/PO (if stock in)
  referenceNo?: string; // Invoice #, PO #, Waybill #
  notes?: string;
  operatorName: string;
  timestamp: string; // ISO timestamp
  deviceId?: string;
}

export interface OperatorUser {
  id: string;
  name: string;
  role: 'Admin' | 'Warehouse Operator' | 'Sales Executive' | 'Technician';
  avatarColor: string;
  deviceId?: string;
}

export interface SupabaseConfig {
  url: string;
  anonKey: string;
  isConnected: boolean;
  isConnecting: boolean;
  lastSyncTime?: string;
  error?: string | null;
}

export type ActiveTab = 'inventory' | 'actions' | 'reports' | 'activity' | 'settings';

export interface ReportFilter {
  dateRange: 'all' | 'today' | 'yesterday' | 'week' | 'month' | 'custom';
  startDate?: string;
  endDate?: string;
  category: 'all' | InventoryCategory;
  operator: 'all' | string;
  searchQuery?: string;
}
