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
import 'employee_page.dart';
import 'history/history_page.dart';
import '../other/printer_settings_page.dart';

import 'package:provider/provider.dart';
import '../../controllers/admin_controller.dart';
import 'widgets/admin_header.dart';
import 'widgets/admin_menu_item.dart';
import 'widgets/admin_drawer.dart';
import 'widgets/low_stock_dialog.dart';

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

  final Color _primaryColor = const Color(0xFFEA5700);

  @override
  void initState() {
    super.initState();
    // Logic is now in the controller
  }

  void _showLowStockAlert(AdminController controller) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) => LowStockDialog(
        lowStockItems: controller.lowStockItems,
        onInventoryTap: () {
          Navigator.pop(context);
          if (mounted && controller.storeId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InventoryPage(storeId: controller.storeId!),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminController()..loadInitialData(),
      child: Consumer<AdminController>(
        builder: (context, controller, child) {
          if (controller.isInitializing) {
            return const Scaffold(
              body: Center(child: CupertinoActivityIndicator(radius: 15)),
            );
          }

          if (controller.storeId == null) {
            return _buildNoStoreView(controller);
          }

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            drawer: AdminDrawer(
              userName: controller.userName,
              profileUrl: controller.profileUrl,
              storeName: controller.storeName,
              storeLogo: controller.storeLogo,
              primaryColor: _primaryColor,
              onProfileTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(storeId: controller.storeId!),
                  ),
                );
                controller.loadInitialData();
              },
              onInventoryTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InventoryPage(storeId: controller.storeId!),
                ),
              ),
              onCategoryTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryPage(storeId: controller.storeId!),
                ),
              ),
              onKasirTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KasirPage()),
              ),
              onEmployeeTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmployeePage(storeId: controller.storeId!),
                ),
              ),
              onHistoryTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryPage(storeId: controller.storeId!),
                ),
              ),
              onPrinterTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrinterSettingsPage(),
                ),
              ),
              role: controller.role,
              onLogoutTap: () async {
                await supabase.auth.signOut();
                if (!context.mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            body: RefreshIndicator(
              onRefresh: controller.loadInitialData,
              color: _primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  children: [
                    AdminHeader(
                      userName: controller.storeName,
                      profileUrl: controller.storeLogo,
                      storeName: controller.storeName,
                      todaySales: controller.todaySales,
                      transactionCount: controller.transactionCount,
                      lowStockCount: controller.lowStockCount,
                      currencyFormat: currencyFormat,
                      primaryColor: _primaryColor,
                      onProfileTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProfilePage(storeId: controller.storeId!),
                          ),
                        );
                        controller.loadInitialData();
                      },
                      onLowStockTap: () => _showLowStockAlert(controller),
                      onSalesTap:
                          (controller.role == 'owner' ||
                              controller.role == 'admin')
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    LaporanPage(storeId: controller.storeId!),
                              ),
                            )
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Akses Dibatasi: Hanya Owner yang dapat melihat laporan detail.",
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            },
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildAnimatedSection(
                            delay: 0,
                            child: AdminMenuSection(
                              title: "Manajemen Stok",
                              icon: CupertinoIcons.cube_box,
                              items: [
                                AdminMenuItem(
                                  label: "Barang",
                                  icon: CupertinoIcons.doc_text_viewfinder,
                                  color: Colors.blue,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InventoryPage(
                                        storeId: controller.storeId!,
                                      ),
                                    ),
                                  ),
                                ),
                                AdminMenuItem(
                                  label: "Kategori",
                                  icon: CupertinoIcons.grid,
                                  color: Colors.indigo,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CategoryPage(
                                        storeId: controller.storeId!,
                                      ),
                                    ),
                                  ),
                                ),
                                AdminMenuItem(
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
                            child: AdminMenuSection(
                              title: "Operasional Kasir",
                              icon: CupertinoIcons.cart,
                              items: [
                                AdminMenuItem(
                                  label: "Transaksi",
                                  icon: CupertinoIcons.cart_badge_plus,
                                  color: Colors.orange,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const KasirPage(),
                                      ),
                                    );
                                    controller.fetchDashboardStats();
                                  },
                                ),
                                AdminMenuItem(
                                  label: "Riwayat",
                                  icon: CupertinoIcons.doc_text,
                                  color: Colors.purple,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => HistoryPage(
                                        storeId: controller.storeId!,
                                      ),
                                    ),
                                  ),
                                ),
                                AdminMenuItem(
                                  label: "Printer",
                                  icon: CupertinoIcons.printer,
                                  color: Colors.blueGrey,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const PrinterSettingsPage(),
                                    ),
                                  ),
                                ),
                                AdminMenuItem(
                                  label: "Karyawan",
                                  icon: CupertinoIcons.person_2,
                                  color: Colors.cyan,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => HistoryPage(
                                        storeId: controller.storeId!,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (controller.role == 'owner' ||
                              controller.role == 'admin')
                            _buildAnimatedSection(
                              delay: 400,
                              child: AdminMenuSection(
                                title: "Analitik & Laporan",
                                icon: CupertinoIcons.graph_square,
                                items: [
                                  AdminMenuItem(
                                    label: "Lap. Shift",
                                    icon: CupertinoIcons.list_bullet_indent,
                                    color: Colors.blueAccent,
                                    onTap: () {},
                                  ),
                                  AdminMenuItem(
                                    label: "Penjualan",
                                    icon: CupertinoIcons.graph_circle,
                                    color: Colors.green,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LaporanPage(
                                          storeId: controller.storeId!,
                                        ),
                                      ),
                                    ),
                                  ),
                                  AdminMenuItem(
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
        },
      ),
    );
  }

  Widget _buildNoStoreView(AdminController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.house_alt_fill,
                size: 100,
                color: Color(0xFFEA5700),
              ),
              const SizedBox(height: 24),
              Text(
                "Toko Belum Terdaftar",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Akun Anda terdeteksi belum memiliki toko. Silakan buat toko baru untuk mulai mengelola bisnis Anda.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _showCreateStoreDialog(controller),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA5700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    "Buat Toko Sekarang",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await supabase.auth.signOut();
                  if (mounted)
                    Navigator.pushReplacementNamed(context, '/login');
                },
                child: Text(
                  "Keluar Akun",
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateStoreDialog(AdminController controller) async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Buka Toko Baru",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Nama Toko",
            hintText: "Contoh: Steak Asri Pusat",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text("Buat Toko"),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final storeRes = await supabase
            .from('stores')
            .insert({'name': result})
            .select()
            .single();

        await supabase
            .from('profiles')
            .update({'store_id': storeRes['id']})
            .eq('id', supabase.auth.currentUser!.id);

        controller.loadInitialData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Toko berhasil dibuat!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
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
