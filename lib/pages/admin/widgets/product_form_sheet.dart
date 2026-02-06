import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class ProductFormSheet extends StatefulWidget {
  final Map<String, dynamic>? product; // If null, Add mode. If not, Edit mode.
  final String storeId;

  const ProductFormSheet({super.key, this.product, required this.storeId});

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _buyPriceController = TextEditingController(); // Harga Beli
  final _salePriceController = TextEditingController(); // Harga Jual
  final _stockController = TextEditingController();

  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Stock Management Logic
  bool _isStockManaged = true; // Default to managed

  // Image Logic
  File? _imageFile;
  String? _currentImageUrl;
  final ImagePicker _picker = ImagePicker();

  // Category Logic
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];

  // Variant & Options Logic
  bool _enableVariants = false;
  List<Map<String, dynamic>> _productOptions = [];

  final Color _primaryColor = const Color(0xFFFF4D4D); // Vibrant Red

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.product != null) {
      _nameController.text = widget.product!['name'] ?? '';
      _skuController.text = widget.product!['sku'] ?? '';
      _descriptionController.text = widget.product!['description'] ?? '';
      _buyPriceController.text = (widget.product!['buy_price'] ?? 0).toString();
      _salePriceController.text = (widget.product!['sale_price'] ?? 0)
          .toString();
      _stockController.text = (widget.product!['stock_quantity'] ?? 0)
          .toString();
      _isStockManaged = widget.product!['is_stock_managed'] ?? true;
      _currentImageUrl = widget.product!['image_url'];
      _selectedCategoryId = widget.product!['category_id'];
      _fetchOptions();
    }
  }

  Future<void> _fetchOptions() async {
    if (widget.product == null) return;
    try {
      final options = await supabase
          .from('product_options')
          .select('*, product_option_values(*)')
          .eq('product_id', widget.product!['id']);

      if (mounted) {
        setState(() {
          _productOptions = List<Map<String, dynamic>>.from(options);
          if (_productOptions.isNotEmpty) {
            _enableVariants = true;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching options: $e");
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('categories')
          .select('id, name')
          .eq('store_id', widget.storeId)
          .order('name');
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
          // If editing and category not in list (deleted?), handle gracefully
          if (_selectedCategoryId != null &&
              !_categories.any((c) => c['id'] == _selectedCategoryId)) {
            _selectedCategoryId = null;
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading categories: $e");
    }
  }

  void _addOption() {
    setState(() {
      _productOptions.add({
        'option_name': '',
        'is_required': false,
        'product_option_values': [],
      });
      _enableVariants = true;
    });
  }

  void _removeOption(int index) {
    setState(() {
      _productOptions.removeAt(index);
      if (_productOptions.isEmpty) _enableVariants = false;
    });
  }

  void _addValue(int optionIndex) {
    setState(() {
      _productOptions[optionIndex]['product_option_values'].add({
        'value_name': '',
        'price_adjustment': 0.0,
      });
    });
  }

  void _removeValue(int optionIndex, int valueIndex) {
    setState(() {
      _productOptions[optionIndex]['product_option_values'].removeAt(
        valueIndex,
      );
    });
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final newCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Tambah Kategori",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Nama Kategori (Contoh: Makanan, Minuman)",
            fillColor: Colors.grey.withValues(alpha: 0.1),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal", style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newCategory != null && newCategory.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final res = await supabase
            .from('categories')
            .insert({'name': newCategory, 'store_id': widget.storeId})
            .select()
            .single();

        await _loadCategories();
        setState(() {
          _selectedCategoryId = res['id'];
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Gagal menambah kategori: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, // Optimize size
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _currentImageUrl;

    try {
      final fileExt = _imageFile!.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'products/$fileName';

      await supabase.storage
          .from('products')
          .upload(
            filePath,
            _imageFile!,
            fileOptions: const FileOptions(upsert: true),
          );

      // If there was a previous image, delete it to keep storage clean
      if (_currentImageUrl != null) {
        try {
          final uri = Uri.parse(_currentImageUrl!);
          final pathSegments = uri.pathSegments;
          // Format usually: /storage/v1/object/public/products/products/filename.ext
          // or similar depending on Supabase version/config.
          // We need the path inside the bucket.
          final bucketIndex = pathSegments.indexOf('products');
          if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
            final fullPathInsideBucket = pathSegments
                .sublist(bucketIndex + 1)
                .join('/');
            await supabase.storage.from('products').remove([
              fullPathInsideBucket,
            ]);
          }
        } catch (e) {
          debugPrint("Cleanup old image error: $e");
        }
      }

      final imageUrl = supabase.storage.from('products').getPublicUrl(filePath);
      return imageUrl;
    } catch (e) {
      debugPrint("Upload Error: $e");
      throw "Gagal upload gambar: $e";
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final imageUrl = await _uploadImage();

      final name = _nameController.text.trim();
      final sku = _skuController.text.trim();
      final description = _descriptionController.text.trim();
      final buyPrice = int.tryParse(_buyPriceController.text.trim()) ?? 0;
      final salePrice = int.tryParse(_salePriceController.text.trim()) ?? 0;
      final stock = _isStockManaged
          ? (int.tryParse(_stockController.text.trim()) ?? 0)
          : 0;

      final data = {
        'store_id': widget.storeId,
        'name': name,
        'sku': sku.isEmpty ? null : sku,
        'description': description.isEmpty ? null : description,
        'buy_price': buyPrice,
        'sale_price': salePrice,
        'stock_quantity': stock,
        'is_stock_managed': _isStockManaged,
        'category_id': _selectedCategoryId,
        'image_url': imageUrl,
      };

      final productId;
      if (widget.product == null) {
        // ADD NEW
        final res = await supabase
            .from('products')
            .insert(data)
            .select()
            .single();
        productId = res['id'];
      } else {
        // UPDATE EXISTING
        productId = widget.product!['id'];
        await supabase.from('products').update(data).eq('id', productId);
      }

      // Sync Variants & Options
      if (_enableVariants) {
        // Delete old options for a clean state
        await supabase
            .from('product_options')
            .delete()
            .eq('product_id', productId);

        for (var opt in _productOptions) {
          final optName = opt['option_name'].toString().trim();
          if (optName.isEmpty) continue;

          // Insert option
          final optRes = await supabase
              .from('product_options')
              .insert({
                'product_id': productId,
                'store_id': widget.storeId,
                'option_name': optName,
                'is_required': opt['is_required'] ?? false,
              })
              .select()
              .single();

          final optId = optRes['id'];

          // Bulk insert values
          final values = List<Map<String, dynamic>>.from(
            opt['product_option_values'] ?? [],
          );
          final List<Map<String, dynamic>> valuesToInsert = [];

          for (var val in values) {
            final valName = val['value_name'].toString().trim();
            if (valName.isEmpty) continue;

            valuesToInsert.add({
              'option_id': optId,
              'value_name': valName,
              'price_adjustment': val['price_adjustment'] ?? 0,
            });
          }

          if (valuesToInsert.isNotEmpty) {
            await supabase.from('product_option_values').insert(valuesToInsert);
          }
        }
      } else if (widget.product != null) {
        // If variants disabled, ensured they are cleared
        await supabase
            .from('product_options')
            .delete()
            .eq('product_id', productId);
      }

      if (mounted) Navigator.pop(context, true); // Return true on success
    } catch (e) {
      debugPrint("Save Product Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal simpan: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headingColor = isDark ? Colors.white : const Color(0xFF2D3436);
    final inputFill = isDark ? Colors.grey.shade800 : const Color(0xFFF1F2F6);
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9, // Taller sheet
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
            child: Row(
              children: [
                Text(
                  widget.product == null ? "Tambah Produk" : "Edit Produk",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: headingColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),

          const Divider(),

          // Form Scrollable
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                children: [
                  // Image Picker
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: inputFill,
                          borderRadius: BorderRadius.circular(20),
                          image: _imageFile != null
                              ? DecorationImage(
                                  image: FileImage(_imageFile!),
                                  fit: BoxFit.cover,
                                )
                              : (_currentImageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_currentImageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: (_imageFile == null && _currentImageUrl == null)
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_rounded,
                                    size: 30,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Foto Produk",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildInput(
                    "Nama Produk",
                    _nameController,
                    Icons.fastfood_rounded,
                    inputFill,
                    textColor,
                  ),
                  const SizedBox(height: 16),

                  // SKU & Kategori Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildInput(
                          "SKU (Opsional)",
                          _skuController,
                          Icons.qr_code_rounded,
                          inputFill,
                          textColor,
                          isRequired: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCategoryDropdown(inputFill, textColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildInput(
                    "Deskripsi",
                    _descriptionController,
                    Icons.description_rounded,
                    inputFill,
                    textColor,
                    maxLines: 3,
                    isRequired: false,
                  ),
                  const SizedBox(height: 16),

                  // Prices Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildInput(
                          "Harga Beli",
                          _buyPriceController,
                          Icons.shopping_bag_outlined,
                          inputFill,
                          textColor,
                          isNumber: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInput(
                          "Harga Jual",
                          _salePriceController,
                          Icons.attach_money_rounded,
                          inputFill,
                          textColor,
                          isNumber: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Variants & Options Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.tune_rounded, color: _primaryColor),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Varian & Opsi",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      "Contoh: Level Pedas, Topping, dll.",
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch(
                              value: _enableVariants,
                              activeThumbColor: _primaryColor,
                              onChanged: (val) {
                                setState(() {
                                  _enableVariants = val;
                                  if (val && _productOptions.isEmpty) {
                                    _addOption();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        if (_enableVariants) ...[
                          const SizedBox(height: 16),
                          ...List.generate(_productOptions.length, (optIdx) {
                            final opt = _productOptions[optIdx];
                            return _buildOptionItem(
                              opt,
                              optIdx,
                              textColor,
                              isDark,
                            );
                          }),
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton.icon(
                              onPressed: _addOption,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text("Tambah Grup Opsi"),
                              style: TextButton.styleFrom(
                                foregroundColor: _primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stock Management Switch
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_rounded,
                                  color: _primaryColor,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Kelola Stok",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      _isStockManaged
                                          ? "Stok Terbatas"
                                          : "Stok Unlimited",
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch(
                              value: _isStockManaged,
                              activeThumbColor: _primaryColor,
                              onChanged: (val) {
                                setState(() => _isStockManaged = val);
                              },
                            ),
                          ],
                        ),
                        if (_isStockManaged) ...[
                          const SizedBox(height: 16),
                          _buildInput(
                            "Jumlah Stok Saat Ini",
                            _stockController,
                            Icons.numbers_rounded,
                            theme.cardColor, // Nested, so contrast slightly
                            textColor,
                            isNumber: true,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ),

          // Submit Button (Fixed at Bottom)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "Simpan Produk",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(Color fillColor, Color textColor) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,
      isExpanded: true, // Prevent text overflow
      dropdownColor: Theme.of(context).cardColor,
      style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: "Kategori",
        labelStyle: GoogleFonts.inter(color: Colors.grey[500]),
        prefixIcon: Icon(Icons.category_rounded, color: _primaryColor),
        // Shortcut button inside the dropdown
        suffixIcon: IconButton(
          onPressed: _showAddCategoryDialog,
          icon: Icon(Icons.add_circle_outline_rounded, color: _primaryColor),
          tooltip: "Tambah Kategori Baru",
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      items: _categories.map((cat) {
        return DropdownMenuItem<String>(
          value: cat['id'] as String,
          child: Text(cat['name'], overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedCategoryId = val),
      validator: (val) => val == null ? "Kategori wajib dipilih" : null,
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController controller,
    IconData icon,
    Color fillColor,
    Color textColor, {
    bool isNumber = false,
    bool isRequired = true,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w500),
      validator: (val) {
        if (!isRequired) return null;
        if (val == null || val.isEmpty) return "$label wajib diisi";
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[500]),
        prefixIcon: maxLines > 1
            ? Container(
                margin: const EdgeInsets.only(bottom: 40), // Align icon top
                child: Icon(icon, color: _primaryColor),
              )
            : Icon(icon, color: _primaryColor),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red[300]!, width: 1),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildOptionItem(
    Map<String, dynamic> opt,
    int idx,
    Color textColor,
    bool isDark,
  ) {
    final values = List<Map<String, dynamic>>.from(
      opt['product_option_values'] ?? [],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: opt['option_name'],
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: "Nama Grup Opsi (Misal: Pilih Kematangan)",
                    isDense: true,
                    border: InputBorder.none,
                    hintStyle: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  onChanged: (val) => opt['option_name'] = val,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
                onPressed: () => _removeOption(idx),
              ),
            ],
          ),
          const Divider(),
          Row(
            children: [
              Text(
                "Wajib dipilih?",
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
              const Spacer(),
              Switch(
                value: opt['is_required'] ?? false,
                onChanged: (val) => setState(() => opt['is_required'] = val),
                activeThumbColor: _primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Pilihan Opsi:",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(values.length, (valIdx) {
            final val = values[valIdx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      initialValue: val['value_name'],
                      style: GoogleFonts.inter(fontSize: 13, color: textColor),
                      decoration: InputDecoration(
                        hintText: "Nama Opsi",
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => val['value_name'] = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: (val['price_adjustment'] ?? 0).toString(),
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 13, color: textColor),
                      decoration: InputDecoration(
                        hintText: "Harga +/-",
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) =>
                          val['price_adjustment'] = double.tryParse(v) ?? 0.0,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.grey,
                      size: 18,
                    ),
                    onPressed: () => _removeValue(idx, valIdx),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => _addValue(idx),
            icon: const Icon(Icons.add, size: 16),
            label: const Text("Tambah Pilihan", style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: _primaryColor),
          ),
        ],
      ),
    );
  }
}
