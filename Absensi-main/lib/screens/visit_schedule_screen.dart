import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/api_services.dart';
import 'visit_detail_screen.dart';

class VisitScheduleScreen extends StatefulWidget {
  final String token;
  const VisitScheduleScreen({super.key, required this.token});

  @override
  State<VisitScheduleScreen> createState() => _VisitScheduleScreenState();
}

class _VisitScheduleScreenState extends State<VisitScheduleScreen> {
  final ApiService _apiService = ApiService();

  // Calendar State
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Data State
  List<dynamic> _visits = [];
  bool _isLoading = false;
  String? _errorMessage;

  // --- AUTOMOTIVE THEME COLORS ---
  final Color _brandRed = const Color(0xFFE50000);
  final Color _brandBlue = const Color(0xFF0044CC);
  final Color _brandBlack = const Color(0xFF212121);
  final Color _darkAsphalt = const Color(0xFF1E1E1E);
  final Color _silverMetal = const Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      setState(() {
        _selectedDay = _focusedDay;
      });
      _fetchVisits(_selectedDay!);
    });
  }

  Future<void> _fetchVisits(DateTime date) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(date);
      var data = await _apiService.getVisitsByDate(widget.token, dateStr);

      if (!mounted) return;

      setState(() {
        _visits = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Gagal memuat data. Cek koneksi internet.";
        _isLoading = false;
        _visits = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _silverMetal,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_brandRed, _brandBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text("JADWAL KUNJUNGAN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
        leading: const BackButton(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
           // Background Decoration
          Positioned(
            bottom: 0, right: 0,
            child: Opacity(opacity: 0.03, child: Icon(Icons.calendar_month_rounded, size: 250, color: _brandBlack)),
          ),

          Column(
            children: [
              // --- 1. KALENDER SECTION ---
              Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: TableCalendar(
                  locale: 'id_ID',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    if (!isSameDay(_selectedDay, selectedDay)) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      _fetchVisits(selectedDay);
                    }
                  },
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(color: _brandBlack, fontSize: 16, fontWeight: FontWeight.bold),
                    leftChevronIcon: Icon(Icons.chevron_left, color: _brandBlack),
                    rightChevronIcon: Icon(Icons.chevron_right, color: _brandBlack),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    defaultTextStyle: TextStyle(color: _brandBlack),
                    weekendTextStyle: const TextStyle(color: Colors.redAccent),
                    selectedDecoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_brandRed, _brandBlue]),
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: _brandBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(color: _brandBlue, fontWeight: FontWeight.bold),
                    outsideDaysVisible: false,
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                    weekendStyle: TextStyle(color: Colors.red[300], fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // --- 2. HEADER LIST SECTION ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
                child: Row(
                  children: [
                    Icon(Icons.event_note_rounded, color: _brandRed, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "Agenda: ${DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDay ?? DateTime.now())}",
                      style: TextStyle(color: _darkAsphalt, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),

              // --- 3. LIST VISIT SECTION ---
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: _brandRed))
                    : _errorMessage != null
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48, color: Colors.red[200]),
                          const SizedBox(height: 10),
                          Text(_errorMessage!, style: TextStyle(color: Colors.grey[600])),
                        ],
                      ))
                    : _visits.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy_rounded, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 15),
                          Text("Tidak ada jadwal kunjungan", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
                        ],
                      ))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        itemCount: _visits.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _visits[index];
                          return _buildVisitItem(item);
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisitItem(Map<String, dynamic> item) {
    var customer = item['customer'] ?? {};
    String status = item['status'] ?? "Pending";
    String time = item['schedule_time'] ?? "--:--";

    if (time.length > 5) time = time.substring(0, 5);

    bool isDone = status.toLowerCase() == "completed" || status.toLowerCase() == "done";
    Color statusColor = isDone ? Colors.green : Colors.orange;

    return GestureDetector(
      onTap: () {
        Map<String, dynamic> detailData = {
          "id": item['id'],
          "customer_name": customer['name'],
          "address": customer['address'],
          "time": time,
          "status": status,
          "contact": customer['cust_id'],
          "notes": item['notes'],
          "latitude": customer['lat'],
          "longitude": customer['long'],
        };

        Navigator.push(context, MaterialPageRoute(builder: (_) => VisitDetailScreen(visitData: detailData, token: widget.token)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Strip Indicator
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                ),
              ),
              
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Time Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _brandBlue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(time, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _darkAsphalt)),
                            const SizedBox(height: 2),
                            Text("WIB", style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Detail Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              customer['name'] ?? "Tanpa Nama",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _brandBlack),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded, size: 14, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    customer['address'] ?? "-",
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Status Badge
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isDone ? "SELESAI" : "PENDING",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
