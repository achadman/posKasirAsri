import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intl/intl.dart';
import '../user/kasir_page.dart';
import 'package:flutter/cupertino.dart';
import 'laporan_page.dart';
import 'category_page.dart';
import 'inventory_page.dart';
import 'profile_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final supabase = Supabase.instance.client;
  final currencyFormat = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String? _storeId;
  String? _userName;
  String? _profileUrl;
  String? _storeName;
  String? _storeLogo;
  bool _isInitializing = true;
  double _todaySales = 0;
  int _lowStockCount = 0;
  int _transactionCount = 0;

  final Color _primaryColor = const Color(0xFFEA5700);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('store_id, full_name')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        _storeId = profile['store_id'];
        _userName = profile['full_name'] ?? user.email?.split('@')[0] ?? 'User';
        _profileUrl = profile['avatar_url'];
      }

      if (_storeId != null) {
        await _fetchDashboardStats();

        // Load Store Info
        final store = await supabase
            .from('stores')
            .select('name, logo_url')
            .eq('id', _storeId!)
            .maybeSingle();

        if (mounted && store != null) {
          setState(() {
            _storeName = store['name'];
            _storeLogo = store['logo_url'];
          });
        }
      }

      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String();

      // Fetch Today's Sales
      final txs = await supabase
          .from('transactions')
          .select('total_amount')
          .eq('store_id', _storeId!)
          .gte('created_at', startOfDay);

      double total = 0;
      for (var tx in txs) {
        total += (tx['total_amount'] as num).toDouble();
      }

      // Fetch Low Stock Count
      final products = await supabase
          .from('products')
          .select('id')
          .eq('store_id', _storeId!)
          .lt('stock_quantity', 5)
          .eq('is_stock_managed', true);

      if (mounted) {
        setState(() {
          _todaySales = total;
          _transactionCount = txs.length;
          _lowStockCount = products.length;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    if (_storeId == null) {
      return _buildNoStoreView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        color: _primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildAnimatedSection(
                      delay: 0,
                      child: _buildMenuSection(
                        title: "Manajemen Stok",
                        icon: CupertinoIcons.cube_box,
                        items: [
                          _MenuItem(
                            label: "Barang",
                            icon: CupertinoIcons.doc_text_viewfinder,
                            color: Colors.blue,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InventoryPage(storeId: _storeId!),
                              ),
                            ),
                          ),
                          _MenuItem(
                            label: "Kategori",
                            icon: CupertinoIcons.grid,
                            color: Colors.indigo,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CategoryPage(storeId: _storeId!),
                              ),
                            ),
                          ),
                          _MenuItem(
                            label: "Pembelian",
                            icon: CupertinoIcons.bag,
                            color: Colors.lightBlue,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildAnimatedSection(
                      delay: 200,
                      child: _buildMenuSection(
                        title: "Operasional Kasir",
                        icon: CupertinoIcons.cart,
                        items: [
                          _MenuItem(
                            label: "Transaksi",
                            icon: CupertinoIcons.cart_badge_plus,
                            color: Colors.orange,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const KasirPage(),
                              ),
                            ),
                          ),
                          _MenuItem(
                            label: "Riwayat",
                            icon: CupertinoIcons.doc_text,
                            color: Colors.purple,
                            onTap: () {},
                          ),
                          _MenuItem(
                            label: "Printer",
                            icon: CupertinoIcons.printer,
                            color: Colors.blueGrey,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildAnimatedSection(
                      delay: 400,
                      child: _buildMenuSection(
                        title: "Analitik & Laporan",
                        icon: CupertinoIcons.graph_square,
                        items: [
                          _MenuItem(
                            label: "Lap. Shift",
                            icon: CupertinoIcons.list_bullet_indent,
                            color: Colors.blueAccent,
                            onTap: () {},
                          ),
                          _MenuItem(
                            label: "Penjualan",
                            icon: CupertinoIcons.graph_circle,
                            color: Colors.green,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LaporanPage(),
                              ),
                            ),
                          ),
                          _MenuItem(
                            label: "Laba Rugi",
                            icon: CupertinoIcons.money_dollar_circle,
                            color: Colors.teal,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_primaryColor, _primaryColor.withValues(alpha: 0.8)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      child: Column(
        children: [
          Row(
            children: [
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(storeId: _storeId!),
                      ),
                    );
                    _loadInitialData(); // Refresh on return
                  },
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    backgroundImage: _profileUrl != null
                        ? NetworkImage(_profileUrl!)
                        : null,
                    child: _profileUrl == null
                        ? const Icon(Icons.person, size: 30, color: Colors.grey)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName ?? 'User',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "Owner (Premium)",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      "BUKA",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(CupertinoIcons.bell, color: Colors.white),
            ],
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.graph_circle,
                            color: Colors.greenAccent,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Penjualan",
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        currencyFormat.format(_todaySales),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "$_transactionCount Transaksi",
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white24),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.cube_box,
                            color: Colors.orangeAccent,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Low Stock",
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "$_lowStockCount Item",
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "Perlu Restok",
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required IconData icon,
    required List<_MenuItem> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3436),
                ),
              ),
              const Spacer(),
              Icon(icon, size: 18, color: Colors.grey.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              return GestureDetector(
                onTap: item.onTap,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, color: item.color, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF636E72),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
      ),
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildDrawerSectionTitle("UTAMA"),
                _buildDrawerItem(
                  icon: CupertinoIcons.square_grid_2x2,
                  label: "Dashboard",
                  onTap: () => Navigator.pop(context),
                  isActive: true,
                ),
                _buildDrawerSectionTitle("OPERASIONAL"),
                _buildDrawerItem(
                  icon: CupertinoIcons.cube_box,
                  label: "Inventori Barang",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InventoryPage(storeId: _storeId!),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: CupertinoIcons.grid,
                  label: "Manajemen Kategori",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryPage(storeId: _storeId!),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: CupertinoIcons.bag,
                  label: "Data Pembelian",
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: CupertinoIcons.cart,
                  label: "Kasir (POS)",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const KasirPage()),
                  ),
                ),
                _buildDrawerItem(
                  icon: CupertinoIcons.doc_text,
                  label: "Riwayat Transaksi",
                  onTap: () {},
                ),
                _buildDrawerSectionTitle("LAINNYA"),
                _buildDrawerItem(
                  icon: CupertinoIcons.graph_square,
                  label:
                      "Laporan Analistik", // Fixing typo from mock "Analistik"
                  onTap: () {},
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildDrawerItem(
              icon: CupertinoIcons.power,
              label: "Keluar Sesi",
              color: Colors.red,
              onTap: () async {
                await supabase.auth.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_primaryColor, _primaryColor.withValues(alpha: 0.8)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white,
                backgroundImage: _profileUrl != null
                    ? NetworkImage(_profileUrl!)
                    : null,
                child: _profileUrl == null
                    ? const Icon(Icons.person, size: 40, color: Colors.grey)
                    : null,
              ),
              if (_storeLogo != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white,
                      backgroundImage: NetworkImage(_storeLogo!),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(storeId: _storeId!),
                ),
              );
              _loadInitialData(); // Refresh on return
            },
            child: Text(
              _userName ?? 'User',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 5),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _storeName ?? "Administrator",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[400],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool isActive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? _primaryColor : (color ?? Colors.grey[700]),
      ),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          color: isActive ? _primaryColor : (color ?? Colors.grey[800]),
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      selected: isActive,
      selectedTileColor: _primaryColor.withValues(alpha: 0.05),
      onTap: onTap,
    );
  }

  Widget _buildNoStoreView() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Akun belum terhubung.",
              style: GoogleFonts.inter(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await supabase.auth.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSection({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuint,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _MenuItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _MenuItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
