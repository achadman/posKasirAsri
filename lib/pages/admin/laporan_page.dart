import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Ganti Firebase
import 'package:intl/intl.dart';

class LaporanPage extends StatelessWidget {
  final String storeId;
  const LaporanPage({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final supabase = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan Penjualan"),
        backgroundColor: const Color(0xFF001D3D), // Konsisten dengan tema kamu
        foregroundColor: Colors.white,
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
              // Header Omzet
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: const Color(0xFF003566),
                child: Column(
                  children: [
                    const Text("Omzet Hari Ini", style: TextStyle(color: Colors.white70)),
                    Text(
                      currency.format(totalHariIni),
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 28, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    Text(
                      "${todayTransactions.length} Transaksi Hari Ini",
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text("Riwayat Transaksi Hari Ini", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              // Daftar Transaksi
              Expanded(
                child: ListView.builder(
                  itemCount: todayTransactions.length,
                  itemBuilder: (context, index) {
                    final tx = todayTransactions[index];
                    DateTime date = DateTime.parse(tx['created_at']).toLocal();
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.receipt_long, color: Color(0xFF003566)),
                        ),
                        title: Text(
                          "Total: ${currency.format(tx['total_amount'])}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy, HH:mm').format(date),
                        ),
                        trailing: Text(
                          tx['payment_method'].toString().toUpperCase(),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }
}