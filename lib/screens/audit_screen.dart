import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/inventory_provider.dart';
import '../models/transaction.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  TransactionType? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    final transactions = provider.transactions.where((t) {
      if (_selectedFilter != null && t.type != _selectedFilter) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          'Audit Log & Sync History',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF111827),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterPill('All Transactions (${provider.transactions.length})', null),
                  _buildFilterPill('Stock In', TransactionType.stockIn),
                  _buildFilterPill('Sold Out', TransactionType.stockSold),
                  _buildFilterPill('Audit Adjustments', TransactionType.countCorrection),
                ],
              ),
            ),
          ),

          // Transactions List
          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Text(
                      'No transactions match the selected filter.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final txn = transactions[index];
                      final isStockIn = txn.type == TransactionType.stockIn;
                      final isSold = txn.type == TransactionType.stockSold;

                      final color = isStockIn
                          ? const Color(0xFF38BDF8)
                          : (isSold ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161F30),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF26334D)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        txn.type.displayName.toUpperCase(),
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      dateFormat.format(txn.timestamp),
                                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                                    ),
                                  ],
                                ),
                                Text(
                                  isStockIn
                                      ? '+${txn.quantity}'
                                      : (isSold ? '-${txn.quantity}' : '${txn.quantity} Adjusted'),
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              txn.itemName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Count: ${txn.previousLeftCount} \u2192 ${txn.newLeftCount} left',
                                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                                ),
                                if (txn.totalAmount != null && txn.totalAmount! > 0)
                                  Text(
                                    currencyFormat.format(txn.totalAmount),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                                  ),
                              ],
                            ),
                            if (txn.clientOrSupplier != null || txn.notes != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${txn.clientOrSupplier != null ? "[Party: ${txn.clientOrSupplier}] " : ""}${txn.notes ?? ""}',
                                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65)),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Text(txn.operatorName, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_android_rounded, size: 13, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(txn.deviceId, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, TransactionType? type) {
    final isSelected = _selectedFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = type),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}
