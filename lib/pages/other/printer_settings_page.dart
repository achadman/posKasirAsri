import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../core/app_theme.dart';
import '../../services/bluetooth_printer_service.dart';
import 'receipt_settings_page.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _connected = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  void _initBluetooth() async {
    try {
      bool? isConnected = await _printerService.isConnectedStatus;
      if (mounted) setState(() => _connected = isConnected ?? false);
    } catch (e) {
      debugPrint("Bluetooth not supported on this platform: $e");
    }
    _getDevices();
  }

  void _getDevices() async {
    setState(() => _isScanning = true);
    try {
      List<BluetoothDevice> devices = await _printerService.getBondedDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isScanning = false;
        });
      }
    } catch (e) {
      debugPrint("Bluetooth scan failed: $e");
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      resizeToAvoidBottomInset: false, // MANDATORY
      appBar: AppBar(
        title: const Text("Pengaturan Printer",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.defaultGradient)),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _ConnectionStatusBar(connected: _connected, isScanning: _isScanning),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text("Pilih Perangkat",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey)),
                const SizedBox(height: 12),
                _DeviceDropdown(
                    devices: _devices,
                    selected: _selectedDevice,
                    onChanged: (v) => setState(() => _selectedDevice = v)),
                const SizedBox(height: 30),
                const Text("Aksi",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey)),
                const SizedBox(height: 12),
                _PrinterActionButton(
                    onPressed: _connected
                        ? _disconnect
                        : (_selectedDevice != null ? _connect : null),
                    icon: _connected
                        ? Icons.bluetooth_disabled
                        : Icons.bluetooth_connected,
                    label: _connected ? "Putuskan Koneksi" : "Hubungkan Printer",
                    color: _connected ? Colors.red : AppTheme.primaryColor),
                const SizedBox(height: 15),
                _PrinterActionButton(
                    onPressed: _connected
                        ? () => _printerService.testPrint()
                        : null,
                    icon: Icons.print_rounded,
                    label: "Cetak Test Struk",
                    color: Colors.green.shade600,
                    isOutlined: true),
                const SizedBox(height: 15),
                _PrinterActionButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReceiptSettingsPage())),
                    icon: Icons.settings_suggest_rounded,
                    label: "Atur Layout Struk",
                    color: Colors.orange.shade700,
                    isOutlined: true),
                const SizedBox(height: 40),
                const _PrinterGuideCard(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: _getDevices,
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.refresh_rounded, color: Colors.white)),
    );
  }

  void _connect() async {
    if (_selectedDevice == null) return;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final success = await _printerService.connect(_selectedDevice!);
      if (mounted) {
        Navigator.pop(context);
        setState(() => _connected = success);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Berhasil terhubung")));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Gagal terhubung")));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal: $e")));
      }
    }
  }

  void _disconnect() async {
    await _printerService.disconnect();
    if (mounted) setState(() => _connected = false);
  }
}

class _ConnectionStatusBar extends StatelessWidget {
  final bool connected;
  final bool isScanning;
  const _ConnectionStatusBar({required this.connected, required this.isScanning});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      color: connected
          ? Colors.green.withOpacity(0.1)
          : Colors.red.withOpacity(0.1),
      child: Row(children: [
        Icon(connected ? Icons.check_circle : Icons.error_outline,
            color: connected ? Colors.green : Colors.red, size: 20),
        const SizedBox(width: 10),
        Text(connected ? "Printer Terhubung" : "Printer Belum Terhubung",
            style: TextStyle(
                color: connected ? Colors.green.shade800 : Colors.red.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        const Spacer(),
        if (isScanning)
          const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
    );
  }
}

class _DeviceDropdown extends StatelessWidget {
  final List<BluetoothDevice> devices;
  final BluetoothDevice? selected;
  final ValueChanged<BluetoothDevice?> onChanged;
  const _DeviceDropdown(
      {required this.devices, this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ]),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BluetoothDevice>(
          isExpanded: true,
          hint: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text("Cari Printer Thermal...")),
          value: selected,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTheme.primaryColor),
          items: devices
              .map((d) => DropdownMenuItem(
                  value: d,
                  child: Row(children: [
                    const Icon(Icons.print_outlined, color: Colors.blueGrey),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Text(d.name ?? "Device Unknown",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                              maxLines: 1),
                          Text(d.address ?? "",
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                              maxLines: 1)
                        ]))
                  ])))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PrinterActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Color color;
  final bool isOutlined;
  const _PrinterActionButton(
      {required this.onPressed,
      required this.icon,
      required this.label,
      required this.color,
      this.isOutlined = false});
  @override
  Widget build(BuildContext context) {
    final style = isOutlined
        ? OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color, width: 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)))
        : ElevatedButton.styleFrom(
            backgroundColor: color,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)));
    return SizedBox(
        width: double.infinity,
        height: 55,
        child: isOutlined
            ? OutlinedButton.icon(
                onPressed: onPressed, icon: Icon(icon), label: Text(label))
            : ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, color: Colors.white),
                label: Text(label, style: const TextStyle(color: Colors.white))));
  }
}

class _PrinterGuideCard extends StatelessWidget {
  const _PrinterGuideCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline, color: Colors.orange.shade800),
          const SizedBox(width: 10),
          Text("Tips Koneksi",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.orange.shade800))
        ]),
        const SizedBox(height: 10),
        const Text(
            "1. Hidupkan Bluetooth.\n2. Pastikan printer sudah 'Paired'.\n3. Jika tidak muncul, tekan tombol refresh.",
            style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87)),
      ]),
    );
  }
}
