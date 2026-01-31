import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Inisialisasi Supabase Client
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();

  // Inisialisasi variabel status dengan nilai pasti (bukan null)
  String _selectedRole = 'cashier';
  bool _isLoading = false;
  bool _obscurePassword = true; // Proteksi awal: dipastikan tidak null

  Future<void> _register() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _fullNameController.text.trim().isEmpty) {
      _showError("Semua field harus diisi");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Mendaftarkan user ke Supabase Auth
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _fullNameController.text.trim(),
          'role': _selectedRole,
        },
      );

      // Force update profile role to ensure it defaults correctly
      // This handles cases where the DB Trigger might default to Owner or ignore metadata
      if (res.user != null) {
        try {
          await supabase
              .from('profiles')
              .update({'role': _selectedRole})
              .eq('id', res.user!.id);
        } catch (_) {
          // If email confirmation is ON, we might not be able to update yet due to RLS.
          // That is expected, but if we ARE logged in, this ensures correctness.
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Registrasi Berhasil! Silakan cek email atau langsung Login.",
          ),
        ),
      );
      Navigator.pop(context);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError("Terjadi kesalahan tak terduga");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF800000), Color(0xFF1A0000)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Image.asset('logo/logoSteakAsri.png', width: 100),
                  const SizedBox(height: 20),
                  Text(
                    "DAFTAR AKUN",
                    style: GoogleFonts.alfaSlabOne(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),

                  _buildTextField(
                    _fullNameController,
                    "Nama Lengkap",
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    _emailController,
                    "Email",
                    Icons.email_outlined,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    _passwordController,
                    "Password",
                    Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: 20),

                  _buildRoleDropdown(),

                  const SizedBox(height: 40),
                  _buildRegisterButton(),
                  const SizedBox(height: 30),
                  _buildLoginLink(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widget untuk Input Field
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
  }) {
    // Pengamanan ekstra: jika _obscurePassword null, paksa jadi true
    final bool safeObscureValue = isPassword
        ? (_obscurePassword ?? true)
        : false;

    return TextField(
      controller: controller,
      obscureText: safeObscureValue,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFFEA5700)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  safeObscureValue ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !(_obscurePassword ?? true);
                  });
                },
              )
            : null,
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // Helper Widget untuk Dropdown
  Widget _buildRoleDropdown() {
    return Theme(
      data: Theme.of(context).copyWith(canvasColor: const Color(0xFFEA5700)),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedRole,
        style: const TextStyle(color: Colors.white),
        items: const [
          DropdownMenuItem(value: 'owner', child: Text("OWNER")),
          DropdownMenuItem(value: 'cashier', child: Text("KASIR")),
        ],
        onChanged: (val) => setState(() => _selectedRole = val ?? 'cashier'),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.badge_outlined,
            color: Color(0xFFEA5700),
          ),
          labelText: "Pilih Role",
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEA5700),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFF001D3D),
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "DAFTAR SEKARANG",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Sudah punya akun?",
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            "Login di sini",
            style: TextStyle(
              color: Color(0xFFEA5700),
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
