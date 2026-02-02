import 'dart:async';
import 'dart:io'; // Added
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart'; // Added
import '../../services/attendance_service.dart';
import 'package:flutter/cupertino.dart';
import '../../widgets/kasir_drawer.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _attendanceService = AttendanceService();
  final supabase = Supabase.instance.client;

  String? _storeId;
  Map<String, dynamic>? _todayLog;
  bool _isLoading = true;
  Timer? _timer;
  DateTime _currentTime = DateTime.now();
  File? _imageFile; // Added for attendance photo

  @override
  void initState() {
    super.initState();
    _startClock();
    _loadData();
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Get Store ID
      final profile = await supabase
          .from('profiles')
          .select('store_id')
          .eq('id', user.id)
          .maybeSingle();

      _storeId = profile?['store_id'];

      // Get Today's Log
      final log = await _attendanceService.getTodayLog(user.id);

      if (mounted) {
        setState(() {
          _todayLog = log;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error loading attendance: $e");
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _handleClockIn() async {
    if (_storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: Store ID not found. Contact Admin."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _attendanceService.clockIn(
        supabase.auth.currentUser!.id,
        _storeId!,
        imageFile: _imageFile,
      );
      await _loadData();
      if (mounted) {
        setState(() => _imageFile = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil Clock In! Selamat bekerja.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error Clock In: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleMarkAbsence() async {
    // Show a dialog for absence reason
    final reasonController = TextEditingController();
    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Keterangan Tidak Hadir"),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: reasonController,
            placeholder: "Alasan (Sakit / Izin / dll)",
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Batal"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Kirim"),
            onPressed: () async {
              Navigator.pop(ctx);
              if (reasonController.text.trim().isEmpty) return;

              setState(() => _isLoading = true);
              try {
                // We'll treat absence as a special clock-in with notes and immediate clock-out or just a note
                // For simplicity, let's just use notes for now.
                await _attendanceService.clockIn(
                  supabase.auth.currentUser!.id,
                  _storeId ?? "unknown",
                  notes: "TIDAK HADIR: ${reasonController.text}",
                );
                // Immediately clock out too
                final log = await _attendanceService.getTodayLog(
                  supabase.auth.currentUser!.id,
                );
                if (log != null) {
                  await _attendanceService.clockOut(
                    log['id'],
                    notes: "TIDAK HADIR: ${reasonController.text}",
                  );
                }
                await _loadData();
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleToggleBreak() async {
    if (_todayLog == null) return;
    final currentStatus = _todayLog!['status'] ?? 'working';
    final newStatus = currentStatus == 'working' ? 'break' : 'working';

    setState(() => _isLoading = true);
    try {
      await _attendanceService.updateStatus(_todayLog!['id'], newStatus);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'break'
                  ? "Berhenti sementara..."
                  : "Kembali bekerja!",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal update status: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleClockOut() async {
    if (_todayLog == null) return;

    setState(() => _isLoading = true);
    try {
      await _attendanceService.clockOut(_todayLog!['id']);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Berhasil Clock Out! Sampai jumpa besok."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error Clock Out: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);

    String statusText = "Belum Masuk";
    Color statusColor = Colors.grey;

    if (_todayLog != null) {
      final status = _todayLog!['status'] ?? 'working';
      if (_todayLog!['clock_out'] != null) {
        statusText = "Selesai Bekerja";
        statusColor = Colors.green;
      } else if (status == 'break') {
        statusText = "Berhenti Sementara";
        statusColor = Colors.blue;
      } else {
        statusText = "Sedang Bekerja";
        statusColor = Colors.orange;
      }
    }

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Absensi Staff",
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(CupertinoIcons.bars, color: textColor),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: const KasirDrawer(currentRoute: '/attendance'),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Digital Clock
                  Text(
                    DateFormat('HH:mm:ss').format(_currentTime),
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy', 'id').format(_currentTime),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Status Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Status Hari Ini",
                          style: GoogleFonts.inter(color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          statusText,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                        if (_todayLog != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildTimeStat(
                                "Masuk",
                                _todayLog!['clock_in'],
                                textColor,
                              ),
                              _buildTimeStat(
                                "Keluar",
                                _todayLog!['clock_out'],
                                textColor,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Actions
                  if (_todayLog == null) ...[
                    // Optional Photo Preview
                    if (_imageFile != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: GestureDetector(
                            onTap: () => setState(() => _imageFile = null),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(CupertinoIcons.camera),
                        label: const Text("Lampirkan Foto (Opsional)"),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            "HADIR",
                            Colors.green,
                            CupertinoIcons.checkmark_circle,
                            _handleClockIn,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            "TIDAK HADIR",
                            Colors.orange,
                            CupertinoIcons.xmark_circle,
                            _handleMarkAbsence,
                          ),
                        ),
                      ],
                    ),
                  ] else if (_todayLog!['clock_out'] == null) ...[
                    _buildActionButton(
                      _todayLog!['status'] == 'break'
                          ? "MASUK KEMBALI"
                          : "BERHENTI SEMENTARA",
                      _todayLog!['status'] == 'break'
                          ? Colors.blue
                          : Colors.grey[700]!,
                      _todayLog!['status'] == 'break'
                          ? CupertinoIcons.play_circle
                          : CupertinoIcons.pause_circle,
                      _handleToggleBreak,
                    ),
                    const SizedBox(height: 16),
                    _buildActionButton(
                      "CLOCK OUT",
                      Colors.red,
                      CupertinoIcons.square_arrow_right,
                      _handleClockOut,
                    ),
                  ] else
                    Text(
                      "Shift hari ini telah selesai.",
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildTimeStat(String label, String? timestamp, Color textColor) {
    String time = "--:--";
    if (timestamp != null) {
      time = DateFormat('HH:mm').format(DateTime.parse(timestamp).toLocal());
    }
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
        ),
        Text(
          time,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 5,
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
