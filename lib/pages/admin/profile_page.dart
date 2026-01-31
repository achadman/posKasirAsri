import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/theme_controller.dart';
import 'employee_page.dart';

class ProfilePage extends StatelessWidget {
  final String storeId;
  const ProfilePage({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Profil Akun",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // User Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                )
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: primaryColor.withOpacity(0.1),
                  child: Icon(Icons.person_rounded, size: 30, color: primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.email ?? "User",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Owner / Admin",
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Menu Items
          _buildMenuTile(
            context,
            icon: Icons.people_alt_rounded,
            title: "Kelola Karyawan",
            subtitle: "Tambah & hapus akses kasir",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmployeePage(storeId: storeId),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          _buildThemeToggle(context),

          const SizedBox(height: 16),

          _buildMenuTile(
            context,
            icon: Icons.logout_rounded,
            title: "Keluar",
            subtitle: "Akhiri sesi login",
            iconColor: Colors.red,
            onTap: () async {
              await supabase.auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance.themeMode,
        builder: (context, mode, child) {
          final isDarkMode = mode == ThemeMode.dark;
          return Row(
            children: [
              Icon(
                isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                color: isDarkMode ? Colors.indigo : Colors.orange,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mode Gelap",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      isDarkMode ? "Aktif" : "Non-aktif",
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isDarkMode,
                onChanged: (_) => ThemeController.instance.toggleTheme(),
              ),
            ],
          );
        },
      ),
    );
  }
}
