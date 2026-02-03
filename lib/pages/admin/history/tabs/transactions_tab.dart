import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../../services/report_service.dart';
import '../widgets/transaction_item.dart';
import '../transaction_detail_page.dart';

class TransactionsTab extends StatefulWidget {
  final String storeId;
  const TransactionsTab({super.key, required this.storeId});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  final _reportService = ReportService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final data = await _reportService.getAllTransactions(widget.storeId);
      if (mounted) {
        setState(() {
          _allTransactions = data;
          _filteredTransactions = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterTransactions(String query) {
    setState(() {
      _filteredTransactions = _allTransactions.where((tx) {
        final id = tx['id'].toString().toLowerCase();
        final name = (tx['profiles']?['full_name'] ?? '')
            .toString()
            .toLowerCase();
        return id.contains(query.toLowerCase()) ||
            name.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      color: const Color(0xFFEA5700),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: CupertinoSearchTextField(
              controller: _searchController,
              onChanged: _filterTransactions,
              placeholder: "Cari ID Transaksi atau Kasir",
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
          Expanded(
            child: _filteredTransactions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = _filteredTransactions[index];
                      return TransactionItem(
                        transaction: tx,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TransactionDetailPage(transaction: tx),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.doc_text_search,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            "Tidak ada transaksi ditemukan",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
