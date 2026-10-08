import React from 'react';
import {
  Smartphone,
  Maximize2,
  ScanLine,
  Database,
  Volume2,
  VolumeX,
  UserCheck,
  RefreshCw,
  Code2,
} from 'lucide-react';
import { useInventory } from '../context/InventoryContext';
import { sound } from '../lib/sound';

export const Header: React.FC = () => {
  const {
    currentOperator,
    syncStatus,
    lastSyncTime,
    isMobileFrame,
    setIsMobileFrame,
    setScannerModalOpen,
    setUserSwitcherModalOpen,
    setSupabaseSettingsModalOpen,
    setFlutterCodeModalOpen,
    syncWithSupabase,
  } = useInventory();

  const [soundEnabled, setSoundEnabled] = React.useState(true);

  const toggleSound = () => {
    const next = !soundEnabled;
    setSoundEnabled(next);
    sound.enabled = next;
    if (next) sound.playClick();
  };

  const getSyncBadge = () => {
    switch (syncStatus) {
      case 'synced':
        return {
          text: 'Supabase Live',
          bg: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30',
          dot: 'bg-emerald-400 animate-pulse',
        };
      case 'syncing':
        return {
          text: 'Syncing...',
          bg: 'bg-blue-500/10 text-blue-400 border-blue-500/30',
          dot: 'bg-blue-400 animate-spin',
        };
      case 'error':
        return {
          text: 'Sync Issue',
          bg: 'bg-rose-500/10 text-rose-400 border-rose-500/30',
          dot: 'bg-rose-400',
        };
      case 'local_mesh':
      default:
        return {
          text: 'Real-Time Mesh (Tab Sync)',
          bg: 'bg-amber-500/10 text-amber-400 border-amber-500/30',
          dot: 'bg-amber-400 animate-pulse',
        };
    }
  };

  const badge = getSyncBadge();

  return (
    <header className="sticky top-0 z-30 bg-slate-900/95 backdrop-blur-md border-b border-slate-800 px-3 py-2.5 sm:px-4">
      <div className="max-w-7xl mx-auto flex items-center justify-between gap-2">
        {/* Left: App Title & Android Identity */}
        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-blue-600 to-indigo-500 flex items-center justify-center shadow-md shadow-blue-500/20 text-white font-bold text-sm tracking-tight flex-shrink-0">
            <Smartphone className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-sm sm:text-base font-bold text-slate-100 tracking-tight leading-none">
                StockSync
              </h1>
              <span className="text-[10px] font-semibold px-1.5 py-0.5 rounded bg-blue-500/20 text-blue-300 border border-blue-500/30">
                Android
              </span>
            </div>
            <p className="text-[11px] text-slate-400 leading-tight mt-0.5 hidden xs:block">
              Printers, Cartridges & Machines
            </p>
          </div>
        </div>

        {/* Center/Right: Sync Status & Controls */}
        <div className="flex items-center gap-1.5 sm:gap-2">
          {/* Supabase Status Pill */}
          <button
            onClick={() => {
              sound.playClick();
              setSupabaseSettingsModalOpen(true);
            }}
            title={`Supabase Database Sync Status. Last synced: ${lastSyncTime}. Click to configure.`}
            className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-medium border transition hover:opacity-90 active:scale-95 ${badge.bg}`}
          >
            <span className={`w-2 h-2 rounded-full flex-shrink-0 ${badge.dot}`} />
            <span className="hidden sm:inline">{badge.text}</span>
            <span className="sm:hidden">{syncStatus === 'synced' ? 'Supabase' : 'Mesh'}</span>
            <Database className="w-3 h-3 ml-0.5 opacity-70" />
          </button>

          {/* Quick Refresh / Re-sync */}
          <button
            onClick={() => {
              sound.playClick();
              syncWithSupabase();
            }}
            title="Refresh / Sync Now"
            className="p-1.5 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition active:scale-95"
          >
            <RefreshCw className={`w-4 h-4 ${syncStatus === 'syncing' ? 'animate-spin text-blue-400' : ''}`} />
          </button>

          {/* Barcode Scanner Trigger */}
          <button
            onClick={() => {
              sound.playScan();
              setScannerModalOpen(true);
            }}
            title="Scan Barcode / SKU"
            className="p-1.5 rounded-lg text-blue-400 bg-blue-500/10 hover:bg-blue-500/20 border border-blue-500/20 transition active:scale-95"
          >
            <ScanLine className="w-4 h-4" />
          </button>

          {/* Active Operator Switcher */}
          <button
            onClick={() => {
              sound.playClick();
              setUserSwitcherModalOpen(true);
            }}
            className="flex items-center gap-1.5 px-2 py-1 rounded-lg bg-slate-800 hover:bg-slate-700/80 border border-slate-700/60 transition active:scale-95 text-left"
            title={`Active Operator: ${currentOperator.name}. Click to switch device user.`}
          >
            <div
              className="w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold text-white flex-shrink-0 shadow-sm"
              style={{ backgroundColor: currentOperator.avatarColor }}
            >
              {currentOperator.name.charAt(0)}
            </div>
            <span className="text-xs text-slate-200 font-medium hidden md:inline max-w-[90px] truncate">
              {currentOperator.name.split(' ')[0]}
            </span>
            <UserCheck className="w-3 h-3 text-slate-400 ml-0.5 hidden sm:inline" />
          </button>

          {/* Sound Mute/Unmute */}
          <button
            onClick={toggleSound}
            title={soundEnabled ? 'Audio Feedback Enabled' : 'Audio Feedback Muted'}
            className="p-1.5 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition active:scale-95"
          >
            {soundEnabled ? (
              <Volume2 className="w-4 h-4 text-slate-300" />
            ) : (
              <VolumeX className="w-4 h-4 text-slate-500" />
            )}
          </button>

          {/* Flutter (Dart) Android Code Explorer */}
          <button
            onClick={() => {
              sound.playClick();
              setFlutterCodeModalOpen(true);
            }}
            title="View & Export Flutter (Dart) Codebase for Android APK"
            className="flex items-center gap-1 px-2 py-1.5 rounded-lg bg-sky-500/10 hover:bg-sky-500/20 text-sky-400 border border-sky-500/30 transition active:scale-95 text-xs font-semibold"
          >
            <Code2 className="w-4 h-4 text-sky-400" />
            <span className="hidden sm:inline">Flutter Code</span>
          </button>

          {/* Android Mobile Frame Toggle */}
          <button
            onClick={() => {
              sound.playClick();
              setIsMobileFrame(prev => !prev);
            }}
            title={isMobileFrame ? 'Expand to Full View' : 'Preview in Android Phone Frame'}
            className={`p-1.5 rounded-lg transition active:scale-95 border ${
              isMobileFrame
                ? 'bg-indigo-600 text-white border-indigo-500 shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800 border-slate-700/50'
            }`}
          >
            {isMobileFrame ? <Maximize2 className="w-4 h-4" /> : <Smartphone className="w-4 h-4" />}
          </button>
        </div>
      </div>
    </header>
  );
};
