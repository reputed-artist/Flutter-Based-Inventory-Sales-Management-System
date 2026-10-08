import React, { useMemo, useState } from 'react';
import {
  Search,
  Plus,
  AlertTriangle,
  ArrowDownRight,
  ArrowUpRight,
  SlidersHorizontal,
  PackagePlus,
  Layers,
  CheckCircle2,
  MapPin,
  TrendingDown,
  TrendingUp,
} from 'lucide-react';
import { useInventory } from '../context/InventoryContext';
import { CATEGORIES } from '../data/initialData';
import { InventoryCategory, InventoryItem } from '../types';
import { sound } from '../lib/sound';

export const InventoryView: React.FC = () => {
  const {
    items,
    selectedCategory,
    setSelectedCategory,
    searchQuery,
    setSearchQuery,
    openQuickAction,
    setDetailModalItem,
    setScannerModalOpen,
  } = useInventory();

  const [sortOption, setSortOption] = useState<'name' | 'left_asc' | 'left_desc' | 'sold_desc'>('name');
  const [showLowStockOnly, setShowLowStockOnly] = useState(false);

  // Compute stats
  const stats = useMemo(() => {
    const totalItems = items.length;
    const lowStockItems = items.filter(i => i.leftCount <= i.minStockAlert).length;
    const totalUnitsLeft = items.reduce((acc, curr) => acc + curr.leftCount, 0);
    const totalUnitsSold = items.reduce((acc, curr) => acc + curr.totalSold, 0);
    const totalInventoryValue = items.reduce((acc, curr) => acc + (curr.leftCount * curr.unitCostPrice), 0);

    return { totalItems, lowStockItems, totalUnitsLeft, totalUnitsSold, totalInventoryValue };
  }, [items]);

  // Filtered and sorted items
  const filteredItems = useMemo(() => {
    return items
      .filter((item) => {
        // Category filter
        if (selectedCategory !== 'all' && item.category !== selectedCategory) {
          return false;
        }
        // Low stock filter
        if (showLowStockOnly && item.leftCount > item.minStockAlert) {
          return false;
        }
        // Search filter
        if (searchQuery.trim()) {
          const q = searchQuery.toLowerCase();
          const matchName = item.name.toLowerCase().includes(q);
          const matchSku = item.sku.toLowerCase().includes(q);
          const matchLocation = item.location?.toLowerCase().includes(q) || false;
          const matchBarcode = item.barcode?.toLowerCase().includes(q) || false;
          return matchName || matchSku || matchLocation || matchBarcode;
        }
        return true;
      })
      .sort((a, b) => {
        if (sortOption === 'left_asc') return a.leftCount - b.leftCount;
        if (sortOption === 'left_desc') return b.leftCount - a.leftCount;
        if (sortOption === 'sold_desc') return b.totalSold - a.totalSold;
        return a.name.localeCompare(b.name);
      });
  }, [items, selectedCategory, showLowStockOnly, searchQuery, sortOption]);

  const getCategoryMeta = (catId: InventoryCategory) => {
    return CATEGORIES.find(c => c.id === catId) || CATEGORIES[0];
  };

  const getCategoryCount = (catId: 'all' | InventoryCategory) => {
    if (catId === 'all') return items.length;
    return items.filter(i => i.category === catId).length;
  };

  return (
    <div className="space-y-4 pb-24">
      {/* Top Metrics Banner */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
        <div className="bg-slate-800/80 border border-slate-700/70 rounded-xl p-3 shadow-sm">
          <div className="flex items-center justify-between text-slate-400">
            <span className="text-xs font-medium">Stock Left</span>
            <Layers className="w-4 h-4 text-blue-400" />
          </div>
          <p className="text-xl sm:text-2xl font-bold text-slate-100 mt-1">
            {stats.totalUnitsLeft} <span className="text-xs font-normal text-slate-400">units</span>
          </p>
          <p className="text-[11px] text-slate-400 mt-0.5">Across {stats.totalItems} catalog items</p>
        </div>

        <div className="bg-slate-800/80 border border-slate-700/70 rounded-xl p-3 shadow-sm">
          <div className="flex items-center justify-between text-slate-400">
            <span className="text-xs font-medium">Total Sold</span>
            <TrendingUp className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-xl sm:text-2xl font-bold text-emerald-400 mt-1">
            {stats.totalUnitsSold} <span className="text-xs font-normal text-emerald-500">sold</span>
          </p>
          <p className="text-[11px] text-slate-400 mt-0.5">Cumulative sales out</p>
        </div>

        <button
          onClick={() => {
            sound.playClick();
            setShowLowStockOnly(prev => !prev);
          }}
          className={`rounded-xl p-3 border text-left transition ${
            showLowStockOnly
              ? 'bg-rose-500/20 border-rose-500/50 shadow-sm'
              : stats.lowStockItems > 0
              ? 'bg-amber-500/10 border-amber-500/40 hover:bg-amber-500/15'
              : 'bg-slate-800/80 border-slate-700/70'
          }`}
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-amber-300">Low Stock Alert</span>
            <AlertTriangle className="w-4 h-4 text-amber-400" />
          </div>
          <p className={`text-xl sm:text-2xl font-bold mt-1 ${stats.lowStockItems > 0 ? 'text-amber-400' : 'text-slate-100'}`}>
            {stats.lowStockItems}
          </p>
          <p className="text-[11px] text-amber-400/80 mt-0.5">
            {showLowStockOnly ? 'Filtered: Tap to reset' : 'Below reorder level'}
          </p>
        </button>

        <div className="bg-slate-800/80 border border-slate-700/70 rounded-xl p-3 shadow-sm">
          <div className="flex items-center justify-between text-slate-400">
            <span className="text-xs font-medium">Inventory Value</span>
            <span className="text-[10px] font-semibold px-1.5 py-0.5 rounded bg-blue-500/20 text-blue-300">Cost</span>
          </div>
          <p className="text-xl sm:text-2xl font-bold text-slate-100 mt-1">
            ${stats.totalInventoryValue.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 })}
          </p>
          <p className="text-[11px] text-slate-400 mt-0.5">Verified shelf worth</p>
        </div>
      </div>

      {/* Quick In/Out/Audit Operation Buttons */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1 no-scrollbar">
        <button
          onClick={() => openQuickAction('STOCK_IN')}
          className="flex-1 min-w-[130px] flex items-center justify-center gap-2 py-2.5 px-3 rounded-xl bg-blue-600 hover:bg-blue-500 active:scale-95 transition text-white text-xs font-semibold shadow-sm shadow-blue-500/20"
        >
          <ArrowDownRight className="w-4 h-4" />
          Insert Count (+In)
        </button>

        <button
          onClick={() => openQuickAction('SOLD')}
          className="flex-1 min-w-[130px] flex items-center justify-center gap-2 py-2.5 px-3 rounded-xl bg-emerald-600 hover:bg-emerald-500 active:scale-95 transition text-white text-xs font-semibold shadow-sm shadow-emerald-500/20"
        >
          <ArrowUpRight className="w-4 h-4" />
          Enter Sold (-Out)
        </button>

        <button
          onClick={() => openQuickAction('COUNT_UPDATE')}
          className="flex-1 min-w-[130px] flex items-center justify-center gap-2 py-2.5 px-3 rounded-xl bg-purple-600 hover:bg-purple-500 active:scale-95 transition text-white text-xs font-semibold shadow-sm shadow-purple-500/20"
        >
          <CheckCircle2 className="w-4 h-4" />
          Update Left (Audit)
        </button>

        <button
          onClick={() => openQuickAction('NEW_ITEM')}
          className="flex items-center justify-center gap-1.5 py-2.5 px-3.5 rounded-xl bg-slate-800 hover:bg-slate-700 active:scale-95 transition text-slate-200 text-xs font-semibold border border-slate-700"
          title="Add New Inventory Item"
        >
          <Plus className="w-4 h-4" />
          <span className="hidden sm:inline">Add Item</span>
        </button>
      </div>

      {/* Search Bar & Sorting */}
      <div className="flex items-center gap-2">
        <div className="relative flex-1">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search HP cartridges, Handy/Docod printer, Rynan, SKU..."
            className="w-full pl-9 pr-8 py-2 bg-slate-800/90 border border-slate-700/80 rounded-xl text-sm text-slate-100 placeholder-slate-400 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-200 text-xs p-1"
            >
              ✕
            </button>
          )}
        </div>

        {/* Sort dropdown */}
        <div className="relative flex items-center">
          <select
            value={sortOption}
            onChange={(e) => {
              sound.playClick();
              setSortOption(e.target.value as typeof sortOption);
            }}
            className="bg-slate-800 border border-slate-700 text-slate-300 text-xs rounded-xl px-2.5 py-2 appearance-none pr-7 focus:outline-none focus:border-blue-500"
          >
            <option value="name">Name (A-Z)</option>
            <option value="left_asc">Stock: Low to High</option>
            <option value="left_desc">Stock: High to Low</option>
            <option value="sold_desc">Most Sold</option>
          </select>
          <SlidersHorizontal className="w-3.5 h-3.5 text-slate-400 absolute right-2 pointer-events-none" />
        </div>
      </div>

      {/* Categories Horizontal Tabs */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar -mx-2 px-2">
        <button
          onClick={() => {
            sound.playClick();
            setSelectedCategory('all');
          }}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-medium whitespace-nowrap transition-all ${
            selectedCategory === 'all'
              ? 'bg-blue-600 text-white shadow-sm shadow-blue-500/20'
              : 'bg-slate-800 text-slate-400 hover:text-slate-200 hover:bg-slate-750 border border-slate-700/50'
          }`}
        >
          <span>All</span>
          <span className={`text-[10px] px-1.5 py-0.2 rounded-full ${
            selectedCategory === 'all' ? 'bg-blue-700 text-blue-100' : 'bg-slate-700 text-slate-300'
          }`}>
            {getCategoryCount('all')}
          </span>
        </button>

        {CATEGORIES.map((cat) => {
          const isSelected = selectedCategory === cat.id;
          const count = getCategoryCount(cat.id);
          return (
            <button
              key={cat.id}
              onClick={() => {
                sound.playClick();
                setSelectedCategory(cat.id);
              }}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-medium whitespace-nowrap transition-all ${
                isSelected
                  ? 'bg-blue-600 text-white shadow-sm shadow-blue-500/20'
                  : 'bg-slate-800 text-slate-400 hover:text-slate-200 hover:bg-slate-750 border border-slate-700/50'
              }`}
            >
              <span>{cat.name}</span>
              <span className={`text-[10px] px-1.5 py-0.2 rounded-full ${
                isSelected ? 'bg-blue-700 text-blue-100' : 'bg-slate-700 text-slate-300'
              }`}>
                {count}
              </span>
            </button>
          );
        })}
      </div>

      {/* Item List Grid */}
      <div className="space-y-2.5">
        {filteredItems.length === 0 ? (
          <div className="bg-slate-800/40 border border-dashed border-slate-700 rounded-2xl p-8 text-center">
            <PackagePlus className="w-12 h-12 text-slate-500 mx-auto mb-3 opacity-60" />
            <h3 className="text-base font-semibold text-slate-200">No items match your criteria</h3>
            <p className="text-xs text-slate-400 mt-1 max-w-sm mx-auto">
              {showLowStockOnly
                ? 'Great news! There are currently no items under the low-stock alert threshold.'
                : 'Try adjusting your search query, clearing filters, or adding a new item.'}
            </p>
            <div className="flex items-center justify-center gap-2 mt-4">
              {showLowStockOnly && (
                <button
                  onClick={() => setShowLowStockOnly(false)}
                  className="px-3 py-1.5 rounded-lg bg-slate-700 text-slate-200 text-xs font-medium hover:bg-slate-600"
                >
                  Clear Low Stock Filter
                </button>
              )}
              <button
                onClick={() => openQuickAction('NEW_ITEM')}
                className="px-3.5 py-1.5 rounded-lg bg-blue-600 text-white text-xs font-medium hover:bg-blue-500"
              >
                + Add New Inventory Item
              </button>
            </div>
          </div>
        ) : (
          filteredItems.map((item) => {
            const cat = getCategoryMeta(item.category);
            const isLowStock = item.leftCount <= item.minStockAlert;
            const isOutOfStock = item.leftCount <= 0;

            return (
              <div
                key={item.id}
                className={`bg-slate-800/90 border rounded-2xl p-3.5 transition-all shadow-sm hover:border-slate-600 ${
                  isOutOfStock
                    ? 'border-rose-500/60 bg-rose-950/10'
                    : isLowStock
                    ? 'border-amber-500/50 bg-amber-950/10'
                    : 'border-slate-700/80'
                }`}
              >
                {/* Header info row */}
                <div className="flex items-start justify-between gap-3">
                  <div
                    className="flex-1 cursor-pointer"
                    onClick={() => {
                      sound.playClick();
                      setDetailModalItem(item);
                    }}
                  >
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-[10px] font-mono font-semibold px-2 py-0.5 rounded-md bg-slate-700/80 text-blue-300 border border-slate-600/50">
                        {item.sku}
                      </span>
                      <span className="text-[10px] font-medium text-slate-400">
                        {cat.name}
                      </span>
                      {isOutOfStock ? (
                        <span className="text-[10px] font-bold px-1.5 py-0.2 rounded bg-rose-500/20 text-rose-400 border border-rose-500/30 flex items-center gap-1">
                          <AlertTriangle className="w-3 h-3" /> Out of Stock
                        </span>
                      ) : isLowStock ? (
                        <span className="text-[10px] font-bold px-1.5 py-0.2 rounded bg-amber-500/20 text-amber-400 border border-amber-500/30 flex items-center gap-1">
                          <AlertTriangle className="w-3 h-3" /> Low Stock
                        </span>
                      ) : null}
                    </div>

                    <h3 className="text-sm font-semibold text-slate-100 mt-1 hover:text-blue-400 transition">
                      {item.name}
                    </h3>

                    {item.location && (
                      <p className="text-[11px] text-slate-400 flex items-center gap-1 mt-0.5">
                        <MapPin className="w-3 h-3 text-slate-500 flex-shrink-0" />
                        <span>{item.location}</span>
                      </p>
                    )}
                  </div>

                  {/* Stock Left Big Stat Badge */}
                  <div
                    className="text-right cursor-pointer flex-shrink-0"
                    onClick={() => {
                      sound.playClick();
                      setDetailModalItem(item);
                    }}
                  >
                    <div className="text-[10px] text-slate-400 font-medium uppercase tracking-wider">
                      Left Stock
                    </div>
                    <div className={`text-2xl font-black leading-tight ${
                      isOutOfStock ? 'text-rose-400' : isLowStock ? 'text-amber-400' : 'text-emerald-400'
                    }`}>
                      {item.leftCount}
                      <span className="text-[10px] font-normal text-slate-400 ml-1">
                        {item.unit}
                      </span>
                    </div>
                    <div className="text-[10px] text-slate-400">
                      Alert at ≤{item.minStockAlert}
                    </div>
                  </div>
                </div>

                {/* Sub row: In / Sold & Price specs */}
                <div className="mt-2.5 pt-2 border-t border-slate-700/60 flex items-center justify-between gap-2 text-xs flex-wrap">
                  <div className="flex items-center gap-3 text-[11px] text-slate-300">
                    <span className="flex items-center gap-1">
                      <span className="text-slate-400">Total In:</span>
                      <strong className="text-slate-100">{item.totalIn}</strong>
                    </span>
                    <span className="text-slate-600">|</span>
                    <span className="flex items-center gap-1">
                      <span className="text-slate-400">Sold:</span>
                      <strong className="text-emerald-400">{item.totalSold}</strong>
                    </span>
                    <span className="text-slate-600">|</span>
                    <span className="flex items-center gap-1">
                      <span className="text-slate-400">Sell Price:</span>
                      <strong className="text-slate-100">${item.unitSellingPrice}</strong>
                    </span>
                  </div>

                  <span className="text-[10px] text-slate-400 ml-auto">
                    By {item.lastUpdatedBy.split(' ')[0]}
                  </span>
                </div>

                {/* Android Quick Action Buttons for this item */}
                <div className="grid grid-cols-3 gap-1.5 mt-3">
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      openQuickAction('STOCK_IN', item);
                    }}
                    className="flex items-center justify-center gap-1 py-1.5 px-2 rounded-lg bg-blue-500/15 hover:bg-blue-500/25 text-blue-300 border border-blue-500/30 text-xs font-medium active:scale-95 transition"
                    title={`Insert more count for ${item.name}`}
                  >
                    <ArrowDownRight className="w-3.5 h-3.5" />
                    <span>+ In Stock</span>
                  </button>

                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      openQuickAction('SOLD', item);
                    }}
                    className="flex items-center justify-center gap-1 py-1.5 px-2 rounded-lg bg-emerald-500/15 hover:bg-emerald-500/25 text-emerald-300 border border-emerald-500/30 text-xs font-medium active:scale-95 transition"
                    title={`Record sold outward for ${item.name}`}
                  >
                    <ArrowUpRight className="w-3.5 h-3.5" />
                    <span>- Sold Out</span>
                  </button>

                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      openQuickAction('COUNT_UPDATE', item);
                    }}
                    className="flex items-center justify-center gap-1 py-1.5 px-2 rounded-lg bg-purple-500/15 hover:bg-purple-500/25 text-purple-300 border border-purple-500/30 text-xs font-medium active:scale-95 transition"
                    title={`Audit physical verified left count for ${item.name}`}
                  >
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    <span>Audit Count</span>
                  </button>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
