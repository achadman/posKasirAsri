import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Ganti Firebase
import 'package:intl/intl.dart';

class LaporanPage extends StatelessWidget {
  const LaporanPage({super.key});

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
            .order('created_at', ascending: true),
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
          DateTime now = DateTime.now();

          // Menghitung omzet hari ini
          for (var tx in transactions) {
            // Parsing ISO string dari Supabase ke DateTime
            DateTime date = DateTime.parse(tx['created_at']).toLocal();
            if (date.day == now.day && date.month == now.month && date.year == now.year) {
              // Pastikan total_amount di-cast ke double/num
              totalHariIni += (tx['total_amount'] as num).toDouble();
            }
          }

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
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text("Riwayat Transaksi", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              // Daftar Transaksi
              Expanded(
                child: ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
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