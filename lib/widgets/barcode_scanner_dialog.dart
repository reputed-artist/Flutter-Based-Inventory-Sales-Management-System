import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/quick_action_sheet.dart';
import '../models/transaction.dart';

class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  final TextEditingController _inputController = TextEditingController();

  final List<Map<String, String>> _sampleBarcodes = [
    {'name': 'HP 2580 Black Solvent', 'barcode': '884962829101'},
    {'name': 'HP 2590 Fast-Dry Black', 'barcode': '884962829102'},
    {'name': 'Handy TIJ 12.7mm Batch Coder', 'barcode': '884962829201'},
    {'name': 'Docod S100 Industrial TIJ', 'barcode': '884962829401'},
    {'name': 'Rynan SoluMark BK90', 'barcode': '884962829501'},
  ];

  void _handleLookup(String code) {
    if (code.trim().isEmpty) return;
    final provider = context.read<InventoryProvider>();
    final trimmed = code.trim().toLowerCase();

    final item = provider.items.firstWhere(
      (i) =>
          (i.barcode != null && i.barcode!.toLowerCase() == trimmed) ||
          i.sku.toLowerCase() == trimmed ||
          i.name.toLowerCase().contains(trimmed),
      orElse: () => provider.items.first,
    );

    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickActionSheet(item: item, initialType: TransactionType.stockSold),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161F30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF38BDF8), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Barcode & SKU Scanner',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Scanner Viewport Mock for Android
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1424),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 180,
                    height: 90,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Container(
                    height: 2,
                    width: 170,
                    color: const Color(0xFFEF4444),
                  ),
                  Positioned(
                    bottom: 8,
                    child: Text(
                      'Point camera at Cartridge or Printer barcode',
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Manual SKU/Barcode Input
            const Text(
              'OR ENTER BARCODE / SKU CODE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. 884962829101 or HP-B3F58B',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0D1424),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                    ),
                    onSubmitted: (val) => _handleLookup(val),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _handleLookup(_inputController.text),
                  child: const Text('Find', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quick Test Tap Chips
            const Text(
              'SAMPLE BARCODES TO TEST:',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _sampleBarcodes.map((b) {
                return GestureDetector(
                  onTap: () => _handleLookup(b['barcode']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      b['name']!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8), fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
