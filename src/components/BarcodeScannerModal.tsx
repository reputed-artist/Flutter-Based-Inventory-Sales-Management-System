import React, { useState } from 'react';
import {
  X,
  ScanLine,
  Search,
  Check,
  Package,
} from 'lucide-react';
import { useInventory } from '../context/InventoryContext';
import { sound } from '../lib/sound';

export const BarcodeScannerModal: React.FC = () => {
  const {
    scannerModalOpen,
    setScannerModalOpen,
    items,
    setDetailModalItem,
    openQuickAction,
  } = useInventory();

  const [inputCode, setInputCode] = useState('');
  const [notFound, setNotFound] = useState(false);

  if (!scannerModalOpen) return null;

  const handleScanCode = (code: string) => {
    sound.playScan();
    const clean = code.trim().toUpperCase();

    // Match barcode or SKU
    const matched = items.find(
      i => (i.barcode && i.barcode.toUpperCase() === clean) || i.sku.toUpperCase() === clean
    );

    if (matched) {
      setScannerModalOpen(false);
      setDetailModalItem(matched);
      sound.playSuccess();
    } else {
      sound.playAlert();
      setNotFound(true);
      setTimeout(() => setNotFound(false), 3000);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/85 backdrop-blur-sm p-4 animate-in fade-in duration-200">
      <div className="w-full max-w-md bg-slate-900 border border-slate-700 rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Top bar */}
        <div className="p-4 border-b border-slate-800 flex items-center justify-between bg-slate-900">
          <div className="flex items-center gap-2">
            <ScanLine className="w-5 h-5 text-blue-400" />
            <h2 className="text-sm font-bold text-slate-100">
              Barcode / SKU Scanner (Android)
            </h2>
          </div>
          <button
            onClick={() => {
              sound.playClick();
              setScannerModalOpen(false);
            }}
            className="p-1.5 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Viewfinder simulation */}
        <div className="p-4 flex flex-col items-center justify-center">
          <div className="relative w-64 h-44 bg-slate-950 rounded-2xl border-2 border-dashed border-blue-500/60 overflow-hidden flex items-center justify-center shadow-inner">
            {/* Corner Markers */}
            <div className="absolute top-2 left-2 w-4 h-4 border-t-2 border-l-2 border-blue-400" />
            <div className="absolute top-2 right-2 w-4 h-4 border-t-2 border-r-2 border-blue-400" />
            <div className="absolute bottom-2 left-2 w-4 h-4 border-b-2 border-l-2 border-blue-400" />
            <div className="absolute bottom-2 right-2 w-4 h-4 border-b-2 border-r-2 border-blue-400" />

            {/* Laser Line Animation */}
            <div className="absolute inset-x-0 h-0.5 bg-rose-500 shadow-[0_0_12px_#f43f5e] animate-pulse" />

            <div className="text-center p-3">
              <ScanLine className="w-8 h-8 text-blue-400/80 mx-auto animate-bounce mb-1" />
              <p className="text-[11px] text-slate-400">
                Point warehouse camera or tap test item below
              </p>
            </div>
          </div>

          {notFound && (
            <p className="text-xs text-rose-400 font-semibold mt-2 animate-shake">
              No matching item found for "{inputCode}"!
            </p>
          )}

          {/* Manual code input */}
          <form
            onSubmit={(e) => {
              e.preventDefault();
              handleScanCode(inputCode);
            }}
            className="w-full flex items-center gap-2 mt-4"
          >
            <div className="relative flex-1">
              <input
                type="text"
                value={inputCode}
                onChange={(e) => setInputCode(e.target.value)}
                placeholder="Enter SKU or Barcode (e.g. HP-2580)..."
                className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-xs text-slate-100 font-mono focus:outline-none focus:border-blue-500"
              />
            </div>
            <button
              type="submit"
              className="py-2 px-3 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-semibold text-xs transition"
            >
              Lookup
            </button>
          </form>
        </div>

        {/* Quick tap item list */}
        <div className="p-3 border-t border-slate-800 bg-slate-950/60 overflow-y-auto flex-1">
          <div className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-2">
            One-Tap Warehouse Barcode Tags:
          </div>

          <div className="space-y-1.5">
            {items.slice(0, 8).map(item => (
              <button
                key={item.id}
                type="button"
                onClick={() => handleScanCode(item.barcode || item.sku)}
                className="w-full p-2 rounded-xl bg-slate-800/80 hover:bg-slate-750 border border-slate-700 flex items-center justify-between text-left transition active:scale-98"
              >
                <div>
                  <span className="text-xs font-semibold text-slate-100 block">
                    {item.name}
                  </span>
                  <span className="text-[10px] font-mono text-slate-400">
                    {item.barcode || item.sku}
                  </span>
                </div>

                <span className="text-xs font-mono font-bold text-blue-400 px-2 py-0.5 rounded bg-blue-500/15 border border-blue-500/30">
                  Left: {item.leftCount}
                </span>
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};
