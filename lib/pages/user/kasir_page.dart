import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Added
import '../../widgets/product_grid.dart';
import '../../widgets/kasir_drawer.dart';
import '../../services/order_service.dart';
import '../../services/receipt_service.dart';
import 'widgets/product_option_modal.dart';
import 'widgets/receipt_preview_page.dart';

class KasirPage extends StatefulWidget {
  const KasirPage({super.key});

  @override
  State<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends State<KasirPage> {
  final supabase = Supabase.instance.client;
  final _orderService = OrderService();
  final _receiptService = ReceiptService();
  final _currencyFormat = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String? _storeId;
  String _selectedCategory = "Semua";
  String? _selectedCategoryId;
  String _searchQuery = "";
  final List<Map<String, dynamic>> _cartItems =
      []; // [{id, product, qty, options, notes, price}]
  List<String> _categories = ["Semua"];
  final Map<String, String> _categoryMap = {}; // Name -> ID

  final Color _primaryColor = const Color(0xFFFF4D4D); // Vibrant Red
  bool _isCategoriesLoading = true;
  String? _storeName;
  String? _storeLogoUrl;

  // Payment Logic
  double _cashReceived = 0;
  String _selectedPaymentMethod = "Tunai";
  final TextEditingController _cashController = TextEditingController();

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

      if (profile?['store_id'] != null && mounted) {
        final sId = profile!['store_id'];
        setState(() => _storeId = sId);

        // Load Store Details for Receipt
        final storeData = await supabase
            .from('stores')
            .select('name, logo_url')
            .eq('id', sId)
            .maybeSingle();

        if (storeData != null && mounted) {
          setState(() {
            _storeName = storeData['name'];
            _storeLogoUrl = storeData['logo_url'];
          });
        }
      }
    }
  }

  int _getCartTotalCount() {
    return _cartItems.fold(0, (sum, item) => sum + (item['quantity'] as int));
  }

  Future<void> _handleProductSelection(Map<String, dynamic> product) async {
    // 1. Check if product has options
    final response = await supabase
        .from('product_options')
        .select('id')
        .eq('product_id', product['id']);

    final count = response.length;

    if (count > 0 && mounted) {
      // Show Customization Modal
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ProductOptionModal(product: product),
      );

      if (result != null) {
        _addToCart(
          product,
          options: result['choices'],
          notes: result['notes'],
          price: result['total_price'],
        );
      }
    } else {
      // Add directly
      _addToCart(product, price: (product['sale_price'] as num).toDouble());
    }
  }

  void _addToCart(
    Map<String, dynamic> product, {
    List? options,
    String? notes,
    double? price,
  }) {
    setState(() {
      // Check if exact same item (product + options + notes) already in cart
      final existingIndex = _cartItems.indexWhere((item) {
        bool sameProduct = item['product']['id'] == product['id'];
        bool sameOptions = _compareOptions(item['selected_options'], options);
        bool sameNotes = (item['notes'] ?? '') == (notes ?? '');
        return sameProduct && sameOptions && sameNotes;
      });

      if (existingIndex != -1) {
        _cartItems[existingIndex]['quantity']++;
      } else {
        _cartItems.add({
          'cart_id': DateTime.now().microsecondsSinceEpoch.toString(),
          'product': product,
          'quantity': 1,
          'selected_options': options ?? [],
          'notes': notes ?? '',
          'price': price ?? (product['sale_price'] as num).toDouble(),
        });
      }
    });
  }

  bool _compareOptions(List? a, List? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    // Sort and compare option/value IDs
    final listA = List<Map<String, dynamic>>.from(a)
      ..sort((x, y) => x['value_id'].compareTo(y['value_id']));
    final listB = List<Map<String, dynamic>>.from(b)
      ..sort((x, y) => x['value_id'].compareTo(y['value_id']));

    for (int i = 0; i < listA.length; i++) {
      if (listA[i]['value_id'] != listB[i]['value_id']) return false;
    }
    return true;
  }

  void _removeFromCart(String cartId) {
    setState(() {
      final index = _cartItems.indexWhere((item) => item['cart_id'] == cartId);
      if (index != -1) {
        if (_cartItems[index]['quantity'] > 1) {
          _cartItems[index]['quantity']--;
        } else {
          _cartItems.removeAt(index);
        }
      }
    });
  }

  Future<void> _processCheckout() async {
    if (_cartItems.isEmpty || _storeId == null) return;

    setState(() => _isProcessing = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch current product prices and details - We use cart item data directly
      double totalAmount = 0;
      List<Map<String, dynamic>> items = [];

      for (var cartItem in _cartItems) {
        final qty = cartItem['quantity'] as int;
        final price = cartItem['price'] as double;
        final total = price * qty;

        totalAmount += total;
        items.add({
          'product_id': cartItem['product']['id'],
          'quantity': qty,
          'unit_price': price,
          'total_price': total,
          'notes': cartItem['notes'],
          'selected_options': cartItem['selected_options'],
        });
      }

      // 2. Save order and get ID
      final txId = await _orderService.createOrder(
        storeId: _storeId!,
        userId: user.id,
        totalAmount: totalAmount,
        items: items,
      );

      // 3. Generate Receipt Data
      final now = DateTime.now();
      final double finalCash = _cashReceived;
      final double finalChange = _cashReceived - totalAmount;
      final currentStoreName = _storeName ?? "Toko Kasir Asri";
      final currentStoreLogo = _storeLogoUrl;

      // Prepare items for receipt with their names (from cart)
      final List<Map<String, dynamic>> receiptItems = [];
      for (var cartItem in _cartItems) {
        receiptItems.add({
          'name': cartItem['product']['name'],
          'quantity': cartItem['quantity'],
          'unit_price': cartItem['price'],
          'total_price':
              (cartItem['price'] as double) * (cartItem['quantity'] as int),
          'notes': cartItem['notes'],
        });
      }

      final pdfData = await _receiptService.generateReceiptPdf(
        storeName: currentStoreName,
        storeLogoUrl: currentStoreLogo,
        transactionId: txId
            .substring(0, 8)
            .toUpperCase(), // Shorten for receipt
        createdAt: now,
        items: receiptItems,
        totalAmount: totalAmount,
        cashReceived: finalCash,
        change: finalChange,
        paymentMethod: _selectedPaymentMethod,
      );

      // 4. Success and Show Receipt
      if (mounted) {
        setState(() {
          _cartItems.clear();
          _cashReceived = 0;
          _cashController.clear();
        });

        Navigator.pop(context); // Close cart sheet

        // Navigate to Receipt Preview
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => ReceiptPreviewPage(
              pdfData: pdfData,
              fileName: "Struk_${txId.substring(0, 8)}.pdf",
              storeName: currentStoreName,
              transactionId: txId.substring(0, 8).toUpperCase(),
              createdAt: now,
              items: receiptItems,
              totalAmount: totalAmount,
              cashReceived: finalCash,
              change: finalChange,
              paymentMethod: _selectedPaymentMethod,
            ),
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
            expandedHeight: 50.0,
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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey[100],
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
                  hintStyle: GoogleFonts.inter(
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.grey,
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
          ),
        ],
        body: _storeId == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Horizontal Categories
                  if (!_isCategoriesLoading)
                    Container(
                      height: 100,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1C1E) : Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? Colors.white10 : Colors.grey[100]!,
                          ),
                        ),
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = cat;
                                  _selectedCategoryId = _categoryMap[cat];
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _primaryColor.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? _primaryColor
                                        : Colors.grey.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _getCategoryIcon(cat),
                                      color: isSelected
                                          ? _primaryColor
                                          : Colors.grey,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      cat,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? _primaryColor
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Product List
                  Expanded(
                    child: ProductGrid(
                      storeId: _storeId!,
                      searchQuery: _searchQuery,
                      categoryFilter: _selectedCategoryId,
                      onItemTap: (p) => _handleProductSelection(p),
                      actionBuilder: (context, p) {
                        // Check stock status for action icon
                        final isStockManaged = p['is_stock_managed'] ?? true;
                        final stockQty = (p['stock_quantity'] ?? 0) as int;
                        final isOutOfStock = isStockManaged && stockQty <= 0;

                        final inCartItems = _cartItems.where(
                          (item) => item['product']['id'] == p['id'],
                        );
                        int qty = inCartItems.fold(
                          0,
                          (sum, item) => sum + (item['quantity'] as int),
                        );

                        if (isOutOfStock) {
                          return Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.block_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          );
                        }

                        return qty == 0
                            ? Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              )
                            : Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _primaryColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    qty.toString(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  IconData _getCategoryIcon(String name) {
    name = name.toLowerCase();
    if (name.contains('semua')) return Icons.grid_view_rounded;
    if (name.contains('makanan') || name.contains('nusantara'))
      return Icons.restaurant_rounded;
    if (name.contains('minuman')) return Icons.local_drink_rounded;
    if (name.contains('snack')) return Icons.cookie_rounded;
    if (name.contains('pasta')) return Icons.ramen_dining_rounded;
    if (name.contains('western')) return Icons.fastfood_rounded;
    if (name.contains('pencuci mulut') || name.contains('dessert'))
      return Icons.icecream_rounded;
    return Icons.category_rounded;
  }

  Widget _buildPaymentMethodChip(
    String label,
    IconData icon,
    StateSetter setSheetState,
  ) {
    final isSelected = _selectedPaymentMethod == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () {
          setSheetState(() => _selectedPaymentMethod = label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? _primaryColor
                : (isDark ? Colors.grey[900] : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? _primaryColor
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCashBtn(
    String label,
    double amount,
    StateSetter setSheetState,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: () {
          setSheetState(() {
            _cashReceived = amount;
            _cashController.text = amount.toInt().toString();
          });
        },
        backgroundColor: Colors.grey.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount, {
    double fontSize = 14,
    bool isBold = false,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.grey[600],
          ),
        ),
        Text(
          _currencyFormat.format(amount),
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color:
                color ??
                (isBold
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white70 : Colors.grey[800])),
          ),
        ),
      ],
    );
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          double total = _cartItems.fold(
            0,
            (sum, item) =>
                sum + ((item['price'] as double) * (item['quantity'] as int)),
          );
          double change = _cashReceived - total;

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
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
                  if (_cartItems.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("Keranjang kosong"),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.3,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _cartItems.length,
                        itemBuilder: (context, i) {
                          final item = _cartItems[i];
                          final p = item['product'];
                          final qty = item['quantity'] as int;
                          final price = item['price'] as double;
                          final options = List<Map<String, dynamic>>.from(
                            item['selected_options'] ?? [],
                          );
                          final notes = item['notes'] as String;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 45,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    image: p['image_url'] != null
                                        ? DecorationImage(
                                            image: NetworkImage(p['image_url']),
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
                                      if (options.isNotEmpty)
                                        Text(
                                          options
                                              .map((o) => o['value_name'])
                                              .join(", "),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      if (notes.isNotEmpty)
                                        Text(
                                          "Note: $notes",
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Colors.orange[800],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _currencyFormat.format(price * qty),
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 18,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () {
                                            _removeFromCart(item['cart_id']);
                                            setSheetState(() {});
                                            setState(() {});
                                          },
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Text(
                                            "$qty",
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 18,
                                            color: Color(0xFFFF4D4D),
                                          ),
                                          onPressed: () {
                                            _addToCart(
                                              p,
                                              options: item['selected_options'],
                                              notes: item['notes'],
                                              price: item['price'],
                                            );
                                            setSheetState(() {});
                                            setState(() {});
                                          },
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
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
                  const Divider(height: 32),
                  Text(
                    "Metode Pembayaran",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildPaymentMethodChip(
                        "Tunai",
                        Icons.payments_outlined,
                        setSheetState,
                      ),
                      const SizedBox(width: 10),
                      _buildPaymentMethodChip(
                        "QRIS",
                        Icons.qr_code_scanner_rounded,
                        setSheetState,
                      ),
                      const SizedBox(width: 10),
                      _buildPaymentMethodChip(
                        "Transfer",
                        Icons.account_balance_wallet_outlined,
                        setSheetState,
                      ),
                    ],
                  ),
                  if (_selectedPaymentMethod == "Tunai") ...[
                    const SizedBox(height: 24),
                    Text(
                      "Uang Diterima",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cashController,
                      keyboardType: TextInputType.number,
                      autofocus: false,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                      decoration: InputDecoration(
                        prefixText: "Rp ",
                        prefixStyle: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.cancel_outlined),
                          onPressed: () {
                            setSheetState(() {
                              _cashController.clear();
                              _cashReceived = 0;
                            });
                          },
                        ),
                      ),
                      onChanged: (val) {
                        setSheetState(() {
                          _cashReceived =
                              double.tryParse(
                                val.replaceAll(RegExp(r'[^0-9]'), ''),
                              ) ??
                              0;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickCashBtn("Uang Pas", total, setSheetState),
                          _buildQuickCashBtn("50.000", 50000, setSheetState),
                          _buildQuickCashBtn("100.000", 100000, setSheetState),
                          _buildQuickCashBtn("200.000", 200000, setSheetState),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  _buildSummaryRow("Subtotal", total, fontSize: 14),
                  if (_selectedPaymentMethod == "Tunai" &&
                      _cashReceived > 0) ...[
                    const SizedBox(height: 8),
                    _buildSummaryRow("Diterima", _cashReceived, fontSize: 14),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      "Kembalian",
                      change > 0 ? change : 0,
                      fontSize: 16,
                      isBold: true,
                      color: change >= 0 ? Colors.green : Colors.red,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          (_isProcessing ||
                              (_selectedPaymentMethod == "Tunai" &&
                                  _cashReceived < total))
                          ? null
                          : _processCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _selectedPaymentMethod == "Tunai" &&
                                      _cashReceived < total
                                  ? "Uang Kurang"
                                  : "Proses Pesanan",
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
        },
      ),
    );
  }
}
