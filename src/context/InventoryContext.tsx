import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import {
  ActiveTab,
  InventoryCategory,
  InventoryItem,
  OperatorUser,
  SupabaseConfig,
  Transaction,
} from '../types';
import {
  INITIAL_INVENTORY_ITEMS,
  INITIAL_OPERATORS,
  INITIAL_TRANSACTIONS,
} from '../data/initialData';
import {
  getStoredSupabaseCredentials,
  getSupabaseClient,
  saveStoredSupabaseCredentials,
} from '../lib/supabaseClient';
import { sound } from '../lib/sound';

interface InventoryContextType {
  items: InventoryItem[];
  transactions: Transaction[];
  operators: OperatorUser[];
  currentOperator: OperatorUser;
  selectedCategory: 'all' | InventoryCategory;
  searchQuery: string;
  activeTab: ActiveTab;
  syncStatus: 'synced' | 'syncing' | 'offline' | 'error' | 'local_mesh';
  lastSyncTime: string;
  supabaseConfig: SupabaseConfig;
  isMobileFrame: boolean;

  // Modals
  quickActionModalOpen: boolean;
  quickActionMode: 'STOCK_IN' | 'SOLD' | 'COUNT_UPDATE' | 'NEW_ITEM';
  selectedItemForAction: InventoryItem | null;
  detailModalItem: InventoryItem | null;
  scannerModalOpen: boolean;
  userSwitcherModalOpen: boolean;
  supabaseSettingsModalOpen: boolean;
  flutterCodeModalOpen: boolean;

  // Setters
  setSelectedCategory: (cat: 'all' | InventoryCategory) => void;
  setSearchQuery: (query: string) => void;
  setActiveTab: (tab: ActiveTab) => void;
  setIsMobileFrame: (val: boolean | ((prev: boolean) => boolean)) => void;
  setCurrentOperator: (op: OperatorUser) => void;
  addOperator: (name: string, role: OperatorUser['role']) => OperatorUser;

  // Modal controls
  openQuickAction: (mode: 'STOCK_IN' | 'SOLD' | 'COUNT_UPDATE' | 'NEW_ITEM', item?: InventoryItem) => void;
  closeQuickAction: () => void;
  setDetailModalItem: (item: InventoryItem | null) => void;
  setScannerModalOpen: (open: boolean) => void;
  setUserSwitcherModalOpen: (open: boolean) => void;
  setSupabaseSettingsModalOpen: (open: boolean) => void;
  setFlutterCodeModalOpen: (open: boolean) => void;

  // Inventory actions
  recordStockIn: (params: {
    itemId: string;
    quantity: number;
    unitCostPrice?: number;
    supplier?: string;
    referenceNo?: string;
    notes?: string;
  }) => Promise<void>;

  recordSoldData: (params: {
    itemId: string;
    quantity: number;
    unitSellingPrice?: number;
    customer?: string;
    referenceNo?: string;
    notes?: string;
  }) => Promise<void>;

  recordCountUpdate: (params: {
    itemId: string;
    newLeftCount: number;
    reason?: string;
    referenceNo?: string;
    notes?: string;
  }) => Promise<void>;

  addNewItem: (itemData: Omit<InventoryItem, 'id' | 'createdDate' | 'lastUpdated' | 'lastUpdatedBy'>) => Promise<void>;
  updateItem: (item: InventoryItem) => Promise<void>;
  deleteItem: (itemId: string) => Promise<void>;

  // Sync operations
  syncWithSupabase: () => Promise<void>;
  updateSupabaseCredentials: (url: string, anonKey: string) => Promise<void>;
  resetToDefaultData: () => void;
}

const InventoryContext = createContext<InventoryContextType | undefined>(undefined);

const LOCAL_STORAGE_ITEMS_KEY = 'stock_sync_items_v2';
const LOCAL_STORAGE_TXS_KEY = 'stock_sync_txs_v2';
const LOCAL_STORAGE_OPS_KEY = 'stock_sync_ops_v2';
const LOCAL_STORAGE_ACTIVE_OP_KEY = 'stock_sync_active_op_v2';

export const InventoryProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  // Load saved state or default
  const [items, setItems] = useState<InventoryItem[]>(() => {
    try {
      const saved = localStorage.getItem(LOCAL_STORAGE_ITEMS_KEY);
      if (saved) return JSON.parse(saved);
    } catch (e) {
      console.error(e);
    }
    return INITIAL_INVENTORY_ITEMS;
  });

  const [transactions, setTransactions] = useState<Transaction[]>(() => {
    try {
      const saved = localStorage.getItem(LOCAL_STORAGE_TXS_KEY);
      if (saved) return JSON.parse(saved);
    } catch (e) {
      console.error(e);
    }
    return INITIAL_TRANSACTIONS;
  });

  const [operators, setOperators] = useState<OperatorUser[]>(() => {
    try {
      const saved = localStorage.getItem(LOCAL_STORAGE_OPS_KEY);
      if (saved) return JSON.parse(saved);
    } catch (e) {
      console.error(e);
    }
    return INITIAL_OPERATORS;
  });

  const [currentOperator, setCurrentOperatorState] = useState<OperatorUser>(() => {
    try {
      const saved = localStorage.getItem(LOCAL_STORAGE_ACTIVE_OP_KEY);
      if (saved) return JSON.parse(saved);
    } catch (e) {
      console.error(e);
    }
    return INITIAL_OPERATORS[0];
  });

  const [selectedCategory, setSelectedCategory] = useState<'all' | InventoryCategory>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [activeTab, setActiveTab] = useState<ActiveTab>('inventory');
  const [isMobileFrame, setIsMobileFrame] = useState(false);

  // Sync & network status
  const [syncStatus, setSyncStatus] = useState<'synced' | 'syncing' | 'offline' | 'error' | 'local_mesh'>('local_mesh');
  const [lastSyncTime, setLastSyncTime] = useState<string>(new Date().toLocaleTimeString());
  const [supabaseConfig, setSupabaseConfig] = useState<SupabaseConfig>(() => {
    const creds = getStoredSupabaseCredentials();
    return {
      url: creds.url,
      anonKey: creds.anonKey,
      isConnected: false,
      isConnecting: false,
      lastSyncTime: undefined,
    };
  });

  // Modal states
  const [quickActionModalOpen, setQuickActionModalOpen] = useState(false);
  const [quickActionMode, setQuickActionMode] = useState<'STOCK_IN' | 'SOLD' | 'COUNT_UPDATE' | 'NEW_ITEM'>('STOCK_IN');
  const [selectedItemForAction, setSelectedItemForAction] = useState<InventoryItem | null>(null);
  const [detailModalItem, setDetailModalItem] = useState<InventoryItem | null>(null);
  const [scannerModalOpen, setScannerModalOpen] = useState(false);
  const [userSwitcherModalOpen, setUserSwitcherModalOpen] = useState(false);
  const [supabaseSettingsModalOpen, setSupabaseSettingsModalOpen] = useState(false);
  const [flutterCodeModalOpen, setFlutterCodeModalOpen] = useState(false);

  // Persist local state
  useEffect(() => {
    localStorage.setItem(LOCAL_STORAGE_ITEMS_KEY, JSON.stringify(items));
  }, [items]);

  useEffect(() => {
    localStorage.setItem(LOCAL_STORAGE_TXS_KEY, JSON.stringify(transactions));
  }, [transactions]);

  useEffect(() => {
    localStorage.setItem(LOCAL_STORAGE_OPS_KEY, JSON.stringify(operators));
  }, [operators]);

  useEffect(() => {
    localStorage.setItem(LOCAL_STORAGE_ACTIVE_OP_KEY, JSON.stringify(currentOperator));
  }, [currentOperator]);

  // Set current operator wrapper
  const setCurrentOperator = (op: OperatorUser) => {
    setCurrentOperatorState(op);
    sound.playClick();
  };

  const addOperator = (name: string, role: OperatorUser['role']): OperatorUser => {
    const colors = ['#3b82f6', '#10b981', '#8b5cf6', '#f59e0b', '#ec4899', '#06b6d4'];
    const newOp: OperatorUser = {
      id: `op-${Date.now()}`,
      name: name.trim(),
      role,
      avatarColor: colors[Math.floor(Math.random() * colors.length)],
    };
    setOperators(prev => [...prev, newOp]);
    setCurrentOperatorState(newOp);
    sound.playSuccess();
    return newOp;
  };

  // Broadcast Channel for Instant Multi-Tab / Multi-Device local sync
  useEffect(() => {
    if (typeof window === 'undefined' || !('BroadcastChannel' in window)) return;
    const channel = new BroadcastChannel('stock_sync_mesh_channel');

    channel.onmessage = (event) => {
      const data = event.data;
      if (data && data.type === 'SYNC_STATE') {
        if (data.items) setItems(data.items);
        if (data.transactions) setTransactions(data.transactions);
        if (data.sender !== currentOperator.name) {
          setSyncStatus('synced');
          setLastSyncTime(new Date().toLocaleTimeString());
          sound.playScan();
        }
      }
    };

    return () => {
      channel.close();
    };
  }, [currentOperator.name]);

  const broadcastState = useCallback((newItems: InventoryItem[], newTxs: Transaction[]) => {
    if (typeof window !== 'undefined' && 'BroadcastChannel' in window) {
      try {
        const channel = new BroadcastChannel('stock_sync_mesh_channel');
        channel.postMessage({
          type: 'SYNC_STATE',
          items: newItems,
          transactions: newTxs,
          sender: currentOperator.name,
          timestamp: new Date().toISOString(),
        });
        channel.close();
      } catch (err) {
        console.error('Broadcast failed:', err);
      }
    }
  }, [currentOperator.name]);

  // Supabase real-time subscription & sync
  const syncWithSupabase = useCallback(async () => {
    const creds = getStoredSupabaseCredentials();
    if (!creds.url || !creds.anonKey) {
      setSyncStatus('local_mesh');
      return;
    }

    const client = getSupabaseClient();
    if (!client) {
      setSyncStatus('error');
      return;
    }

    setSyncStatus('syncing');
    try {
      // 1. Fetch remote items
      const { data: remoteItems, error: itemsErr } = await client
        .from('inventory_items')
        .select('*')
        .order('name', { ascending: true });

      if (itemsErr) {
        // Table might not exist yet
        console.warn('Supabase fetch items error:', itemsErr.message);
        setSyncStatus('local_mesh');
        setSupabaseConfig(prev => ({
          ...prev,
          isConnected: false,
          error: itemsErr.message,
        }));
        return;
      }

      // 2. Fetch remote transactions
      const { data: remoteTxs, error: txsErr } = await client
        .from('inventory_transactions')
        .select('*')
        .order('timestamp', { ascending: false })
        .limit(100);

      if (txsErr) {
        console.warn('Supabase fetch txs error:', txsErr.message);
      }

      if (remoteItems && remoteItems.length > 0) {
        // Map snake_case to camelCase
        const mappedItems: InventoryItem[] = remoteItems.map((r: Record<string, unknown>) => ({
          id: String(r.id),
          sku: String(r.sku || ''),
          name: String(r.name || ''),
          category: String(r.category || 'hp_cartridges') as InventoryCategory,
          description: String(r.description || ''),
          unit: String(r.unit || 'pcs'),
          totalIn: Number(r.total_in ?? 0),
          totalSold: Number(r.total_sold ?? 0),
          leftCount: Number(r.left_count ?? 0),
          minStockAlert: Number(r.min_stock_alert ?? 5),
          unitCostPrice: Number(r.unit_cost_price ?? 0),
          unitSellingPrice: Number(r.unit_selling_price ?? 0),
          location: String(r.location || ''),
          barcode: String(r.barcode || ''),
          lastUpdated: String(r.last_updated || new Date().toISOString()),
          lastUpdatedBy: String(r.last_updated_by || 'System'),
          createdDate: String(r.created_date || new Date().toISOString()),
        }));
        setItems(mappedItems);
      } else {
        // Push local items to Supabase if remote table is empty!
        for (const it of items) {
          await client.from('inventory_items').upsert({
            id: it.id,
            sku: it.sku,
            name: it.name,
            category: it.category,
            description: it.description,
            unit: it.unit,
            total_in: it.totalIn,
            total_sold: it.totalSold,
            left_count: it.leftCount,
            min_stock_alert: it.minStockAlert,
            unit_cost_price: it.unitCostPrice,
            unit_selling_price: it.unitSellingPrice,
            location: it.location,
            barcode: it.barcode,
            last_updated: it.lastUpdated,
            last_updated_by: it.lastUpdatedBy,
            created_date: it.createdDate,
          });
        }
      }

      if (remoteTxs && remoteTxs.length > 0) {
        const mappedTxs: Transaction[] = remoteTxs.map((r: Record<string, unknown>) => ({
          id: String(r.id),
          itemId: String(r.item_id),
          itemSku: String(r.item_sku || ''),
          itemName: String(r.item_name || ''),
          category: String(r.category || 'hp_cartridges') as InventoryCategory,
          type: String(r.type || 'STOCK_IN') as Transaction['type'],
          quantityChange: Number(r.quantity_change ?? 0),
          previousLeftCount: Number(r.previous_left_count ?? 0),
          newLeftCount: Number(r.new_left_count ?? 0),
          unitPrice: r.unit_price != null ? Number(r.unit_price) : undefined,
          totalAmount: r.total_amount != null ? Number(r.total_amount) : undefined,
          customerOrSupplier: r.customer_or_supplier ? String(r.customer_or_supplier) : undefined,
          referenceNo: r.reference_no ? String(r.reference_no) : undefined,
          notes: r.notes ? String(r.notes) : undefined,
          operatorName: String(r.operator_name || 'Operator'),
          deviceId: r.device_id ? String(r.device_id) : undefined,
          timestamp: String(r.timestamp || new Date().toISOString()),
        }));
        setTransactions(mappedTxs);
      }

      setSyncStatus('synced');
      setLastSyncTime(new Date().toLocaleTimeString());
      setSupabaseConfig(prev => ({
        ...prev,
        isConnected: true,
        error: null,
        lastSyncTime: new Date().toISOString(),
      }));
    } catch (err: unknown) {
      console.error('Supabase sync error:', err);
      setSyncStatus('error');
      setSupabaseConfig(prev => ({
        ...prev,
        isConnected: false,
        error: err instanceof Error ? err.message : String(err),
      }));
    }
  }, [items]);

  // Initial connection check
  useEffect(() => {
    syncWithSupabase();
  }, [syncWithSupabase]);

  // Realtime Supabase Channel
  useEffect(() => {
    const client = getSupabaseClient();
    if (!client) return;

    try {
      const channel = client
        .channel('inventory-realtime-channel')
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'inventory_items' },
          (payload) => {
            console.log('Realtime inventory item update received:', payload);
            if (payload.eventType === 'INSERT' || payload.eventType === 'UPDATE') {
              const r = payload.new as Record<string, unknown>;
              setItems(prev => {
                const idx = prev.findIndex(i => i.id === r.id);
                const updated: InventoryItem = {
                  id: String(r.id),
                  sku: String(r.sku || ''),
                  name: String(r.name || ''),
                  category: String(r.category || 'hp_cartridges') as InventoryCategory,
                  description: String(r.description || ''),
                  unit: String(r.unit || 'pcs'),
                  totalIn: Number(r.total_in ?? 0),
                  totalSold: Number(r.total_sold ?? 0),
                  leftCount: Number(r.left_count ?? 0),
                  minStockAlert: Number(r.min_stock_alert ?? 5),
                  unitCostPrice: Number(r.unit_cost_price ?? 0),
                  unitSellingPrice: Number(r.unit_selling_price ?? 0),
                  location: String(r.location || ''),
                  barcode: String(r.barcode || ''),
                  lastUpdated: String(r.last_updated || new Date().toISOString()),
                  lastUpdatedBy: String(r.last_updated_by || 'Remote Device'),
                  createdDate: String(r.created_date || new Date().toISOString()),
                };
                if (idx >= 0) {
                  const copy = [...prev];
                  copy[idx] = updated;
                  return copy;
                }
                return [updated, ...prev];
              });
              setLastSyncTime(new Date().toLocaleTimeString());
              sound.playScan();
            } else if (payload.eventType === 'DELETE') {
              const oldId = payload.old?.id;
              if (oldId) {
                setItems(prev => prev.filter(i => i.id !== oldId));
              }
            }
          }
        )
        .on(
          'postgres_changes',
          { event: 'INSERT', schema: 'public', table: 'inventory_transactions' },
          (payload) => {
            const r = payload.new as Record<string, unknown>;
            const newTx: Transaction = {
              id: String(r.id),
              itemId: String(r.item_id),
              itemSku: String(r.item_sku || ''),
              itemName: String(r.item_name || ''),
              category: String(r.category || 'hp_cartridges') as InventoryCategory,
              type: String(r.type || 'STOCK_IN') as Transaction['type'],
              quantityChange: Number(r.quantity_change ?? 0),
              previousLeftCount: Number(r.previous_left_count ?? 0),
              newLeftCount: Number(r.new_left_count ?? 0),
              unitPrice: r.unit_price != null ? Number(r.unit_price) : undefined,
              totalAmount: r.total_amount != null ? Number(r.total_amount) : undefined,
              customerOrSupplier: r.customer_or_supplier ? String(r.customer_or_supplier) : undefined,
              referenceNo: r.reference_no ? String(r.reference_no) : undefined,
              notes: r.notes ? String(r.notes) : undefined,
              operatorName: String(r.operator_name || 'Operator'),
              deviceId: r.device_id ? String(r.device_id) : undefined,
              timestamp: String(r.timestamp || new Date().toISOString()),
            };
            setTransactions(prev => {
              if (prev.some(t => t.id === newTx.id)) return prev;
              return [newTx, ...prev];
            });
            setLastSyncTime(new Date().toLocaleTimeString());
          }
        )
        .subscribe();

      return () => {
        client.removeChannel(channel);
      };
    } catch (e) {
      console.warn('Realtime channel subscription not active:', e);
    }
  }, []);

  const updateSupabaseCredentials = async (url: string, anonKey: string) => {
    saveStoredSupabaseCredentials(url, anonKey);
    setSupabaseConfig({
      url,
      anonKey,
      isConnected: false,
      isConnecting: true,
      lastSyncTime: undefined,
    });
    await syncWithSupabase();
  };

  // 1. RECORD STOCK IN (Insert Total Count / Inward Batch)
  const recordStockIn = async (params: {
    itemId: string;
    quantity: number;
    unitCostPrice?: number;
    supplier?: string;
    referenceNo?: string;
    notes?: string;
  }) => {
    const item = items.find(i => i.id === params.itemId);
    if (!item) throw new Error('Item not found');

    const prevLeft = item.leftCount;
    const newLeft = prevLeft + params.quantity;
    const newTotalIn = item.totalIn + params.quantity;
    const nowIso = new Date().toISOString();

    const updatedItem: InventoryItem = {
      ...item,
      totalIn: newTotalIn,
      leftCount: newLeft,
      unitCostPrice: params.unitCostPrice ?? item.unitCostPrice,
      lastUpdated: nowIso,
      lastUpdatedBy: currentOperator.name,
    };

    const newTx: Transaction = {
      id: `tx-in-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
      itemId: item.id,
      itemSku: item.sku,
      itemName: item.name,
      category: item.category,
      type: 'STOCK_IN',
      quantityChange: params.quantity,
      previousLeftCount: prevLeft,
      newLeftCount: newLeft,
      unitPrice: params.unitCostPrice ?? item.unitCostPrice,
      totalAmount: (params.unitCostPrice ?? item.unitCostPrice) * params.quantity,
      customerOrSupplier: params.supplier || 'Warehouse Batch Receipt',
      referenceNo: params.referenceNo || `IN-${Date.now().toString().slice(-4)}`,
      notes: params.notes,
      operatorName: currentOperator.name,
      timestamp: nowIso,
    };

    const nextItems = items.map(i => (i.id === item.id ? updatedItem : i));
    const nextTxs = [newTx, ...transactions];

    setItems(nextItems);
    setTransactions(nextTxs);
    broadcastState(nextItems, nextTxs);
    sound.playSuccess();

    // Supabase push
    const client = getSupabaseClient();
    if (client) {
      client.from('inventory_items').update({
        total_in: newTotalIn,
        left_count: newLeft,
        unit_cost_price: updatedItem.unitCostPrice,
        last_updated: nowIso,
        last_updated_by: currentOperator.name,
      }).eq('id', item.id).then(() => {});

      client.from('inventory_transactions').insert({
        id: newTx.id,
        item_id: newTx.itemId,
        item_sku: newTx.itemSku,
        item_name: newTx.itemName,
        category: newTx.category,
        type: newTx.type,
        quantity_change: newTx.quantityChange,
        previous_left_count: newTx.previousLeftCount,
        new_left_count: newTx.newLeftCount,
        unit_price: newTx.unitPrice,
        total_amount: newTx.totalAmount,
        customer_or_supplier: newTx.customerOrSupplier,
        reference_no: newTx.referenceNo,
        notes: newTx.notes,
        operator_name: newTx.operatorName,
        timestamp: newTx.timestamp,
      }).then(() => {});
    }
  };

  // 2. ENTER SOLD DATA (Sales / Dispatch Outward)
  const recordSoldData = async (params: {
    itemId: string;
    quantity: number;
    unitSellingPrice?: number;
    customer?: string;
    referenceNo?: string;
    notes?: string;
  }) => {
    const item = items.find(i => i.id === params.itemId);
    if (!item) throw new Error('Item not found');

    const prevLeft = item.leftCount;
    const newLeft = prevLeft - params.quantity;
    const newTotalSold = item.totalSold + params.quantity;
    const nowIso = new Date().toISOString();
    const salePrice = params.unitSellingPrice ?? item.unitSellingPrice;

    const updatedItem: InventoryItem = {
      ...item,
      totalSold: newTotalSold,
      leftCount: newLeft,
      unitSellingPrice: salePrice,
      lastUpdated: nowIso,
      lastUpdatedBy: currentOperator.name,
    };

    const newTx: Transaction = {
      id: `tx-sold-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
      itemId: item.id,
      itemSku: item.sku,
      itemName: item.name,
      category: item.category,
      type: 'SOLD',
      quantityChange: -params.quantity,
      previousLeftCount: prevLeft,
      newLeftCount: newLeft,
      unitPrice: salePrice,
      totalAmount: salePrice * params.quantity,
      customerOrSupplier: params.customer || 'Direct Dispatch Client',
      referenceNo: params.referenceNo || `INV-${Date.now().toString().slice(-4)}`,
      notes: params.notes,
      operatorName: currentOperator.name,
      timestamp: nowIso,
    };

    const nextItems = items.map(i => (i.id === item.id ? updatedItem : i));
    const nextTxs = [newTx, ...transactions];

    setItems(nextItems);
    setTransactions(nextTxs);
    broadcastState(nextItems, nextTxs);
    sound.playSuccess();

    const client = getSupabaseClient();
    if (client) {
      client.from('inventory_items').update({
        total_sold: newTotalSold,
        left_count: newLeft,
        unit_selling_price: salePrice,
        last_updated: nowIso,
        last_updated_by: currentOperator.name,
      }).eq('id', item.id).then(() => {});

      client.from('inventory_transactions').insert({
        id: newTx.id,
        item_id: newTx.itemId,
        item_sku: newTx.itemSku,
        item_name: newTx.itemName,
        category: newTx.category,
        type: newTx.type,
        quantity_change: newTx.quantityChange,
        previous_left_count: newTx.previousLeftCount,
        new_left_count: newTx.newLeftCount,
        unit_price: newTx.unitPrice,
        total_amount: newTx.totalAmount,
        customer_or_supplier: newTx.customerOrSupplier,
        reference_no: newTx.referenceNo,
        notes: newTx.notes,
        operator_name: newTx.operatorName,
        timestamp: newTx.timestamp,
      }).then(() => {});
    }
  };

  // 3. UPDATE LEFT DATA COUNTS (Audit Count / Shelf Reconciliation)
  const recordCountUpdate = async (params: {
    itemId: string;
    newLeftCount: number;
    reason?: string;
    referenceNo?: string;
    notes?: string;
  }) => {
    const item = items.find(i => i.id === params.itemId);
    if (!item) throw new Error('Item not found');

    const prevLeft = item.leftCount;
    const discrepancy = params.newLeftCount - prevLeft;
    const nowIso = new Date().toISOString();

    const updatedItem: InventoryItem = {
      ...item,
      leftCount: params.newLeftCount,
      lastUpdated: nowIso,
      lastUpdatedBy: currentOperator.name,
    };

    const newTx: Transaction = {
      id: `tx-audit-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
      itemId: item.id,
      itemSku: item.sku,
      itemName: item.name,
      category: item.category,
      type: 'COUNT_UPDATE',
      quantityChange: discrepancy,
      previousLeftCount: prevLeft,
      newLeftCount: params.newLeftCount,
      customerOrSupplier: params.reason || 'Physical Count Audit',
      referenceNo: params.referenceNo || `AUDIT-${new Date().toISOString().slice(5, 10)}`,
      notes: params.notes || `Stock adjusted from ${prevLeft} to ${params.newLeftCount} (${discrepancy >= 0 ? '+' : ''}${discrepancy})`,
      operatorName: currentOperator.name,
      timestamp: nowIso,
    };

    const nextItems = items.map(i => (i.id === item.id ? updatedItem : i));
    const nextTxs = [newTx, ...transactions];

    setItems(nextItems);
    setTransactions(nextTxs);
    broadcastState(nextItems, nextTxs);
    sound.playSuccess();

    const client = getSupabaseClient();
    if (client) {
      client.from('inventory_items').update({
        left_count: params.newLeftCount,
        last_updated: nowIso,
        last_updated_by: currentOperator.name,
      }).eq('id', item.id).then(() => {});

      client.from('inventory_transactions').insert({
        id: newTx.id,
        item_id: newTx.itemId,
        item_sku: newTx.itemSku,
        item_name: newTx.itemName,
        category: newTx.category,
        type: newTx.type,
        quantity_change: newTx.quantityChange,
        previous_left_count: newTx.previousLeftCount,
        new_left_count: newTx.newLeftCount,
        customer_or_supplier: newTx.customerOrSupplier,
        reference_no: newTx.referenceNo,
        notes: newTx.notes,
        operator_name: newTx.operatorName,
        timestamp: newTx.timestamp,
      }).then(() => {});
    }
  };

  // 4. ADD NEW ITEM
  const addNewItem = async (itemData: Omit<InventoryItem, 'id' | 'createdDate' | 'lastUpdated' | 'lastUpdatedBy'>) => {
    const nowIso = new Date().toISOString();
    const newItemId = `${itemData.category.slice(0, 3)}-${Date.now().toString().slice(-6)}`;

    const newItem: InventoryItem = {
      ...itemData,
      id: newItemId,
      createdDate: nowIso,
      lastUpdated: nowIso,
      lastUpdatedBy: currentOperator.name,
    };

    const initialTx: Transaction = {
      id: `tx-init-${Date.now()}`,
      itemId: newItem.id,
      itemSku: newItem.sku,
      itemName: newItem.name,
      category: newItem.category,
      type: 'ITEM_CREATED',
      quantityChange: newItem.leftCount,
      previousLeftCount: 0,
      newLeftCount: newItem.leftCount,
      unitPrice: newItem.unitCostPrice,
      totalAmount: newItem.unitCostPrice * newItem.leftCount,
      customerOrSupplier: 'Initial Catalog Insertion',
      notes: `Item created with initial count ${newItem.leftCount}`,
      operatorName: currentOperator.name,
      timestamp: nowIso,
    };

    const nextItems = [newItem, ...items];
    const nextTxs = [initialTx, ...transactions];

    setItems(nextItems);
    setTransactions(nextTxs);
    broadcastState(nextItems, nextTxs);
    sound.playSuccess();

    const client = getSupabaseClient();
    if (client) {
      client.from('inventory_items').insert({
        id: newItem.id,
        sku: newItem.sku,
        name: newItem.name,
        category: newItem.category,
        description: newItem.description,
        unit: newItem.unit,
        total_in: newItem.totalIn,
        total_sold: newItem.totalSold,
        left_count: newItem.leftCount,
        min_stock_alert: newItem.minStockAlert,
        unit_cost_price: newItem.unitCostPrice,
        unit_selling_price: newItem.unitSellingPrice,
        location: newItem.location,
        barcode: newItem.barcode,
        last_updated: newItem.lastUpdated,
        last_updated_by: newItem.lastUpdatedBy,
        created_date: newItem.createdDate,
      }).then(() => {});

      client.from('inventory_transactions').insert({
        id: initialTx.id,
        item_id: initialTx.itemId,
        item_sku: initialTx.itemSku,
        item_name: initialTx.itemName,
        category: initialTx.category,
        type: initialTx.type,
        quantity_change: initialTx.quantityChange,
        previous_left_count: 0,
        new_left_count: initialTx.newLeftCount,
        notes: initialTx.notes,
        operator_name: initialTx.operatorName,
        timestamp: initialTx.timestamp,
      }).then(() => {});
    }
  };

  // 5. UPDATE ITEM
  const updateItem = async (updated: InventoryItem) => {
    const nowIso = new Date().toISOString();
    const itemWithTs = {
      ...updated,
      lastUpdated: nowIso,
      lastUpdatedBy: currentOperator.name,
    };
    const nextItems = items.map(i => (i.id === updated.id ? itemWithTs : i));
    setItems(nextItems);
    broadcastState(nextItems, transactions);
    sound.playClick();

    const client = getSupabaseClient();
    if (client) {
      client.from('inventory_items').update({
        sku: itemWithTs.sku,
        name: itemWithTs.name,
        category: itemWithTs.category,
        description: itemWithTs.description,
        unit: itemWithTs.unit,
        min_stock_alert: itemWithTs.minStockAlert,
        unit_cost_price: itemWithTs.unitCostPrice,
        unit_selling_price: itemWithTs.unitSellingPrice,
        location: itemWithTs.location,
        barcode: itemWithTs.barcode,
        last_updated: nowIso,
        last_updated_by: currentOperator.name,
      }).eq('id', updated.id).then(() => {});
    }
  };

  // 6. DELETE ITEM
  const deleteItem = async (itemId: string) => {
    const nextItems = items.filter(i => i.id !== itemId);
    setItems(nextItems);
    broadcastState(nextItems, transactions);
    sound.playAlert();

    const client = getSupabaseClient();
    if (client) {
      client.from('inventory_items').delete().eq('id', itemId).then(() => {});
    }
  };

  // 7. RESET TO DEFAULT
  const resetToDefaultData = () => {
    setItems(INITIAL_INVENTORY_ITEMS);
    setTransactions(INITIAL_TRANSACTIONS);
    broadcastState(INITIAL_INVENTORY_ITEMS, INITIAL_TRANSACTIONS);
    sound.playAlert();
  };

  const openQuickAction = (mode: 'STOCK_IN' | 'SOLD' | 'COUNT_UPDATE' | 'NEW_ITEM', item?: InventoryItem) => {
    setQuickActionMode(mode);
    setSelectedItemForAction(item || null);
    setQuickActionModalOpen(true);
    sound.playClick();
  };

  const closeQuickAction = () => {
    setQuickActionModalOpen(false);
    setSelectedItemForAction(null);
  };

  return (
    <InventoryContext.Provider
      value={{
        items,
        transactions,
        operators,
        currentOperator,
        selectedCategory,
        searchQuery,
        activeTab,
        syncStatus,
        lastSyncTime,
        supabaseConfig,
        isMobileFrame,

        quickActionModalOpen,
        quickActionMode,
        selectedItemForAction,
        detailModalItem,
        scannerModalOpen,
        userSwitcherModalOpen,
        supabaseSettingsModalOpen,
        flutterCodeModalOpen,

        setSelectedCategory,
        setSearchQuery,
        setActiveTab,
        setIsMobileFrame,
        setCurrentOperator,
        addOperator,

        openQuickAction,
        closeQuickAction,
        setDetailModalItem,
        setScannerModalOpen,
        setUserSwitcherModalOpen,
        setSupabaseSettingsModalOpen,
        setFlutterCodeModalOpen,

        recordStockIn,
        recordSoldData,
        recordCountUpdate,
        addNewItem,
        updateItem,
        deleteItem,

        syncWithSupabase,
        updateSupabaseCredentials,
        resetToDefaultData,
      }}
    >
      {children}
    </InventoryContext.Provider>
  );
};

export function useInventory() {
  const context = useContext(InventoryContext);
  if (!context) {
    throw new Error('useInventory must be used within an InventoryProvider');
  }
  return context;
}
