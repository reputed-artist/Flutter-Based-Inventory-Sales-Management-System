import React from 'react';
import { InventoryProvider, useInventory } from './context/InventoryContext';
import { Header } from './components/Header';
import { BottomNav } from './components/BottomNav';
import { InventoryView } from './components/InventoryView';
import { ReportsView } from './components/ReportsView';
import { AuditLogView } from './components/AuditLogView';
import { QuickActionModal } from './components/QuickActionModal';
import { ItemDetailModal } from './components/ItemDetailModal';
import { BarcodeScannerModal } from './components/BarcodeScannerModal';
import { UserSwitcherModal } from './components/UserSwitcherModal';
import { SupabaseSettingsModal } from './components/SupabaseSettingsModal';
import { FlutterCodeModal } from './components/FlutterCodeModal';
import { usePWAInstall } from './hooks/usePWAInstall';
import { Download, X } from 'lucide-react';
import { sound } from './lib/sound';

const AppContent: React.FC = () => {
  const { activeTab, flutterCodeModalOpen, setFlutterCodeModalOpen } = useInventory();
  const { isInstallable, install, isInstalled } = usePWAInstall();
  const [installDismissed, setInstallDismissed] = React.useState(false);

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col selection:bg-blue-500 selection:text-white">
      {/* PWA Install Banner for Android */}
      {isInstallable && !installDismissed && !isInstalled && (
        <div className="bg-gradient-to-r from-blue-700 via-indigo-600 to-blue-800 text-white px-4 py-2.5 text-xs flex items-center justify-between shadow-md border-b border-blue-500/40 animate-in slide-in-from-top duration-300">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-lg bg-white/20 flex items-center justify-center font-bold">
              📦
            </div>
            <div>
              <p className="font-bold leading-tight">Install Android App</p>
              <p className="text-[11px] text-blue-100">Add to Home Screen for offline scanning & fast access</p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => {
                sound.playClick();
                install();
              }}
              className="px-3 py-1.5 rounded-lg bg-white text-blue-700 font-bold text-xs shadow hover:bg-blue-50 transition active:scale-95 flex items-center gap-1"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Install</span>
            </button>
            <button
              onClick={() => setInstallDismissed(true)}
              className="p-1 rounded-md text-blue-200 hover:text-white"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      {/* Main Top Header */}
      <Header />

      {/* Main Scrollable Canvas */}
      <main className="flex-1 max-w-5xl w-full mx-auto p-3 sm:p-5">
        {activeTab === 'inventory' && <InventoryView />}
        {activeTab === 'reports' && <ReportsView />}
        {activeTab === 'activity' && <AuditLogView />}
      </main>

      {/* Bottom Navigation for Android PWA */}
      <BottomNav />

      {/* Modals */}
      <QuickActionModal />
      <ItemDetailModal />
      <BarcodeScannerModal />
      <UserSwitcherModal />
      <SupabaseSettingsModal />
      <FlutterCodeModal
        isOpen={flutterCodeModalOpen}
        onClose={() => setFlutterCodeModalOpen(false)}
      />
    </div>
  );
};

export default function App() {
  return (
    <InventoryProvider>
      <AppContent />
    </InventoryProvider>
  );
}
