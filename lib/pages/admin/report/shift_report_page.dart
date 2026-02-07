import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/shift_service.dart';

class ShiftReportPage extends StatefulWidget {
  final String storeId;
  const ShiftReportPage({super.key, required this.storeId});

  @override
  State<ShiftReportPage> createState() => _ShiftReportPageState();
}

class _ShiftReportPageState extends State<ShiftReportPage> {
  final ShiftService _shiftService = ShiftService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _shifts = [];
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _fetchShifts();
  }

  Future<void> _fetchShifts() async {
    setState(() => _isLoading = true);
    try {
      final data = await _shiftService.getShiftHistory(
        widget.storeId,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end.add(
          const Duration(days: 1),
        ), // Include end date
      );
      setState(() => _shifts = data);
    } catch (e) {
      debugPrint("Error fetching shifts: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFEA5700),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _fetchShifts();
    }
  }

  String _formatDuration(String? start, String? end) {
    if (start == null) return "-";
    final startTime = DateTime.parse(start);
    final endTime = end != null ? DateTime.parse(end) : DateTime.now();
    final duration = endTime.difference(startTime);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (end == null) {
      return "$hours jam $minutes menit (Sedang Berjalan)";
    }
    return "$hours jam $minutes menit";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Laporan Shift",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.calendar),
            onPressed: _pickDateRange,
            tooltip: "Filter Tanggal",
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      "${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}",
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() => _selectedDateRange = null);
                      _fetchShifts();
                    },
                    backgroundColor: const Color(
                      0xFFEA5700,
                    ).withValues(alpha: 0.1),
                    side: BorderSide.none,
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _shifts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.clock,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Belum ada data shift.",
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _shifts.length,
                    itemBuilder: (context, index) {
                      final shift = _shifts[index];
                      final profile = shift['profiles'] ?? {};
                      final name = profile['full_name'] ?? 'Unknown';
                      final role = profile['role'] ?? 'Staff';
                      final String? avatarUrl = profile['avatar_url'];
                      final clockIn = DateTime.parse(
                        shift['clock_in'],
                      ).toLocal();
                      final clockOutStr = shift['clock_out'];
                      final clockOut = clockOutStr != null
                          ? DateTime.parse(clockOutStr).toLocal()
                          : null;
                      final status = shift['status'] ?? 'unknown';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: avatarUrl != null
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: avatarUrl == null
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: textColor,
                                        ),
                                      ),
                                      Text(
                                        role.toString().toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      status,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status == 'working'
                                        ? 'AKTIF'
                                        : status == 'finished'
                                        ? 'SELESAI'
                                        : status.toString().toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInfoColumn(
                                  "MULAI",
                                  DateFormat('HH:mm').format(clockIn),
                                  DateFormat('dd MMM').format(clockIn),
                                  textColor,
                                  isLeft: true,
                                ),
                                const Icon(
                                  CupertinoIcons.arrow_right,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                _buildInfoColumn(
                                  "SELESAI",
                                  clockOut != null
                                      ? DateFormat('HH:mm').format(clockOut)
                                      : "-",
                                  clockOut != null
                                      ? DateFormat('dd MMM').format(clockOut)
                                      : "",
                                  textColor,
                                  isLeft: false,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.timer,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Durasi: ${_formatDuration(shift['clock_in'], shift['clock_out'])}",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(
    String label,
    String time,
    String date,
    Color textColor, {
    required bool isLeft,
  }) {
    return Column(
      crossAxisAlignment: isLeft
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        if (date.isNotEmpty)
          Text(
            date,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'working':
        return Colors.green;
      case 'finished':
        return Colors.blue;
      case 'break':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
