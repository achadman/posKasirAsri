import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ProductGrid extends StatelessWidget {
  final String storeId;
  final String searchQuery;
  final String? categoryFilter;
  final Function(Map<String, dynamic>) onItemTap;
  final Widget Function(BuildContext, Map<String, dynamic>)? extraInfoBuilder;
  final Widget Function(BuildContext, Map<String, dynamic>)? actionBuilder;

  const ProductGrid({
    super.key,
    required this.storeId,
    this.searchQuery = "",
    this.categoryFilter,
    required this.onItemTap,
    this.extraInfoBuilder,
    this.actionBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if Dark Mode
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final textHeading = isDark ? Colors.white : const Color(0xFF2D3436);

    final currencyFormat = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final supabase = Supabase.instance.client;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('store_id', storeId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        var products = snapshot.data!;

        // Client-side Filtering (Search & Deleted)
        products = products.where((p) {
          final isDeleted = p['is_deleted'] ?? false;
          if (isDeleted == true) return false;

          if (searchQuery.isNotEmpty) {
            return p['name'].toString().toLowerCase().contains(searchQuery);
          }
          return true;
        }).toList();

        // Client-side Filtering (Category)
        if (categoryFilter != null && categoryFilter != "Semua") {
          products = products.where((p) {
            return p['category_id'] == categoryFilter;
          }).toList();
        }

        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 60,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 10),
                Text(
                  searchQuery.isEmpty
                      ? "Belum ada produk."
                      : "Produk tidak ditemukan.",
                  style: GoogleFonts.inter(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          itemCount: products.length,
          itemBuilder: (context, i) {
            final p = products[i];

            // Stock Logic
            final isStockManaged = p['is_stock_managed'] ?? true;
            final stockQty = (p['stock_quantity'] ?? 0) as int;
            final isOutOfStock = isStockManaged && stockQty <= 0;

            final originalPrice =
                (p['buy_price'] ?? 0)
                    as num; // Assuming buy_price acts as original for discount display if needed, or if there's a specific field
            final salePrice = (p['sale_price'] ?? 0) as num;
            final hasDiscount = originalPrice > salePrice;

            return Opacity(
              opacity: isOutOfStock ? 0.6 : 1.0,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: isOutOfStock ? null : () => onItemTap(p),
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Image on the Left
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            image: p['image_url'] != null
                                ? DecorationImage(
                                    image: NetworkImage(p['image_url']),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: p['image_url'] == null
                              ? Icon(
                                  Icons.fastfood_rounded,
                                  size: 30,
                                  color: isDark
                                      ? Colors.grey[600]
                                      : Colors.orange[100],
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),

                        // Product Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p['name'] ?? 'Tanpa Nama',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: textHeading,
                                      ),
                                    ),
                                  ),
                                  if (hasDiscount)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "${((originalPrice - salePrice) / originalPrice * 100).toInt()}% OFF",
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Price Row
                              Row(
                                children: [
                                  Text(
                                    currencyFormat.format(salePrice),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  if (hasDiscount) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      currencyFormat.format(originalPrice),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Stock & Action Row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Stock Info (Only if managed)
                                  if (isStockManaged)
                                    Text(
                                      isOutOfStock
                                          ? "Habis Terjual"
                                          : "Stok: $stockQty",
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: isOutOfStock
                                            ? Colors.red
                                            : Colors.grey[600],
                                        fontWeight: isOutOfStock
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    )
                                  else
                                    const SizedBox.shrink(),

                                  // Action Icon (on the right)
                                  if (actionBuilder != null)
                                    actionBuilder!(context, p)
                                  else
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isOutOfStock
                                            ? Colors.grey[300]
                                            : primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
