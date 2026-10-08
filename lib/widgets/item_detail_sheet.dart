import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';

class ItemDetailSheet extends StatefulWidget {
  final InventoryItem? item;

  const ItemDetailSheet({super.key, this.item});

  @override
  State<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<ItemDetailSheet> {
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _descController;
  late TextEditingController _initialCountController;
  late TextEditingController _minAlertController;
  late TextEditingController _costPriceController;
  late TextEditingController _sellPriceController;
  late TextEditingController _locationController;
  late TextEditingController _barcodeController;
  late InventoryCategory _category;
  late String _unit;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _skuController = TextEditingController(text: item?.sku ?? '');
    _descController = TextEditingController(text: item?.description ?? '');
    _initialCountController = TextEditingController(text: item != null ? '${item.leftCount}' : '10');
    _minAlertController = TextEditingController(text: item != null ? '${item.minStockAlert}' : '5');
    _costPriceController = TextEditingController(text: item != null ? '${item.unitCostPrice.toInt()}' : '2500');
    _sellPriceController = TextEditingController(text: item != null ? '${item.unitSellingPrice.toInt()}' : '3500');
    _locationController = TextEditingController(text: item?.location ?? 'Shelf A-1');
    _barcodeController = TextEditingController(text: item?.barcode ?? '');
    _category = item?.category ?? InventoryCategory.hpCartridges;
    _unit = item?.unit ?? 'Cartridge';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _descController.dispose();
    _initialCountController.dispose();
    _minAlertController.dispose();
    _costPriceController.dispose();
    _sellPriceController.dispose();
    _locationController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty || _skuController.text.trim().isEmpty) {
      return;
    }

    final provider = context.read<InventoryProvider>();
    final count = int.tryParse(_initialCountController.text) ?? 0;
    final minAlert = int.tryParse(_minAlertController.text) ?? 5;
    final costPrice = double.tryParse(_costPriceController.text) ?? 0.0;
    final sellPrice = double.tryParse(_sellPriceController.text) ?? 0.0;

    final newItem = InventoryItem(
      id: widget.item?.id ?? 'item_${DateTime.now().millisecondsSinceEpoch}',
      sku: _skuController.text.trim().toUpperCase(),
      name: _nameController.text.trim(),
      category: _category,
      unit: _unit,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      totalIn: widget.item?.totalIn ?? count,
      totalSold: widget.item?.totalSold ?? 0,
      leftCount: widget.item != null ? widget.item!.leftCount : count,
      minStockAlert: minAlert,
      unitCostPrice: costPrice,
      unitSellingPrice: sellPrice,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      lastUpdated: DateTime.now(),
      lastUpdatedBy: provider.currentOperator.name,
    );

    provider.saveItem(newItem);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF161F30),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEdit ? 'Edit Inventory Item' : 'Register New Item',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              children: [
                _buildField('Item / Product Name *', _nameController, 'e.g. HP 2580 Black Solvent Cartridge'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildField('SKU Code *', _skuController, 'e.g. HP-B3F58B')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildField('Barcode Number', _barcodeController, 'e.g. 884962829101')),
                  ],
                ),
                const SizedBox(height: 12),

                // Category Dropdown
                const Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1424),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<InventoryCategory>(
                      value: _category,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: InventoryCategory.values.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat.displayName));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _category = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    if (!isEdit) ...[
                      Expanded(child: _buildField('Initial Count In Stock', _initialCountController, '10', isNumber: true)),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: _buildField('Low Stock Reorder Alert', _minAlertController, '5', isNumber: true)),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(child: _buildField('Unit Cost Price (₹)', _costPriceController, '2500', isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildField('Unit Selling Price (₹)', _sellPriceController, '3500', isNumber: true)),
                  ],
                ),
                const SizedBox(height: 12),

                _buildField('Warehouse Shelf / Rack Location', _locationController, 'e.g. Rack A-1 (Inks)'),
                const SizedBox(height: 12),
                _buildField('Description / Specifications', _descController, 'Solvent ink cartridge for foil packaging...', maxLines: 2),
                const SizedBox(height: 20),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _save,
              child: Text(
                isEdit ? 'SAVE CHANGES' : 'CREATE ITEM',
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF0D1424),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}
