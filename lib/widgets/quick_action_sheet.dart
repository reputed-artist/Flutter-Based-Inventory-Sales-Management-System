import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_item.dart';
import '../models/transaction.dart';
import '../providers/inventory_provider.dart';

class QuickActionSheet extends StatefulWidget {
  final InventoryItem item;
  final TransactionType initialType;

  const QuickActionSheet({
    super.key,
    required this.item,
    required this.initialType,
  });

  @override
  State<QuickActionSheet> createState() => _QuickActionSheetState();
}

class _QuickActionSheetState extends State<QuickActionSheet> {
  late TransactionType _type;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    if (_type == TransactionType.countCorrection) {
      _quantityController.text = '${widget.item.leftCount}';
    } else {
      _quantityController.text = '1';
    }
    _priceController.text = _type == TransactionType.stockSold
        ? '${widget.item.unitSellingPrice.toInt()}'
        : '${widget.item.unitCostPrice.toInt()}';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _partyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _saving = false;

  /// Validate, then persist and only close the sheet once the server has
  /// committed.
  ///
  /// This used to be fire-and-forget: the sheet popped immediately, so a
  /// rejected sale (e.g. not enough stock) vanished without a trace and the
  /// count on screen looked unchanged.
  Future<void> _submit() async {
    final qty = int.tryParse(_quantityController.text) ?? 0;
    final isAudit = _type == TransactionType.countCorrection;
    if (qty <= 0 && !isAudit) return;

    final provider = context.read<InventoryProvider>();

    // Catch an obvious over-sale before spending a round trip. The server
    // re-checks under a row lock, so this is only a courtesy.
    if (_type == TransactionType.stockSold && qty > widget.item.leftCount) {
      _showError('Only ${widget.item.leftCount} left in stock.');
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);
    // Clear any error left over from a previous attempt, otherwise the check
    // below would always see a stale value.
    provider.clearError();

    final price = double.tryParse(_priceController.text);
    final party = _partyController.text.trim();
    final notes = _notesController.text.trim();

    try {
      switch (_type) {
        case TransactionType.stockIn:
          await provider.recordStockIn(
            itemId: widget.item.id,
            quantity: qty,
            unitPrice: price,
            supplier: party.isEmpty ? null : party,
            notes: notes.isEmpty ? null : notes,
          );
        case TransactionType.stockSold:
          await provider.recordStockSold(
            itemId: widget.item.id,
            quantity: qty,
            unitPrice: price,
            client: party.isEmpty ? null : party,
            notes: notes.isEmpty ? null : notes,
          );
        case TransactionType.countCorrection:
          await provider.recordCountAudit(
            itemId: widget.item.id,
            physicalCount: qty,
            reason: notes.isEmpty ? null : notes,
          );
        case TransactionType.stockTransfer:
          // Transfers are recorded but not moved by this sheet: they need a
          // source AND destination location, which the server RPC does not yet
          // model. Never silently treated as a sale.
          _showError('Transfers are not supported from this sheet yet.');
          return;
      }

      if (!mounted) return;
      // provider.lastError is non-null when the server refused the movement.
      if (provider.lastError != null) {
        _showError(provider.lastError!);
        return;
      }

      // Close only after reading the messenger, then warn if the change never
      // reached the database. A local-only save looks identical to a synced
      // one unless it is called out - and on the web build it is what made
      // Chrome appear to work while nothing was persisted.
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      if (!provider.lastSaveReachedServer) {
        setState(() => _saving = false);
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Saved on this device only - it could not reach the server, so '
              'the database was NOT updated.',
            ),
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      navigator.pop();
    } catch (e, st) {
      // Report the real cause. The previous hardcoded string here hid genuine
      // server refusals behind a misleading connectivity message.
      debugPrint('QuickActionSheet._submit failed: $e\n$st');
      if (!mounted) return;
      _showError(context.read<InventoryProvider>().lastError ?? 'Could not save: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStockIn = _type == TransactionType.stockIn;
    final isSold = _type == TransactionType.stockSold;
    final isAudit = _type == TransactionType.countCorrection;

    final actionColor = isStockIn
        ? const Color(0xFF0284C7)
        : (isSold ? const Color(0xFF059669) : const Color(0xFFD97706));

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF161F30),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.item.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'SKU: ${widget.item.sku} • Current Left: ${widget.item.leftCount} ${widget.item.unit}',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),

            // Mode Selector
            Row(
              children: [
                _buildModeTab('Stock In', TransactionType.stockIn, const Color(0xFF0284C7)),
                const SizedBox(width: 8),
                _buildModeTab('Sold Out', TransactionType.stockSold, const Color(0xFF059669)),
                const SizedBox(width: 8),
                _buildModeTab('Audit Count', TransactionType.countCorrection, const Color(0xFFD97706)),
              ],
            ),
            const SizedBox(height: 20),

            // Quantity input with quick stepper buttons (+1, +5, +10, +25)
            Text(
              isAudit ? 'PHYSICAL AUDIT COUNT (ACTUAL ON SHELF)' : 'QUANTITY TO ${isStockIn ? "ADD" : "DISPATCH"}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.remove_rounded, color: Colors.white),
                  onPressed: () {
                    final cur = int.tryParse(_quantityController.text) ?? 1;
                    if (cur > 0) _quantityController.text = '${cur - 1}';
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0D1424),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  onPressed: () {
                    final cur = int.tryParse(_quantityController.text) ?? 0;
                    _quantityController.text = '${cur + 1}';
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Quick increment pills
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [5, 10, 20, 50].map((step) {
                return GestureDetector(
                  onTap: () {
                    final cur = int.tryParse(_quantityController.text) ?? 0;
                    _quantityController.text = '${cur + step}';
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text('+$step', style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            if (!isAudit) ...[
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: isStockIn ? 'Unit Purchase Cost (₹)' : 'Unit Selling Price (₹)',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0D1424),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _partyController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: isStockIn ? 'Supplier / Manufacturer Name' : 'Client / Buyer Name',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0D1424),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                ),
              ),
              const SizedBox(height: 10),
            ],

            TextField(
              controller: _notesController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: isAudit ? 'Audit reason / note (e.g. damaged, shelf count)' : 'Notes / Batch # / Invoice #',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0D1424),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isStockIn
                            ? 'CONFIRM STOCK IN'
                            : (isSold
                                ? 'RECORD SALES DISPATCH'
                                : 'UPDATE SHELF AUDIT COUNT'),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, TransactionType type, Color color) {
    final isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _type = type;
            if (type == TransactionType.countCorrection) {
              _quantityController.text = '${widget.item.leftCount}';
            } else if (_quantityController.text == '${widget.item.leftCount}') {
              _quantityController.text = '1';
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : const Color(0xFF334155), width: isSelected ? 1.5 : 1),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
