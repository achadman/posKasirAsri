import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../controllers/admin_controller.dart';
import 'tabs/transactions_tab.dart';
import 'tabs/performance_tab.dart';

class HistoryPage extends StatefulWidget {
  final String? storeId;
  const HistoryPage({super.key, this.storeId});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String? _storeId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _storeId = widget.storeId;
    if (_storeId == null) {
      _loadStoreId();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadStoreId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final prof = await Supabase.instance.client
          .from('profiles')
          .select('store_id')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _storeId = prof?['store_id'];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            "Riwayat & Performa",
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
          bottom: TabBar(
            indicatorColor: const Color(0xFFEA5700),
            labelColor: const Color(0xFFEA5700),
            unselectedLabelColor: Colors.grey,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: const [
              Tab(
                text: "TRANSAKSI",
                icon: Icon(CupertinoIcons.list_bullet, size: 20),
              ),
              Tab(
                text: "PERFORMA STAF",
                icon: Icon(CupertinoIcons.graph_square, size: 20),
              ),
            ],
          ),
        ),
        body: Consumer<AdminController>(
          builder: (context, adminCtrl, child) {
            if (_isLoading || adminCtrl.isInitializing) {
              return const Center(child: CupertinoActivityIndicator());
            }

            if (_storeId == null) {
              return const Center(child: Text("Toko tidak ditemukan"));
            }

            return TabBarView(
              children: [
                TransactionsTab(storeId: _storeId!),
                PerformanceTab(storeId: _storeId!),
              ],
            );
          },
        ),
      ),
    );
  }
}
