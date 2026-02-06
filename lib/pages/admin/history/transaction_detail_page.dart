import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../widgets/floating_card.dart';
import '../../../services/receipt_service.dart';
import '../../../controllers/admin_controller.dart';
import '../../user/widgets/receipt_preview_page.dart';

class TransactionDetailPage extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailPage({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final total = (transaction['total_amount'] as num).toDouble();
    final items = List<Map<String, dynamic>>.from(
      transaction['transaction_items'] ?? [],
    );
    final date = DateTime.parse(transaction['created_at']).toLocal();
    final cashierName = transaction['profiles']?['full_name'] ?? 'System';

    final currencyFormat = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Detail Transaksi",
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Receipt Header Card
            FloatingCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA5700).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.bag_fill,
                      color: Color(0xFFEA5700),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currencyFormat.format(total),
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEA5700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "ID: #${transaction['id'].toString().substring(0, 8).toUpperCase()}",
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Transaction Info
            FloatingCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildInfoRow(
                    context,
                    "Waktu",
                    DateFormat('d MMM yyyy, HH:mm').format(date),
                    CupertinoIcons.time,
                  ),
                  const Divider(height: 32),
                  _buildInfoRow(
                    context,
                    "Kasir",
                    cashierName,
                    CupertinoIcons.person,
                  ),
                  const Divider(height: 32),
                  _buildInfoRow(
                    context,
                    "Metode Bayar",
                    transaction['payment_method']?.toString().toUpperCase() ??
                        "TUNAI",
                    CupertinoIcons.creditcard,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Items List
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  "DAFTAR BELANJA",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            FloatingCard(
              padding: const EdgeInsets.all(20),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final productName = item['products']?['name'] ?? 'Produk';
                  final qty = item['quantity'] ?? 1;
                  final price = (item['price_at_time'] as num).toDouble();

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF2D3436),
                              ),
                            ),
                            Text(
                              "$qty x ${currencyFormat.format(price)}",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currencyFormat.format(qty * price),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF2D3436),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            // Print Action
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final adminCtrl = context.read<AdminController>();
                  final receiptService = ReceiptService();

                  final pdfData = await receiptService.generateReceiptPdf(
                    storeName: adminCtrl.storeName ?? "Toko Asri",
                    storeLogoUrl: adminCtrl.storeLogo,
                    transactionId: transaction['id'].toString(),
                    createdAt: date,
                    items: items.map((it) {
                      return {
                        'name': it['products']?['name'] ?? 'Produk',
                        'quantity': it['quantity'],
                        'total_price':
                            (it['price_at_time'] as num).toDouble() *
                            (it['quantity'] as num).toDouble(),
                      };
                    }).toList(),
                    totalAmount: total,
                    cashReceived:
                        (transaction['cash_received'] as num?)?.toDouble() ??
                        total,
                    change:
                        (transaction['cash_change'] as num?)?.toDouble() ?? 0,
                    paymentMethod:
                        transaction['payment_method']?.toString() ?? "TUNAI",
                  );

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReceiptPreviewPage(
                          pdfData: pdfData,
                          fileName:
                              "Struk_${transaction['id'].toString().substring(0, 8)}.pdf",
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(CupertinoIcons.printer),
                label: Text(
                  "CETAK STRUK",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA5700),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFEA5700)),
        const SizedBox(width: 16),
        Text(
          label,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF2D3436),
          ),
        ),
      ],
    );
  }
}
