import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../../services/report_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _reportService.getCashierPerformance(widget.storeId),
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

    if (_staffStatus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.person_2, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              "Belum ada data performa karyawan",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
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

          return EmployeePerformanceCard(performance: perf!, statusInfo: staff);
        },
      ),
    );
  }
}
