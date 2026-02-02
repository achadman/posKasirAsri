import 'package:flutter/material.dart';

class LowStockDialog extends StatelessWidget {
  final List<Map<String, dynamic>> lowStockItems;
  final VoidCallback onInventoryTap;

  const LowStockDialog({
    super.key,
    required this.lowStockItems,
    required this.onInventoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final primaryColor = Theme.of(context).primaryColor;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: screenWidth * 0.9,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade800, Colors.orange.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Stok Menipis!",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Segera lakukan restock.",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: lowStockItems.isEmpty
                  ? const _StockSafe()
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: lowStockItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) => _LowStockItem(
                        item: lowStockItems[i],
                        index: i,
                      ),
                    ),
            ),
            // Footer
            _DialogFooter(
              onClose: () => Navigator.pop(context),
              onManage: onInventoryTap,
              primaryColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _StockSafe extends StatelessWidget {
  const _StockSafe();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 60, color: Colors.green.shade300),
          const SizedBox(height: 10),
          const Text(
            "Stok Aman",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Tidak ada barang perlu restok.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LowStockItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;

  const _LowStockItem({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? 'Tanpa Nama';
    final stock = (item['stock_quantity'] as num?)?.toDouble() ?? 0.0;
    // Assuming 5 as default min stock threshold since it's hardcoded in the controller
    const double minStock = 5.0;
    final progress = (stock / minStock).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${index + 1}",
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      stock == 0 ? Colors.red : Colors.orange,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Sisa: ${stock.toInt()}",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: stock == 0 ? Colors.red : Colors.orange.shade800,
                      ),
                    ),
                    Text(
                      "Min: ${minStock.toInt()}",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogFooter extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onManage;
  final Color primaryColor;

  const _DialogFooter({
    required this.onClose,
    required this.onManage,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onClose,
              child: const Text("Tutup"),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: onManage,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text("Kelola Stok"),
            ),
          ),
        ],
      ),
    );
  }
}
