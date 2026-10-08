import React, { useMemo, useState } from 'react';
import {
  Download,
  Printer,
  Calendar,
  Filter,
  DollarSign,
  TrendingUp,
  Package,
  AlertTriangle,
  FileSpreadsheet,
  CheckCircle2,
} from 'lucide-react';
import { useInventory } from '../context/InventoryContext';
import { CATEGORIES } from '../data/initialData';
import { InventoryCategory, Transaction } from '../types';
import { sound } from '../lib/sound';

type ReportTab = 'stock_valuation' | 'sales_revenue' | 'low_stock' | 'category_breakdown';

export const ReportsView: React.FC = () => {
  const { items, transactions } = useInventory();

  const [activeReportTab, setActiveReportTab] = useState<ReportTab>('stock_valuation');
  const [dateFilter, setDateFilter] = useState<'all' | 'today' | 'week' | 'month'>('all');
  const [selectedCategory, setSelectedCategory] = useState<'all' | InventoryCategory>('all');
  const [exportNotice, setExportNotice] = useState<string | null>(null);

  // Filtered transactions by date & category
  const filteredTransactions = useMemo(() => {
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const startOfWeek = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).getTime();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).getTime();

    return transactions.filter(t => {
      // Category filter
      if (selectedCategory !== 'all' && t.category !== selectedCategory) {
        return false;
      }
      // Date filter
      const txTime = new Date(t.timestamp).getTime();
      if (dateFilter === 'today' && txTime < startOfToday) return false;
      if (dateFilter === 'week' && txTime < startOfWeek) return false;
      if (dateFilter === 'month' && txTime < startOfMonth) return false;
      return true;
    });
  }, [transactions, selectedCategory, dateFilter]);

  // Filtered items by category
  const filteredItems = useMemo(() => {
    if (selectedCategory === 'all') return items;
    return items.filter(i => i.category === selectedCategory);
  }, [items, selectedCategory]);

  // KPI Calculations
  const kpis = useMemo(() => {
    const totalInventoryValue = items.reduce((acc, curr) => acc + (curr.leftCount * curr.unitCostPrice), 0);
    const totalPotentialRevenue = items.reduce((acc, curr) => acc + (curr.leftCount * curr.unitSellingPrice), 0);

    const soldTransactions = filteredTransactions.filter(t => t.type === 'SOLD');
    const totalSoldRevenue = soldTransactions.reduce((acc, curr) => acc + (curr.totalAmount || 0), 0);
    const totalSoldUnits = soldTransactions.reduce((acc, curr) => acc + Math.abs(curr.quantityChange), 0);

    const lowStockCount = items.filter(i => i.leftCount <= i.minStockAlert).length;
    const outOfStockCount = items.filter(i => i.leftCount <= 0).length;

    return {
      totalInventoryValue,
      totalPotentialRevenue,
      totalSoldRevenue,
      totalSoldUnits,
      lowStockCount,
      outOfStockCount,
    };
  }, [items, filteredTransactions]);

  // CSV Export Handler
  const exportToCsv = () => {
    sound.playSuccess();
    let csvContent = '';
    let fileName = `inventory_report_${activeReportTab}_${new Date().toISOString().slice(0, 10)}.csv`;

    if (activeReportTab === 'stock_valuation' || activeReportTab === 'low_stock') {
      const exportList = activeReportTab === 'low_stock'
        ? filteredItems.filter(i => i.leftCount <= i.minStockAlert)
        : filteredItems;

      csvContent = 'SKU,Item Name,Category,Unit,Total In,Total Sold,Left Count,Min Alert,Unit Cost,Unit Selling,Inventory Cost Value,Status,Location\n';
      exportList.forEach(i => {
        const costVal = (i.leftCount * i.unitCostPrice).toFixed(2);
        const status = i.leftCount <= 0 ? 'OUT_OF_STOCK' : i.leftCount <= i.minStockAlert ? 'LOW_STOCK' : 'HEALTHY';
        csvContent += `"${i.sku}","${i.name.replace(/"/g, '""')}","${i.category}","${i.unit}",${i.totalIn},${i.totalSold},${i.leftCount},${i.minStockAlert},${i.unitCostPrice},${i.unitSellingPrice},${costVal},"${status}","${i.location || ''}"\n`;
      });
    } else if (activeReportTab === 'sales_revenue') {
      csvContent = 'Timestamp,Transaction ID,Item SKU,Item Name,Category,Quantity Sold,Unit Price,Total Revenue,Customer,Invoice Ref,Operator,Notes\n';
      const sales = filteredTransactions.filter(t => t.type === 'SOLD');
      sales.forEach(t => {
        csvContent += `"${t.timestamp}","${t.id}","${t.itemSku}","${t.itemName.replace(/"/g, '""')}","${t.category}",${Math.abs(t.quantityChange)},${t.unitPrice || 0},${t.totalAmount || 0},"${(t.customerOrSupplier || '').replace(/"/g, '""')}","${t.referenceNo || ''}","${t.operatorName}","${(t.notes || '').replace(/"/g, '""')}"\n`;
      });
    } else if (activeReportTab === 'category_breakdown') {
      csvContent = 'Category Name,Catalog Items,Total In Units,Total Sold Units,Current Left Units,Total Value ($)\n';
      CATEGORIES.forEach(cat => {
        const catItems = items.filter(i => i.category === cat.id);
        const inUnits = catItems.reduce((acc, c) => acc + c.totalIn, 0);
        const soldUnits = catItems.reduce((acc, c) => acc + c.totalSold, 0);
        const leftUnits = catItems.reduce((acc, c) => acc + c.leftCount, 0);
        const val = catItems.reduce((acc, c) => acc + (c.leftCount * c.unitCostPrice), 0).toFixed(2);
        csvContent += `"${cat.name}",${catItems.length},${inUnits},${soldUnits},${leftUnits},${val}\n`;
      });
    }

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', fileName);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    setExportNotice(`Report exported successfully as ${fileName}`);
    setTimeout(() => setExportNotice(null), 4000);
  };

  const handlePrint = () => {
    sound.playClick();
    window.print();
  };

  return (
    <div className="space-y-4 pb-24">
      {/* Top Header & Export controls */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-slate-800/90 border border-slate-700/80 rounded-2xl p-4 shadow-sm">
        <div>
          <h2 className="text-lg font-bold text-slate-100 flex items-center gap-2">
            <FileSpreadsheet className="w-5 h-5 text-blue-400" />
            Inventory & Sales Reports
          </h2>
          <p className="text-xs text-slate-400 mt-0.5">
            Real-time analytics for HP cartridges, Handy/Online/Docod printers, Rynan & machines
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handlePrint}
            className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-700 hover:bg-slate-600 text-slate-200 text-xs font-medium transition active:scale-95 border border-slate-600"
            title="Print or Save as PDF"
          >
            <Printer className="w-4 h-4" />
            <span>Print Report</span>
          </button>

          <button
            onClick={exportToCsv}
            className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold shadow-sm shadow-emerald-500/20 transition active:scale-95"
            title="Download CSV for Excel or Sheets"
          >
            <Download className="w-4 h-4" />
            <span>Export CSV</span>
          </button>
        </div>
      </div>

      {exportNotice && (
        <div className="p-3 rounded-xl bg-emerald-500/15 border border-emerald-500/40 text-emerald-300 text-xs flex items-center gap-2">
          <CheckCircle2 className="w-4 h-4 flex-shrink-0" />
          <span>{exportNotice}</span>
        </div>
      )}

      {/* KPI Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-2.5">
        <div className="bg-slate-800/80 border border-slate-700/70 rounded-xl p-3 shadow-sm">
          <div className="flex items-center justify-between text-slate-400 text-xs">
            <span>Sales Revenue</span>
            <DollarSign className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-xl font-bold text-emerald-400 mt-1">
            ${kpis.totalSoldRevenue.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </p>
          <p className="text-[11px] text-slate-400 mt-0.5">
            {kpis.totalSoldUnits} units sold in period
          </p>
        </div>

        <div className="bg-slate-800/80 border border-slate-700/70 rounded-xl p-3 shadow-sm">
          <div className="flex items-center justify-between text-slate-400 text-xs">
            <span>Inventory Valuation</span>
            <Package className="w-4 h-4 text-blue-400" />
          </div>
          <p className="text-xl font-bold text-slate-100 mt-1">
            ${kpis.totalInventoryValue.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 })}
          </p>
          <p className="text-[11px] text-slate-400 mt-0.5">
            Total asset cost value
          </p>
        </div>

        <div className="bg-slate-800/80 border border-slate-700/70 rounded-xl p-3 shadow-sm">
          <div className="flex items-center justify-between text-slate-400 text-xs">
            <span>Potential Sales Worth</span>
            <TrendingUp className="w-4 h-4 text-indigo-400" />
          </div>
          <p className="text-xl font-bold text-indigo-300 mt-1">
            ${kpis.totalPotentialRevenue.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 })}
          </p>
          <p className="text-[11px] text-slate-400 mt-0.5">
            At current selling prices
          </p>
        </div>

        <div className="bg-slate-800/80 border border-slate-700/70 rounded-xl p-3 shadow-sm">
          <div className="flex items-center justify-between text-slate-400 text-xs">
            <span>Critical Reorder</span>
            <AlertTriangle className="w-4 h-4 text-amber-400" />
          </div>
          <p className="text-xl font-bold text-amber-400 mt-1">
            {kpis.lowStockCount} items
          </p>
          <p className="text-[11px] text-amber-400/80 mt-0.5">
            {kpis.outOfStockCount} completely empty
          </p>
        </div>
      </div>

      {/* Filter Toolbar: Report Type Tabs & Filters */}
      <div className="bg-slate-800/90 border border-slate-700/70 rounded-2xl p-3 space-y-3">
        {/* Report Sub-Tabs */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar text-xs">
          <button
            onClick={() => {
              sound.playClick();
              setActiveReportTab('stock_valuation');
            }}
            className={`px-3 py-2 rounded-xl font-medium whitespace-nowrap transition ${
              activeReportTab === 'stock_valuation'
                ? 'bg-blue-600 text-white shadow-sm'
                : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
            }`}
          >
            📦 Stock Status & Valuation
          </button>

          <button
            onClick={() => {
              sound.playClick();
              setActiveReportTab('sales_revenue');
            }}
            className={`px-3 py-2 rounded-xl font-medium whitespace-nowrap transition ${
              activeReportTab === 'sales_revenue'
                ? 'bg-blue-600 text-white shadow-sm'
                : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
            }`}
          >
            💰 Sales & Dispatch Outward
          </button>

          <button
            onClick={() => {
              sound.playClick();
              setActiveReportTab('low_stock');
            }}
            className={`px-3 py-2 rounded-xl font-medium whitespace-nowrap transition ${
              activeReportTab === 'low_stock'
                ? 'bg-blue-600 text-white shadow-sm'
                : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
            }`}
          >
            ⚠️ Low Stock Alert ({kpis.lowStockCount})
          </button>

          <button
            onClick={() => {
              sound.playClick();
              setActiveReportTab('category_breakdown');
            }}
            className={`px-3 py-2 rounded-xl font-medium whitespace-nowrap transition ${
              activeReportTab === 'category_breakdown'
                ? 'bg-blue-600 text-white shadow-sm'
                : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
            }`}
          >
            📊 Category Analysis
          </button>
        </div>

        {/* Filters: Category & Date */}
        <div className="flex items-center gap-2 flex-wrap pt-1 border-t border-slate-700/60 text-xs">
          <div className="flex items-center gap-1 text-slate-400">
            <Filter className="w-3.5 h-3.5" />
            <span>Category:</span>
          </div>
          <select
            value={selectedCategory}
            onChange={(e) => {
              sound.playClick();
              setSelectedCategory(e.target.value as typeof selectedCategory);
            }}
            className="bg-slate-900 border border-slate-700 text-slate-200 rounded-lg px-2.5 py-1.5 focus:outline-none focus:border-blue-500"
          >
            <option value="all">All Categories</option>
            {CATEGORIES.map(c => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>

          {activeReportTab === 'sales_revenue' && (
            <>
              <div className="flex items-center gap-1 text-slate-400 ml-2">
                <Calendar className="w-3.5 h-3.5" />
                <span>Period:</span>
              </div>
              <select
                value={dateFilter}
                onChange={(e) => {
                  sound.playClick();
                  setDateFilter(e.target.value as typeof dateFilter);
                }}
                className="bg-slate-900 border border-slate-700 text-slate-200 rounded-lg px-2.5 py-1.5 focus:outline-none focus:border-blue-500"
              >
                <option value="all">All Recorded History</option>
                <option value="today">Today</option>
                <option value="week">Past 7 Days</option>
                <option value="month">This Month</option>
              </select>
            </>
          )}
        </div>
      </div>

      {/* Report Data Tables */}
      <div className="bg-slate-800/90 border border-slate-700/70 rounded-2xl overflow-hidden shadow-sm">
        {/* 1. STOCK VALUATION TABLE */}
        {activeReportTab === 'stock_valuation' && (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs text-slate-300">
              <thead className="bg-slate-900/90 text-slate-400 uppercase font-semibold text-[10px] tracking-wider border-b border-slate-700">
                <tr>
                  <th className="p-3">Item & SKU</th>
                  <th className="p-3">Category</th>
                  <th className="p-3 text-right">Total In</th>
                  <th className="p-3 text-right">Sold</th>
                  <th className="p-3 text-right font-bold text-blue-400">Left Count</th>
                  <th className="p-3 text-right">Cost Price</th>
                  <th className="p-3 text-right">Stock Valuation</th>
                  <th className="p-3 text-center">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-700/60">
                {filteredItems.map(item => {
                  const cat = CATEGORIES.find(c => c.id === item.category);
                  const isLow = item.leftCount <= item.minStockAlert;
                  const isOut = item.leftCount <= 0;
                  const val = item.leftCount * item.unitCostPrice;

                  return (
                    <tr key={item.id} className="hover:bg-slate-750 transition">
                      <td className="p-3">
                        <div className="font-semibold text-slate-100">{item.name}</div>
                        <div className="text-[10px] font-mono text-slate-400">{item.sku}</div>
                      </td>
                      <td className="p-3 text-slate-400">
                        {cat?.name || item.category}
                      </td>
                      <td className="p-3 text-right font-mono">{item.totalIn}</td>
                      <td className="p-3 text-right font-mono text-emerald-400">{item.totalSold}</td>
                      <td className="p-3 text-right font-mono font-bold text-sm text-slate-100">
                        {item.leftCount} <span className="text-[10px] text-slate-400 font-normal">{item.unit}</span>
                      </td>
                      <td className="p-3 text-right font-mono">${item.unitCostPrice.toFixed(2)}</td>
                      <td className="p-3 text-right font-mono font-semibold text-slate-100">${val.toFixed(2)}</td>
                      <td className="p-3 text-center">
                        {isOut ? (
                          <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-rose-500/20 text-rose-400 border border-rose-500/30">
                            Out of Stock
                          </span>
                        ) : isLow ? (
                          <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-amber-500/20 text-amber-400 border border-amber-500/30">
                            Low Stock (≤{item.minStockAlert})
                          </span>
                        ) : (
                          <span className="px-2 py-0.5 rounded text-[10px] font-medium bg-emerald-500/20 text-emerald-300">
                            Adequate
                          </span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}

        {/* 2. SALES & REVENUE TABLE */}
        {activeReportTab === 'sales_revenue' && (
          <div className="overflow-x-auto">
            {filteredTransactions.filter(t => t.type === 'SOLD').length === 0 ? (
              <div className="p-8 text-center text-slate-400 text-xs">
                No sold outward transactions found for the selected filter period.
              </div>
            ) : (
              <table className="w-full text-left text-xs text-slate-300">
                <thead className="bg-slate-900/90 text-slate-400 uppercase font-semibold text-[10px] tracking-wider border-b border-slate-700">
                  <tr>
                    <th className="p-3">Date & Time</th>
                    <th className="p-3">Item Name</th>
                    <th className="p-3">Customer</th>
                    <th className="p-3">Invoice #</th>
                    <th className="p-3 text-right font-bold text-emerald-400">Sold Qty</th>
                    <th className="p-3 text-right">Unit Price</th>
                    <th className="p-3 text-right font-bold text-slate-100">Total Revenue</th>
                    <th className="p-3">Operator</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-700/60">
                  {filteredTransactions
                    .filter(t => t.type === 'SOLD')
                    .map(tx => (
                      <tr key={tx.id} className="hover:bg-slate-750 transition">
                        <td className="p-3 text-slate-400 font-mono text-[11px]">
                          {new Date(tx.timestamp).toLocaleDateString()} {new Date(tx.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                        </td>
                        <td className="p-3">
                          <div className="font-semibold text-slate-100">{tx.itemName}</div>
                          <div className="text-[10px] font-mono text-slate-400">{tx.itemSku}</div>
                        </td>
                        <td className="p-3 font-medium text-slate-200">
                          {tx.customerOrSupplier || 'Direct Client'}
                        </td>
                        <td className="p-3 font-mono text-blue-400">
                          {tx.referenceNo || '—'}
                        </td>
                        <td className="p-3 text-right font-mono font-bold text-emerald-400 text-sm">
                          {Math.abs(tx.quantityChange)}
                        </td>
                        <td className="p-3 text-right font-mono">
                          ${(tx.unitPrice || 0).toFixed(2)}
                        </td>
                        <td className="p-3 text-right font-mono font-bold text-slate-100 text-sm">
                          ${(tx.totalAmount || 0).toFixed(2)}
                        </td>
                        <td className="p-3 text-slate-300">
                          <span className="px-1.5 py-0.5 rounded bg-slate-700 text-[10px] text-slate-200">
                            {tx.operatorName.split(' ')[0]}
                          </span>
                        </td>
                      </tr>
                    ))}
                </tbody>
              </table>
            )}
          </div>
        )}

        {/* 3. LOW STOCK & REORDER TABLE */}
        {activeReportTab === 'low_stock' && (
          <div className="overflow-x-auto">
            {filteredItems.filter(i => i.leftCount <= i.minStockAlert).length === 0 ? (
              <div className="p-8 text-center text-slate-400 text-xs">
                No items are currently below their minimum threshold. All inventory levels are healthy!
              </div>
            ) : (
              <table className="w-full text-left text-xs text-slate-300">
                <thead className="bg-slate-900/90 text-slate-400 uppercase font-semibold text-[10px] tracking-wider border-b border-slate-700">
                  <tr>
                    <th className="p-3">Item & Code</th>
                    <th className="p-3">Location</th>
                    <th className="p-3 text-right font-bold text-rose-400">Left Count</th>
                    <th className="p-3 text-right">Min Threshold</th>
                    <th className="p-3 text-right font-bold text-amber-400">Units Needed</th>
                    <th className="p-3 text-right">Unit Cost</th>
                    <th className="p-3 text-right font-bold">Estimated Restock Cost</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-700/60">
                  {filteredItems
                    .filter(i => i.leftCount <= i.minStockAlert)
                    .map(item => {
                      const needed = Math.max(item.minStockAlert * 2 - item.leftCount, item.minStockAlert);
                      const restockCost = needed * item.unitCostPrice;

                      return (
                        <tr key={item.id} className="hover:bg-slate-750 transition">
                          <td className="p-3">
                            <div className="font-semibold text-slate-100">{item.name}</div>
                            <div className="text-[10px] font-mono text-slate-400">{item.sku}</div>
                          </td>
                          <td className="p-3 text-slate-400">{item.location || '—'}</td>
                          <td className="p-3 text-right font-mono font-bold text-sm text-rose-400">
                            {item.leftCount} {item.unit}
                          </td>
                          <td className="p-3 text-right font-mono">{item.minStockAlert}</td>
                          <td className="p-3 text-right font-mono font-bold text-amber-400">
                            +{needed}
                          </td>
                          <td className="p-3 text-right font-mono">${item.unitCostPrice.toFixed(2)}</td>
                          <td className="p-3 text-right font-mono font-bold text-slate-100">
                            ${restockCost.toFixed(2)}
                          </td>
                        </tr>
                      );
                    })}
                </tbody>
              </table>
            )}
          </div>
        )}

        {/* 4. CATEGORY BREAKDOWN TABLE */}
        {activeReportTab === 'category_breakdown' && (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs text-slate-300">
              <thead className="bg-slate-900/90 text-slate-400 uppercase font-semibold text-[10px] tracking-wider border-b border-slate-700">
                <tr>
                  <th className="p-3">Category</th>
                  <th className="p-3 text-right">Items in Catalog</th>
                  <th className="p-3 text-right">Total Influx (Total In)</th>
                  <th className="p-3 text-right font-bold text-emerald-400">Units Sold</th>
                  <th className="p-3 text-right font-bold text-blue-400">Current Left</th>
                  <th className="p-3 text-right font-bold text-slate-100">Total Asset Value</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-700/60">
                {CATEGORIES.map(cat => {
                  const catItems = items.filter(i => i.category === cat.id);
                  const inUnits = catItems.reduce((acc, c) => acc + c.totalIn, 0);
                  const soldUnits = catItems.reduce((acc, c) => acc + c.totalSold, 0);
                  const leftUnits = catItems.reduce((acc, c) => acc + c.leftCount, 0);
                  const totalVal = catItems.reduce((acc, c) => acc + (c.leftCount * c.unitCostPrice), 0);

                  return (
                    <tr key={cat.id} className="hover:bg-slate-750 transition">
                      <td className="p-3">
                        <div className="font-semibold text-slate-100">{cat.name}</div>
                        <div className="text-[10px] text-slate-400">{cat.description}</div>
                      </td>
                      <td className="p-3 text-right font-mono">{catItems.length}</td>
                      <td className="p-3 text-right font-mono">{inUnits}</td>
                      <td className="p-3 text-right font-mono font-bold text-emerald-400">{soldUnits}</td>
                      <td className="p-3 text-right font-mono font-bold text-blue-400 text-sm">{leftUnits}</td>
                      <td className="p-3 text-right font-mono font-bold text-slate-100">${totalVal.toFixed(2)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};
