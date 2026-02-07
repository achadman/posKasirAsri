import 'package:supabase_flutter/supabase_flutter.dart';

class ShiftService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch shift history overlapping with a date range (optional).
  /// If no dates provided, fetches all.
  Future<List<Map<String, dynamic>>> getShiftHistory(
    String storeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final startIso = startDate?.toIso8601String();
    final endIso = endDate?.toIso8601String();

    // Select * from attendance_logs and join with profiles to get name/avatar
    // We start with the select and basic filter
    var query = _supabase
        .from('attendance_logs')
        .select('*, profiles:user_id(full_name, avatar_url, role)')
        .eq('store_id', storeId);

    // Apply date filters if provided
    if (startIso != null) {
      query = query.gte('clock_in', startIso);
    }
    if (endIso != null) {
      query = query.lte('clock_in', endIso);
    }

    // Finally apply ordering and await the result
    final response = await query.order('clock_in', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
}
