import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches all transactions for a specific store with details
  Future<List<Map<String, dynamic>>> getAllTransactions(
    String storeId, {
    DateTime? dateLimit,
    String? cashierId,
  }) async {
    debugPrint(
      "ReportService.getAllTransactions: id=$storeId, cashier=$cashierId, dateLimit=$dateLimit",
    );
    var query = _supabase
        .from('transactions')
        .select(
          '*, profiles:cashier_id(full_name, avatar_url), transaction_items(*, products(name))',
        )
        .eq('store_id', storeId);

    if (cashierId != null) {
      query = query.eq('cashier_id', cashierId);
    }

    if (dateLimit != null) {
      query = query.gte('created_at', dateLimit.toUtc().toIso8601String());
    }

    final response = await query.order('created_at', ascending: false);

    debugPrint(
      "ReportService.getAllTransactions: Query complete. Found ${response.length} items.",
    );
    if (response.isNotEmpty) {
      final sample = response.first;
      debugPrint(
        "ReportService.getAllTransactions: Sample Tx ID: ${sample['id']}, store_id: ${sample['store_id']}, created_at: ${sample['created_at']}",
      );
    } else {
      // DEBUG: Try fetching without date limit to see if ANYTHING exists for this store
      final totalForStore = await _supabase
          .from('transactions')
          .select('id')
          .eq('store_id', storeId)
          .limit(1);
      debugPrint(
        "ReportService.getAllTransactions: DEBUG - Store ID: $storeId has ${totalForStore.isNotEmpty ? 'at least one' : 'ZERO'} transactions TOTAL in DB.",
      );

      if (totalForStore.isEmpty) {
        final anyTxs = await _supabase
            .from('transactions')
            .select('store_id')
            .limit(3);
        debugPrint(
          "ReportService.getAllTransactions: CRITICAL DEBUG - Any transactions in DB have these store_ids: ${anyTxs.map((e) => e['store_id']).toList()}",
        );
      }
    }

    return List<Map<String, dynamic>>.from(response);
  }

  /// Deletes transactions and their items older than 30 days
  Future<void> cleanupOldTransactions(String storeId) async {
    final thirtyDaysAgo = DateTime.now()
        .subtract(const Duration(days: 30))
        .toUtc()
        .toIso8601String();

    try {
      // Supabase cascade delete should handle items if foreign keys are set correctly,
      // but if not, we might need to delete items first.
      // For now, we assume the user want to delete from transactions table.
      await _supabase
          .from('transactions')
          .delete()
          .eq('store_id', storeId)
          .lt('created_at', thirtyDaysAgo);
    } catch (e) {
      print("Error cleaning up old transactions: $e");
    }
  }

  /// Fetches cashier performance data (sales volume and count)
  Future<List<Map<String, dynamic>>> getCashierPerformance(
    String storeId, {
    DateTime? dateLimit,
  }) async {
    var query = _supabase
        .from('transactions')
        .select(
          'cashier_id, total_amount, profiles:cashier_id(full_name, avatar_url)',
        )
        .eq('store_id', storeId);

    if (dateLimit != null) {
      query = query.gte('created_at', dateLimit.toUtc().toIso8601String());
    }

    final response = await query;

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
