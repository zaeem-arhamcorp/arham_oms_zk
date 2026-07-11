import 'package:arham_corporation/helper/helper.dart';
import 'package:flutter/material.dart';

class ItemsView extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String partyName;
  final String partyCode;
  final String partyAddress;

  const ItemsView({
    super.key,
    required this.items,
    required this.partyName,
    required this.partyCode,
    required this.partyAddress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Items',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: items.isEmpty
            ? _buildEmptyState(isDark)
            : Column(
                children: [
                  if (partyName.isNotEmpty || partyCode.isNotEmpty)
                    _buildPartyNameSection(isDark),
                  if (partyAddress.isNotEmpty) _buildAddressBanner(isDark),
                  _buildSummaryBar(isDark),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      itemBuilder: (context, index) =>
                          _buildItemCard(context, index, isDark),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPartyNameSection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Text(
        partyName.isNotEmpty
            ? '$partyName${partyCode.isNotEmpty ? ' ($partyCode)' : ''}'
            : partyCode,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildAddressBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on,
              size: 14,
              color:
                  isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              partyAddress,
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? const Color(0xFFCED2D8) : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(bool isDark) {
    final totalQty = items.fold<num>(0, (sum, item) {
      final qty = item['QUANTITY'] ?? item['quantity'] ?? 0;
      return sum + (qty is num ? qty : num.tryParse(qty.toString()) ?? 0);
    });
    final totalAmount = items.fold<double>(0.0, (sum, item) {
      final amt = item['AMOUNT'] ?? item['amount'] ?? 0;
      return sum +
          (amt is num
              ? amt.toDouble()
              : double.tryParse(amt.toString()) ?? 0.0);
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A5F), const Color(0xFF1E293B)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3B82F6).withOpacity(0.20)
              : const Color(0xFF3B82F6).withOpacity(0.15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem(
            icon: Icons.inventory_2_outlined,
            label: 'Items',
            value: items.length.toString(),
            color: const Color(0xFF3B82F6),
            isDark: isDark,
          ),
          _divider(isDark),
          _summaryItem(
            icon: Icons.shopping_bag_outlined,
            label: 'Total Qty',
            value: totalQty.toString(),
            color: const Color(0xFF8B5CF6),
            isDark: isDark,
          ),
          _divider(isDark),
          _summaryItem(
            icon: Icons.currency_rupee,
            label: 'Total Amount',
            value: '₹${Helper.parseNumericValue(totalAmount.toString())}',
            color: const Color(0xFF10B981), //0xFF10B981
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Container(
      height: 30,
      width: 1,
      color: isDark
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.08),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, int index, bool isDark) {
    final item = items[index];
    final nestedItem = item['item'] is Map ? item['item'] as Map : null;
    final itemName = (item['ITEM_NAME'] ??
            item['item_name'] ??
            nestedItem?['ITEM_NAME'] ??
            nestedItem?['item_name'] ??
            '')
        .toString();
    final itemSname = (item['ITEM_SNAME'] ??
            item['item_sname'] ??
            nestedItem?['ITEM_SNAME'] ??
            nestedItem?['item_sname'] ??
            '')
        .toString();
    final quantity = item['QUANTITY'] ??
        item['quantity'] ??
        nestedItem?['QUANTITY'] ??
        nestedItem?['quantity'] ??
        0;
    final rate = item['RATE'] ??
        item['rate'] ??
        nestedItem?['RATE'] ??
        nestedItem?['rate'] ??
        0;
    final amount = item['AMOUNT'] ??
        item['amount'] ??
        nestedItem?['AMOUNT'] ??
        nestedItem?['amount'] ??
        0;

    final amountDouble = amount is num
        ? amount.toDouble()
        : double.tryParse(amount.toString()) ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.20 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item index badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName.isNotEmpty ? itemName : 'Unknown Item',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      if (itemSname.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          itemSname,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Amount badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: amountDouble > 0
                        ? const Color(0xFF10B981).withOpacity(0.10)
                        : const Color(0xFFEF4444).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '₹${Helper.parseNumericValue(amount.toString())}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: amountDouble > 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.06),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _metaChip(
                  label: 'Qty',
                  value: quantity.toString(),
                  icon: Icons.shopping_bag_outlined,
                  color: const Color(0xFF3B82F6),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _metaChip(
                  label: 'Rate',
                  value: '₹$rate',
                  icon: Icons.price_change_outlined,
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 56,
            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 16),
          Text(
            'No Items Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This order has no items recorded.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
