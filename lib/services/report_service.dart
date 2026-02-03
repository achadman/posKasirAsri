import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches all transactions for a specific store with details
  Future<List<Map<String, dynamic>>> getAllTransactions(String storeId) async {
    final response = await _supabase
        .from('transactions')
        .select(
          '*, profiles:cashier_id(full_name, avatar_url), transaction_items(*, products(name, price))',
        )
        .eq('store_id', storeId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches cashier performance data (sales volume and count)
  Future<List<Map<String, dynamic>>> getCashierPerformance(
    String storeId,
  ) async {
    final response = await _supabase
        .from('transactions')
        .select(
          'cashier_id, total_amount, profiles:cashier_id(full_name, avatar_url)',
        )
        .eq('store_id', storeId);

    final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
      response,
    );

    // Group and aggregate data
    final Map<String, Map<String, dynamic>> performance = {};

    for (var tx in data) {
      final id = tx['cashier_id'];
      final name = tx['profiles']?['full_name'] ?? 'Unknown';
      final avatar = tx['profiles']?['avatar_url'];
      final amount = (tx['total_amount'] as num).toDouble();

      if (!performance.containsKey(id)) {
        performance[id] = {
          'id': id,
          'name': name,
          'avatar': avatar,
          'total_sales': 0.0,
          'transaction_count': 0,
        };
      }

      performance[id]!['total_sales'] += amount;
      performance[id]!['transaction_count'] += 1;
    }

    return performance.values.toList();
  }

  /// Fetches the current status (Online/Offline/Break) and attendance for each staff
  Future<List<Map<String, dynamic>>> getStaffStatus(String storeId) async {
    // 1. Get all profiles for the store with role 'cashier'
    final staffResponse = await _supabase
        .from('profiles')
        .select('id, full_name, avatar_url, role')
        .eq('store_id', storeId)
        .eq('role', 'cashier');

    final List<Map<String, dynamic>> staff = List<Map<String, dynamic>>.from(
      staffResponse,
    );

    // 2. Get today's attendance logs
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    final logsResponse = await _supabase
        .from('attendance_logs')
        .select()
        .eq('store_id', storeId)
        .gte('clock_in', startOfDay);

    final List<Map<String, dynamic>> logs = List<Map<String, dynamic>>.from(
      logsResponse,
    );

    // 3. Map status to staff
    return staff.map((s) {
      final log = logs.cast<Map<String, dynamic>?>().firstWhere(
        (l) => l?['user_id'] == s['id'],
        orElse: () => null,
      );

      String status = 'offline';
      String? clockIn;
      String? clockOut;

      if (log != null) {
        if (log['clock_out'] != null) {
          status = 'offline'; // Finished for the day
          clockIn = log['clock_in'];
          clockOut = log['clock_out'];
        } else if (log['status'] == 'break') {
          status = 'break';
          clockIn = log['clock_in'];
        } else {
          status = 'online';
          clockIn = log['clock_in'];
        }
      }

      return {
        ...s,
        'status': status,
        'clock_in': clockIn,
        'clock_out': clockOut,
      };
    }).toList();
  }
}
