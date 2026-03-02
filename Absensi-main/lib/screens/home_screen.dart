import 'package:sumber_baru/screens/pdf_viewer_screen.dart';
import 'package:sumber_baru/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/api_services.dart';
import 'attendance_screen.dart';
import 'leave_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String token;
  final String name;

  const HomeScreen({super.key, required this.token, required this.name});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  late Future<List<dynamic>> _attendanceFuture;
  late Future<List<dynamic>> _leaveFuture;
  late Future<Map<String, dynamic>?> _profileFuture;

  late TabController _tabController;
  final GlobalKey<NestedScrollViewState> _nestedScrollViewKey = GlobalKey<NestedScrollViewState>();

  // --- AUTOMOTIVE THEME COLORS (MATCHING MOBILE HOME SCREEN) ---
  final Color _brandRed = const Color(0xFFE50000); 
  final Color _brandBlue = const Color(0xFF0044CC); 
  final Color _brandBlack = const Color(0xFF212121);
  final Color _darkAsphalt = const Color(0xFF1E1E1E);
  final Color _successGreen = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  void _loadInitialData() {
    _profileFuture = _apiService.getProfile(widget.token);
    _attendanceFuture = _apiService.getHistory(widget.token);
    _leaveFuture = _apiService.getLeaveHistory(widget.token);
  }

  Future<void> _refreshData() async {
    setState(() {
      _loadInitialData();
    });
    try {
      await Future.wait([_profileFuture, _attendanceFuture, _leaveFuture]);
    } catch (e) {
      print("Error refreshing data: $e");
    }
  }

  Future<void> _handleLogout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("KONFIRMASI", style: TextStyle(color: _brandRed, fontWeight: FontWeight.bold)),
        content: const Text("Apakah Anda yakin ingin keluar?", style: TextStyle(color: Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _brandRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("KELUAR"),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    // Format terpisah untuk desain baru
    String dayName = DateFormat('EEEE', 'id_ID').format(now).toUpperCase();
    String fullDate = DateFormat('d MMMM yyyy', 'id_ID').format(now).toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // --- 1. BACKGROUND DENGAN POLA OTOMOTIF ---
          Container(
            color: const Color(0xFFF8F9FA),
            child: Stack(
              children: [
                Positioned(
                  top: 300,
                  left: 20,
                  bottom: 0,
                  child: Opacity(
                    opacity: 0.03,
                    child: Column(
                      children: List.generate(15, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          width: 40,
                          height: 8,
                          child: CustomPaint(painter: ChevronPainter(color: Colors.black)),
                        );
                      }),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  width: 200,
                  height: 200,
                  child: Opacity(
                    opacity: 0.03,
                    child: CustomPaint(
                      painter: DotGridPainter(color: _brandBlack),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- 2. MAIN CONTENT ---
          SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: _refreshData,
              color: _brandRed,
              notificationPredicate: (notification) {
                if (notification.depth == 0) return true;
                if (_nestedScrollViewKey.currentState != null && 
                    _nestedScrollViewKey.currentState!.outerController.hasClients) {
                   if (_nestedScrollViewKey.currentState!.outerController.offset > 0.0) {
                     return false;
                   }
                }
                return notification.depth <= 2;
              },
              child: NestedScrollView(
                key: _nestedScrollViewKey,
                physics: const AlwaysScrollableScrollPhysics(),
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildAutomotiveHeader(dayName, fullDate),
                          Transform.translate(
                            offset: const Offset(0, -50),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  _buildStatsSection(),
                                  const SizedBox(height: 25),
                                  
                                  Row(
                                    children: [
                                      Icon(Icons.dashboard_customize_rounded, color: _brandRed, size: 20),
                                      const SizedBox(width: 10),
                                      Text("AKSES CEPAT", style: TextStyle(fontWeight: FontWeight.w800, color: _darkAsphalt, fontSize: 16, letterSpacing: 0.5)),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  _buildActionButtons(),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        minHeight: 60.0,
                        maxHeight: 60.0,
                        child: Container(
                          color: const Color(0xFFF8F9FA),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                color: _brandRed,
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(colors: [_brandRed, const Color(0xFF8B0000)]),
                              ),
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.grey[600],
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              tabs: const [Tab(text: "Riwayat Absen"), Tab(text: "Riwayat Cuti")],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildScrollableList(_buildSliverAttendanceList(), 'absen'),
                    _buildScrollableList(_buildSliverLeaveList(), 'cuti'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableList(Widget sliverList, String key) {
    return Builder(builder: (context) => CustomScrollView(
      key: PageStorageKey<String>(key),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 30), sliver: sliverList),
      ],
    ));
  }

  // --- AUTOMOTIVE HEADER ---
  Widget _buildAutomotiveHeader(String dayName, String fullDate) {
    return ClipPath(
      clipper: AutomotiveHeaderClipper(),
      child: Container(
        width: double.infinity,
        height: 280,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0D1117),
              _brandRed.withOpacity(0.9),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background Image Overlay (Subtle)
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  'lib/assets/spooring-berkala.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                ),
              ),
            ),
            // Carbon Fiber Pattern
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: CustomPaint(painter: CarbonFiberPainter()),
              ),
            ),
            // Decorative Elements
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.05), width: 30),
                ),
              ),
            ),
            Positioned(
              left: 30, top: 0, bottom: 0,
              child: Transform(
                transform: Matrix4.skewX(-0.2),
                child: Container(width: 60, decoration: BoxDecoration(color: Colors.white.withOpacity(0.02))),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // --- NEW DATE DESIGN (SPORTY BADGE) ---
                      Container(
                        padding: const EdgeInsets.all(2), // Border effect
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: [Colors.white.withOpacity(0.6), Colors.white.withOpacity(0.1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight
                          )
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Day Box
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _brandRed,
                                  borderRadius: BorderRadius.circular(4)
                                ),
                                child: Text(
                                  dayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Date Text
                              Text(
                                fullDate,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  fontFamily: 'RobotoMono' // Monospace look for tech feel
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Logout Button
                      IconButton(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
                        tooltip: "Keluar Aplikasi",
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(token: widget.token))),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [_brandRed, Colors.orange], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            boxShadow: [BoxShadow(color: _brandRed.withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 4))]
                          ),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: _brandBlack,
                            child: Text(
                              widget.name.isNotEmpty ? widget.name[0].toUpperCase() : "?",
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Selamat Datang,", style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(
                              widget.name.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: _brandRed, borderRadius: BorderRadius.circular(4)),
                              child: const Text("OFFICE", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
             child: Column(
               children: [
                 Icon(Icons.warning_amber_rounded, color: Colors.orange[300], size: 30),
                 const SizedBox(height: 8),
                 Text("Gagal memuat info", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                 TextButton(
                   onPressed: _refreshData,
                   child: Text("Refresh", style: TextStyle(color: _brandRed)),
                 )
               ],
             ),
          );
        }

        String sisa = snapshot.data?['leave_quota']?.toString() ?? "-";
        String hutang = snapshot.data?['debt_hours']?.toString() ?? "-";
        
        return FutureBuilder<List<dynamic>>(
          future: _attendanceFuture,
          builder: (context, snapAtt) {
            String hadir = snapAtt.hasData ? snapAtt.data!.length.toString() : "-";
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))]
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _statItem("Sisa Cuti", sisa, "Hari", Icons.pie_chart_outline_rounded, Colors.orange),
                    VerticalDivider(color: Colors.grey[200], thickness: 1, width: 20),
                    _statItem("Total Hadir", hadir, "Hari", Icons.check_circle_rounded, _successGreen),
                    VerticalDivider(color: Colors.grey[200], thickness: 1, width: 20),
                    _statItem("Terlambat", hutang, "Menit", Icons.access_time_rounded, _brandRed),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _statItem(String label, String val, String unit, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _darkAsphalt)),
          Text("$label ($unit)", style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMenuButton("ABSEN MASUK", "Clock In", Icons.login_rounded, _successGreen, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(token: widget.token))))),
            const SizedBox(width: 16),
            Expanded(child: _buildMenuButton("ABSEN KELUAR", "Clock Out", Icons.logout_rounded, _brandRed, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(token: widget.token))))),
          ],
        ),
        const SizedBox(height: 16),
        _buildMenuButton("PENGAJUAN CUTI", "Form Izin & Cuti", Icons.event_note_rounded, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveScreen(token: widget.token)))),
      ],
    );
  }

  Widget _buildMenuButton(String title, String subtitle, IconData icon, Color accentColor, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _darkAsphalt)),
                      Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- REUSABLE ERROR WIDGET (NEW) ---
  Widget _buildErrorWidget(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "Terjadi Kesalahan",
              style: TextStyle(fontWeight: FontWeight.bold, color: _darkAsphalt, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("COBA LAGI"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAttendanceList() {
    return FutureBuilder<List<dynamic>>(
      future: _attendanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())));

        // Handle Error Explicitly
        if (snapshot.hasError) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildErrorWidget("Gagal memuat riwayat absen.\nPeriksa koneksi internet Anda.", _refreshData),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverFillRemaining(hasScrollBody: false, child: _emptyIllustration("Belum ada riwayat absen"));
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            var item = snapshot.data![index];
            DateTime date = DateTime.parse(item['created_at']);
            String timeIn = item['clock_in'] != null ? DateFormat('HH:mm').format(DateTime.parse(item['clock_in'])) : "--:--";
            String timeOut = item['clock_out'] != null ? DateFormat('HH:mm').format(DateTime.parse(item['clock_out'])) : "--:--";
            bool isComplete = item['clock_out'] != null;
            
            // Perubahan warna UI absensi mengikuti tema merah
            Color statusColor = isComplete ? _successGreen : _brandRed;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: statusColor, width: 4)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(DateFormat('dd').format(date), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: statusColor)),
                          Text(DateFormat('MMM').format(date).toUpperCase(), style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                           _timeInfo("MASUK", timeIn),
                           _timeInfo("KELUAR", timeOut),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          }, childCount: snapshot.data!.length),
        );
      },
    );
  }

  Widget _timeInfo(String label, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(time, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _darkAsphalt)),
      ],
    );
  }

  Widget _buildSliverLeaveList() {
    return FutureBuilder<List<dynamic>>(
      future: _leaveFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())));

        // Handle Error Explicitly
        if (snapshot.hasError) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildErrorWidget("Gagal memuat riwayat cuti.\nPeriksa koneksi internet Anda.", _refreshData),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverFillRemaining(hasScrollBody: false, child: _emptyIllustration("Belum ada riwayat cuti"));
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            var item = snapshot.data![index];
            String status = item['status'] ?? "Pending";
            Color badgeColor = status == "Approved" ? _successGreen : Colors.orange;
            
            return GestureDetector(
              onTap: () => _showLeaveDetail(item),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: badgeColor, width: 4)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: _brandRed.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(Icons.description_outlined, color: _brandRed, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['type'] ?? "Cuti", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _darkAsphalt)),
                            const SizedBox(height: 4),
                            Text("${item['start_date']}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(status.toUpperCase(), style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }, childCount: snapshot.data!.length),
        );
      },
    );
  }

  Widget _emptyIllustration(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showLeaveDetail(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(25),
          child: ListView(
            controller: controller,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Text("Detail Pengajuan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _darkAsphalt)),
              const SizedBox(height: 20),
              _detailRow(Icons.category_outlined, "Tipe", item['type'] ?? "-"),
              _detailRow(Icons.info_outline, "Status", item['status'] ?? "Pending"),
              const Divider(height: 30),
              _detailRow(Icons.calendar_today_outlined, "Mulai", item['start_date'] ?? "-"),
              _detailRow(Icons.event_outlined, "Selesai", item['end_date'] ?? "-"),
              _detailRow(Icons.note_outlined, "Alasan", item['reason'] ?? "Tidak ada catatan"),
              if (item['attachment_url'] != null) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PdfViewerScreen(url: item['attachment_url'], title: "Lampiran Cuti"))),
                  icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text("LIHAT LAMPIRAN PDF"),
                  style: ElevatedButton.styleFrom(backgroundColor: _brandRed, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(children: [
        Icon(icon, size: 18, color: _brandRed), const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _darkAsphalt))])
      ]),
    );
  }
}

// --- PAINTERS (COPIED FROM MOBILE HOME SCREEN) ---
class AutomotiveHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.6, size.height - 20);
    path.quadraticBezierTo(size.width * 0.85, size.height - 35, size.width, size.height - 10);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class CarbonFiberPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.fill;
    const double spacing = 8.0; const double sizeSquare = 3.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
         if ((x ~/ spacing) % 2 == (y ~/ spacing) % 2) {
            canvas.drawRect(Rect.fromLTWH(x, y, sizeSquare, sizeSquare), paint);
         }
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ChevronPainter extends CustomPainter {
  final Color color;
  ChevronPainter({this.color = Colors.black});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, 0); path.lineTo(size.width / 2, size.height); path.lineTo(size.width, 0); path.lineTo(size.width, size.height * 0.3);
    path.lineTo(size.width / 2, size.height * 1.3); path.lineTo(0, size.height * 0.3); path.close();
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DotGridPainter extends CustomPainter {
  final Color color;
  DotGridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    const double spacing = 15.0; const double dotSize = 2.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        if (x + y > size.width * 0.5) canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight; final double maxHeight; final Widget child;
  _SliverAppBarDelegate({required this.minHeight, required this.maxHeight, required this.child});
  @override double get minExtent => minHeight;
  @override double get maxExtent => maxHeight;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => maxHeight != oldDelegate.maxHeight || minHeight != oldDelegate.minHeight || child != oldDelegate.child;
}