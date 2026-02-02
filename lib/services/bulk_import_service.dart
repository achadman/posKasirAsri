import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BulkImportService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> importProductsFromCsv(String storeId) async {
    try {
      // 1. Pick File
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) return {'status': 'cancelled'};

      File file = File(result.files.single.path!);
      final input = file.openRead();
      final fields = await input
          .transform(utf8.decoder)
          .transform(const CsvToListConverter())
          .toList();

      if (fields.isEmpty) return {'status': 'error', 'message': 'File kosong'};

      // 2. Process Headers
      // Expected header: name,sku,category,buy_price,sale_price,stock_quantity,description
      final headers = fields[0]
          .map((e) => e.toString().toLowerCase().trim())
          .toList();

      int nameIdx = headers.indexOf('name');
      int skuIdx = headers.indexOf('sku');
      int categoryIdx = headers.indexOf('category');
      int buyPriceIdx = headers.indexOf('buy_price');
      int salePriceIdx = headers.indexOf('sale_price');
      int stockIdx = headers.indexOf('stock_quantity');
      int descIdx = headers.indexOf('description');

      if (nameIdx == -1) {
        return {'status': 'error', 'message': 'Kolom "name" wajib ada'};
      }

      // 3. Fetch Categories for Matching
      final catData = await supabase
          .from('categories')
          .select('id, name')
          .eq('store_id', storeId);

      Map<String, String> categoryMap = {
        for (var cat in catData)
          cat['name'].toString().toLowerCase(): cat['id'].toString(),
      };

      // 4. Parse Rows
      List<Map<String, dynamic>> productsToInsert = [];
      int successCount = 0;
      int failCount = 0;
      List<String> errors = [];

      for (int i = 1; i < fields.length; i++) {
        final row = fields[i];
        if (row.isEmpty) continue;

        try {
          String name = row[nameIdx]?.toString() ?? '';
          if (name.isEmpty) {
            failCount++;
            errors.add('Baris ${i + 1}: Nama kosong');
            continue;
          }

          String? categoryName = categoryIdx != -1
              ? row[categoryIdx]?.toString().toLowerCase().trim()
              : null;
          String? categoryId =
              (categoryName != null && categoryMap.containsKey(categoryName))
              ? categoryMap[categoryName]
              : null;

          productsToInsert.add({
            'store_id': storeId,
            'name': name,
            'sku': skuIdx != -1 ? row[skuIdx]?.toString() : null,
            'category_id': categoryId,
            'buy_price': _parsePrice(buyPriceIdx != -1 ? row[buyPriceIdx] : 0),
            'sale_price': _parsePrice(
              salePriceIdx != -1 ? row[salePriceIdx] : 0,
            ),
            'stock_quantity': _parseInt(stockIdx != -1 ? row[stockIdx] : 0),
            'description': descIdx != -1 ? row[descIdx]?.toString() : null,
            'is_stock_managed': true,
          });
          successCount++;
        } catch (e) {
          failCount++;
          errors.add('Baris ${i + 1}: $e');
        }
      }

      // 5. Bulk Insert
      if (productsToInsert.isNotEmpty) {
        await supabase.from('products').insert(productsToInsert);
      }

      return {
        'status': 'success',
        'successCount': successCount,
        'failCount': failCount,
        'errors': errors,
      };
    } catch (e) {
      debugPrint("Import Error: $e");
      return {'status': 'error', 'message': e.toString()};
    }
  }

  int _parsePrice(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }
}
