import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Use a standalone client for account creation to avoid signing out the current user
  final String _supabaseUrl = 'https://pyesewttbjqtniixrhvc.supabase.co';
  final String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB5ZXNld3R0YmpxdG5paXhyaHZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk4NTI5ODAsImV4cCI6MjA4NTQyODk4MH0.Z71ogOpR-oD_WXClMXGlf7UUHNEZ09B63_TyrDboP4c';

  /// Fetch all employees (cashiers) for a specific store
  Future<List<Map<String, dynamic>>> getEmployees(String storeId) async {
    final response = await _supabase
        .from('profiles')
        .select('*, permissions')
        .eq('store_id', storeId)
        .eq('role', 'cashier')
        .order('full_name', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Create a new cashier account and link it to the store
  Future<void> createCashierAccount({
    required String email,
    required String password,
    required String fullName,
    required String storeId,
    Map<String, bool>? permissions,
  }) async {
    // 1. Initialize a temporary client
    // We use implicit flow to avoid PKCE storage requirements for this temporary background client
    final tempClient = SupabaseClient(
      _supabaseUrl,
      _supabaseAnonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );

    // 2. Sign up the new user
    final AuthResponse res = await tempClient.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': 'cashier',
        'permissions': permissions ??
            {
              'manage_inventory': false,
              'manage_categories': false,
              'pos_access': true,
              'view_history': true,
              'view_reports': false,
              'manage_printer': true,
            },
      },
    );

    if (res.user != null) {
      // 3. Update the profile created by the trigger
      // Wait a moment for the DB trigger to create the profile record
      await Future.delayed(const Duration(milliseconds: 500));

      try {
        final updateResponse = await _supabase
            .from('profiles')
            .update({
              'full_name': fullName,
              'role': 'cashier',
              'store_id': storeId,
              'permissions': permissions ??
                  {
                    'manage_inventory': false,
                    'manage_categories': false,
                    'pos_access': true,
                    'view_history': true,
                    'view_reports': false,
                    'manage_printer': true,
                  },
            })
            .eq('id', res.user!.id)
            .select();

        if (updateResponse.isEmpty) {
          throw Exception(
            "Profil berhasil dibuat tetapi tidak dapat diperbarui. "
            "Pastikan RLS di Supabase mengizinkan Admin/Owner untuk memperbarui profil karyawan.",
          );
        }
      } catch (dbError) {
        throw Exception("Gagal sinkronisasi profil ke Toko: $dbError");
      }
    }
  }

  /// Remove an employee from the store (reset role to user and clear store_id)
  Future<void> removeEmployee(String userId) async {
    await _supabase
        .from('profiles')
        .update({'store_id': null, 'role': 'user'})
        .eq('id', userId);
  }
}
