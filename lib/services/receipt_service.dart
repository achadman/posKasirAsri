import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class ReceiptService {
  final _currencyFormat = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  Future<Uint8List> generateReceiptPdf({
    required String storeName,
    String? storeLogoUrl,
    required String transactionId,
    required DateTime createdAt,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double cashReceived,
    required double change,
    required String paymentMethod,
  }) async {
    final pdf = pw.Document();

    // Load logo if available
    pw.ImageProvider? logoImage;
    if (storeLogoUrl != null && storeLogoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(storeLogoUrl));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        print("Error loading store logo: $e");
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Classic receipt width
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header / Logo
              if (logoImage != null)
                pw.Container(
                  width: 50,
                  height: 50,
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Image(logoImage),
                ),
              pw.Text(
                storeName.toUpperCase(),
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 1),

              // Transaction Details
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "ID: #$transactionId",
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      "Waktu: ${DateFormat('dd MMM yyyy, HH:mm').format(createdAt)}",
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      "Pembayaran: $paymentMethod",
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
              pw.Divider(thickness: 0.5),

              // Items Table
              pw.Table(
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(
                          "Item",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(
                          "Qty",
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(
                          "Total",
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (var item in items)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item['name'] ?? 'Produk',
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                              if (item['notes'] != null &&
                                  item['notes'].toString().isNotEmpty)
                                pw.Text(
                                  "(${item['notes']})",
                                  style: pw.TextStyle(
                                    fontSize: 7,
                                    fontStyle: pw.FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Text(
                            "${item['quantity']}x",
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Text(
                            _currencyFormat.format(item['total_price'] ?? 0),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Summary
              pw.Container(
                width: double.infinity,
                child: pw.Column(
                  children: [
                    _buildSummaryRow(
                      "Total Tagihan",
                      totalAmount,
                      isBold: true,
                    ),
                    _buildSummaryRow("Uang Diterima", cashReceived),
                    _buildSummaryRow("Kembalian", change),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 10),
              pw.Text(
                "Terima kasih sudah berbelanja di",
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                storeName,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                "Selamat menikmati!",
                style: pw.TextStyle(
                  fontStyle: pw.FontStyle.italic,
                  fontSize: 9,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                "--- POS KASIR ASRI ---",
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isBold ? 11 : 9,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            _currencyFormat.format(amount),
            style: pw.TextStyle(
              fontSize: isBold ? 11 : 9,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
