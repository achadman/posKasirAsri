import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/report_service.dart';

class AdminController extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  String? _userId;
  String? _storeId;
  String? _userName;
  String? _profileUrl;
  String? _storeName;
  String? _storeLogo;
  String? _role;
  Map<String, dynamic>? _permissions;
  bool _isInitializing = true;
  double _todaySales = 0;
  int _lowStockCount = 0;
  List<Map<String, dynamic>> _lowStockItems = [];
  int _transactionCount = 0;

  // Getters
  String? get userId => _userId;
  String? get storeId => _storeId;
  String? get userName => _userName;
  String? get profileUrl => _profileUrl;
  String? get storeName => _storeName;
  String? get storeLogo => _storeLogo;
  String? get role => _role;
  Map<String, dynamic>? get permissions => _permissions;
  bool get isInitializing => _isInitializing;
  double get todaySales => _todaySales;
  int get lowStockCount => _lowStockCount;
  List<Map<String, dynamic>> get lowStockItems => _lowStockItems;
  int get transactionCount => _transactionCount;

  Future<void> loadInitialData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('store_id, full_name, role, avatar_url, permissions')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        _userId = user.id;
        _storeId = profile['store_id'];
        _userName = profile['full_name'] ?? user.email?.split('@')[0] ?? 'User';
        _role = profile['role'];
        _profileUrl = profile['avatar_url'];
        _permissions = profile['permissions'];

        debugPrint(
          "AdminController: Profile loaded. userId: $_userId, storeId: $_storeId, role: $_role",
        );

        // DEBUG: List all stores to check for mismatches
        final allStores = await supabase.from('stores').select('id, name');
        debugPrint("AdminController: ALL STORES in DB: ${allStores.length}");
        for (var s in allStores) {
          debugPrint("  - Store: ${s['name']} (ID: ${s['id']})");
        }
      } else {
        debugPrint("AdminController: Profile NOT FOUND for userId: ${user.id}");
      }

      if (_storeId != null) {
        await fetchDashboardStats();

        // Load Store Info
        final store = await supabase
            .from('stores')
            .select('name, logo_url')
            .eq('id', _storeId!)
            .maybeSingle();

        if (store != null) {
          _storeName = store['name'];
          _storeLogo = store['logo_url'];
        }

        // Auto-cleanup old transactions (older than 30 days)
        await ReportService().cleanupOldTransactions(_storeId!);
      }

      _isInitializing = false;
      notifyListeners();
    } catch (e) {
      debugPrint("AdminController: Error loading profile: $e");
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> fetchDashboardStats() async {
    if (_storeId == null) return;

    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final utcStartOfToday = startOfToday.toUtc();

      debugPrint("AdminController: Fetching dashboard for storeId: $_storeId");
      debugPrint("AdminController: Local startOfToday: $startOfToday");
      debugPrint(
        "AdminController: UTC startOfToday: ${utcStartOfToday.toIso8601String()}",
      );

      // Fetch Today's Sales
      final txs = await supabase
          .from('transactions')
          .select('total_amount')
          .eq('store_id', _storeId!)
          .gte('created_at', utcStartOfToday.toIso8601String());

      debugPrint(
        "AdminController: Fetched ${txs.length} transactions for today.",
      );

      double total = 0;
      for (var tx in txs) {
        total += (tx['total_amount'] as num).toDouble();
      }

      // DEBUG: Fetch total count ever for this store
      final allTxs = await supabase
          .from('transactions')
          .select('id')
          .eq('store_id', _storeId!);
      debugPrint(
        "AdminController: TOTAL transactions ever for this store ID ($_storeId): ${allTxs.length}",
      );

      // NEW DEBUG: Fetch 5 arbitrary transactions and log their store_ids to see what's in the DB
      final sampleTxs = await supabase
          .from('transactions')
          .select('id, store_id, created_at')
          .limit(5);
      debugPrint("AdminController: DB SAMPLE (Size: ${sampleTxs.length}):");
      for (var tx in sampleTxs) {
        debugPrint(
          "  - ID: ${tx['id']}, STORE: ${tx['store_id']}, CREATED: ${tx['created_at']}",
        );
      }

      // Fetch Low Stock Details
      final products = await supabase
          .from('products')
          .select('id, name, stock_quantity')
          .eq('store_id', _storeId!)
          .lt('stock_quantity', 5)
          .eq('is_stock_managed', true)
          .order('stock_quantity', ascending: true);

      final newLowStockItems = List<Map<String, dynamic>>.from(
        products,
      ).where((p) => (p['is_deleted'] ?? false) == false).toList();

      // Update values and notify
      bool changed = false;
      if (_todaySales != total) {
        _todaySales = total;
        changed = true;
      }
      if (_transactionCount != txs.length) {
        _transactionCount = txs.length;
        changed = true;
      }
      if (_lowStockCount != products.length) {
        _lowStockCount = products.length;
        changed = true;
      }
      if (_lowStockItems.length != newLowStockItems.length) {
        _lowStockItems = newLowStockItems;
        changed = true;
      } else {
        // Simple comparison for content if needed, but length check is often enough for a first pass
        // or we could do a more thorough check if necessary.
        _lowStockItems = newLowStockItems;
      }

      if (changed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint("AdminController: Error fetching stats: $e");
    }
  }

  Future<void> resetStore({bool deleteProducts = false}) async {
    if (_storeId == null) return;

    try {
      // 1. Delete Transaction Items (Foreign Key Constraint)
      // We need to find all transaction IDs for this store first or just delete using inner join logic if Supabase supports it cleanly.
      // But RLS usually handles "delete if you own it", so let's try direct delete if possible or cascading.
      // Safest way without cascade config in DB is to delete items first.

      // Actually, if we delete transactions, items should cascade IF structured that way.
      // If not, we must delete items first. Let's assume standard behavior but be safe.

      // Get all transaction IDs for this store
      final txs = await supabase
          .from('transactions')
          .select('id')
          .eq('store_id', _storeId!);

      if (txs.isNotEmpty) {
        final txIds = txs.map((t) => t['id'] as String).toList();
        await supabase
            .from('transaction_items')
            .delete()
            .filter(
              'transaction_id',
              'in',
              txIds,
            ); // Fixed: Use filter for 'in'
        await supabase
            .from('transactions')
            .delete()
            .filter('id', 'in', txIds); // Fixed: Use filter for 'in'
      }

      // 2. Delete Attendance Logs (Clean start for employees too)
      await supabase.from('attendance_logs').delete().eq('store_id', _storeId!);

      // 3. Handle Products & Categories
      if (deleteProducts) {
        // Hard Delete all products
        await supabase.from('products').delete().eq('store_id', _storeId!);

        // Hard Delete all categories (Since products are gone, categories are useless)
        await supabase.from('categories').delete().eq('store_id', _storeId!);
      } else {
        // Reset Stock Only
        await supabase
            .from('products')
            .update({
              'stock_quantity': 0,
              'is_deleted': false,
            }) // Ensure they are visible
            .eq('store_id', _storeId!)
            .eq('is_stock_managed', true);
      }

      // Refresh Stats
      await fetchDashboardStats();
    } catch (e) {
      debugPrint("AdminController: Error resetting store: $e");
      rethrow;
    }
  }
}
