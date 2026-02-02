import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/logo/logoSteakAsri.png',
                width: 150,
                height: 150,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "Steak Asri",
              style: GoogleFonts.alfaSlabOne(
                fontSize: 32,
                color: const Color(0xFFEA5700),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Memuat Aplikasi...",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA5700)),
            ),
          ],
        ),
      ),
    );
  }
}
