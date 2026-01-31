import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/product_form_sheet.dart';
import 'widgets/finance_report.dart'; // Extracted Widget
import 'profile_page.dart';
import '../../widgets/product_grid.dart'; // Extracted Reusable Widget
import '../../controllers/theme_controller.dart';
import 'package:intl/intl.dart';

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
  bool _isInitializing = true;
  int _selectedIndex = 0;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

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

  void _openProductForm({Map<String, dynamic>? product}) async {
    if (_storeId == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductFormSheet(product: product, storeId: _storeId!),
    );
  }

  Future<void> _confirmDelete(String id) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Hapus Produk?",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Tindakan ini tidak dapat dibatalkan.",
          style: GoogleFonts.inter(color: Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal", style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[50],
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Hapus",
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await supabase.from('products').delete().eq('id', id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final textHeading = theme.brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF2D3436);

    if (_isInitializing) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_storeId == null) {
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
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                child: const Text("Logout"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER Custom (ADOL Style) ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  // Logo / Brand
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/logo/logoSteakAsri.png',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Steak Asri",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textHeading,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            // --- MAIN CONTENT ---
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  // Tab 0: Products
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? Colors.grey[800]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  theme.brightness == Brightness.dark
                                      ? 0.2
                                      : 0.03,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(
                              () => _searchQuery = val.toLowerCase(),
                            ),
                            style: GoogleFonts.inter(color: textHeading),
                            decoration: InputDecoration(
                              hintText: "Cari produk...",
                              hintStyle: GoogleFonts.inter(
                                color: Colors.grey[400],
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: Colors.grey[400],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ProductGrid(
                          storeId: _storeId!,
                          searchQuery: _searchQuery,
                          onItemTap: (p) => _openProductForm(product: p),
                          extraInfoBuilder: (context, p) {
                            return Text(
                              "Stok: ${p['stock_quantity']}",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            );
                          },
                          actionBuilder: (context, p) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                InkWell(
                                  onTap: () => _confirmDelete(p['id']),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.red[300],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  // Tab 1: Finance
                  FinanceReport(storeId: _storeId!),

                  // Tab 2: Profile
                  ProfilePage(storeId: _storeId!),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04), // Subtle shadow
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _selectedIndex,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: "Produk",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_rounded),
              label: "Laporan",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: "Profil",
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              backgroundColor: primaryColor,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: () => _openProductForm(),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            )
          : null,
    );
  }
}
