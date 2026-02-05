import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../services/bluetooth_printer_service.dart';

class ReceiptPreviewPage extends StatelessWidget {
  final Uint8List pdfData;
  final String fileName;

  // Added for Bluetooth Printing
  final String? storeName;
  final String? transactionId;
  final DateTime? createdAt;
  final List<Map<String, dynamic>>? items;
  final double? totalAmount;
  final double? cashReceived;
  final double? change;
  final String? paymentMethod;

  const ReceiptPreviewPage({
    super.key,
    required this.pdfData,
    required this.fileName,
    this.storeName,
    this.transactionId,
    this.createdAt,
    this.items,
    this.totalAmount,
    this.cashReceived,
    this.change,
    this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1C1E) : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Struk Belanja",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Placeholder for Print UI
          IconButton(
            icon: const Icon(Icons.print_rounded),
            onPressed: () async {
              final printerService = BluetoothPrinterService();
              if (printerService.isConnected) {
                await printerService.printReceipt(
                  storeName: storeName ?? "Toko Kasir Asri",
                  transactionId: transactionId ?? "TXN",
                  createdAt: createdAt ?? DateTime.now(),
                  items: items ?? [],
                  totalAmount: totalAmount ?? 0,
                  cashReceived: cashReceived ?? 0,
                  change: change ?? 0,
                  paymentMethod: paymentMethod ?? "Tunai",
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Mencetak struk...")),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Printer Bluetooth belum terhubung!"),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            tooltip: "Cetak ke Printer Bluetooth",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: PdfPreview(
                build: (format) => pdfData,
                allowPrinting: true,
                allowSharing: true,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                maxPageWidth: 400,
                loadingWidget: const Center(child: CircularProgressIndicator()),
                pdfFileName: fileName,
                actions:
                    const [], // Clear default top actions since we added them to AppBar
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  "Selesai",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D4D), // Brand Red
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
