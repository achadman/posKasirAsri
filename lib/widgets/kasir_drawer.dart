import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/theme_controller.dart';

class KasirDrawer extends StatefulWidget {
  final String currentRoute;
  const KasirDrawer({super.key, required this.currentRoute});

  @override
  State<KasirDrawer> createState() => _KasirDrawerState();
}

class _KasirDrawerState extends State<KasirDrawer> {
  final supabase = Supabase.instance.client;
  String? _avatarUrl;
  String _fullName = "Kasir";
  String? _userId;
  String? _role;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    _userId = user.id;

    final data = await supabase
        .from('profiles')
        .select('full_name, role')
        .eq('id', user.id)
        .maybeSingle();

    if (mounted && data != null) {
      setState(() {
        _fullName = data['full_name'] ?? "Kasir";
        _avatarUrl =
            data['avatar_url']; // Though we removed it from select, it's still in the state variable, I'll keep it as nullable
        _role = data['role'];
      });
    }
  }

  Future<void> _updateName() async {
    if (_userId == null) return;
    final controller = TextEditingController(text: _fullName);

    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Ubah Nama"),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: controller,
            placeholder: "Nama Lengkap",
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Batal"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            child: const Text("Simpan"),
            onPressed: () async {
              Navigator.pop(ctx);
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await supabase
                    .from('profiles')
                    .update({'full_name': newName})
                    .eq('id', _userId!);
                setState(() => _fullName = newName);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updatePhoto() async {
    if (_userId == null) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (mounted) setState(() => _isLoading = true);
      try {
        final file = File(pickedFile.path);
        final fileExt = pickedFile.path.split('.').last;
        final fileName = '$_userId/avatar.$fileExt';

        // Upload to Supabase Storage 'avatars' bucket
        // Ensure you have created 'avatars' bucket in Supabase dashboard
        await supabase.storage
            .from('avatars')
            .upload(
              fileName,
              file,
              fileOptions: const FileOptions(upsert: true),
            );

        final publicUrl = supabase.storage
            .from('avatars')
            .getPublicUrl(fileName);

        // Update profile
        // await supabase
        //     .from('profiles')
        //     .update({'avatar_url': publicUrl})
        //     .eq('id', _userId!);

        if (mounted) {
          setState(() {
            _avatarUrl = publicUrl;
            // Force refresh UI by appending timestamp if needed,
            // but public URL usually updates if cached properly or use key
          });
        }
      } catch (e) {
        debugPrint("Upload Error: $e");
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Gagal upload foto: $e")));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme aware
    final isDark = ThemeController.instance.isDarkMode;
    final bgColor = isDark ? const Color(0xFF1A1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);
    const accentColor = Color(0xFFFF4D4D);

    return Drawer(
      backgroundColor: bgColor,
      child: SafeArea(
        child: Column(
          children: [
            // Header Profile
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _updatePhoto,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: accentColor, width: 2),
                            image: _avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_avatarUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: Colors.grey[200],
                          ),
                          child: _avatarUrl == null
                              ? Icon(
                                  CupertinoIcons.person_solid,
                                  size: 50,
                                  color: Colors.grey[400],
                                )
                              : null,
                        ),
                        if (_isLoading)
                          const Positioned.fill(
                            child: CircularProgressIndicator(),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.camera_fill,
                              size: 16,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _fullName,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _updateName,
                        child: Icon(
                          CupertinoIcons.pencil,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      "KASIR",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Navigation Items
            _buildNavItem(
              icon: CupertinoIcons.home,
              label: "Beranda",
              isSelected: widget.currentRoute == '/kasir',
              onTap: () {
                Navigator.pop(context);
                if (widget.currentRoute != '/kasir') {
                  Navigator.pushReplacementNamed(context, '/kasir');
                }
              },
              textColor: textColor,
              accentColor: accentColor,
            ),
            _buildNavItem(
              icon: CupertinoIcons.clock,
              label: "Absensi Staff",
              isSelected: widget.currentRoute == '/attendance',
              onTap: () {
                Navigator.pop(context);
                if (widget.currentRoute != '/attendance') {
                  Navigator.pushReplacementNamed(context, '/attendance');
                }
              },
              textColor: textColor,
              accentColor: accentColor,
            ),
            _buildNavItem(
              icon: CupertinoIcons.doc_text,
              label: "Riwayat Pesanan",
              isSelected: widget.currentRoute == '/order-history',
              onTap: () {
                Navigator.pop(context);
                if (widget.currentRoute != '/order-history') {
                  Navigator.pushNamed(context, '/order-history');
                }
              },
              textColor: textColor,
              accentColor: accentColor,
            ),
            if (_role == 'admin' || _role == 'owner') ...[
              const Divider(),
              _buildNavItem(
                icon: CupertinoIcons.shield_lefthalf_fill,
                label: "Panel Admin",
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/admin');
                },
                textColor: textColor,
                accentColor: Colors.blue,
              ),
            ],

            const Spacer(),

            // Dark Mode Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    isDark
                        ? CupertinoIcons.moon_fill
                        : CupertinoIcons.sun_max_fill,
                    color: textColor,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    isDark ? "Dark Mode" : "Light Mode",
                    style: GoogleFonts.poppins(color: textColor),
                  ),
                  const Spacer(),
                  CupertinoSwitch(
                    value: isDark,
                    activeTrackColor: accentColor,
                    onChanged: (val) {
                      ThemeController.instance.toggleTheme();
                      // Force rebuild
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),

            const Divider(),

            // Logout
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              leading: const Icon(
                CupertinoIcons.square_arrow_right,
                color: Colors.red,
              ),
              title: Text(
                "Keluar Aplikasi",
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                await supabase.auth.signOut();
                if (!context.mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color textColor,
    required Color accentColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? accentColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? accentColor : textColor.withValues(alpha: 0.7),
        ),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? accentColor : textColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
