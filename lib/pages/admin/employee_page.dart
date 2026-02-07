import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/employee_service.dart';
import '../../widgets/floating_card.dart';

class EmployeePage extends StatefulWidget {
  final String storeId;
  const EmployeePage({super.key, required this.storeId});

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  final _employeeService = EmployeeService();
  bool _isLoading = false;

  Future<void> _addEmployee() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    Map<String, bool> selectedPermissions = {
      'manage_inventory': false,
      'manage_categories': false,
      'pos_access': true,
      'view_history': true,
      'view_reports': false,
      'manage_printer': true,
    };

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              "Tambah Karyawan",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D3436),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogField(
                    controller: nameController,
                    label: "Nama Lengkap",
                    icon: CupertinoIcons.person,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogField(
                    controller: emailController,
                    label: "Email",
                    icon: CupertinoIcons.mail,
                    isDark: isDark,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogField(
                    controller: passwordController,
                    label: "Password",
                    icon: CupertinoIcons.lock,
                    isDark: isDark,
                    isPassword: true,
                    obscureText: obscurePassword,
                    onTogglePassword: () {
                      setDialogState(() => obscurePassword = !obscurePassword);
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Izin Akses Fitur",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEA5700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPermissionInDialog(
                    label: "Akses Kasir (POS)",
                    value: selectedPermissions['pos_access']!,
                    onChanged: (v) =>
                        setDialogState(() => selectedPermissions['pos_access'] = v!),
                    isDark: isDark,
                  ),
                  _buildPermissionInDialog(
                    label: "Kelola Produk & Stok",
                    value: selectedPermissions['manage_inventory']!,
                    onChanged: (v) =>
                        setDialogState(() => selectedPermissions['manage_inventory'] = v!),
                    isDark: isDark,
                  ),
                  _buildPermissionInDialog(
                    label: "Kelola Kategori",
                    value: selectedPermissions['manage_categories']!,
                    onChanged: (v) =>
                        setDialogState(() => selectedPermissions['manage_categories'] = v!),
                    isDark: isDark,
                  ),
                  _buildPermissionInDialog(
                    label: "Lihat Riwayat Saja",
                    value: selectedPermissions['view_history']!,
                    onChanged: (v) =>
                        setDialogState(() => selectedPermissions['view_history'] = v!),
                    isDark: isDark,
                  ),
                  _buildPermissionInDialog(
                    label: "Lihat Laporan Detail",
                    value: selectedPermissions['view_reports']!,
                    onChanged: (v) =>
                        setDialogState(() => selectedPermissions['view_reports'] = v!),
                    isDark: isDark,
                  ),
                  _buildPermissionInDialog(
                    label: "Pengaturan Printer",
                    value: selectedPermissions['manage_printer']!,
                    onChanged: (v) =>
                        setDialogState(() => selectedPermissions['manage_printer'] = v!),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Karyawan baru akan langsung terdaftar dan dapat login menggunakan email & password ini.",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Batal",
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final email = emailController.text.trim();
                  final pass = passwordController.text.trim();

                  if (name.isEmpty || email.isEmpty || pass.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Semua field harus diisi")),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  setState(() => _isLoading = true);

                  try {
                    await _employeeService.createCashierAccount(
                      email: email,
                      password: pass,
                      fullName: name,
                      storeId: widget.storeId,
                      permissions: selectedPermissions,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Karyawan berhasil didaftarkan"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint("Error registering employee: $e");
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Gagal mendaftarkan karyawan: ${e.toString()}",
                          ),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                          action: SnackBarAction(
                            label: "Detail",
                            textColor: Colors.white,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Detail Eror"),
                                  content: Text(e.toString()),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text("Tutup"),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA5700),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Daftarkan"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPermissionInDialog({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required bool isDark,
  }) {
    return CheckboxListTile(
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFFEA5700),
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? obscureText : false,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: isDark ? Colors.white60 : Colors.grey[600],
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFEA5700), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                  size: 20,
                  color: Colors.grey,
                ),
                onPressed: onTogglePassword,
              )
            : null,
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Manajemen Karyawan",
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
      ),
      body: SafeArea(
        child: Stack(
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _employeeService.getEmployees(widget.storeId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !_isLoading) {
                  return const Center(child: CupertinoActivityIndicator());
                }
  
                final employees = snapshot.data ?? [];
  
                if (employees.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.person_2,
                          size: 80,
                          color: isDark ? Colors.white10 : Colors.grey[200],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Belum ada karyawan terdaftar.",
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white38 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }
  
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final emp = employees[index];
                    return FloatingCard(
                      padding: const EdgeInsets.all(12),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA5700).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.person_fill,
                            color: Color(0xFFEA5700),
                          ),
                        ),
                        title: Text(
                          emp['full_name'] ?? 'Karyawan',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF2D3436),
                          ),
                        ),
                        subtitle: Text(
                          emp['role']?.toString().toUpperCase() ?? 'KASIR',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFFEA5700),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            CupertinoIcons.trash,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () => _confirmDeletion(emp),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CupertinoActivityIndicator(
                    radius: 15,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _addEmployee,
        backgroundColor: const Color(0xFFEA5700),
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(CupertinoIcons.plus, color: Colors.white),
        label: Text(
          "Tambah Karyawan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeletion(Map<String, dynamic> emp) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Hapus Karyawan"),
        content: Text(
          "Apakah Anda yakin ingin menghapus ${emp['full_name']} dari toko ini?",
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Batal"),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _employeeService.removeEmployee(emp['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Karyawan berhasil dihapus")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Gagal menghapus: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}
