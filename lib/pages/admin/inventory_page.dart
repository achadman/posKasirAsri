import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'widgets/product_form_sheet.dart';
import '../../services/bulk_import_service.dart';

class InventoryPage extends StatefulWidget {
  final String storeId;
  const InventoryPage({super.key, required this.storeId});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  final _searchController = TextEditingController();
  final _importService = BulkImportService();

  final currencyFormat = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await supabase
          .from('products')
          .select('*, categories(name)')
          .eq('store_id', widget.storeId)
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(data);
          _filteredProducts = _products;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching products: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        final name = product['name'].toString().toLowerCase();
        final sku = (product['sku'] ?? '').toString().toLowerCase();
        return name.contains(query) || sku.contains(query);
      }).toList();
    });
  }

  void _openProductForm({Map<String, dynamic>? product}) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          ProductFormSheet(product: product, storeId: widget.storeId),
    );

    if (result == true) {
      _fetchProducts();
    }
  }

  void _handleBulkImport() async {
    final result = await _importService.importProductsFromCsv(widget.storeId);

    if (result['status'] == 'cancelled') return;

    if (result['status'] == 'error') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${result['message']}"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (result['status'] == 'success') {
      _fetchProducts();
      if (mounted) {
        _showImportResultDialog(
          success: result['successCount'],
          fail: result['failCount'],
          errors: result['errors'],
        );
      }
    }
  }

  void _showImportResultDialog({
    required int success,
    required int fail,
    required List<String> errors,
  }) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Hasil Impor"),
        content: Column(
          children: [
            const SizedBox(height: 10),
            Text("Berhasil: $success"),
            Text("Gagal: $fail"),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                "Detail Kesalahan:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  itemCount: errors.length,
                  itemBuilder: (c, i) => Text(
                    errors[i],
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Tutup"),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(String id) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Hapus Produk?"),
        content: const Text("Tindakan ini tidak dapat dibatalkan."),
        actions: [
          CupertinoDialogAction(
            child: const Text("Batal"),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Fetch product to get image_url before deletion
        final product = _products.firstWhere((p) => p['id'] == id);
        final imageUrl = product['image_url'];

        // Delete from Database
        await supabase.from('products').delete().eq('id', id);

        // Delete from Storage if exists
        if (imageUrl != null) {
          try {
            final uri = Uri.parse(imageUrl);
            final pathSegments = uri.pathSegments;
            final bucketIndex = pathSegments.indexOf('product');
            if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
              final fullPathInsideBucket = pathSegments
                  .sublist(bucketIndex + 1)
                  .join('/');
              await supabase.storage.from('product').remove([
                fullPathInsideBucket,
              ]);
            }
          } catch (e) {
            debugPrint("Storage cleanup error: $e");
          }
        }

        _fetchProducts();
      } catch (e) {
        debugPrint("Error deleting product: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Inventori Barang",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF2D3436),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: isDark ? Colors.white : const Color(0xFF2D3436),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              CupertinoIcons.cloud_upload_fill,
              color: Colors.blue,
              size: 24,
            ),
            onPressed: _handleBulkImport,
            tooltip: "Import CSV",
          ),
          IconButton(
            icon: const Icon(
              CupertinoIcons.plus_circle_fill,
              color: Color(0xFFEA5700),
              size: 28,
            ),
            onPressed: () => _openProductForm(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: "Cari nama barang atau SKU...",
                  hintStyle: GoogleFonts.inter(
                    color: isDark ? Colors.white38 : Colors.grey[400],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // Product List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchProducts,
              color: const Color(0xFFEA5700),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredProducts.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.2,
                        ),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                CupertinoIcons.cube_box,
                                size: 80,
                                color: Colors.grey[200],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? "Belum ada produk"
                                    : "Produk tidak ditemukan",
                                style: GoogleFonts.inter(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return _buildProductCard(product, index);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 50)),
      curve: Curves.easeOutQuint,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.2
                    : 0.03,
              ),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _openProductForm(product: product),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Product Image
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    image: product['image_url'] != null
                        ? DecorationImage(
                            image: NetworkImage(product['image_url']),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: product['image_url'] == null
                      ? Icon(CupertinoIcons.photo, color: Colors.grey[300])
                      : null,
                ),
                const SizedBox(width: 15),
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'],
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF2D3436),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              product['categories']?['name'] ?? 'No Category',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.indigo,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Stock: ${product['is_stock_managed'] ? product['stock_quantity'] : '∞'}",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color:
                                  product['is_stock_managed'] &&
                                      product['stock_quantity'] < 5
                                  ? Colors.red
                                  : Colors.grey[600],
                              fontWeight:
                                  product['is_stock_managed'] &&
                                      product['stock_quantity'] < 5
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(product['sale_price']),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFFEA5700),
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.pencil,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onPressed: () => _openProductForm(product: product),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(height: 10),
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.trash,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _deleteProduct(product['id']),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
