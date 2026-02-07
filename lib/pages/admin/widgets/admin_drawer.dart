import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminDrawer extends StatelessWidget {
  final String? userName;
  final String? profileUrl;
  final String? storeName;
  final String? storeLogo;
  final String? role;
  final Map<String, dynamic>? permissions;
  final Color primaryColor;
  final VoidCallback onProfileTap;
  final VoidCallback onInventoryTap;
  final VoidCallback onCategoryTap;
  final VoidCallback onKasirTap;
  final VoidCallback onEmployeeTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onAnalyticsTap;
  final VoidCallback onPrinterTap;
  final VoidCallback onLogoutTap;

  const AdminDrawer({
    super.key,
    this.userName,
    this.profileUrl,
    this.storeName,
    this.storeLogo,
    this.role,
    this.permissions,
    required this.primaryColor,
    required this.onProfileTap,
    required this.onInventoryTap,
    required this.onCategoryTap,
    required this.onKasirTap,
    required this.onEmployeeTap,
    required this.onHistoryTap,
    required this.onAnalyticsTap,
    required this.onPrinterTap,
    required this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  context: context,
                  icon: CupertinoIcons.square_grid_2x2,
                  label: "Dashboard",
                  onTap: () => Navigator.pop(context),
                  isActive: true,
                ),
                _buildDrawerSectionTitle("OPERASIONAL"),
                if (role?.toLowerCase() == 'owner' ||
                    role?.toLowerCase() == 'admin' ||
                    (permissions?['manage_inventory'] ?? true))
                  _buildDrawerItem(
                    context: context,
                    icon: CupertinoIcons.cube_box,
                    label: "Inventori Barang",
                    onTap: () {
                      Navigator.pop(context);
                      onInventoryTap();
                    },
                  ),
                if (role?.toLowerCase() == 'owner' ||
                    role?.toLowerCase() == 'admin' ||
                    (permissions?['manage_categories'] ?? true))
                  _buildDrawerItem(
                    context: context,
                    icon: CupertinoIcons.grid,
                    label: "Manajemen Kategori",
                    onTap: () {
                      Navigator.pop(context);
                      onCategoryTap();
                    },
                  ),
                _buildDrawerItem(
                  context: context,
                  icon: CupertinoIcons.bag,
                  label: "Data Pembelian",
                  onTap: () {},
                ),
                if (role?.toLowerCase() == 'owner' ||
                    role?.toLowerCase() == 'admin' ||
                    (permissions?['pos_access'] ?? true))
                  _buildDrawerItem(
                    context: context,
                    icon: CupertinoIcons.cart,
                    label: "Kasir (POS)",
                    onTap: () {
                      Navigator.pop(context);
                      onKasirTap();
                    },
                  ),
                if (role?.toLowerCase() == 'owner' ||
                    role?.toLowerCase() == 'admin')
                  _buildDrawerItem(
                    context: context,
                    icon: CupertinoIcons.person_2,
                    label: "Manajemen Karyawan",
                    onTap: () {
                      Navigator.pop(context);
                      onEmployeeTap();
                    },
                  ),
                if (role?.toLowerCase() == 'owner' ||
                    role?.toLowerCase() == 'admin' ||
                    (permissions?['view_history'] ?? true))
                  _buildDrawerItem(
                    context: context,
                    icon: CupertinoIcons.doc_text,
                    label: "Riwayat Transaksi",
                    onTap: () {
                      Navigator.pop(context);
                      onHistoryTap();
                    },
                  ),
                if (role?.toLowerCase() == 'owner' ||
                    role?.toLowerCase() == 'admin' ||
                    (permissions?['manage_printer'] ?? true))
                  _buildDrawerItem(
                    context: context,
                    icon: CupertinoIcons.printer,
                    label: "Pengaturan Printer",
                    onTap: () {
                      Navigator.pop(context);
                      onPrinterTap();
                    },
                  ),
                if (role?.toLowerCase() == 'owner' ||
                    role?.toLowerCase() == 'admin' ||
                    (permissions?['view_reports'] ?? false)) ...[
                  _buildDrawerSectionTitle("LAINNYA"),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.analytics_rounded,
                    label: "Laporan Analitik",
                    color: primaryColor,
                    onTap: () {
                      Navigator.pop(context);
                      onAnalyticsTap();
                    },
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildDrawerItem(
              context: context,
              icon: CupertinoIcons.power,
              label: "Keluar Sesi",
              color: Colors.red,
              onTap: onLogoutTap,
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
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onProfileTap,
            child: CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white,
              backgroundImage: profileUrl != null
                  ? NetworkImage(profileUrl!)
                  : null,
              child: profileUrl == null
                  ? const Icon(Icons.person, size: 40, color: Colors.grey)
                  : null,
            ),
          ),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: onProfileTap,
            child: Text(
              userName ?? 'User',
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
              storeName ?? "Administrator",
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
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool isActive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(
        icon,
        color: isActive
            ? primaryColor
            : (color ?? (isDark ? Colors.white70 : Colors.grey[700])),
      ),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          color: isActive
              ? primaryColor
              : (color ?? (isDark ? Colors.white : Colors.grey[800])),
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      selected: isActive,
      selectedTileColor: primaryColor.withValues(alpha: 0.05),
      onTap: onTap,
    );
  }
}
