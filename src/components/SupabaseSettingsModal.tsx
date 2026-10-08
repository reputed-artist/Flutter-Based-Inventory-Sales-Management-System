import React, { useState } from 'react';
import {
  X,
  Database,
  CheckCircle2,
  AlertCircle,
  Copy,
  RefreshCw,
  Server,
  Zap,
  RotateCcw,
  Check,
} from 'lucide-react';
import { useInventory } from '../context/InventoryContext';
import {
  SUPABASE_SQL_SETUP_SCRIPT,
  clearStoredSupabaseCredentials,
  getStoredSupabaseCredentials,
  testSupabaseConnection,
} from '../lib/supabaseClient';
import { sound } from '../lib/sound';

export const SupabaseSettingsModal: React.FC = () => {
  const {
    supabaseSettingsModalOpen,
    setSupabaseSettingsModalOpen,
    supabaseConfig,
    syncStatus,
    lastSyncTime,
    updateSupabaseCredentials,
    syncWithSupabase,
    resetToDefaultData,
  } = useInventory();

  const [urlInput, setUrlInput] = useState(() => getStoredSupabaseCredentials().url);
  const [keyInput, setKeyInput] = useState(() => getStoredSupabaseCredentials().anonKey);
  const [isTesting, setIsTesting] = useState(false);
  const [testResult, setTestResult] = useState<{ success: boolean; message: string } | null>(null);
  const [sqlCopied, setSqlCopied] = useState(false);
  const [activeTab, setActiveTab] = useState<'config' | 'sql' | 'maintenance'>('config');

  if (!supabaseSettingsModalOpen) return null;

  const handleTestConnection = async () => {
    sound.playClick();
    if (!urlInput.trim() || !keyInput.trim()) {
      setTestResult({ success: false, message: 'Please provide both Supabase URL and Anon Key.' });
      return;
    }
    setIsTesting(true);
    setTestResult(null);

    const res = await testSupabaseConnection(urlInput, keyInput);
    setIsTesting(false);
    setTestResult(res);

    if (res.success) {
      sound.playSuccess();
    } else {
      sound.playAlert();
    }
  };

  const handleSaveAndSync = async () => {
    sound.playClick();
    await updateSupabaseCredentials(urlInput.trim(), keyInput.trim());
    sound.playSuccess();
  };

  const handleClearCredentials = () => {
    sound.playClick();
    clearStoredSupabaseCredentials();
    setUrlInput('');
    setKeyInput('');
    setTestResult(null);
    updateSupabaseCredentials('', '');
  };

  const copySqlToClipboard = () => {
    sound.playClick();
    navigator.clipboard.writeText(SUPABASE_SQL_SETUP_SCRIPT);
    setSqlCopied(true);
    setTimeout(() => setSqlCopied(false), 3000);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-sm p-0 sm:p-4 animate-in fade-in duration-200">
      <div className="w-full sm:max-w-xl bg-slate-900 border border-slate-700/80 rounded-t-3xl sm:rounded-2xl shadow-2xl max-h-[92vh] flex flex-col overflow-hidden text-sm">
        {/* Modal Header */}
        <div className="p-4 border-b border-slate-800 flex items-center justify-between bg-slate-900/90">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-emerald-500/20 border border-emerald-500/30 flex items-center justify-center text-emerald-400">
              <Database className="w-4 h-4" />
            </div>
            <div>
              <h2 className="text-base font-bold text-slate-100 flex items-center gap-2">
                Supabase Realtime Database
              </h2>
              <p className="text-[11px] text-slate-400">
                Multi-device synchronization for cartridges, printers & machines
              </p>
            </div>
          </div>
          <button
            onClick={() => {
              sound.playClick();
              setSupabaseSettingsModalOpen(false);
            }}
            className="p-1.5 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Tab switcher */}
        <div className="flex border-b border-slate-800 bg-slate-950/60 text-xs px-3">
          <button
            onClick={() => {
              sound.playClick();
              setActiveTab('config');
            }}
            className={`py-2.5 px-4 font-semibold border-b-2 transition ${
              activeTab === 'config'
                ? 'border-emerald-500 text-emerald-400'
                : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
          >
            Connection Setup
          </button>
          <button
            onClick={() => {
              sound.playClick();
              setActiveTab('sql');
            }}
            className={`py-2.5 px-4 font-semibold border-b-2 transition ${
              activeTab === 'sql'
                ? 'border-emerald-500 text-emerald-400'
                : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
          >
            SQL Table Schema (Copy)
          </button>
          <button
            onClick={() => {
              sound.playClick();
              setActiveTab('maintenance');
            }}
            className={`py-2.5 px-4 font-semibold border-b-2 transition ${
              activeTab === 'maintenance'
                ? 'border-emerald-500 text-emerald-400'
                : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
          >
            Device Sync & Reset
          </button>
        </div>

        {/* Modal Body */}
        <div className="p-4 space-y-4 overflow-y-auto flex-1">
          {/* Current Status Box */}
          <div className="p-3.5 rounded-xl bg-slate-800/90 border border-slate-700/80 flex items-center justify-between gap-3">
            <div className="flex items-center gap-2.5">
              <span className={`w-3 h-3 rounded-full ${
                syncStatus === 'synced' ? 'bg-emerald-400 animate-pulse' :
                syncStatus === 'syncing' ? 'bg-blue-400 animate-spin' :
                syncStatus === 'error' ? 'bg-rose-400' : 'bg-amber-400 animate-pulse'
              }`} />
              <div>
                <span className="text-xs font-bold text-slate-200 block">
                  {syncStatus === 'synced' ? 'Connected to Supabase Realtime' :
                   syncStatus === 'syncing' ? 'Synchronizing with Database...' :
                   syncStatus === 'error' ? 'Supabase Connection Error' :
                   'Local Multi-Tab Mesh Active (Ready for Supabase)'}
                </span>
                <span className="text-[11px] text-slate-400">
                  Last sync: {lastSyncTime}
                </span>
              </div>
            </div>

            <button
              onClick={() => {
                sound.playClick();
                syncWithSupabase();
              }}
              className="p-2 rounded-lg bg-slate-700 hover:bg-slate-600 text-slate-200 text-xs flex items-center gap-1 transition active:scale-95"
              title="Manual Sync Trigger"
            >
              <RefreshCw className="w-3.5 h-3.5" />
              <span>Sync</span>
            </button>
          </div>

          {/* TAB 1: CONFIG */}
          {activeTab === 'config' && (
            <div className="space-y-3.5">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Supabase Project URL
                </label>
                <input
                  type="text"
                  value={urlInput}
                  onChange={(e) => setUrlInput(e.target.value)}
                  placeholder="https://xyzproject.supabase.co"
                  className="w-full px-3 py-2.5 bg-slate-800 border border-slate-700 rounded-xl text-xs text-slate-100 font-mono focus:outline-none focus:border-emerald-500"
                />
                <p className="text-[11px] text-slate-400 mt-1">
                  Found in your Supabase Dashboard → Project Settings → API
                </p>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Supabase Anon Public API Key
                </label>
                <input
                  type="password"
                  value={keyInput}
                  onChange={(e) => setKeyInput(e.target.value)}
                  placeholder="eyJhbGciOiJIUzI1NiIsInR5cCI6..."
                  className="w-full px-3 py-2.5 bg-slate-800 border border-slate-700 rounded-xl text-xs text-slate-100 font-mono focus:outline-none focus:border-emerald-500"
                />
                <p className="text-[11px] text-slate-400 mt-1">
                  The 'anon' public key is safe for client-side multi-user inventory syncing.
                </p>
              </div>

              {testResult && (
                <div className={`p-3 rounded-xl border text-xs flex items-start gap-2 ${
                  testResult.success
                    ? 'bg-emerald-500/15 border-emerald-500/40 text-emerald-300'
                    : 'bg-rose-500/15 border-rose-500/40 text-rose-300'
                }`}>
                  {testResult.success ? (
                    <CheckCircle2 className="w-4 h-4 flex-shrink-0 mt-0.5 text-emerald-400" />
                  ) : (
                    <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5 text-rose-400" />
                  )}
                  <span>{testResult.message}</span>
                </div>
              )}

              <div className="flex items-center gap-2 pt-2">
                <button
                  type="button"
                  onClick={handleTestConnection}
                  disabled={isTesting}
                  className="flex-1 py-2.5 px-3 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 font-semibold text-xs border border-slate-700 transition active:scale-95 flex items-center justify-center gap-1.5"
                >
                  <Server className="w-3.5 h-3.5 text-blue-400" />
                  {isTesting ? 'Testing Connection...' : 'Test Connection'}
                </button>

                <button
                  type="button"
                  onClick={handleSaveAndSync}
                  className="flex-1 py-2.5 px-3 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-semibold text-xs shadow-md shadow-emerald-500/20 transition active:scale-95 flex items-center justify-center gap-1.5"
                >
                  <CheckCircle2 className="w-3.5 h-3.5" />
                  Save & Connect Realtime
                </button>
              </div>

              {(urlInput || keyInput) && (
                <div className="text-center pt-2">
                  <button
                    type="button"
                    onClick={handleClearCredentials}
                    className="text-xs text-rose-400 hover:text-rose-300 underline"
                  >
                    Clear Credentials & Revert to Local Mesh
                  </button>
                </div>
              )}
            </div>
          )}

          {/* TAB 2: SQL SCHEMA */}
          {activeTab === 'sql' && (
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-xs text-slate-300 font-semibold">
                  PostgreSQL & Supabase Table DDL
                </span>
                <button
                  type="button"
                  onClick={copySqlToClipboard}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold shadow-sm transition active:scale-95"
                >
                  {sqlCopied ? (
                    <>
                      <Check className="w-3.5 h-3.5" />
                      Copied to Clipboard!
                    </>
                  ) : (
                    <>
                      <Copy className="w-3.5 h-3.5" />
                      Copy SQL Script
                    </>
                  )}
                </button>
              </div>

              <p className="text-[11px] text-slate-400">
                Paste this script into your Supabase Dashboard → <strong>SQL Editor</strong> to create the tables (<code className="text-emerald-400">inventory_items</code>, <code className="text-emerald-400">inventory_transactions</code>) and activate Realtime streaming:
              </p>

              <pre className="p-3 bg-slate-950 rounded-xl text-[11px] font-mono text-slate-300 border border-slate-800 overflow-x-auto max-h-64 leading-relaxed">
                {SUPABASE_SQL_SETUP_SCRIPT}
              </pre>
            </div>
          )}

          {/* TAB 3: MAINTENANCE & LOCAL MESH */}
          {activeTab === 'maintenance' && (
            <div className="space-y-3.5">
              <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700/60 text-xs text-slate-300 space-y-1.5">
                <div className="font-semibold text-slate-100 flex items-center gap-1.5">
                  <Zap className="w-4 h-4 text-amber-400" />
                  Instant Tab-to-Tab Synchronization
                </div>
                <p className="text-slate-400 text-[11px]">
                  This application utilizes modern <code>BroadcastChannel</code> protocols alongside Supabase. Even when working locally or across multiple browser tabs/windows on the same computer, changes in stock immediately reflect on other tabs without refreshing!
                </p>
              </div>

              <div className="pt-2">
                <button
                  type="button"
                  onClick={() => {
                    if (confirm('Reset catalog to sample HP cartridges, Handy printers, Docod, Rynan & machines?')) {
                      resetToDefaultData();
                      setSupabaseSettingsModalOpen(false);
                    }
                  }}
                  className="w-full py-2.5 px-3 rounded-xl bg-slate-800 hover:bg-rose-500/20 text-rose-400 hover:text-rose-300 text-xs font-semibold border border-slate-700 hover:border-rose-500/40 transition flex items-center justify-center gap-2"
                >
                  <RotateCcw className="w-3.5 h-3.5" />
                  Reset to Industrial Sample Data
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
