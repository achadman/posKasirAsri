import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AttendanceReportPage extends StatefulWidget {
  final String storeId;
  const AttendanceReportPage({super.key, required this.storeId});

  @override
  State<AttendanceReportPage> createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends State<AttendanceReportPage> {
  final supabase = Supabase.instance.client;
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Laporan Absensi",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Data Tanggal: ${DateFormat('dd MMMM yyyy', 'id').format(_selectedDate)}",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from('attendance_logs')
                  .stream(primaryKey: ['id'])
                  .eq('store_id', widget.storeId)
                  .order('clock_in', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text("Error: ${snapshot.error}"));
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                // Filter by selected date locally for the stream
                final filteredLogs = snapshot.data!.where((log) {
                  final clockIn = DateTime.parse(log['clock_in']).toLocal();
                  return clockIn.year == _selectedDate.year &&
                      clockIn.month == _selectedDate.month &&
                      clockIn.day == _selectedDate.day;
                }).toList();

                if (filteredLogs.isEmpty) {
                  return Center(
                    child: Text(
                      "Tidak ada absensi pada tanggal ini.",
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    return _buildLogCard(log, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log, bool isDark) {
    final clockIn = DateTime.parse(log['clock_in']).toLocal();
    final clockOut = log['clock_out'] != null
        ? DateTime.parse(log['clock_out']).toLocal()
        : null;
    final status = log['status'] ?? 'working';
    final photoUrl = log['photo_url'];

    return FutureBuilder<Map<String, dynamic>?>(
      future: supabase
          .from('profiles')
          .select('full_name')
          .eq('id', log['user_id'])
          .maybeSingle(),
      builder: (context, userSnapshot) {
        final name = userSnapshot.data?['full_name'] ?? "User...";

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            status == 'finished'
                                ? "Selesai Shift"
                                : (status == 'break'
                                      ? "Sedang Istirahat"
                                      : "Sedang Bekerja"),
                            style: TextStyle(
                              color: _getStatusColor(
                                status,
                                log['clock_out'] != null,
                              ),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (photoUrl != null)
                      GestureDetector(
                        onTap: () => _showPhoto(photoUrl),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(photoUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _timeInfo("Masuk", DateFormat('HH:mm').format(clockIn)),
                    _timeInfo(
                      "Keluar",
                      clockOut != null
                          ? DateFormat('HH:mm').format(clockOut)
                          : "--:--",
                    ),
                    _timeInfo("Status", status.toUpperCase()),
                  ],
                ),
                if (log['notes'] != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    "Catatan: ${log['notes']}",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status, bool isFinished) {
    if (isFinished) return Colors.green;
    if (status == 'break') return Colors.blue;
    return Colors.orange;
  }

  Widget _timeInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }

  void _showPhoto(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(url),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Tutup"),
            ),
          ],
        ),
      ),
    );
  }
}
