import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Ganti Firebase
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_application_1/pages/auth/login_page.dart';

// Inisialisasi client global (pastikan ini sesuai dengan main.dart kamu)
final supabase = Supabase.instance.client;

// --- FUNGSI PDF (Sudah Standar Supabase) ---
Future<void> _generateSingleReceiptPdf(Map<String, dynamic> data) async {
  final pdf = pw.Document();
  final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
  
  // Supabase mengembalikan string ISO 8601, bukan Timestamp
  DateTime tgl = data['created_at'] != null 
      ? DateTime.parse(data['created_at']).toLocal() 
      : DateTime.now();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text("WARKOP NGOET", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text("Bandung, West Java, Indonesia", style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("Telp: 0812-2492-3591", style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(borderStyle: pw.BorderStyle.dashed),
            _buildPdfRow("Tgl", DateFormat('dd/MM/yy HH:mm').format(tgl)),
            pw.Divider(borderStyle: pw.BorderStyle.dashed),
            pw.Text("PESANAN:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            pw.SizedBox(height: 4),
            // Loop item dari detail_transaksi
            ...(data['transaction_items'] as List).map((item) {
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text("${item['products']['name']} x${item['quantity']}", style: const pw.TextStyle(fontSize: 9))),
                    pw.Text(currencyFormat.format(item['price_at_time'] * item['quantity']), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              );
            }),
            pw.Divider(borderStyle: pw.BorderStyle.dashed),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("TOTAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.Text(currencyFormat.format(data['total_amount']), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Center(child: pw.Text("Terima Kasih!", style: const pw.TextStyle(fontSize: 8))),
          ],
        );
      },
    ),
  );
  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
}

pw.Widget _buildPdfRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
  );
}

// --- HALAMAN KASIR ---
class KasirPage extends StatefulWidget {
  const KasirPage({super.key});
  @override
  State<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends State<KasirPage> {
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final List<Map<String, dynamic>> _cart = [];
  
  String _searchQuery = "";
  double _totalPayment = 0;
  double _change = 0;
  final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

  // Logout Supabase
  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false
      );
    }
  }

  void _calculateTotal() {
    double subtotal = _cart.fold(0, (total, item) => total + (item['price'] * item['qty']));
    setState(() {
      _totalPayment = subtotal;
      double cash = double.tryParse(_cashController.text) ?? 0;
      _change = cash - _totalPayment;
    });
  }

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      int index = _cart.indexWhere((item) => item['id'] == product['id']);
      if (index != -1) {
        if (_cart[index]['qty'] < product['stock_quantity']) {
          _cart[index]['qty']++;
        }
      } else {
        _cart.add({
          'id': product['id'], 
          'name': product['name'], 
          'price': product['sale_price'], 
          'qty': 1, 
          'maxStock': product['stock_quantity'], 
        });
      }
      _calculateTotal();
    });
  }

  // LOGIKA TRANSAKSI SUPABASE (RELATIONAL)
  Future<void> _processTransaction() async {
    if (_cart.isEmpty) return;
    
    try {
      // 1. Ambil Store ID (Asumsi store pertama atau dari profile user)
      final storeData = await supabase.from('stores').select('id').limit(1).single();
      final String storeId = storeData['id'];
      final String userId = supabase.auth.currentUser!.id;

      // 2. Simpan ke tabel TRANSACTIONS
      final transaction = await supabase.from('transactions').insert({
        'store_id': storeId,
        'cashier_id': userId,
        'total_amount': _totalPayment,
        'payment_method': 'cash',
        'status': 'completed',
      }).select().single();

      final String transId = transaction['id'];

      // 3. Simpan ke tabel TRANSACTION_ITEMS (Bulk Insert)
      final List<Map<String, dynamic>> itemsToInsert = _cart.map((item) => {
        'transaction_id': transId,
        'product_id': item['id'],
        'quantity': item['qty'],
        'price_at_time': item['price'],
      }).toList();

      await supabase.from('transaction_items').insert(itemsToInsert);

      // 4. Update Stok Produk (Postgres mengurus ini lewat RPC atau loop)
      for (var item in _cart) {
        await supabase.rpc('decrement_stock', params: {
          'row_id': item['id'],
          'amount': item['qty']
        });
      }

      setState(() => _cart.clear());
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transaksi Berhasil!")));
      
    } catch (e) {
      log("Error Transaksi: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kasir Warkop"),
        backgroundColor: const Color(0xFF001D3D),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout)
        ],
      ),
      body: Column(
        children: [
          _buildSearchBox(),
          Expanded(child: _buildProductList()),
        ],
      ),
      floatingActionButton: _cart.isEmpty ? null : FloatingActionButton.extended(
        onPressed: _showCartBottomSheet,
        label: Text("Bayar: ${currencyFormat.format(_totalPayment)}"),
        icon: const Icon(Icons.shopping_cart),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: const InputDecoration(hintText: "Cari Menu...", prefixIcon: Icon(Icons.search)),
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
      ),
    );
  }

  Widget _buildProductList() {
    // Stream diganti dengan FutureBuilder atau Supabase Stream
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('products').stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final products = snapshot.data!.where((p) => p['name'].toString().toLowerCase().contains(_searchQuery)).toList();

        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8),
          itemCount: products.length,
          itemBuilder: (context, i) {
            final p = products[i];
            return Card(
              child: Column(
                children: [
                  Expanded(child: Icon(Icons.fastfood, size: 50, color: Colors.blueGrey[200])),
                  Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(currencyFormat.format(p['sale_price'])),
                  Text("Stok: ${p['stock_quantity']}"),
                  ElevatedButton(
                    onPressed: p['stock_quantity'] > 0 ? () => _addToCart(p) : null,
                    child: const Text("Tambah"),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Modal Bottom Sheet (Logic sama, hanya ganti pemanggilan fungsi proses) ---
  void _showCartBottomSheet() {
     // ... (Gunakan UI BottomSheet lama kamu, panggil _processTransaction saat tombol ditekan)
  }
}