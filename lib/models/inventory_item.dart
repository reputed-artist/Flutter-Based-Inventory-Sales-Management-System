enum InventoryCategory {
  hpCartridges,
  handyPrinter,
  onlinePrinter,
  docodPrinter,
  rynanCartridges,
  packagingMachines,
}

extension InventoryCategoryExtension on InventoryCategory {
  String get id {
    switch (this) {
      case InventoryCategory.hpCartridges:
        return 'hp_cartridges';
      case InventoryCategory.handyPrinter:
        return 'handy_printer';
      case InventoryCategory.onlinePrinter:
        return 'online_printer';
      case InventoryCategory.docodPrinter:
        return 'docod_printer';
      case InventoryCategory.rynanCartridges:
        return 'rynan_cartridges';
      case InventoryCategory.packagingMachines:
        return 'packaging_machines';
    }
  }

  String get displayName {
    switch (this) {
      case InventoryCategory.hpCartridges:
        return 'HP Cartridges';
      case InventoryCategory.handyPrinter:
        return 'Handy Printers';
      case InventoryCategory.onlinePrinter:
        return 'Online Printers';
      case InventoryCategory.docodPrinter:
        return 'Docod Printers';
      case InventoryCategory.rynanCartridges:
        return 'Rynan Cartridges';
      case InventoryCategory.packagingMachines:
        return 'Packaging Machines';
    }
  }

  static InventoryCategory fromString(String val) {
    switch (val) {
      case 'hp_cartridges':
        return InventoryCategory.hpCartridges;
      case 'handy_printer':
        return InventoryCategory.handyPrinter;
      case 'online_printer':
        return InventoryCategory.onlinePrinter;
      case 'docod_printer':
        return InventoryCategory.docodPrinter;
      case 'rynan_cartridges':
        return InventoryCategory.rynanCartridges;
      case 'packaging_machines':
        return InventoryCategory.packagingMachines;
      default:
        return InventoryCategory.hpCartridges;
    }
  }
}

class InventoryItem {
  final String id;
  final String sku;
  final String name;
  final InventoryCategory category;
  final String unit;
  final String? description;
  final int totalIn;
  final int totalSold;
  final int leftCount;
  final int minStockAlert;
  final double unitCostPrice;
  final double unitSellingPrice;
  final String? location;
  final String? barcode;
  final DateTime lastUpdated;
  final String lastUpdatedBy;

  InventoryItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.unit,
    this.description,
    required this.totalIn,
    required this.totalSold,
    required this.leftCount,
    this.minStockAlert = 5,
    this.unitCostPrice = 0.0,
    this.unitSellingPrice = 0.0,
    this.location,
    this.barcode,
    required this.lastUpdated,
    required this.lastUpdatedBy,
  });

  bool get isLowStock => leftCount <= minStockAlert && leftCount > 0;
  bool get isOutOfStock => leftCount <= 0;

  InventoryItem copyWith({
    String? id,
    String? sku,
    String? name,
    InventoryCategory? category,
    String? unit,
    String? description,
    int? totalIn,
    int? totalSold,
    int? leftCount,
    int? minStockAlert,
    double? unitCostPrice,
    double? unitSellingPrice,
    String? location,
    String? barcode,
    DateTime? lastUpdated,
    String? lastUpdatedBy,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      totalIn: totalIn ?? this.totalIn,
      totalSold: totalSold ?? this.totalSold,
      leftCount: leftCount ?? this.leftCount,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      unitCostPrice: unitCostPrice ?? this.unitCostPrice,
      unitSellingPrice: unitSellingPrice ?? this.unitSellingPrice,
      location: location ?? this.location,
      barcode: barcode ?? this.barcode,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sku': sku,
      'name': name,
      'category': category.id,
      'unit': unit,
      'description': description,
      'total_in': totalIn,
      'total_sold': totalSold,
      'left_count': leftCount,
      'min_stock_alert': minStockAlert,
      'unit_cost_price': unitCostPrice,
      'unit_selling_price': unitSellingPrice,
      'location': location,
      'barcode': barcode,
      'last_updated': lastUpdated.toIso8601String(),
      'last_updated_by': lastUpdatedBy,
    };
  }

  factory InventoryItem.fromJson(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id']?.toString() ?? '',
      sku: map['sku']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: InventoryCategoryExtension.fromString(map['category']?.toString() ?? 'hp_cartridges'),
      unit: map['unit']?.toString() ?? 'units',
      description: map['description']?.toString(),
      totalIn: (map['total_in'] as num?)?.toInt() ?? 0,
      totalSold: (map['total_sold'] as num?)?.toInt() ?? 0,
      leftCount: (map['left_count'] as num?)?.toInt() ?? 0,
      minStockAlert: (map['min_stock_alert'] as num?)?.toInt() ?? 5,
      unitCostPrice: (map['unit_cost_price'] as num?)?.toDouble() ?? 0.0,
      unitSellingPrice: (map['unit_selling_price'] as num?)?.toDouble() ?? 0.0,
      location: map['location']?.toString(),
      barcode: map['barcode']?.toString(),
      lastUpdated: DateTime.tryParse(map['last_updated']?.toString() ?? '') ?? DateTime.now(),
      lastUpdatedBy: map['last_updated_by']?.toString() ?? 'Operator',
    );
  }
}
