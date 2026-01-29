import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/auth/login_page.dart';
import 'pages/admin/laporan_page.dart';
import 'pages/admin_page.dart';
import 'pages/kasir_page.dart';
import 'pages/auth/onboarding_page.dart';
import 'pages/auth/register_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://jdimobnakpatngchsrpu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpkaW1vYm5ha3BhdG5nY2hzcnB1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcyNjk0NDYsImV4cCI6MjA4Mjg0NTQ0Nn0.VbvqQUsn60Awp4TncrJ-EoRTrxTLToe3qR11x50aAWY',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WarkopNgoetApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      
      // Menggunakan home dengan StreamBuilder untuk cek sesi login
      home: StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // Tampilkan loading saat mengecek sesi
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final session = snapshot.data?.session;

          // JIKA SUDAH LOGIN (Sesi ditemukan)
          if (session != null) {
            return const AuthGate(); // Kita arahkan ke gerbang pengecekan Role
          }

          // JIKA BELUM LOGIN (Sesi null)
          return const OnboardingPage();
        },
      ),

      routes: {
        '/onboarding': (context) => const OnboardingPage(),
        '/register': (context) => const RegisterPage(),
        '/login': (context) => const LoginPage(),
        '/admin': (context) => const AdminPage(),
        '/kasir': (context) => const KasirPage(),
        '/laporan': (context) => const LaporanPage(),
      },
    );
  }
}

// --- GERBANG OTOMATIS BERDASARKAN ROLE ---
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      // Mengambil role dari tabel profiles berdasarkan ID user yang login
      future: supabase
          .from('profiles')
          .select('role')
          .eq('id', supabase.auth.currentUser!.id)
          .single(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          final String role = snapshot.data!['role'];
          // Arahkan admin ke AdminPage, sisanya ke KasirPage
          if (role == 'admin' || role == 'owner') {
            return const AdminPage();
          } else {
            return const KasirPage();
          }
        }

        // Jika data profile tidak ketemu, balikkan ke Login
        return const LoginPage();
      },
    );
  }
}