import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/auth/login_page.dart';
import 'pages/admin/laporan_page.dart';
import 'pages/admin/admin_page.dart';
import 'pages/user/kasir_page.dart';
import 'pages/auth/onboarding_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/attendance/attendance_page.dart';

import 'controllers/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pyesewttbjqtniixrhvc.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB5ZXNld3R0YmpxdG5paXhyaHZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk4NTI5ODAsImV4cCI6MjA4NTQyODk4MH0.Z71ogOpR-oD_WXClMXGlf7UUHNEZ09B63_TyrDboP4c',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.themeMode,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SteakAsriApp',
          themeMode: currentMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF4D4D),
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF8F9FD),
            textTheme: GoogleFonts.poppinsTextTheme(),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF4D4D),
              brightness: Brightness.dark,
              primary: const Color(0xFFFF4D4D),
            ),
            scaffoldBackgroundColor: const Color(0xFF1A1C1E),
            cardColor: const Color(0xFF2D3436),
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
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

          onGenerateRoute: (settings) {
            Widget page;
            switch (settings.name) {
              case '/onboarding':
                page = const OnboardingPage();
                break;
              case '/register':
                page = const RegisterPage();
                break;
              case '/login':
                page = const LoginPage();
                break;
              case '/admin':
                page = const AdminPage();
                break;
              case '/kasir':
                page = const KasirPage();
                break;
              case '/laporan':
                page = const LaporanPage();
                break;
              case '/attendance':
                page = const AttendancePage();
                break;
              default:
                return null;
            }
            return CustomPageRoute(builder: (_) => page, settings: settings);
          },
        );
      },
    );
  }
}

class CustomPageRoute extends PageRouteBuilder {
  final WidgetBuilder builder;
  @override
  final RouteSettings settings;

  CustomPageRoute({required this.builder, required this.settings})
    : super(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      );
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
