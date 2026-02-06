import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

enum ChartRange { today, week, month }

class AnalyticsController extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  double _totalSales = 0;
  double get totalSales => _totalSales;

  double _todaySales = 0;
  double get todaySales => _todaySales;

  double _thisWeekSales = 0;
  double get thisWeekSales => _thisWeekSales;

  double _thisMonthSales = 0;
  double get thisMonthSales => _thisMonthSales;

  double _lastWeekSales = 0;
  double _lastMonthSales = 0;

  int _employeeCount = 0;
  int get employeeCount => _employeeCount;

  int _totalTransactionCount = 0;
  int get totalTransactionCount => _totalTransactionCount;

  int _totalProductCount = 0;
  int get totalProductCount => _totalProductCount;

  List<Map<String, dynamic>> _chartData = [];
  List<Map<String, dynamic>> get chartData => _chartData;

  ChartRange _selectedRange = ChartRange.week;
  ChartRange get selectedRange => _selectedRange;

  String? _storeId;

  Future<void> init(String? storeId) async {
    if (storeId == null) return;
    _storeId = storeId;
    await refreshData();
  }

  void setRange(ChartRange range) {
    _selectedRange = range;
    _fetchChartData();
    notifyListeners();
  }

  Future<void> refreshData() async {
    if (_storeId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _fetchTotalSales(),
        _fetchPeriodicSales(),
        _fetchChartData(),
        _fetchCounts(),
      ]);
    } catch (e) {
      debugPrint("AnalyticsController: Error refreshing data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchTotalSales() async {
    final response = await supabase
        .from('transactions')
        .select('total_amount')
        .eq('store_id', _storeId!);

    _totalSales = 0;
    for (var row in response) {
      _totalSales += (row['total_amount'] as num).toDouble();
    }
  }

  Future<void> _fetchPeriodicSales() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfThisWeek = startOfToday.subtract(
      Duration(days: now.weekday - 1),
    );
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
    final startOfThisMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);

    // This is simplified. In a production app, we might do one query and filter in Dart,
    // or use Supabase functions for aggregation.

    final txs = await supabase
        .from('transactions')
        .select('total_amount, created_at')
        .eq('store_id', _storeId!)
        .gte('created_at', startOfLastMonth.toUtc().toIso8601String());

    _todaySales = 0;
    _thisWeekSales = 0;
    _lastWeekSales = 0;
    _thisMonthSales = 0;
    _lastMonthSales = 0;

    for (var tx in txs) {
      final date = DateTime.parse(tx['created_at']).toLocal();
      final amount = (tx['total_amount'] as num).toDouble();

      if (!date.isBefore(startOfToday)) _todaySales += amount;
      if (!date.isBefore(startOfThisWeek)) _thisWeekSales += amount;
      if (date.isBefore(startOfThisWeek) && !date.isBefore(startOfLastWeek)) {
        _lastWeekSales += amount;
      }
      if (!date.isBefore(startOfThisMonth)) _thisMonthSales += amount;
      if (date.isBefore(startOfThisMonth) && !date.isBefore(startOfLastMonth)) {
        _lastMonthSales += amount;
      }
    }
  }

  Future<void> _fetchCounts() async {
    // 1. Employee Count
    final employees = await supabase
        .from('profiles')
        .select('id')
        .eq('store_id', _storeId!)
        .eq('role', 'cashier');
    _employeeCount = employees.length;

    // 2. Transaction Count (All Time)
    final transactions = await supabase
        .from('transactions')
        .select('id')
        .eq('store_id', _storeId!);
    _totalTransactionCount = transactions.length;

    // 3. Product Count
    final products = await supabase
        .from('products')
        .select('id')
        .eq('store_id', _storeId!);
    _totalProductCount = products.length;
  }

  Future<void> _fetchChartData() async {
    final now = DateTime.now();
    DateTime startDate;
    int steps;
    DateFormat format;

    switch (_selectedRange) {
      case ChartRange.today:
        startDate = DateTime(now.year, now.month, now.day);
        steps = 24;
        format = DateFormat('HH:00');
        break;
      case ChartRange.month:
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 29));
        steps = 30;
        format = DateFormat('dd MMM');
        break;
      case ChartRange.week:
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
        steps = 7;
        format = DateFormat('E');
        break;
    }

    final txs = await supabase
        .from('transactions')
        .select('total_amount, created_at')
        .eq('store_id', _storeId!)
        .gte('created_at', startDate.toUtc().toIso8601String());

    Map<String, double> dataMap = {};
    for (int i = 0; i < steps; i++) {
      DateTime stepDate;
      if (_selectedRange == ChartRange.today) {
        stepDate = startDate.add(Duration(hours: i));
      } else {
        stepDate = startDate.add(Duration(days: i));
      }
      final key = DateFormat('yyyy-MM-dd HH').format(stepDate);
      dataMap[key] = 0;
    }

    for (var tx in txs) {
      final date = DateTime.parse(tx['created_at']).toLocal();
      final key = DateFormat('yyyy-MM-dd HH').format(date);

      String? foundKey;
      if (_selectedRange == ChartRange.today) {
        if (dataMap.containsKey(key)) foundKey = key;
      } else {
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        foundKey = dataMap.keys.firstWhere(
          (k) => k.startsWith(dateKey),
          orElse: () => '',
        );
      }

      if (foundKey != null && foundKey.isNotEmpty) {
        dataMap[foundKey] =
            dataMap[foundKey]! + (tx['total_amount'] as num).toDouble();
      }
    }

    _chartData = dataMap.entries.map((e) {
      DateTime d = DateFormat('yyyy-MM-dd HH').parse(e.key);
      return {'date': e.key, 'amount': e.value, 'label': format.format(d)};
    }).toList();
  }

  double get weeklyGrowth {
    if (_lastWeekSales == 0) return _thisWeekSales > 0 ? 100 : 0;
    return ((_thisWeekSales - _lastWeekSales) / _lastWeekSales) * 100;
  }

  double get monthlyGrowth {
    if (_lastMonthSales == 0) return _thisMonthSales > 0 ? 100 : 0;
    return ((_thisMonthSales - _lastMonthSales) / _lastMonthSales) * 100;
  }
}
