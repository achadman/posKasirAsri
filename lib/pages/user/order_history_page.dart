import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/order_service.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final _orderService = OrderService();
  final supabase = Supabase.instance.client;
  String? _storeId;
  bool _isLoading = true;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final profile = await supabase
          .from('profiles')
          .select('store_id')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _storeId = profile?['store_id'];
          _isLoading = false;
        });
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
          "Riwayat Pesanan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF2D3436),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF2D3436),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _storeId == null
          ? const Center(child: Text("Toko tidak ditemukan"))
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _orderService.getTodayOrders(_storeId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final orders = snapshot.data ?? [];

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 80,
                          color: isDark ? Colors.white10 : Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Belum ada pesanan hari ini.",
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final items = order['transaction_items'] as List;
                    final date = DateTime.parse(order['created_at']).toLocal();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.2 : 0.03,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ExpansionTile(
                        shape: const Border(), // Remove default borders
                        collapsedShape: const Border(),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Colors.green,
                          ),
                        ),
                        title: Text(
                          _currencyFormat.format(order['total_amount']),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF2D3436),
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('HH:mm').format(date),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                        children: [
                          const Divider(),
                          ...items.map((item) {
                            final productName =
                                item['products']['name'] ?? 'Product';
                            final qty = item['quantity'] ?? 0;
                            final price = item['price_at_time'] ?? 0;
                            return ListTile(
                              dense: true,
                              title: Text(
                                productName,
                                style: GoogleFonts.inter(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                "${qty}x ${_currencyFormat.format(price)}",
                                style: GoogleFonts.inter(
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.grey[600],
                                ),
                              ),
                              trailing: Text(
                                _currencyFormat.format(qty * price),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
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
