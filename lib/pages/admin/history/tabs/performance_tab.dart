import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../../services/report_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/employee_performance_card.dart';

class PerformanceTab extends StatefulWidget {
  final String storeId;
  const PerformanceTab({super.key, required this.storeId});

  @override
  State<PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<PerformanceTab> {
  final _reportService = ReportService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _performanceData = [];
  List<Map<String, dynamic>> _staffStatus = [];

  String _selectedFilter = "Semua";
  final List<String> _filters = [
    "Semua",
    "Hari Ini",
    "Minggu Ini",
    "Bulan Ini",
  ];

  DateTime? _getDateLimit() {
    final now = DateTime.now();
    if (_selectedFilter == "Hari Ini") {
      return DateTime(now.year, now.month, now.day);
    } else if (_selectedFilter == "Minggu Ini") {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    } else if (_selectedFilter == "Bulan Ini") {
      return DateTime(now.year, now.month, 1);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dateLimit = _getDateLimit();
      final results = await Future.wait([
        _reportService.getCashierPerformance(
          widget.storeId,
          dateLimit: dateLimit,
        ),
        _reportService.getStaffStatus(widget.storeId),
      ]);

      if (mounted) {
        setState(() {
          _performanceData = results[0];
          _staffStatus = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return Column(
      children: [
        /* Filter Chips */
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: _filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    filter,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedFilter = filter);
                      _loadData();
                    }
                  },
                  selectedColor: const Color(0xFFEA5700),
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.grey.withOpacity(0.3),
                  ),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),

        /* Content */
        Expanded(
          child: _staffStatus.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.person_2,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Belum ada data performa karyawan",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: const Color(0xFFEA5700),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _staffStatus.length,
                    itemBuilder: (context, index) {
                      final staff = _staffStatus[index];
                      // Find performance data for this staff
                      final perf = _performanceData
                          .cast<Map<String, dynamic>?>()
                          .firstWhere(
                            (p) => p?['id'] == staff['id'],
                            orElse: () => {
                              'id': staff['id'],
                              'name': staff['full_name'],
                              'avatar': staff['avatar_url'],
                              'total_sales': 0.0,
                              'transaction_count': 0,
                            },
                          );

                      return EmployeePerformanceCard(
                        performance: perf!,
                        statusInfo: staff,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
