import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'floating_card.dart';

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

        // Client-side Filtering (Search)
        if (searchQuery.isNotEmpty) {
          products = products.where((p) {
            return p['name'].toString().toLowerCase().contains(searchQuery);
          }).toList();
        }

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

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: products.length,
          itemBuilder: (context, i) {
            final p = products[i];
            return FloatingCard(
              onTap: () => onItemTap(p),
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[50],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        image: p['image_url'] != null
                            ? DecorationImage(
                                image: NetworkImage(p['image_url']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: p['image_url'] == null
                          ? Center(
                              child: Icon(
                                Icons.fastfood_rounded,
                                size: 40,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.orange[100],
                              ),
                            )
                          : null,
                    ),
                  ),

                  // Info
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['name'] ?? 'Tanpa Nama',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textHeading,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(p['sale_price']),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                        // Additional Info (like Stock)
                        if (extraInfoBuilder != null)
                          extraInfoBuilder!(context, p),

                        const SizedBox(height: 8),

                        // Action Buttons (Add to Cart / Delete)
                        if (actionBuilder != null) actionBuilder!(context, p),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
