import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/floating_card.dart';
import '../../widgets/glass_app_bar.dart';

class KasirPage extends StatefulWidget {
  const KasirPage({super.key});

  @override
  State<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends State<KasirPage> {
  final supabase = Supabase.instance.client;
  final currencyFormat = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String? _storeId;
  String _selectedCategory = "Semua";
  String _searchQuery = "";
  Map<String, int> _cart = {}; // ProductID -> Qty
  final List<String> _categories = [
    "Semua",
    "Steak",
    "Chicken",
    "Rice Bowl",
    "Drink",
    "Snack",
  ];

  // Modern Clean Palette
  final Color _bgColor = const Color(0xFFF8F9FD); // Cool Light Grey
  final Color _primaryColor = const Color(0xFFFF4D4D); // Vibrant Red
  final Color _textHeading = const Color(0xFF2D3436); // Charcoal

  @override
  void initState() {
    super.initState();
    _loadStoreId();
  }

  Future<void> _loadStoreId() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final profile = await supabase
          .from('profiles')
          .select('store_id')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) setState(() => _storeId = profile?['store_id']);
    }
  }

  void _addToCart(String productId) {
    setState(() {
      _cart[productId] = (_cart[productId] ?? 0) + 1;
    });
  }

  void _removeFromCart(String productId) {
    setState(() {
      if ((_cart[productId] ?? 0) > 0) {
        _cart[productId] = _cart[productId]! - 1;
        if (_cart[productId] == 0) _cart.remove(productId);
      }
    });
  }

  int _getCartTotalCount() {
    return _cart.values.fold(0, (sum, qty) => sum + qty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Column(
          children: [
            Text(
              "Kasir Mode",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _textHeading,
              ),
            ),
            const SizedBox(height: 16),
            // Search Bar inside AppBar
            Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (val) =>
                    setState(() => _searchQuery = val.toLowerCase()),
                style: GoogleFonts.inter(color: _textHeading),
                decoration: InputDecoration(
                  hintText: "Cari menu...",
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey[400],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.access_time_filled_rounded, color: _primaryColor),
            tooltip: "Absensi Staff",
            onPressed: () {
              Navigator.pushNamed(context, '/attendance');
            },
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: _primaryColor),
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 150), // Space for tall AppBar
          // Categories
          SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? _primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        if (!isSelected)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Product Grid
          Expanded(
            child: _storeId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: supabase
                        .from('products')
                        .stream(primaryKey: ['id'])
                        .eq('store_id', _storeId!),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: _primaryColor,
                          ),
                        );
                      }

                      var products = snapshot.data!;
                      // Filter by Search
                      if (_searchQuery.isNotEmpty) {
                        products = products
                            .where(
                              (p) => p['name']
                                  .toString()
                                  .toLowerCase()
                                  .contains(_searchQuery),
                            )
                            .toList();
                      }
                      // Filter by Category (Mock logic as DB doesn't have Category yet)
                      // In real implementation: .where((p) => p['category'] == _selectedCategory)

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
                                "Menu tidak ditemukan",
                                style: GoogleFonts.inter(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.72,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: products.length,
                        itemBuilder: (context, i) {
                          final p = products[i];
                          int qty = _cart[p['id']] ?? 0;
                          return FloatingCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(24),
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.fastfood_rounded,
                                        size: 40,
                                        color: Colors.orange[100],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['name'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          color: _textHeading,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        currencyFormat.format(p['sale_price']),
                                        style: GoogleFonts.inter(
                                          color: _primaryColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      qty == 0
                                          ? SizedBox(
                                              width: double.infinity,
                                              height: 36,
                                              child: ElevatedButton(
                                                onPressed: () =>
                                                    _addToCart(p['id']),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor:
                                                      _primaryColor,
                                                  elevation: 0,
                                                  side: BorderSide(
                                                    color: _primaryColor
                                                        .withOpacity(0.5),
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  "Tambah",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                _circleBtn(
                                                  Icons.remove,
                                                  () =>
                                                      _removeFromCart(p['id']),
                                                ),
                                                Text(
                                                  "$qty",
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                _circleBtn(
                                                  Icons.add,
                                                  () => _addToCart(p['id']),
                                                ),
                                              ],
                                            ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _getCartTotalCount() > 0
          ? FloatingActionButton.extended(
              backgroundColor: _primaryColor,
              onPressed: () => _showCartSheet(),
              label: Text(
                "${_getCartTotalCount()} Item | Lihat Keranjang",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.shopping_bag_outlined),
            )
          : null,
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: _primaryColor),
      ),
    );
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ringkasan Pesanan",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _textHeading,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            // Cart Items List would go here
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Fitur Checkout akan segera hadir!",
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "Proses Pesanan",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
