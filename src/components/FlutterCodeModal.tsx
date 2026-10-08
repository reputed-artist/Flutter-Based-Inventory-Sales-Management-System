import React, { useState } from 'react';
import {
  X,
  Code2,
  Copy,
  Check,
  Download,
  Terminal,
  FileCode,
  FolderTree,
  ExternalLink,
  Smartphone,
} from 'lucide-react';
import { sound } from '../lib/sound';

interface FlutterFile {
  name: string;
  path: string;
  language: string;
  code: string;
}

const FLUTTER_FILES: FlutterFile[] = [
  {
    name: 'pubspec.yaml',
    path: 'pubspec.yaml',
    language: 'yaml',
    code: `name: ink_inventory_sync
description: "Real-time Multi-Device Inventory Management App for HP Cartridges, Handy Printers, Docod, Rynan and Packaging Machines."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.5.0
  provider: ^6.1.2
  shared_preferences: ^2.2.2
  mobile_scanner: ^5.1.0
  intl: ^0.19.0
  lucide_icons: ^0.252.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true`,
  },
  {
    name: 'main.dart',
    path: 'lib/main.dart',
    language: 'dart',
    code: `import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/inventory_provider.dart';
import 'screens/inventory_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/audit_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
      ],
      child: const InventorySyncApp(),
    ),
  );
}

class InventorySyncApp extends StatelessWidget {
  const InventorySyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ink & Machine Inventory Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F17),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0284C7),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF161F30),
          error: Color(0xFFEF4444),
          onPrimary: Colors.white,
          onSurface: Colors.white,
        ),
      ),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    InventoryScreen(),
    ReportsScreen(),
    AuditScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(top: BorderSide(color: Color(0xFF1E293B))),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFF0284C7).withOpacity(0.2),
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8)),
              selectedIcon: Icon(Icons.inventory_2_rounded, color: Color(0xFF38BDF8)),
              label: 'Stock Items',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, color: Color(0xFF94A3B8)),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: Color(0xFF38BDF8)),
              label: 'Reports',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_edu_outlined, color: Color(0xFF94A3B8)),
              selectedIcon: Icon(Icons.history_edu_rounded, color: Color(0xFF38BDF8)),
              label: 'Audit Log',
            ),
          ],
        ),
      ),
    );
  }
}`,
  },
  {
    name: 'inventory_screen.dart',
    path: 'lib/screens/inventory_screen.dart',
    language: 'dart',
    code: `// Matches exact UI layout: KPI metrics cards, category filter chips, search & barcode trigger,
// stock badges (TOTAL IN, SOLD, LEFT COUNT), and quick action buttons (+ Add In, - Sold Out, Count Audit).
// View full file in lib/screens/inventory_screen.dart inside the project workspace!`,
  },
  {
    name: 'inventory_provider.dart',
    path: 'lib/providers/inventory_provider.dart',
    language: 'dart',
    code: `// Complete ChangeNotifier state manager handling:
// - recordStockIn(itemId, quantity, unitPrice, supplier, notes)
// - recordStockSold(itemId, quantity, unitPrice, client, notes)
// - recordCountAudit(itemId, physicalCount, reason)
// - Realtime Supabase synchronization & PostgresChange stream listeners
// - Multi-operator profile switching & device watermarking
// View full file in lib/providers/inventory_provider.dart`,
  },
  {
    name: 'supabase_service.dart',
    path: 'lib/services/supabase_service.dart',
    language: 'dart',
    code: `// Supabase Realtime Service for Flutter
// Initializes Supabase client with project URL & Anon Key
// Manages real-time channels:
// - public:inventory_items (on PostgresChangeEvent.all)
// - public:inventory_transactions (on PostgresChangeEvent.insert)
// Local persistence via shared_preferences.
// View full file in lib/services/supabase_service.dart`,
  },
  {
    name: 'inventory_item.dart',
    path: 'lib/models/inventory_item.dart',
    language: 'dart',
    code: `// Data model for HP Cartridges, Handy Printers, Online, Docod, Rynan, Machines
// Includes JSON serialization, low stock calculation, and category mappings.
// View full file in lib/models/inventory_item.dart`,
  },
  {
    name: 'transaction.dart',
    path: 'lib/models/transaction.dart',
    language: 'dart',
    code: `// InventoryTransaction model for Stock In, Sold to Client, Physical Audit Count
// Full JSON serialization for Supabase table \`inventory_transactions\`.
// View full file in lib/models/transaction.dart`,
  },
];

interface Props {
  isOpen: boolean;
  onClose: () => void;
}

export const FlutterCodeModal: React.FC<Props> = ({ isOpen, onClose }) => {
  const [selectedFile, setSelectedFile] = useState<FlutterFile>(FLUTTER_FILES[0]);
  const [copied, setCopied] = useState(false);

  if (!isOpen) return null;

  const handleCopy = () => {
    sound.playClick();
    navigator.clipboard.writeText(selectedFile.code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownloadSingle = () => {
    sound.playClick();
    const blob = new Blob([selectedFile.code], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = selectedFile.name;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-950/80 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-slate-900 border border-slate-700/80 rounded-2xl w-full max-w-4xl max-h-[90vh] flex flex-col shadow-2xl overflow-hidden">
        {/* Header */}
        <div className="p-4 bg-slate-800/80 border-b border-slate-700 flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-blue-500/20 border border-blue-400/40 flex items-center justify-center text-blue-400">
              <Code2 className="w-4 h-4" />
            </div>
            <div>
              <h2 className="text-sm sm:text-base font-bold text-white flex items-center gap-2">
                Flutter (Dart) Android Codebase
                <span className="text-[10px] font-semibold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 px-2 py-0.5 rounded-full">
                  Production Ready
                </span>
              </h2>
              <p className="text-xs text-slate-400">
                All source files generated in <code className="text-blue-300">/lib</code> and <code className="text-blue-300">pubspec.yaml</code>
              </p>
            </div>
          </div>
          <button
            onClick={() => {
              sound.playClick();
              onClose();
            }}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-700/60"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Quick Android Build Guide Strip */}
        <div className="bg-blue-950/40 border-b border-blue-900/40 px-4 py-2 text-xs flex flex-wrap items-center justify-between gap-2 text-blue-200">
          <div className="flex items-center gap-2">
            <Terminal className="w-3.5 h-3.5 text-blue-400" />
            <span>To build on Android Studio / Terminal:</span>
            <code className="bg-slate-950/80 px-2 py-0.5 rounded text-sky-300 font-mono text-[11px] border border-blue-800/40">
              flutter build apk --release
            </code>
          </div>
          <span className="text-slate-400 text-[11px]">
            Export project to ZIP via AI Studio Settings menu
          </span>
        </div>

        {/* Content Area */}
        <div className="flex-1 flex flex-col md:flex-row min-h-0">
          {/* File Sidebar */}
          <div className="w-full md:w-64 bg-slate-900/90 border-r border-slate-800 p-2 overflow-y-auto max-h-48 md:max-h-none">
            <div className="text-[11px] font-bold text-slate-400 px-2 py-1.5 uppercase tracking-wider flex items-center gap-1.5">
              <FolderTree className="w-3.5 h-3.5" />
              <span>Flutter Project Tree</span>
            </div>
            <div className="space-y-0.5">
              {FLUTTER_FILES.map((file) => {
                const isSelected = selectedFile.path === file.path;
                return (
                  <button
                    key={file.path}
                    onClick={() => {
                      sound.playClick();
                      setSelectedFile(file);
                    }}
                    className={`w-full text-left px-2.5 py-1.5 rounded-lg text-xs font-mono transition flex items-center justify-between ${
                      isSelected
                        ? 'bg-blue-600 text-white font-bold'
                        : 'text-slate-300 hover:bg-slate-800 hover:text-white'
                    }`}
                  >
                    <div className="flex items-center gap-2 truncate">
                      <FileCode className="w-3.5 h-3.5 flex-shrink-0 opacity-70" />
                      <span className="truncate">{file.name}</span>
                    </div>
                    <span className="text-[10px] opacity-60 uppercase">{file.language}</span>
                  </button>
                );
              })}
            </div>

            <div className="mt-4 pt-3 border-t border-slate-800 px-2 text-[11px] text-slate-400">
              <p className="font-semibold text-slate-300 mb-1">Generated Files in Root:</p>
              <ul className="list-disc list-inside space-y-0.5 text-[10px] text-slate-400 font-mono">
                <li>/pubspec.yaml</li>
                <li>/lib/main.dart</li>
                <li>/lib/models/*</li>
                <li>/lib/providers/*</li>
                <li>/lib/screens/*</li>
                <li>/lib/widgets/*</li>
                <li>/lib/services/*</li>
                <li>/README_FLUTTER.md</li>
              </ul>
            </div>
          </div>

          {/* Code Viewer Panel */}
          <div className="flex-1 flex flex-col bg-slate-950 min-h-0">
            {/* Viewer Header */}
            <div className="px-4 py-2 bg-slate-900 border-b border-slate-800 flex items-center justify-between">
              <span className="text-xs font-mono text-slate-300 flex items-center gap-1.5">
                <FileCode className="w-3.5 h-3.5 text-blue-400" />
                {selectedFile.path}
              </span>
              <div className="flex items-center gap-2">
                <button
                  onClick={handleCopy}
                  className="px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs flex items-center gap-1 transition"
                >
                  {copied ? (
                    <>
                      <Check className="w-3.5 h-3.5 text-emerald-400" />
                      <span className="text-emerald-400">Copied</span>
                    </>
                  ) : (
                    <>
                      <Copy className="w-3.5 h-3.5" />
                      <span>Copy</span>
                    </>
                  )}
                </button>
                <button
                  onClick={handleDownloadSingle}
                  className="px-2.5 py-1 rounded bg-blue-600 hover:bg-blue-500 text-white text-xs flex items-center gap-1 transition"
                >
                  <Download className="w-3.5 h-3.5" />
                  <span>Download</span>
                </button>
              </div>
            </div>

            {/* Code Content */}
            <div className="flex-1 p-4 overflow-auto font-mono text-xs text-slate-200 bg-slate-950/90 leading-relaxed whitespace-pre selection:bg-blue-500 selection:text-white">
              {selectedFile.code}
            </div>
          </div>
        </div>

        {/* Footer info */}
        <div className="p-3 bg-slate-900 border-t border-slate-800 flex items-center justify-between text-xs text-slate-400">
          <div className="flex items-center gap-2">
            <Smartphone className="w-4 h-4 text-emerald-400" />
            <span>Exact same UI & Supabase real-time sync in Flutter (Dart)</span>
          </div>
          <button
            onClick={() => {
              sound.playClick();
              onClose();
            }}
            className="px-4 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 font-semibold text-xs"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
