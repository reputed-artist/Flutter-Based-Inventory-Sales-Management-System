import React, { useMemo, useState } from 'react';
import {
  History,
  ArrowDownRight,
  ArrowUpRight,
  CheckCircle2,
  PlusCircle,
  Filter,
  User,
  Clock,
  FileText,
  Search,
} from 'lucide-react';
import { useInventory } from '../context/InventoryContext';
import { TransactionType } from '../types';
import { sound } from '../lib/sound';

export const AuditLogView: React.FC = () => {
  const { transactions, operators } = useInventory();

  const [typeFilter, setTypeFilter] = useState<'all' | TransactionType>('all');
  const [operatorFilter, setOperatorFilter] = useState<'all' | string>('all');
  const [searchQuery, setSearchQuery] = useState('');

  const filteredLogs = useMemo(() => {
    return transactions.filter(tx => {
      if (typeFilter !== 'all' && tx.type !== typeFilter) return false;
      if (operatorFilter !== 'all' && tx.operatorName !== operatorFilter) return false;
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const matchName = tx.itemName.toLowerCase().includes(q);
        const matchSku = tx.itemSku.toLowerCase().includes(q);
        const matchRef = tx.referenceNo?.toLowerCase().includes(q) || false;
        const matchParty = tx.customerOrSupplier?.toLowerCase().includes(q) || false;
        const matchNotes = tx.notes?.toLowerCase().includes(q) || false;
        return matchName || matchSku || matchRef || matchParty || matchNotes;
      }
      return true;
    });
  }, [transactions, typeFilter, operatorFilter, searchQuery]);

  const getTypeBadge = (type: TransactionType) => {
    switch (type) {
      case 'STOCK_IN':
        return {
          label: 'Stock In (+)',
          icon: ArrowDownRight,
          color: 'bg-blue-500/20 text-blue-300 border-blue-500/30',
          badgeColor: 'text-blue-400',
        };
      case 'SOLD':
        return {
          label: 'Sold Out (-)',
          icon: ArrowUpRight,
          color: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30',
          badgeColor: 'text-emerald-400',
        };
      case 'COUNT_UPDATE':
        return {
          label: 'Count Audit (Left)',
          icon: CheckCircle2,
          color: 'bg-purple-500/20 text-purple-300 border-purple-500/30',
          badgeColor: 'text-purple-400',
        };
      case 'ITEM_CREATED':
      default:
        return {
          label: 'New Catalog Item',
          icon: PlusCircle,
          color: 'bg-amber-500/20 text-amber-300 border-amber-500/30',
          badgeColor: 'text-amber-400',
        };
    }
  };

  return (
    <div className="space-y-4 pb-24">
      {/* Header */}
      <div className="bg-slate-800/90 border border-slate-700/80 rounded-2xl p-4 shadow-sm flex items-center justify-between">
        <div>
          <h2 className="text-lg font-bold text-slate-100 flex items-center gap-2">
            <History className="w-5 h-5 text-blue-400" />
            Live Sync Activity Feed
          </h2>
          <p className="text-xs text-slate-400 mt-0.5">
            Audit trail of all multi-user stock inputs, sales entries, and left count updates
          </p>
        </div>
        <div className="text-right">
          <span className="text-xs text-slate-400">Total Events:</span>
          <span className="font-bold text-slate-100 ml-1 font-mono text-sm">{transactions.length}</span>
        </div>
      </div>

      {/* Filter Bar */}
      <div className="bg-slate-800/90 border border-slate-700/70 rounded-2xl p-3 space-y-3">
        {/* Search */}
        <div className="relative">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search by SKU, item, customer, invoice #, PO..."
            className="w-full pl-9 pr-4 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-slate-100 placeholder-slate-400 focus:outline-none focus:border-blue-500"
          />
        </div>

        {/* Action Type & Operator Dropdowns */}
        <div className="flex items-center gap-2 flex-wrap text-xs">
          <div className="flex items-center gap-1 text-slate-400">
            <Filter className="w-3.5 h-3.5" />
            <span>Action:</span>
          </div>
          <select
            value={typeFilter}
            onChange={(e) => {
              sound.playClick();
              setTypeFilter(e.target.value as typeof typeFilter);
            }}
            className="bg-slate-900 border border-slate-700 text-slate-200 rounded-lg px-2.5 py-1.5 focus:outline-none focus:border-blue-500"
          >
            <option value="all">All Actions</option>
            <option value="STOCK_IN">Stock In (+)</option>
            <option value="SOLD">Sold Out (-)</option>
            <option value="COUNT_UPDATE">Count Audit</option>
            <option value="ITEM_CREATED">New Item Created</option>
          </select>

          <div className="flex items-center gap-1 text-slate-400 ml-2">
            <User className="w-3.5 h-3.5" />
            <span>Operator:</span>
          </div>
          <select
            value={operatorFilter}
            onChange={(e) => {
              sound.playClick();
              setOperatorFilter(e.target.value);
            }}
            className="bg-slate-900 border border-slate-700 text-slate-200 rounded-lg px-2.5 py-1.5 focus:outline-none focus:border-blue-500"
          >
            <option value="all">All Operators</option>
            {operators.map(op => (
              <option key={op.id} value={op.name}>{op.name}</option>
            ))}
          </select>
        </div>
      </div>

      {/* Transaction Feed */}
      <div className="space-y-2.5">
        {filteredLogs.length === 0 ? (
          <div className="bg-slate-800/40 border border-dashed border-slate-700 rounded-2xl p-8 text-center text-slate-400 text-xs">
            No transaction logs found matching the filter criteria.
          </div>
        ) : (
          filteredLogs.map(tx => {
            const badge = getTypeBadge(tx.type);
            const Icon = badge.icon;
            const op = operators.find(o => o.name === tx.operatorName);

            return (
              <div
                key={tx.id}
                className="bg-slate-800/90 border border-slate-700/80 rounded-2xl p-3.5 shadow-sm hover:border-slate-600 transition"
              >
                {/* Header row: Badge, Timestamp, Operator */}
                <div className="flex items-center justify-between gap-2 flex-wrap">
                  <div className="flex items-center gap-2">
                    <span className={`flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold border ${badge.color}`}>
                      <Icon className="w-3 h-3" />
                      {badge.label}
                    </span>
                    <span className="text-[10px] font-mono text-slate-400">
                      {tx.itemSku}
                    </span>
                  </div>

                  <div className="flex items-center gap-2 text-xs">
                    <div className="flex items-center gap-1.5 px-2 py-0.5 rounded-full bg-slate-900 border border-slate-700/70 text-[10px] text-slate-300">
                      <div
                        className="w-3.5 h-3.5 rounded-full flex items-center justify-center text-[8px] font-bold text-white"
                        style={{ backgroundColor: op?.avatarColor || '#3b82f6' }}
                      >
                        {tx.operatorName.charAt(0)}
                      </div>
                      <span>{tx.operatorName.split(' ')[0]}</span>
                    </div>

                    <span className="text-[10px] text-slate-400 flex items-center gap-1 font-mono">
                      <Clock className="w-3 h-3 text-slate-500" />
                      {new Date(tx.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </span>
                  </div>
                </div>

                {/* Main Body */}
                <div className="mt-2 flex items-start justify-between gap-3">
                  <div>
                    <h3 className="text-sm font-semibold text-slate-100">
                      {tx.itemName}
                    </h3>

                    {tx.customerOrSupplier && (
                      <p className="text-xs text-slate-300 mt-0.5">
                        <strong className="text-slate-400 font-normal">Party: </strong>
                        {tx.customerOrSupplier}
                        {tx.referenceNo && (
                          <span className="ml-1.5 font-mono text-[11px] text-blue-400">
                            ({tx.referenceNo})
                          </span>
                        )}
                      </p>
                    )}

                    {tx.notes && (
                      <p className="text-[11px] text-slate-400 mt-1 italic flex items-center gap-1">
                        <FileText className="w-3 h-3 text-slate-500 flex-shrink-0" />
                        <span>"{tx.notes}"</span>
                      </p>
                    )}
                  </div>

                  {/* Quantity & Stock Delta Box */}
                  <div className="text-right flex-shrink-0">
                    <div className={`text-lg font-black font-mono leading-none ${
                      tx.quantityChange > 0 ? 'text-blue-400' : tx.quantityChange < 0 ? 'text-emerald-400' : 'text-slate-300'
                    }`}>
                      {tx.quantityChange > 0 ? `+${tx.quantityChange}` : tx.quantityChange}
                    </div>

                    <div className="text-[10px] text-slate-400 mt-1 font-mono">
                      {tx.previousLeftCount} → <strong className="text-slate-200">{tx.newLeftCount}</strong> left
                    </div>

                    {tx.totalAmount != null && tx.totalAmount > 0 && (
                      <div className="text-[10px] font-bold text-emerald-400 font-mono mt-0.5">
                        ${tx.totalAmount.toFixed(2)}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
