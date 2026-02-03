import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Ganti Firebase
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class LaporanPage extends StatelessWidget {
  final String storeId;
  const LaporanPage({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final supabase = Supabase.instance.client;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Laporan Penjualan"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF2D3436),
        ),
        titleTextStyle: GoogleFonts.poppins(
          color: isDark ? Colors.white : const Color(0xFF2D3436),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // Menggunakan Stream Supabase untuk update realtime
        stream: supabase
            .from('transactions')
            .stream(primaryKey: ['id'])
            .eq('store_id', storeId)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Tidak ada data transaksi.'));
          }

          final transactions = snapshot.data!;
          double totalHariIni = 0;
          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);

          // Menghitung omzet hari ini
          for (var tx in transactions) {
            final date = DateTime.parse(tx['created_at']).toLocal();
            if (!date.isBefore(startOfToday)) {
              totalHariIni += (tx['total_amount'] as num).toDouble();
            } else {
              break; // Optimized: transactions are ordered descending
            }
          }

          // Filter daftar untuk hanya menampilkan hari ini agar konsisten dengan header
          final todayTransactions = transactions.where((tx) {
            final date = DateTime.parse(tx['created_at']).toLocal();
            return !date.isBefore(startOfToday);
          }).toList();

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E1E1E), const Color(0xFF121212)]
                        : [const Color(0xFF003566), const Color(0xFF001D3D)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      "Omzet Hari Ini",
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      currency.format(totalHariIni),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${todayTransactions.length} Transaksi Hari Ini",
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Riwayat Transaksi Hari Ini",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D3436),
                  ),
                ),
              ),
              // Daftar Transaksi
              Expanded(
                child: ListView.builder(
                  itemCount: todayTransactions.length,
                  itemBuilder: (context, index) {
                    final tx = todayTransactions[index];
                    DateTime date = DateTime.parse(tx['created_at']).toLocal();

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.2 : 0.03,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          "Total: ${currency.format(tx['total_amount'])}",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF2D3436),
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy, HH:mm').format(date),
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white60 : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tx['payment_method'].toString().toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
