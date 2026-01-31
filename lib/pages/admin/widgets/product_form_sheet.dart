import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  final Color _primaryColor = const Color(0xFFFF4D4D); // Vibrant Red

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!['name'] ?? '';
      _priceController.text = (widget.product!['sale_price'] ?? 0).toString();
      _stockController.text = (widget.product!['stock_quantity'] ?? 0)
          .toString();
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();
      final price = int.parse(_priceController.text.trim());
      final stock = int.parse(_stockController.text.trim());

      if (widget.product == null) {
        // ADD NEW
        await supabase.from('products').insert({
          'store_id': widget.storeId,
          'name': name,
          'sale_price': price,
          'stock_quantity': stock,
        });
      } else {
        // UPDATE EXISTING
        await supabase
            .from('products')
            .update({
              'name': name,
              'sale_price': price,
              'stock_quantity': stock,
            })
            .eq('id', widget.product!['id']);
      }

      if (mounted) Navigator.pop(context, true); // Return true on success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.product == null ? "Tambah Produk" : "Edit Produk",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: headingColor,
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
              _buildInput(
                "Harga Jual",
                _priceController,
                Icons.attach_money_rounded,
                inputFill,
                textColor,
                isNumber: true,
              ),
              const SizedBox(height: 16),
              _buildInput(
                "Stok Awal",
                _stockController,
                Icons.inventory_2_rounded,
                inputFill,
                textColor,
                isNumber: true,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: _primaryColor.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Simpan Data",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController controller,
    IconData icon,
    Color fillColor,
    Color textColor, {
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w500),
      validator: (val) =>
          val == null || val.isEmpty ? "$label wajib diisi" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[500]),
        prefixIcon: Icon(icon, color: _primaryColor),
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
}
