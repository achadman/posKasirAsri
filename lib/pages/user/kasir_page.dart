import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Added
import '../../widgets/product_grid.dart';
import '../../widgets/kasir_drawer.dart';
import '../../services/order_service.dart'; // Added

class KasirPage extends StatefulWidget {
  const KasirPage({super.key});

  @override
  State<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends State<KasirPage> {
  final supabase = Supabase.instance.client;
  final _orderService = OrderService(); // Added
  final _currencyFormat = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String? _storeId;
  String _selectedCategory = "Semua";
  String? _selectedCategoryId;
  String _searchQuery = "";
  final Map<String, int> _cart = {}; // ProductID -> Qty
  List<String> _categories = ["Semua"];
  final Map<String, String> _categoryMap = {}; // Name -> ID

  final Color _primaryColor = const Color(0xFFFF4D4D); // Vibrant Red
  bool _isCategoriesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStoreId();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // First get store id if not already loaded
      final prof = await supabase
          .from('profiles')
          .select('store_id')
          .eq('id', user.id)
          .maybeSingle();
      final sId = prof?['store_id'];

      if (sId != null) {
        final List<Map<String, dynamic>> data = await supabase
            .from('categories')
            .select('id, name')
            .eq('store_id', sId);

        if (mounted) {
          setState(() {
            _categoryMap.clear();
            List<String> names = ["Semua"];
            for (var c in data) {
              final name = c['name'] as String;
              final id = c['id'] as String;
              names.add(name);
              _categoryMap[name] = id;
            }
            _categories = names;
            _isCategoriesLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading categories: $e");
      if (mounted) setState(() => _isCategoriesLoading = false);
    }
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

  Future<void> _processCheckout() async {
    if (_cart.isEmpty || _storeId == null) return;

    setState(() => _isProcessing = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch current product prices and details
      final productIds = _cart.keys.toList();
      final productsResponse = await supabase
          .from('products')
          .select('id, sale_price')
          .filter('id', 'in', productIds);

      double totalAmount = 0;
      List<Map<String, dynamic>> items = [];

      for (var p in productsResponse) {
        final id = p['id'];
        final qty = _cart[id]!;
        final price = (p['sale_price'] as num).toDouble();
        final total = price * qty;

        totalAmount += total;
        items.add({
          'product_id': id,
          'quantity': qty,
          'unit_price': price,
          'total_price': total,
        });
      }

      // 2. Save order
      await _orderService.createOrder(
        storeId: _storeId!,
        userId: user.id,
        totalAmount: totalAmount,
        items: items,
      );

      // 3. Success
      if (mounted) {
        setState(() => _cart.clear());
        Navigator.pop(context); // Close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Transaksi Berhasil!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Checkout Gagal: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      drawer: const KasirDrawer(currentRoute: '/kasir'),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1A1C1E) : Colors.white,
            elevation: 0,
            leading: Builder(
              builder: (context) => IconButton(
                icon: Icon(
                  CupertinoIcons.bars,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                onChanged: (val) =>
                    setState(() => _searchQuery = val.toLowerCase()),
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: "Cari menu...",
                  hintStyle: GoogleFonts.inter(color: Colors.grey),
                  prefixIcon: const Icon(
                    CupertinoIcons.search,
                    size: 20,
                    color: Colors.grey,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Stack(
                  children: [
                    Icon(
                      CupertinoIcons.cart,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    if (_getCartTotalCount() > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 8,
                            minHeight: 8,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: _getCartTotalCount() > 0 ? _showCartSheet : null,
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                height: 50,
                padding: const EdgeInsets.only(bottom: 10),
                child: _isCategoriesLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = _selectedCategory == cat;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCategory = cat;
                                _selectedCategoryId = _categoryMap[cat];
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _primaryColor
                                    : (isDark
                                          ? Colors.grey[800]
                                          : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? _primaryColor
                                      : Colors.grey.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                cat,
                                style: GoogleFonts.poppins(
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.white70
                                            : Colors.grey[600]),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
        body: _storeId == null
            ? const Center(child: CircularProgressIndicator())
            : ProductGrid(
                storeId: _storeId!,
                searchQuery: _searchQuery,
                categoryFilter: _selectedCategoryId,
                onItemTap: (p) => _addToCart(p['id']),
                extraInfoBuilder: (context, p) {
                  final stock = p['stock_quantity'] ?? 0;
                  return Text(
                    "Stok: $stock",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: stock < 5 ? Colors.red : Colors.grey,
                      fontWeight: stock < 5
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  );
                },
                actionBuilder: (context, p) {
                  int qty = _cart[p['id']] ?? 0;
                  return qty == 0
                      ? SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            color: isDark
                                ? Colors.grey[800]
                                : const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(12),
                            onPressed: () => _addToCart(p['id']),
                            child: Text(
                              "Tambah",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _circleBtn(
                              CupertinoIcons.minus,
                              () => _removeFromCart(p['id']),
                            ),
                            Text(
                              "$qty",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            _circleBtn(
                              CupertinoIcons.add,
                              () => _addToCart(p['id']),
                            ),
                          ],
                        );
                },
              ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: _primaryColor),
      ),
    );
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from('products')
                .select()
                .filter('id', 'in', _cart.keys.toList()),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              double total = 0;
              for (var p in items) {
                total +=
                    (p['sale_price'] as num).toDouble() * (_cart[p['id']] ?? 0);
              }

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(25),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Ringkasan Pesanan",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${_getCartTotalCount()} Item",
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (items.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text("Keranjang kosong"),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final p = items[i];
                            final qty = _cart[p['id']] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      image: p['image_url'] != null
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                p['image_url'],
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: p['image_url'] == null
                                        ? const Icon(
                                            Icons.fastfood,
                                            size: 20,
                                            color: Colors.grey,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p['name'],
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          "${qty}x ${_currencyFormat.format(p['sale_price'])}",
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _currencyFormat.format(
                                      p['sale_price'] * qty,
                                    ),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total Pembayaran",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(total),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _processCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isProcessing
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
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
              );
            },
          );
        },
      ),
    );
  }
}
