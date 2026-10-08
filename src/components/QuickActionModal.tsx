import React, { useState, useEffect } from 'react';
import {
  X,
  ArrowDownRight,
  ArrowUpRight,
  CheckCircle2,
  PlusCircle,
  AlertCircle,
  DollarSign,
  User,
  Package,
} from 'lucide-react';
import { useInventory } from '../context/InventoryContext';
import { CATEGORIES } from '../data/initialData';
import { InventoryCategory, InventoryItem } from '../types';
import { sound } from '../lib/sound';

export const QuickActionModal: React.FC = () => {
  const {
    quickActionModalOpen,
    quickActionMode,
    selectedItemForAction,
    closeQuickAction,
    items,
    currentOperator,
    recordStockIn,
    recordSoldData,
    recordCountUpdate,
    addNewItem,
    setUserSwitcherModalOpen,
  } = useInventory();

  // Mode switcher inside modal
  const [activeMode, setActiveMode] = useState<'STOCK_IN' | 'SOLD' | 'COUNT_UPDATE' | 'NEW_ITEM'>('STOCK_IN');
  const [selectedItemId, setSelectedItemId] = useState<string>('');

  // Form fields for Stock In / Sold / Count Update
  const [quantity, setQuantity] = useState<string>('1');
  const [unitPrice, setUnitPrice] = useState<string>('');
  const [partyName, setPartyName] = useState<string>('');
  const [referenceNo, setReferenceNo] = useState<string>('');
  const [notes, setNotes] = useState<string>('');
  const [auditReason, setAuditReason] = useState<string>('Physical Inventory Audit');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Form fields for New Item
  const [newName, setNewName] = useState('');
  const [newSku, setNewSku] = useState('');
  const [newCategory, setNewCategory] = useState<InventoryCategory>('hp_cartridges');
  const [newUnit, setNewUnit] = useState('cartridges');
  const [newInitialIn, setNewInitialIn] = useState('20');
  const [newInitialLeft, setNewInitialLeft] = useState('20');
  const [newMinAlert, setNewMinAlert] = useState('5');
  const [newCostPrice, setNewCostPrice] = useState('35');
  const [newSellingPrice, setNewSellingPrice] = useState('55');
  const [newLocation, setNewLocation] = useState('Rack A-01');
  const [newBarcode, setNewBarcode] = useState('');
  const [newDescription, setNewDescription] = useState('');

  // Sync state when modal opens
  useEffect(() => {
    if (quickActionModalOpen) {
      setActiveMode(quickActionMode);
      setErrorMessage(null);

      const targetItem = selectedItemForAction || items[0];
      if (targetItem) {
        setSelectedItemId(targetItem.id);
        if (quickActionMode === 'STOCK_IN') {
          setUnitPrice(String(targetItem.unitCostPrice));
          setQuantity('10');
          setPartyName('');
          setReferenceNo(`PO-${Date.now().toString().slice(-4)}`);
        } else if (quickActionMode === 'SOLD') {
          setUnitPrice(String(targetItem.unitSellingPrice));
          setQuantity('1');
          setPartyName('');
          setReferenceNo(`INV-${Date.now().toString().slice(-4)}`);
        } else if (quickActionMode === 'COUNT_UPDATE') {
          setQuantity(String(targetItem.leftCount));
          setReferenceNo(`AUDIT-${new Date().toISOString().slice(5, 10)}`);
        }
      }
      setNotes('');
    }
  }, [quickActionModalOpen, quickActionMode, selectedItemForAction, items]);

  // Handle selected item change
  const currentItem = items.find(i => i.id === selectedItemId);

  useEffect(() => {
    if (currentItem) {
      if (activeMode === 'STOCK_IN') {
        setUnitPrice(String(currentItem.unitCostPrice));
      } else if (activeMode === 'SOLD') {
        setUnitPrice(String(currentItem.unitSellingPrice));
      } else if (activeMode === 'COUNT_UPDATE') {
        setQuantity(String(currentItem.leftCount));
      }
    }
  }, [selectedItemId, activeMode]);

  if (!quickActionModalOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);
    setIsSubmitting(true);

    try {
      if (activeMode === 'STOCK_IN') {
        if (!currentItem) throw new Error('Please select an item');
        const qty = parseInt(quantity, 10);
        if (isNaN(qty) || qty <= 0) throw new Error('Quantity must be greater than 0');

        await recordStockIn({
          itemId: currentItem.id,
          quantity: qty,
          unitCostPrice: unitPrice ? parseFloat(unitPrice) : currentItem.unitCostPrice,
          supplier: partyName.trim() || undefined,
          referenceNo: referenceNo.trim() || undefined,
          notes: notes.trim() || undefined,
        });
      } else if (activeMode === 'SOLD') {
        if (!currentItem) throw new Error('Please select an item');
        const qty = parseInt(quantity, 10);
        if (isNaN(qty) || qty <= 0) throw new Error('Quantity sold must be greater than 0');

        await recordSoldData({
          itemId: currentItem.id,
          quantity: qty,
          unitSellingPrice: unitPrice ? parseFloat(unitPrice) : currentItem.unitSellingPrice,
          customer: partyName.trim() || undefined,
          referenceNo: referenceNo.trim() || undefined,
          notes: notes.trim() || undefined,
        });
      } else if (activeMode === 'COUNT_UPDATE') {
        if (!currentItem) throw new Error('Please select an item');
        const newLeft = parseInt(quantity, 10);
        if (isNaN(newLeft) || newLeft < 0) throw new Error('Left count cannot be negative');

        await recordCountUpdate({
          itemId: currentItem.id,
          newLeftCount: newLeft,
          reason: auditReason,
          referenceNo: referenceNo.trim() || undefined,
          notes: notes.trim() || undefined,
        });
      } else if (activeMode === 'NEW_ITEM') {
        if (!newName.trim()) throw new Error('Item name is required');
        if (!newSku.trim()) throw new Error('SKU / Code is required');

        const initialIn = parseInt(newInitialIn, 10) || 0;
        const initialLeft = parseInt(newInitialLeft, 10) || 0;

        await addNewItem({
          sku: newSku.trim().toUpperCase(),
          name: newName.trim(),
          category: newCategory,
          unit: newUnit,
          description: newDescription.trim() || undefined,
          totalIn: initialIn,
          totalSold: 0,
          leftCount: initialLeft,
          minStockAlert: parseInt(newMinAlert, 10) || 5,
          unitCostPrice: parseFloat(newCostPrice) || 0,
          unitSellingPrice: parseFloat(newSellingPrice) || 0,
          location: newLocation.trim() || undefined,
          barcode: newBarcode.trim() || undefined,
        });
      }

      closeQuickAction();
    } catch (err: unknown) {
      sound.playAlert();
      setErrorMessage(err instanceof Error ? err.message : String(err));
    } finally {
      setIsSubmitting(false);
    }
  };

  const parsedQty = parseInt(quantity, 10) || 0;
  const parsedPrice = parseFloat(unitPrice) || 0;
  const calculatedTotal = parsedQty * parsedPrice;

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/75 backdrop-blur-sm p-0 sm:p-4 animate-in fade-in duration-200">
      <div className="w-full sm:max-w-lg bg-slate-900 border border-slate-700/80 rounded-t-3xl sm:rounded-2xl shadow-2xl max-h-[92vh] flex flex-col overflow-hidden">
        {/* Top Header */}
        <div className="p-4 border-b border-slate-800 flex items-center justify-between bg-slate-900/90">
          <div className="flex items-center gap-2">
            <span className="w-2.5 h-2.5 rounded-full bg-blue-500 animate-pulse" />
            <h2 className="text-base font-bold text-slate-100">
              Inventory Action
            </h2>
          </div>
          <button
            onClick={() => {
              sound.playClick();
              closeQuickAction();
            }}
            className="p-1.5 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* 4 Mode Tabs */}
        <div className="grid grid-cols-4 p-2 bg-slate-950/60 border-b border-slate-800 text-xs gap-1">
          <button
            type="button"
            onClick={() => {
              sound.playClick();
              setActiveMode('STOCK_IN');
              setErrorMessage(null);
            }}
            className={`py-2 px-1 rounded-xl font-medium flex flex-col items-center justify-center gap-1 transition ${
              activeMode === 'STOCK_IN'
                ? 'bg-blue-600 text-white shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
            }`}
          >
            <ArrowDownRight className="w-4 h-4" />
            <span className="truncate max-w-full">Insert In</span>
          </button>

          <button
            type="button"
            onClick={() => {
              sound.playClick();
              setActiveMode('SOLD');
              setErrorMessage(null);
            }}
            className={`py-2 px-1 rounded-xl font-medium flex flex-col items-center justify-center gap-1 transition ${
              activeMode === 'SOLD'
                ? 'bg-emerald-600 text-white shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
            }`}
          >
            <ArrowUpRight className="w-4 h-4" />
            <span className="truncate max-w-full">Enter Sold</span>
          </button>

          <button
            type="button"
            onClick={() => {
              sound.playClick();
              setActiveMode('COUNT_UPDATE');
              setErrorMessage(null);
            }}
            className={`py-2 px-1 rounded-xl font-medium flex flex-col items-center justify-center gap-1 transition ${
              activeMode === 'COUNT_UPDATE'
                ? 'bg-purple-600 text-white shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
            }`}
          >
            <CheckCircle2 className="w-4 h-4" />
            <span className="truncate max-w-full">Update Left</span>
          </button>

          <button
            type="button"
            onClick={() => {
              sound.playClick();
              setActiveMode('NEW_ITEM');
              setErrorMessage(null);
            }}
            className={`py-2 px-1 rounded-xl font-medium flex flex-col items-center justify-center gap-1 transition ${
              activeMode === 'NEW_ITEM'
                ? 'bg-amber-600 text-white shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
            }`}
          >
            <PlusCircle className="w-4 h-4" />
            <span className="truncate max-w-full">New Item</span>
          </button>
        </div>

        {/* Scrollable Form Body */}
        <form onSubmit={handleSubmit} className="p-4 space-y-4 overflow-y-auto flex-1 text-sm">
          {errorMessage && (
            <div className="p-3 rounded-xl bg-rose-500/15 border border-rose-500/40 text-rose-300 text-xs flex items-center gap-2">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              <span>{errorMessage}</span>
            </div>
          )}

          {/* Active Operator Banner */}
          <div className="flex items-center justify-between p-2.5 rounded-xl bg-slate-800/60 border border-slate-700/60 text-xs">
            <div className="flex items-center gap-2">
              <div
                className="w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold text-white shadow-sm"
                style={{ backgroundColor: currentOperator.avatarColor }}
              >
                {currentOperator.name.charAt(0)}
              </div>
              <span className="text-slate-300 font-medium">
                Acting as: <strong className="text-slate-100">{currentOperator.name}</strong> ({currentOperator.role})
              </span>
            </div>
            <button
              type="button"
              onClick={() => {
                sound.playClick();
                setUserSwitcherModalOpen(true);
              }}
              className="text-blue-400 hover:text-blue-300 text-[11px] underline font-medium"
            >
              Change User
            </button>
          </div>

          {/* Form Content: STOCK_IN, SOLD, COUNT_UPDATE */}
          {activeMode !== 'NEW_ITEM' && (
            <>
              {/* Item Selector */}
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Select Item
                </label>
                <select
                  value={selectedItemId}
                  onChange={(e) => {
                    sound.playClick();
                    setSelectedItemId(e.target.value);
                  }}
                  className="w-full px-3 py-2.5 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-sm focus:outline-none focus:border-blue-500"
                >
                  {items.map((it) => (
                    <option key={it.id} value={it.id}>
                      [{it.sku}] {it.name} (Left: {it.leftCount} {it.unit})
                    </option>
                  ))}
                </select>
              </div>

              {/* Current Status Box for Selected Item */}
              {currentItem && (
                <div className="p-3 rounded-xl bg-slate-800/80 border border-slate-700/60 grid grid-cols-3 gap-2 text-center text-xs">
                  <div>
                    <span className="text-slate-400 block text-[10px]">Total In</span>
                    <span className="font-bold text-slate-200 text-sm">{currentItem.totalIn}</span>
                  </div>
                  <div>
                    <span className="text-slate-400 block text-[10px]">Total Sold</span>
                    <span className="font-bold text-emerald-400 text-sm">{currentItem.totalSold}</span>
                  </div>
                  <div>
                    <span className="text-slate-400 block text-[10px]">Currently Left</span>
                    <span className="font-bold text-blue-400 text-sm">{currentItem.leftCount} {currentItem.unit}</span>
                  </div>
                </div>
              )}

              {/* Specific inputs for STOCK_IN */}
              {activeMode === 'STOCK_IN' && (
                <>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-xs font-medium text-slate-300 mb-1">
                        Quantity to Add (+In) *
                      </label>
                      <input
                        type="number"
                        min="1"
                        required
                        value={quantity}
                        onChange={(e) => setQuantity(e.target.value)}
                        placeholder="e.g. 50"
                        className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 font-bold focus:outline-none focus:border-blue-500"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-slate-300 mb-1">
                        Unit Cost Price ($)
                      </label>
                      <input
                        type="number"
                        step="0.01"
                        value={unitPrice}
                        onChange={(e) => setUnitPrice(e.target.value)}
                        placeholder="0.00"
                        className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 focus:outline-none focus:border-blue-500"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-xs font-medium text-slate-300 mb-1">
                        Supplier / Source
                      </label>
                      <input
                        type="text"
                        value={partyName}
                        onChange={(e) => setPartyName(e.target.value)}
                        placeholder="e.g. HP Factory Direct"
                        className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-blue-500"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-slate-300 mb-1">
                        PO / Delivery Note #
                      </label>
                      <input
                        type="text"
                        value={referenceNo}
                        onChange={(e) => setReferenceNo(e.target.value)}
                        placeholder="e.g. PO-8841"
                        className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs font-mono focus:outline-none focus:border-blue-500"
                      />
                    </div>
                  </div>

                  {currentItem && (
                    <div className="p-2.5 rounded-lg bg-blue-500/10 border border-blue-500/20 text-xs text-blue-300">
                      Outcome: Left stock will increase from <strong>{currentItem.leftCount}</strong> to{' '}
                      <strong>{currentItem.leftCount + parsedQty} {currentItem.unit}</strong>.
                      {calculatedTotal > 0 && ` Total batch cost: $${calculatedTotal.toFixed(2)}.`}
                    </div>
                  )}
                </>
              )}

              {/* Specific inputs for SOLD */}
              {activeMode === 'SOLD' && (
                <>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-xs font-medium text-slate-300 mb-1">
                        Quantity Sold (-Out) *
                      </label>
                      <input
                        type="number"
                        min="1"
                        required
                        value={quantity}
                        onChange={(e) => setQuantity(e.target.value)}
                        placeholder="e.g. 5"
                        className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 font-bold focus:outline-none focus:border-emerald-500"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-slate-300 mb-1">
                        Unit Selling Price ($)
                      </label>
                      <input
                        type="number"
                        step="0.01"
                        value={unitPrice}
                        onChange={(e) => setUnitPrice(e.target.value)}
                        placeholder="0.00"
                        className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 focus:outline-none focus:border-emerald-500"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-xs font-medium text-slate-300 mb-1">
                        Customer / Client Name
                      </label>
                      <input
                        type="text"
                        value={partyName}
                        onChange={(e) => setPartyName(e.target.value)}
                        placeholder="e.g. Pharma Packaging Ltd"
                        className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-emerald-500"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-slate-300 mb-1">
                        Sales Invoice #
                      </label>
                      <input
                        type="text"
                        value={referenceNo}
                        onChange={(e) => setReferenceNo(e.target.value)}
                        placeholder="e.g. INV-904"
                        className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs font-mono focus:outline-none focus:border-emerald-500"
                      />
                    </div>
                  </div>

                  {currentItem && (
                    <div className={`p-2.5 rounded-lg text-xs border ${
                      currentItem.leftCount - parsedQty < 0
                        ? 'bg-rose-500/15 border-rose-500/40 text-rose-300'
                        : 'bg-emerald-500/10 border-emerald-500/20 text-emerald-300'
                    }`}>
                      Outcome: Remaining left stock will update to{' '}
                      <strong>{currentItem.leftCount - parsedQty} {currentItem.unit}</strong>.
                      {calculatedTotal > 0 && ` Total sale revenue: $${calculatedTotal.toFixed(2)}.`}
                    </div>
                  )}
                </>
              )}

              {/* Specific inputs for COUNT_UPDATE (Audit / Physical Reconciliation) */}
              {activeMode === 'COUNT_UPDATE' && (
                <>
                  <div>
                    <label className="block text-xs font-medium text-slate-300 mb-1">
                      New Verified Left Count (Actual Physical Count) *
                    </label>
                    <input
                      type="number"
                      min="0"
                      required
                      value={quantity}
                      onChange={(e) => setQuantity(e.target.value)}
                      placeholder="e.g. 42"
                      className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-lg font-bold focus:outline-none focus:border-purple-500"
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-xs font-medium text-slate-300 mb-1">
                        Audit Reason
                      </label>
                      <select
                        value={auditReason}
                        onChange={(e) => setAuditReason(e.target.value)}
                        className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-purple-500"
                      >
                        <option value="Physical Inventory Audit">Physical Inventory Audit</option>
                        <option value="Damaged / Leaking Scrapped">Damaged / Leaking Scrapped</option>
                        <option value="Customer Demo / Sample Given">Customer Demo / Sample Given</option>
                        <option value="Returned from Customer">Returned from Customer</option>
                        <option value="Lost / Unaccounted Variance">Lost / Unaccounted Variance</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-slate-300 mb-1">
                        Audit Sheet Reference #
                      </label>
                      <input
                        type="text"
                        value={referenceNo}
                        onChange={(e) => setReferenceNo(e.target.value)}
                        placeholder="AUDIT-2026-09"
                        className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs font-mono focus:outline-none focus:border-purple-500"
                      />
                    </div>
                  </div>

                  {currentItem && (
                    <div className="p-2.5 rounded-lg bg-purple-500/10 border border-purple-500/20 text-xs text-purple-300">
                      Discrepancy adjustment: Recorded left was <strong>{currentItem.leftCount}</strong>.
                      New left will be <strong>{parsedQty}</strong> (Variance:{' '}
                      <strong className={parsedQty - currentItem.leftCount < 0 ? 'text-rose-400' : 'text-emerald-400'}>
                        {parsedQty - currentItem.leftCount >= 0 ? '+' : ''}{parsedQty - currentItem.leftCount}
                      </strong>).
                    </div>
                  )}
                </>
              )}

              {/* Notes field */}
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1">
                  Notes / Observations (Optional)
                </label>
                <input
                  type="text"
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="e.g. Inspected batch, box sealed, shelf checked..."
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-blue-500"
                />
              </div>
            </>
          )}

          {/* Form Content: NEW_ITEM */}
          {activeMode === 'NEW_ITEM' && (
            <div className="space-y-3">
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1">
                  Category *
                </label>
                <select
                  value={newCategory}
                  onChange={(e) => {
                    const cat = e.target.value as InventoryCategory;
                    setNewCategory(cat);
                    if (cat.includes('cartridge')) setNewUnit('cartridges');
                    else if (cat.includes('machine')) setNewUnit('sets');
                    else setNewUnit('units');
                  }}
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-sm focus:outline-none focus:border-amber-500"
                >
                  {CATEGORIES.map(c => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">
                    Item Name *
                  </label>
                  <input
                    type="text"
                    required
                    value={newName}
                    onChange={(e) => setNewName(e.target.value)}
                    placeholder="e.g. HP 2590 Ultra Fast Dry"
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-amber-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">
                    SKU / Model Code *
                  </label>
                  <input
                    type="text"
                    required
                    value={newSku}
                    onChange={(e) => setNewSku(e.target.value)}
                    placeholder="e.g. HP-2590-UFD"
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs font-mono focus:outline-none focus:border-amber-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-3 gap-2">
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">
                    Initial Total In
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={newInitialIn}
                    onChange={(e) => {
                      setNewInitialIn(e.target.value);
                      setNewInitialLeft(e.target.value);
                    }}
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-amber-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">
                    Initial Left
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={newInitialLeft}
                    onChange={(e) => setNewInitialLeft(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-amber-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">
                    Unit
                  </label>
                  <input
                    type="text"
                    value={newUnit}
                    onChange={(e) => setNewUnit(e.target.value)}
                    placeholder="cartridges, units..."
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-amber-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-3 gap-2">
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">
                    Cost Price ($)
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    value={newCostPrice}
                    onChange={(e) => setNewCostPrice(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-amber-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">
                    Selling Price ($)
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    value={newSellingPrice}
                    onChange={(e) => setNewSellingPrice(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-amber-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">
                    Min Alert Lvl
                  </label>
                  <input
                    type="number"
                    min="1"
                    value={newMinAlert}
                    onChange={(e) => setNewMinAlert(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-amber-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">
                    Warehouse Location
                  </label>
                  <input
                    type="text"
                    value={newLocation}
                    onChange={(e) => setNewLocation(e.target.value)}
                    placeholder="Rack A-01, Bay 2..."
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-amber-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">
                    Barcode / Serial
                  </label>
                  <input
                    type="text"
                    value={newBarcode}
                    onChange={(e) => setNewBarcode(e.target.value)}
                    placeholder="e.g. 89012345678"
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs font-mono focus:outline-none focus:border-amber-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1">
                  Item Description (Optional)
                </label>
                <input
                  type="text"
                  value={newDescription}
                  onChange={(e) => setNewDescription(e.target.value)}
                  placeholder="Application substrates, ink volume, nozzle size, features..."
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-100 text-xs focus:outline-none focus:border-amber-500"
                />
              </div>
            </div>
          )}

          {/* Action Button */}
          <div className="pt-2">
            <button
              type="submit"
              disabled={isSubmitting}
              className={`w-full py-3 px-4 rounded-xl text-white font-semibold text-sm shadow-md transition active:scale-98 flex items-center justify-center gap-2 ${
                activeMode === 'STOCK_IN'
                  ? 'bg-blue-600 hover:bg-blue-500 shadow-blue-500/25'
                  : activeMode === 'SOLD'
                  ? 'bg-emerald-600 hover:bg-emerald-500 shadow-emerald-500/25'
                  : activeMode === 'COUNT_UPDATE'
                  ? 'bg-purple-600 hover:bg-purple-500 shadow-purple-500/25'
                  : 'bg-amber-600 hover:bg-amber-500 shadow-amber-500/25'
              }`}
            >
              {isSubmitting ? (
                <span>Syncing across devices...</span>
              ) : activeMode === 'STOCK_IN' ? (
                <>
                  <ArrowDownRight className="w-4 h-4" />
                  Confirm Stock In & Sync
                </>
              ) : activeMode === 'SOLD' ? (
                <>
                  <ArrowUpRight className="w-4 h-4" />
                  Confirm Sold & Sync
                </>
              ) : activeMode === 'COUNT_UPDATE' ? (
                <>
                  <CheckCircle2 className="w-4 h-4" />
                  Confirm Left Count & Sync
                </>
              ) : (
                <>
                  <PlusCircle className="w-4 h-4" />
                  Create Item & Sync
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
