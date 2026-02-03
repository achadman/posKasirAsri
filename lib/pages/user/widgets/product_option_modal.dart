import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ProductOptionModal extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductOptionModal({super.key, required this.product});

  @override
  State<ProductOptionModal> createState() => _ProductOptionModalState();
}

class _ProductOptionModalState extends State<ProductOptionModal> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _options = [];
  Map<String, String> _selectedValues = {}; // OptionID -> ValueID
  final _notesController = TextEditingController();

  final _currencyFormat = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchOptions();
  }

  Future<void> _fetchOptions() async {
    try {
      final data = await supabase
          .from('product_options')
          .select('*, product_option_values(*)')
          .eq('product_id', widget.product['id'])
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _options = List<Map<String, dynamic>>.from(data);
          // Set defaults for required options if possible
          for (var opt in _options) {
            final values = List<Map<String, dynamic>>.from(
              opt['product_option_values'] ?? [],
            );
            if (opt['is_required'] == true && values.isNotEmpty) {
              _selectedValues[opt['id']] = values[0]['id'];
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching product options: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calculateTotalPrice() {
    double total = (widget.product['sale_price'] as num).toDouble();

    for (var entry in _selectedValues.entries) {
      final optId = entry.key;
      final valId = entry.value;

      final opt = _options.firstWhere((o) => o['id'] == optId);
      final vals = List<Map<String, dynamic>>.from(
        opt['product_option_values'] ?? [],
      );
      final val = vals.firstWhere((v) => v['id'] == valId);

      total += (val['price_adjustment'] as num).toDouble();
    }

    return total;
  }

  void _confirmSelection() {
    // Validate required options
    for (var opt in _options) {
      if (opt['is_required'] == true &&
          !_selectedValues.containsKey(opt['id'])) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${opt['option_name']} wajib dipilih!")),
        );
        return;
      }
    }

    // Build selection data
    List<Map<String, dynamic>> choices = [];
    for (var entry in _selectedValues.entries) {
      final opt = _options.firstWhere((o) => o['id'] == entry.key);
      final val = List<Map<String, dynamic>>.from(
        opt['product_option_values'] ?? [],
      ).firstWhere((v) => v['id'] == entry.value);

      choices.add({
        'option_id': opt['id'],
        'option_name': opt['option_name'],
        'value_id': val['id'],
        'value_name': val['value_name'],
        'price_adjustment': val['price_adjustment'],
      });
    }

    Navigator.pop(context, {
      'choices': choices,
      'total_price': _calculateTotalPrice(),
      'notes': _notesController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFFFF4D4D);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product['name'],
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(widget.product['sale_price']),
                        style: GoogleFonts.inter(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      ..._options
                          .map((opt) => _buildOptionSection(opt, isDark))
                          .toList(),

                      const SizedBox(height: 16),
                      Text(
                        "Catatan Khusus",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText:
                              "Contoh: Jangan pakai bawang, pedas banget...",
                          hintStyle: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
          ),

          // Footer
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Harga",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(_calculateTotalPrice()),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 50,
                  width: 160,
                  child: ElevatedButton(
                    onPressed: _confirmSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "Tambah ke Cart",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionSection(Map<String, dynamic> opt, bool isDark) {
    final values = List<Map<String, dynamic>>.from(
      opt['product_option_values'] ?? [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              opt['option_name'],
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (opt['is_required'] == true) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "WAJIB",
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: values.map((val) {
            final isSelected = _selectedValues[opt['id']] == val['id'];
            final adj = (val['price_adjustment'] as num).toDouble();

            return ChoiceChip(
              label: Text(
                adj != 0
                    ? "${val['value_name']} (${adj > 0 ? '+' : ''}${_currencyFormat.format(adj)})"
                    : val['value_name'],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedValues[opt['id']] = val['id'];
                  } else if (opt['is_required'] != true) {
                    _selectedValues.remove(opt['id']);
                  }
                });
              },
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              selectedColor: const Color(0xFFFF4D4D).withValues(alpha: 0.1),
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                color: isSelected
                    ? const Color(0xFFFF4D4D)
                    : (isDark ? Colors.white : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFFFF4D4D)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              showCheckmark: false,
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
