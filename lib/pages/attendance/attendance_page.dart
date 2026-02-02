import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/attendance_service.dart';
import '../../widgets/glass_app_bar.dart';

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
      );
      await _loadData(); // Refresh to update UI
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Berhasil Clock In!")));
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

  Future<void> _handleClockOut() async {
    if (_todayLog == null) return;

    setState(() => _isLoading = true);
    try {
      await _attendanceService.clockOut(_todayLog!['id']);
      await _loadData(); // Refresh
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
      if (_todayLog!['clock_out'] != null) {
        statusText = "Selesai Bekerja";
        statusColor = Colors.green;
      } else {
        statusText = "Sedang Bekerja";
        statusColor = Colors.orange;
      }
    }

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(
          "Absensi Staff",
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
                          color: Colors.black.withOpacity(0.05),
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
                  if (_todayLog == null)
                    _buildActionButton(
                      "CLOCK IN",
                      Colors.green,
                      Icons.login_rounded,
                      _handleClockIn,
                    )
                  else if (_todayLog!['clock_out'] == null)
                    _buildActionButton(
                      "CLOCK OUT",
                      Colors.red,
                      Icons.logout_rounded,
                      _handleClockOut,
                    )
                  else
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
