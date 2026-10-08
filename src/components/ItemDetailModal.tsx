import React, { useState } from 'react';
import {
  X,
  MapPin,
  Barcode,
  Clock,
  ArrowDownRight,
  ArrowUpRight,
  CheckCircle2,
  Trash2,
  Edit3,
  Save,
  DollarSign,
  Package,
  Layers,
} from 'lucide-react';
import { useInventory } from '../context/InventoryContext';
import { CATEGORIES } from '../data/initialData';
import { InventoryItem } from '../types';
import { sound } from '../lib/sound';

export const ItemDetailModal: React.FC = () => {
  const {
    detailModalItem,
    setDetailModalItem,
    openQuickAction,
    updateItem,
    deleteItem,
    transactions,
  } = useInventory();

  const [isEditing, setIsEditing] = useState(false);
  const [editName, setEditName] = useState('');
  const [editSku, setEditSku] = useState('');
  const [editMinAlert, setEditMinAlert] = useState('5');
  const [editCost, setEditCost] = useState('0');
  const [editPrice, setEditPrice] = useState('0');
  const [editLocation, setEditLocation] = useState('');
  const [editBarcode, setEditBarcode] = useState('');
  const [editDescription, setEditDescription] = useState('');

  if (!detailModalItem) return null;

  const item = detailModalItem;
  const categoryMeta = CATEGORIES.find(c => c.id === item.category) || CATEGORIES[0];
  const itemTransactions = transactions.filter(t => t.itemId === item.id);

  const isLowStock = item.leftCount <= item.minStockAlert;
  const isOutOfStock = item.leftCount <= 0;

  const handleStartEdit = () => {
    sound.playClick();
    setEditName(item.name);
    setEditSku(item.sku);
    setEditMinAlert(String(item.minStockAlert));
    setEditCost(String(item.unitCostPrice));
    setEditPrice(String(item.unitSellingPrice));
    setEditLocation(item.location || '');
    setEditBarcode(item.barcode || '');
    setEditDescription(item.description || '');
    setIsEditing(true);
  };

  const handleSaveEdit = async () => {
    sound.playClick();
    const updated: InventoryItem = {
      ...item,
      name: editName.trim(),
      sku: editSku.trim().toUpperCase(),
      minStockAlert: parseInt(editMinAlert, 10) || 5,
      unitCostPrice: parseFloat(editCost) || 0,
      unitSellingPrice: parseFloat(editPrice) || 0,
      location: editLocation.trim() || undefined,
      barcode: editBarcode.trim() || undefined,
      description: editDescription.trim() || undefined,
    };
    await updateItem(updated);
    setDetailModalItem(updated);
    setIsEditing(false);
    sound.playSuccess();
  };

  const handleDelete = async () => {
    if (confirm(`Are you sure you want to delete ${item.name}? This will remove it from the active catalog.`)) {
      await deleteItem(item.id);
      setDetailModalItem(null);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-sm p-0 sm:p-4 animate-in fade-in duration-200">
      <div className="w-full sm:max-w-lg bg-slate-900 border border-slate-700/80 rounded-t-3xl sm:rounded-2xl shadow-2xl max-h-[92vh] flex flex-col overflow-hidden text-sm">
        {/* Modal Top Bar */}
        <div className="p-4 border-b border-slate-800 flex items-center justify-between bg-slate-900/90">
          <div className="flex items-center gap-2">
            <span className="text-xs font-mono font-bold px-2 py-0.5 rounded bg-slate-800 text-blue-400 border border-slate-700">
              {item.sku}
            </span>
            <span className="text-xs text-slate-400 font-medium">
              {categoryMeta.name}
            </span>
          </div>

          <div className="flex items-center gap-1.5">
            {!isEditing ? (
              <button
                onClick={handleStartEdit}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition"
                title="Edit item specifications"
              >
                <Edit3 className="w-4 h-4" />
              </button>
            ) : (
              <button
                onClick={handleSaveEdit}
                className="flex items-center gap-1 px-2.5 py-1 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold"
              >
                <Save className="w-3.5 h-3.5" />
                <span>Save</span>
              </button>
            )}

            <button
              onClick={() => {
                sound.playClick();
                setDetailModalItem(null);
              }}
              className="p-1.5 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Content Scrollable */}
        <div className="p-4 space-y-4 overflow-y-auto flex-1">
          {isEditing ? (
            <div className="space-y-3">
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1">Item Name</label>
                <input
                  type="text"
                  value={editName}
                  onChange={(e) => setEditName(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-blue-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">SKU / Code</label>
                  <input
                    type="text"
                    value={editSku}
                    onChange={(e) => setEditSku(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs font-mono focus:outline-none focus:border-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">Min Stock Alert</label>
                  <input
                    type="number"
                    value={editMinAlert}
                    onChange={(e) => setEditMinAlert(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-blue-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">Unit Cost ($)</label>
                  <input
                    type="number"
                    step="0.01"
                    value={editCost}
                    onChange={(e) => setEditCost(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">Unit Selling ($)</label>
                  <input
                    type="number"
                    step="0.01"
                    value={editPrice}
                    onChange={(e) => setEditPrice(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-blue-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">Location</label>
                  <input
                    type="text"
                    value={editLocation}
                    onChange={(e) => setEditLocation(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">Barcode</label>
                  <input
                    type="text"
                    value={editBarcode}
                    onChange={(e) => setEditBarcode(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs font-mono focus:outline-none focus:border-blue-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1">Description</label>
                <textarea
                  rows={2}
                  value={editDescription}
                  onChange={(e) => setEditDescription(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-blue-500"
                />
              </div>
            </div>
          ) : (
            <>
              {/* Item Title & Description */}
              <div>
                <h3 className="text-lg font-bold text-slate-100">
                  {item.name}
                </h3>
                {item.description && (
                  <p className="text-xs text-slate-400 mt-1 leading-relaxed">
                    {item.description}
                  </p>
                )}
              </div>

              {/* Status Banner */}
              <div className="p-4 rounded-2xl bg-slate-800/90 border border-slate-700/80 grid grid-cols-3 gap-3 text-center">
                <div>
                  <span className="text-[10px] uppercase font-semibold text-slate-400 block">Total In</span>
                  <span className="text-xl font-bold font-mono text-slate-100">{item.totalIn}</span>
                  <span className="text-[10px] text-slate-500 block">cumulative</span>
                </div>

                <div>
                  <span className="text-[10px] uppercase font-semibold text-slate-400 block">Total Sold</span>
                  <span className="text-xl font-bold font-mono text-emerald-400">{item.totalSold}</span>
                  <span className="text-[10px] text-emerald-500/80 block">outward</span>
                </div>

                <div>
                  <span className="text-[10px] uppercase font-semibold text-slate-400 block">Left Count</span>
                  <span className={`text-xl font-black font-mono ${
                    isOutOfStock ? 'text-rose-400' : isLowStock ? 'text-amber-400' : 'text-blue-400'
                  }`}>
                    {item.leftCount}
                  </span>
                  <span className="text-[10px] text-slate-400 block">{item.unit}</span>
                </div>
              </div>

              {/* Quick Operation Buttons */}
              <div className="grid grid-cols-3 gap-2">
                <button
                  onClick={() => {
                    sound.playClick();
                    setDetailModalItem(null);
                    openQuickAction('STOCK_IN', item);
                  }}
                  className="py-2 px-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-semibold text-xs flex items-center justify-center gap-1 active:scale-95 transition"
                >
                  <ArrowDownRight className="w-4 h-4" />
                  <span>+ In Stock</span>
                </button>

                <button
                  onClick={() => {
                    sound.playClick();
                    setDetailModalItem(null);
                    openQuickAction('SOLD', item);
                  }}
                  className="py-2 px-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-semibold text-xs flex items-center justify-center gap-1 active:scale-95 transition"
                >
                  <ArrowUpRight className="w-4 h-4" />
                  <span>- Enter Sold</span>
                </button>

                <button
                  onClick={() => {
                    sound.playClick();
                    setDetailModalItem(null);
                    openQuickAction('COUNT_UPDATE', item);
                  }}
                  className="py-2 px-2 rounded-xl bg-purple-600 hover:bg-purple-500 text-white font-semibold text-xs flex items-center justify-center gap-1 active:scale-95 transition"
                >
                  <CheckCircle2 className="w-4 h-4" />
                  <span>Audit Left</span>
                </button>
              </div>

              {/* Spec Details */}
              <div className="p-3.5 rounded-xl bg-slate-800/60 border border-slate-700/60 space-y-2 text-xs">
                <div className="flex items-center justify-between text-slate-300">
                  <span className="text-slate-400 flex items-center gap-1">
                    <DollarSign className="w-3.5 h-3.5" /> Unit Cost:
                  </span>
                  <span className="font-mono font-semibold text-slate-100">${item.unitCostPrice.toFixed(2)}</span>
                </div>

                <div className="flex items-center justify-between text-slate-300">
                  <span className="text-slate-400 flex items-center gap-1">
                    <DollarSign className="w-3.5 h-3.5" /> Unit Selling Price:
                  </span>
                  <span className="font-mono font-semibold text-emerald-400">${item.unitSellingPrice.toFixed(2)}</span>
                </div>

                <div className="flex items-center justify-between text-slate-300">
                  <span className="text-slate-400 flex items-center gap-1">
                    <MapPin className="w-3.5 h-3.5" /> Warehouse Location:
                  </span>
                  <span className="font-medium text-slate-100">{item.location || 'Not Assigned'}</span>
                </div>

                {item.barcode && (
                  <div className="flex items-center justify-between text-slate-300">
                    <span className="text-slate-400 flex items-center gap-1">
                      <Barcode className="w-3.5 h-3.5" /> Barcode:
                    </span>
                    <span className="font-mono text-slate-100">{item.barcode}</span>
                  </div>
                )}

                <div className="flex items-center justify-between text-slate-300 pt-1 border-t border-slate-700/60">
                  <span className="text-slate-400 flex items-center gap-1">
                    <Clock className="w-3.5 h-3.5" /> Last Updated:
                  </span>
                  <span className="text-[11px] text-slate-400">
                    {new Date(item.lastUpdated).toLocaleString()} by {item.lastUpdatedBy}
                  </span>
                </div>
              </div>

              {/* Transaction History for this item */}
              <div>
                <h4 className="text-xs font-bold text-slate-200 uppercase tracking-wider mb-2">
                  Item Movement History ({itemTransactions.length})
                </h4>

                <div className="space-y-1.5 max-h-48 overflow-y-auto">
                  {itemTransactions.length === 0 ? (
                    <p className="text-xs text-slate-500 italic">No movement recorded yet for this item.</p>
                  ) : (
                    itemTransactions.map(tx => (
                      <div
                        key={tx.id}
                        className="p-2 rounded-lg bg-slate-800/80 border border-slate-700/60 flex items-center justify-between text-xs"
                      >
                        <div>
                          <span className={`font-semibold ${
                            tx.type === 'STOCK_IN' ? 'text-blue-400' : tx.type === 'SOLD' ? 'text-emerald-400' : 'text-purple-400'
                          }`}>
                            {tx.type === 'STOCK_IN' ? '+ Stock In' : tx.type === 'SOLD' ? '- Sold Out' : 'Count Audit'}
                          </span>
                          <span className="text-[11px] text-slate-400 ml-1.5 font-mono">
                            {new Date(tx.timestamp).toLocaleDateString()}
                          </span>
                          {tx.customerOrSupplier && (
                            <div className="text-[10px] text-slate-400">{tx.customerOrSupplier}</div>
                          )}
                        </div>

                        <div className="text-right font-mono">
                          <span className={`font-bold ${
                            tx.quantityChange > 0 ? 'text-blue-400' : tx.quantityChange < 0 ? 'text-emerald-400' : 'text-slate-300'
                          }`}>
                            {tx.quantityChange > 0 ? `+${tx.quantityChange}` : tx.quantityChange}
                          </span>
                          <div className="text-[10px] text-slate-500">
                            → {tx.newLeftCount} left
                          </div>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>

              {/* Delete button */}
              <div className="pt-2 text-right">
                <button
                  type="button"
                  onClick={handleDelete}
                  className="text-xs text-rose-400 hover:text-rose-300 transition flex items-center gap-1 ml-auto"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                  <span>Delete Item</span>
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};
