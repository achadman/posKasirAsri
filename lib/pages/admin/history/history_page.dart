import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tabs/transactions_tab.dart';
import 'tabs/performance_tab.dart';

class HistoryPage extends StatefulWidget {
  final String storeId;
  const HistoryPage({super.key, required this.storeId});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            "Riwayat & Performa",
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
          bottom: TabBar(
            indicatorColor: const Color(0xFFEA5700),
            labelColor: const Color(0xFFEA5700),
            unselectedLabelColor: Colors.grey,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: const [
              Tab(
                text: "TRANSAKSI",
                icon: Icon(CupertinoIcons.list_bullet, size: 20),
              ),
              Tab(
                text: "PERFORMA STAF",
                icon: Icon(CupertinoIcons.graph_square, size: 20),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TransactionsTab(storeId: widget.storeId),
            PerformanceTab(storeId: widget.storeId),
          ],
        ),
      ),
    );
  }
}
