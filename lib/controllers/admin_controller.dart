import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminController extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  String? _storeId;
  String? _userName;
  String? _profileUrl;
  String? _storeName;
  String? _storeLogo;
  String? _role;
  bool _isInitializing = true;
  double _todaySales = 0;
  int _lowStockCount = 0;
  List<Map<String, dynamic>> _lowStockItems = [];
  int _transactionCount = 0;

  // Getters
  String? get storeId => _storeId;
  String? get userName => _userName;
  String? get profileUrl => _profileUrl;
  String? get storeName => _storeName;
  String? get storeLogo => _storeLogo;
  String? get role => _role;
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
          .select('store_id, full_name, role, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        _storeId = profile['store_id'];
        _userName = profile['full_name'] ?? user.email?.split('@')[0] ?? 'User';
        _role = profile['role'];
        _profileUrl = profile['avatar_url'];
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

      // Fetch Today's Sales
      final txs = await supabase
          .from('transactions')
          .select('total_amount')
          .eq('store_id', _storeId!)
          .gte('created_at', startOfToday.toUtc().toIso8601String());

      double total = 0;
      for (var tx in txs) {
        total += (tx['total_amount'] as num).toDouble();
      }

      // Fetch Low Stock Details
      final products = await supabase
          .from('products')
          .select('id, name, stock_quantity')
          .eq('store_id', _storeId!)
          .lt('stock_quantity', 5)
          .eq('is_stock_managed', true)
          .order('stock_quantity', ascending: true);

      final newLowStockItems = List<Map<String, dynamic>>.from(products);

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
}
