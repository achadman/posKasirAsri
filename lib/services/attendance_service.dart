import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get today's attendance log for a specific user
  Future<Map<String, dynamic>?> getTodayLog(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    ).toIso8601String();

    try {
      final response = await _supabase
          .from('attendance_logs')
          .select()
          .eq('user_id', userId)
          .gte('clock_in', startOfDay)
          .lte('clock_in', endOfDay)
          .maybeSingle();

      return response;
    } catch (e) {
      // If error or no rows found (though maybeSingle handles no rows)
      return null;
    }
  }

  /// Clock In
  Future<void> clockIn(
    String userId,
    String storeId, {
    String? notes,
    File? imageFile,
  }) async {
    String? photoUrl;

    if (imageFile != null) {
      final fileExt = imageFile.path.split('.').last;
      final fileName =
          '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await _supabase.storage
          .from('attendance')
          .upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      photoUrl = _supabase.storage.from('attendance').getPublicUrl(fileName);
    }

    await _supabase.from('attendance_logs').insert({
      'user_id': userId,
      'store_id': storeId,
      'clock_in': DateTime.now().toIso8601String(),
      'notes': notes,
      'photo_url': photoUrl,
      'status': 'working',
    });
  }

  /// Update attendance status (e.g., 'working', 'break', 'finished')
  Future<void> updateStatus(String logId, String status) async {
    await _supabase
        .from('attendance_logs')
        .update({'status': status})
        .eq('id', logId);
  }

  /// Clock Out
  Future<void> clockOut(String logId, {String? notes}) async {
    final now = DateTime.now();
    await _supabase
        .from('attendance_logs')
        .update({
          'clock_out': now.toIso8601String(),
          'status': 'finished',
          if (notes != null) 'notes': notes,
        })
        .eq('id', logId);
  }
}
