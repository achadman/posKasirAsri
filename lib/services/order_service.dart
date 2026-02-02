import 'package:supabase_flutter/supabase_flutter.dart';

class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a new transaction and its items, then update product stock
  Future<void> createOrder({
    required String storeId,
    required String userId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    // 1. Insert transaction
    final txResponse = await _supabase
        .from('transactions')
        .insert({
          'store_id': storeId,
          'cashier_id': userId,
          'total_amount': totalAmount,
          'payment_method': 'cash',
          'status': 'completed',
          'source': 'pos_mobile',
        })
        .select()
        .single();

    final txId = txResponse['id'];

    // 2. Insert transaction items
    final List<Map<String, dynamic>> itemsToInsert = items.map((item) {
      return {
        'transaction_id': txId,
        'product_id': item['product_id'],
        'quantity': item['quantity'],
        'price_at_time': item['unit_price'],
      };
    }).toList();

    await _supabase.from('transaction_items').insert(itemsToInsert);

    // 3. Update Product Stock (Decreasing stock)
    for (var item in items) {
      final pId = item['product_id'];
      final qty = item['quantity'];

      // Get current stock
      final productData = await _supabase
          .from('products')
          .select('stock_quantity')
          .eq('id', pId)
          .single();
      final currentStock = productData['stock_quantity'] ?? 0;

      // Update stock
      await _supabase
          .from('products')
          .update({'stock_quantity': currentStock - qty})
          .eq('id', pId);
    }
  }

  /// Get transactions for today for a specific store
  Future<List<Map<String, dynamic>>> getTodayOrders(String storeId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    // Fetch transactions with their items joined
    final response = await _supabase
        .from('transactions')
        .select('*, transaction_items(*, products(name))')
        .eq('store_id', storeId)
        .gte('created_at', startOfDay)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
