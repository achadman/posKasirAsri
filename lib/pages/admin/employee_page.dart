import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class EmployeePage extends StatefulWidget {
  final String storeId;
  const EmployeePage({super.key, required this.storeId});

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  Future<void> _addEmployee() async {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Tambah Karyawan", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nama Lengkap"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email Karyawan"),
            ),
            const SizedBox(height: 10),
            const Text(
              "Catatan: Karyawan harus mendaftar sendiri menggunakan email ini untuk terhubung ke toko Anda.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'name': nameController.text.trim(),
              'email': emailController.text.trim(),
            }),
            child: const Text("Simpan"),
          ),
        ],
      ),
    );

    if (result != null && result['email']!.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        // Simple approach: Provide the User ID of the registered user
        // and assign them to this store.
        final userId = result['email']; // Reusing the field for ID or email
        
        await supabase.from('profiles').update({
          'role': 'cashier',
          'store_id': widget.storeId,
          if (result['name']!.isNotEmpty) 'full_name': result['name'],
        }).or('id.eq.$userId,email.eq.$userId'); // Try matching by ID or Email if exists

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Karyawan berhasil ditambahkan")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Kelola Karyawan", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('profiles')
            .stream(primaryKey: ['id'])
            .eq('store_id', widget.storeId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // Filter out the owner manually
          final employees = snapshot.data!.where((p) => p['role'] != 'owner').toList();

          if (employees.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("Belum ada karyawan.", style: GoogleFonts.inter(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final emp = employees[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(emp['full_name'] ?? 'Karyawan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  subtitle: Text(emp['role'] ?? 'Kasir'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      // Remove from store
                      await supabase.from('profiles').update({'store_id': null, 'role': 'user'}).eq('id', emp['id']);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _addEmployee,
        label: _isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text("Tambah Karyawan"),
        icon: const Icon(Icons.add),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }
}
