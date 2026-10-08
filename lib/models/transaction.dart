enum TransactionType {
  stockIn,
  stockSold,
  countCorrection,
  stockTransfer,
}

extension TransactionTypeExtension on TransactionType {
  String get id {
    switch (this) {
      case TransactionType.stockIn:
        return 'in';
      case TransactionType.stockSold:
        return 'sold';
      case TransactionType.countCorrection:
        return 'correction';
      case TransactionType.stockTransfer:
        return 'transfer';
    }
  }

  String get displayName {
    switch (this) {
      case TransactionType.stockIn:
        return 'Stock Received';
      case TransactionType.stockSold:
        return 'Sold to Client';
      case TransactionType.countCorrection:
        return 'Physical Audit Count';
      case TransactionType.stockTransfer:
        return 'Location Transfer';
    }
  }

  static TransactionType fromString(String val) {
    switch (val) {
      case 'in':
        return TransactionType.stockIn;
      case 'sold':
        return TransactionType.stockSold;
      case 'correction':
        return TransactionType.countCorrection;
      case 'transfer':
        return TransactionType.stockTransfer;
      default:
        return TransactionType.stockIn;
    }
  }
}

class InventoryTransaction {
  final String id;
  final String itemId;
  final String itemName;
  final String itemSku;
  final TransactionType type;
  final int quantity;
  final int previousLeftCount;
  final int newLeftCount;
  final double? unitPrice;
  final double? totalAmount;
  final String? clientOrSupplier;
  final String? notes;
  final String operatorName;
  final String deviceId;
  final DateTime timestamp;

  InventoryTransaction({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.itemSku,
    required this.type,
    required this.quantity,
    required this.previousLeftCount,
    required this.newLeftCount,
    this.unitPrice,
    this.totalAmount,
    this.clientOrSupplier,
    this.notes,
    required this.operatorName,
    required this.deviceId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_id': itemId,
      'item_name': itemName,
      'item_sku': itemSku,
      'type': type.id,
      'quantity': quantity,
      'previous_left_count': previousLeftCount,
      'new_left_count': newLeftCount,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'client_or_supplier': clientOrSupplier,
      'notes': notes,
      'operator_name': operatorName,
      'device_id': deviceId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory InventoryTransaction.fromJson(Map<String, dynamic> map) {
    return InventoryTransaction(
      id: map['id']?.toString() ?? '',
      itemId: map['item_id']?.toString() ?? '',
      itemName: map['item_name']?.toString() ?? '',
      itemSku: map['item_sku']?.toString() ?? '',
      type: TransactionTypeExtension.fromString(map['type']?.toString() ?? 'in'),
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      previousLeftCount: (map['previous_left_count'] as num?)?.toInt() ?? 0,
      newLeftCount: (map['new_left_count'] as num?)?.toInt() ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble(),
      totalAmount: (map['total_amount'] as num?)?.toDouble(),
      clientOrSupplier: map['client_or_supplier']?.toString(),
      notes: map['notes']?.toString(),
      operatorName: map['operator_name']?.toString() ?? 'Operator',
      deviceId: map['device_id']?.toString() ?? 'Android',
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
