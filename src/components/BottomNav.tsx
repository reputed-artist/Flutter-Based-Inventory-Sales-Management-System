import React from 'react';
import {
  Boxes,
  Zap,
  BarChart3,
  History,
  Settings,
} from 'lucide-react';
import { useInventory } from '../context/InventoryContext';
import { sound } from '../lib/sound';
import { ActiveTab } from '../types';

export const BottomNav: React.FC = () => {
  const {
    activeTab,
    setActiveTab,
    openQuickAction,
    transactions,
    setSupabaseSettingsModalOpen,
  } = useInventory();

  const handleTabSelect = (tab: ActiveTab) => {
    sound.playClick();
    if (tab === 'actions') {
      openQuickAction('STOCK_IN');
      return;
    }
    // "Settings & DB" opens the Supabase/database configuration modal
    // rather than switching to an empty main tab.
    if (tab === 'settings') {
      setSupabaseSettingsModalOpen(true);
      return;
    }
    setActiveTab(tab);
  };

  const navItems = [
    { id: 'inventory' as ActiveTab, label: 'Inventory', icon: Boxes },
    { id: 'reports' as ActiveTab, label: 'Reports', icon: BarChart3 },
    { id: 'actions' as ActiveTab, label: 'Quick Action', icon: Zap, isFab: true },
    {
      id: 'activity' as ActiveTab,
      label: 'Activity',
      icon: History,
      badge: transactions.length > 0 ? transactions.length : undefined,
    },
    { id: 'settings' as ActiveTab, label: 'Settings & DB', icon: Settings },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-30 bg-slate-950/95 backdrop-blur-lg border-t border-slate-800 pb-safe">
      <div className="max-w-md md:max-w-xl mx-auto flex items-center justify-around px-2 py-1.5">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;

          if (item.isFab) {
            return (
              <button
                key={item.id}
                onClick={() => handleTabSelect(item.id)}
                className="relative -top-3 flex flex-col items-center group focus:outline-none"
                title="Quick Stock In / Sold / Audit Action"
              >
                <div className="w-12 h-12 rounded-2xl bg-gradient-to-tr from-blue-600 to-indigo-500 flex items-center justify-center text-white shadow-lg shadow-blue-500/30 group-active:scale-95 group-hover:shadow-blue-500/50 transition-all border-2 border-slate-900">
                  <Zap className="w-6 h-6 fill-white" />
                </div>
                <span className="text-[10px] font-semibold text-blue-400 mt-0.5">
                  Update
                </span>
              </button>
            );
          }

          return (
            <button
              key={item.id}
              onClick={() => handleTabSelect(item.id)}
              className={`flex flex-col items-center justify-center py-1 px-3 rounded-xl transition-all relative ${
                isActive
                  ? 'text-blue-400 font-semibold'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              <div className="relative">
                <Icon className={`w-5 h-5 transition-transform ${isActive ? 'scale-110' : ''}`} />
                {item.badge && (
                  <span className="absolute -top-1.5 -right-2.5 bg-blue-600 text-white text-[9px] font-bold px-1.5 py-0.2 rounded-full min-w-[14px] text-center border border-slate-900">
                    {item.badge > 99 ? '99+' : item.badge}
                  </span>
                )}
              </div>
              <span className="text-[10px] mt-1 tracking-tight">
                {item.label}
              </span>
              {isActive && (
                <div className="w-4 h-0.5 bg-blue-500 rounded-full mt-0.5" />
              )}
            </button>
          );
        })}
      </div>
    </nav>
  );
};
