import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class BluetoothPrinterService {
  static final BluetoothPrinterService _instance =
      BluetoothPrinterService._internal();
  factory BluetoothPrinterService() => _instance;
  BluetoothPrinterService._internal();

  final BlueThermalPrinter _printer = BlueThermalPrinter.instance;
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;

  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _isConnected;

  static const String _prefKeyAddress = 'printer_address';
  static const String _prefKeyName = 'printer_name';

  Future<void> init() async {
    _isConnected = (await _printer.isConnected) ?? false;
    if (!_isConnected) {
      await _tryAutoConnect();
    }
  }

  Future<bool?> get isConnectedStatus async => await _printer.isConnected;

  Future<List<BluetoothDevice>> getBondedDevices() async {
    return await _printer.getBondedDevices();
  }

  Future<List<BluetoothDevice>> getDevices() => getBondedDevices();

  Future<bool> connect(BluetoothDevice device) async {
    try {
      if (await _printer.isConnected ?? false) {
        await _printer.disconnect();
      }
      await _printer.connect(device);
      _selectedDevice = device;
      _isConnected = true;
      await _savePrinter(device);
      return true;
    } catch (e) {
      print("Error connecting to printer: $e");
      _isConnected = false;
      return false;
    }
  }

  Future<void> disconnect() async {
    await _printer.disconnect();
    _isConnected = false;
    _selectedDevice = null;
    await _clearPrinter();
  }

  Future<void> _savePrinter(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyAddress, device.address!);
    await prefs.setString(_prefKeyName, device.name!);
  }

  Future<void> _clearPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyAddress);
    await prefs.remove(_prefKeyName);
  }

  Future<void> _tryAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_prefKeyAddress);
    if (address != null) {
      final devices = await getDevices();
      final device = devices.firstWhere(
        (d) => d.address == address,
        orElse: () => BluetoothDevice("Unknown", address),
      );
      if (device.name != "Unknown") {
        await connect(device);
      }
    }
  }

  Future<void> testPrint() => printTest();

  Future<void> printTest() async {
    if (!(await _printer.isConnected ?? false)) return;

    _printer.printNewLine();
    _printer.printCustom("TEST PRINT", 3, 1); // Size 3, Align 1 (Center)
    _printer.printNewLine();
    _printer.printCustom("Printer Bluetooth Berhasil Terhubung", 1, 1);
    _printer.printNewLine();
    _printer.printNewLine();
    _printer.printNewLine();
  }

  Future<void> printReceipt({
    required String storeName,
    required String transactionId,
    required DateTime createdAt,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double cashReceived,
    required double change,
    required String paymentMethod,
  }) async {
    if (!(await _printer.isConnected ?? false)) return;

    final currencyFormat = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    _printer.printNewLine();
    _printer.printCustom(storeName.toUpperCase(), 3, 1);
    _printer.printNewLine();
    _printer.printCustom("ID: #$transactionId", 1, 1);
    _printer.printCustom(
      DateFormat('dd MMM yyyy, HH:mm').format(createdAt),
      1,
      1,
    );
    _printer.printCustom("Pembayaran: $paymentMethod", 1, 1);
    _printer.printNewLine();
    _printer.printCustom("--------------------------------", 1, 1);

    for (var item in items) {
      final name = item['name'] ?? 'Produk';
      final qty = item['quantity'] ?? 1;
      final total = item['total_price'] ?? 0;

      _printer.printLeftRight(name, "", 1);
      _printer.printLeftRight(
        "$qty x ${currencyFormat.format(total / qty)}",
        currencyFormat.format(total),
        1,
      );
      if (item['notes'] != null && item['notes'].toString().isNotEmpty) {
        _printer.printCustom("(${item['notes']})", 0, 0);
      }
    }

    _printer.printCustom("--------------------------------", 1, 1);
    _printer.printLeftRight(
      "TOTAL",
      currencyFormat.format(totalAmount),
      2,
    );
    _printer.printLeftRight(
      "Bayar",
      currencyFormat.format(cashReceived),
      1,
    );
    _printer.printLeftRight(
      "Kembalian",
      currencyFormat.format(change),
      1,
    );

    _printer.printNewLine();
    _printer.printCustom("Terima kasih sudah berbelanja", 1, 1);
    _printer.printCustom("--- POS KASIR ASRI ---", 0, 1);
    _printer.printNewLine();
    _printer.printNewLine();
    _printer.printNewLine();
  }
}
