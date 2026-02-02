import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/widgets/floating_card.dart';

class FinanceReport extends StatelessWidget {
  final String storeId;

  const FinanceReport({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final textHeading = isDark ? Colors.white : const Color(0xFF2D3436);

    final currencyFormat = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final supabase = Supabase.instance.client;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('transactions')
          .stream(primaryKey: ['id'])
          .eq('store_id', storeId)
          .order('created_at'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final txs = snapshot.data!;
        if (txs.isEmpty) {
          return Center(
            child: Text(
              "Belum ada transaksi.",
              style: GoogleFonts.inter(color: Colors.grey[500]),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          itemCount: txs.length,
          itemBuilder: (context, index) {
            final tx = txs[index];
            return FloatingCard(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.receipt_long_rounded, color: primaryColor),
                ),
                title: Text(
                  currencyFormat.format(tx['total_amount']),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: textHeading,
                  ),
                ),
                subtitle: Text(
                  "${tx['payment_method']} • ${DateFormat('dd MMM, HH:mm').format(DateTime.parse(tx['created_at']).toLocal())}",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[300],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
