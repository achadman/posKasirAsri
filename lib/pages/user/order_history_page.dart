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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Riwayat Pesanan",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Belum ada pesanan hari ini.",
                          style: GoogleFonts.inter(color: Colors.grey),
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

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ExpansionTile(
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
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('HH:mm').format(date),
                          style: GoogleFonts.inter(fontSize: 12),
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
                              title: Text(productName),
                              subtitle: Text(
                                "${qty}x ${_currencyFormat.format(price)}",
                              ),
                              trailing: Text(
                                _currencyFormat.format(qty * price),
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
