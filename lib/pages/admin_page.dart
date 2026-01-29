import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final supabase = Supabase.instance.client;
  final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
  
  String? _adminEmail;
  String? _storeId;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _adminEmail = supabase.auth.currentUser?.email;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Mengambil store_id agar admin hanya melihat data tokonya sendiri
      final profile = await supabase
          .from('profiles')
          .select('store_id')
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _storeId = profile != null ? profile['store_id'] : null;
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mencegah blank page saat data toko sedang dimuat
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF001D3D))),
      );
    }

    // Jika store_id tidak ditemukan, tampilkan pesan error bukan blank page
    if (_storeId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Admin Mode")),
        body: const Center(
          child: Text("Akun Anda belum terhubung ke toko manapun.\nHubungi Super Admin.", textAlign: TextAlign.center),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_adminEmail ?? "Admin Mode", style: const TextStyle(fontSize: 14, color: Color(0xFFFFD60A))),
          backgroundColor: const Color(0xFF001D3D),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFFD60A),
            labelColor: Color(0xFFFFD60A),
            unselectedLabelColor: Colors.white,
            tabs: [Tab(text: "Produk"), Tab(text: "Laporan")],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await supabase.auth.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/login');
              },
            )
          ],
        ),
        body: TabBarView(
          children: [
            _buildProductManagement(),
            _buildFinanceReport(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFFD32F2F),
          onPressed: () => Navigator.pushNamed(context, '/addMenu'), // Sesuaikan dengan route kamu
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildProductManagement() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('store_id', _storeId ?? ''),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final products = snapshot.data!;
        if (products.isEmpty) return const Center(child: Text("Belum ada produk."));

        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, i) {
            final p = products[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: ListTile(
                leading: const Icon(Icons.fastfood),
                title: Text(p['name'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Stok: ${p['stock_quantity']} | ${currencyFormat.format(p['sale_price'])}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(p['id']),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFinanceReport() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('transactions')
          .stream(primaryKey: ['id'])
          .eq('store_id', _storeId ?? '')
          .order('created_at'),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final txs = snapshot.data!;
        if (txs.isEmpty) return const Center(child: Text("Belum ada transaksi."));

        return ListView.builder(
          itemCount: txs.length,
          itemBuilder: (context, index) {
            final tx = txs[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(currencyFormat.format(tx['total_amount'])),
                subtitle: Text("Metode: ${tx['payment_method']}"),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(String id) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Produk?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Hapus", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await supabase.from('products').delete().eq('id', id);
    }
  }
}