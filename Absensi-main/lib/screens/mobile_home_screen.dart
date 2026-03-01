import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_device_info/my_device_info.dart';
import '../services/api_services.dart';
import 'attendance_screen.dart';
import 'leave_screen.dart';
import 'pdf_viewer_screen.dart';
import 'visit_schedule_screen.dart';
import 'profile_screen.dart';
import 'add_store_screen.dart'; 
import 'dart:math' as math; 

class MobileHomeScreen extends StatefulWidget {
  final String token;
  final String name;

  const MobileHomeScreen({super.key, required this.token, required this.name});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  
  // Key untuk mendeteksi posisi scroll header
  final GlobalKey<NestedScrollViewState> _nestedScrollViewKey = GlobalKey<NestedScrollViewState>();

  late Future<List<dynamic>> _attendanceFuture;
  late Future<List<dynamic>> _leaveFuture;
  late Future<Map<String, dynamic>?> _profileFuture;

  late TabController _tabController;

  // --- AUTOMOTIVE THEME COLORS ---
  final Color _brandRed = const Color(0xFFE50000); 
  final Color _brandBlue = const Color(0xFF0044CC); 
  final Color _brandBlack = const Color(0xFF212121);
  final Color _darkAsphalt = const Color(0xFF1E1E1E);
  final Color _silverMetal = const Color(0xFFF5F5F5);
  final Color _carbonGrey = const Color(0xFF37474F);

  // Device Info
  String _platformVersion = 'Unknown';
  String _imeiNo = 'Unknown';
  String _modelName = 'Unknown';
  String _manufacturer = 'Unknown';
  String _deviceName = 'Unknown';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _tabController = TabController(length: 2, vsync: this);

    _loadInitialData();
    _initDeviceState();
  }

  Future<void> _initDeviceState() async {
    var status = await Permission.phone.status;
    if (!status.isGranted) {
      status = await Permission.phone.request();
    }

    if (status.isGranted) {
      try {
        String platformVersion = await MyDeviceInfo.platformVersion;
        String imeiNo = await MyDeviceInfo.deviceIMEINumber;
        String modelName = await MyDeviceInfo.deviceModel;
        String manufacturer = await MyDeviceInfo.deviceManufacturer;
        String deviceName = await MyDeviceInfo.deviceName;

        if (!mounted) return;

        setState(() {
          _platformVersion = platformVersion;
          _imeiNo = imeiNo;
          _modelName = modelName;
          _manufacturer = manufacturer;
          _deviceName = deviceName;
        });
      } on PlatformException {
        if (!mounted) return;
        setState(() {
          _platformVersion = 'Failed';
        });
      }
    }
  }

  void _loadInitialData() {
    _profileFuture = _apiService.getProfile(widget.token);
    _attendanceFuture = _apiService.getHistory(widget.token);
    _leaveFuture = _apiService.getLeaveHistory(widget.token);
  }

  Future<void> _refreshData() async {
    setState(() {
      _loadInitialData();
      _initDeviceState();
    });
    try {
      await Future.wait([_profileFuture, _attendanceFuture, _leaveFuture]);
    } catch (e) {
      debugPrint("Error refreshing data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    // Format tanggal terpisah untuk desain baru
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

          // --- 2. MAIN CONTENT (NESTED SCROLL VIEW) ---
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
                headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
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
                                  _buildInfoCardsSection(),
                                  const SizedBox(height: 25),
                                  
                                  Row(
                                    children: [
                                      Icon(Icons.dashboard_customize_rounded, color: _brandBlue, size: 20),
                                      const SizedBox(width: 10),
                                      Text("AKSES CEPAT", style: TextStyle(fontWeight: FontWeight.w800, color: _darkAsphalt, fontSize: 16, letterSpacing: 0.5)),
                                    ],
                                  ),
                                  const SizedBox(height: 15),

                                  _buildMenuGrid(),
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
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(colors: [_brandBlue, const Color(0xFF003399)]),
                              ),
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.grey[600],
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              tabs: const [Tab(text: "RIWAYAT ABSEN"), Tab(text: "RIWAYAT CUTI")],
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
                    _buildSimpleList(_buildSliverAttendanceList()),
                    _buildSimpleList(_buildSliverLeaveList()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW HEADER DESIGN (BOLD & SPORTY) ---
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
              const Color(0xFF0D1117), // Hampir Hitam
              _brandBlue.withOpacity(0.8),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: CustomPaint(painter: CarbonFiberPainter()),
              ),
            ),
            
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
              left: 30,
              top: 0,
              bottom: 0,
              child: Transform(
                transform: Matrix4.skewX(-0.2),
                child: Container(
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _brandBlue,
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
                              Text(
                                fullDate,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  fontFamily: 'RobotoMono'
                                ),
                              ),
                            ],
                          ),
                        ),
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
                            gradient: LinearGradient(
                              colors: [_brandBlue, Colors.cyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(color: _brandBlue.withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 4))
                            ]
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
                            Text(
                              "Selamat Datang,",
                              style: TextStyle(color: Colors.grey[400], fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 20, 
                                fontWeight: FontWeight.w900, 
                                letterSpacing: 0.5,
                                fontFamily: 'Roboto' 
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                             Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _brandBlue,
                                borderRadius: BorderRadius.circular(4)
                              ),
                              child: const Text("ONLINE", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
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

  Widget _buildInfoCardsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: FutureBuilder<Map<String, dynamic>?>(
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
                     child: Text("Refresh", style: TextStyle(color: _brandBlue)),
                   )
                 ],
               ),
             );
          }

          String sisaCuti = snapshot.data?['leave_quota']?.toString() ?? "-";
          String terlambat = snapshot.data?['debt_hours']?.toString() ?? "-";
          
          return FutureBuilder<List<dynamic>>(
            future: _attendanceFuture,
            builder: (ctx, snapAtt) {
              String hadir = snapAtt.hasData ? snapAtt.data!.length.toString() : "-";
              return Row(
                children: [
                  _buildStatItem("Sisa Cuti", sisaCuti, "Hari", Icons.event_available_rounded, Colors.orange),
                  Container(width: 1, height: 40, color: Colors.grey[200]),
                  _buildStatItem("Total Hadir", hadir, "Hari", Icons.check_circle_rounded, Colors.green),
                  Container(width: 1, height: 40, color: Colors.grey[200]),
                  _buildStatItem("Terlambat", terlambat, "Jam", Icons.timelapse_rounded, _brandBlue),
                ],
              );
            }
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _darkAsphalt)),
          Text("$label ($unit)", style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5, 
      children: [
        _buildMenuButton("ABSENSI", "Masuk/Pulang", Icons.fingerprint, _brandBlue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(token: widget.token, isMobile: true)))), 
        _buildMenuButton("JADWAL", "Kunjungan Toko", Icons.map_outlined, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitScheduleScreen(token: widget.token)))),
        _buildMenuButton("TAMBAH TOKO", "Pelanggan Baru", Icons.storefront_outlined, _brandRed, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddStoreScreen(token: widget.token)))),
        _buildMenuButton("PENGAJUAN", "Cuti & Izin", Icons.assignment_outlined, _carbonGrey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveScreen(token: widget.token)))),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const Spacer(),
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _darkAsphalt)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleList(Widget sliverList) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
         SliverPadding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 30), sliver: sliverList),
      ],
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
                backgroundColor: _brandBlue,
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
          return SliverFillRemaining(hasScrollBody: false, child: _emptyIllustration("Belum ada riwayat kunjungan"));
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            var item = snapshot.data![index];
            DateTime date = DateTime.parse(item['created_at']);
            String timeIn = item['clock_in'] != null ? DateFormat('HH:mm').format(DateTime.parse(item['clock_in'])) : "--:--";

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: _brandBlue, width: 4)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _brandBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(DateFormat('dd').format(date), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _brandBlue)),
                      Text(DateFormat('MMM').format(date).toUpperCase(), style: TextStyle(fontSize: 10, color: _brandBlue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                title: Text("ABSENSI / KUNJUNGAN", style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                subtitle: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 16, color: _darkAsphalt),
                    const SizedBox(width: 4),
                    Text("$timeIn WIB", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _darkAsphalt)),
                  ],
                ),
              ),
            );
          }, childCount: snapshot.data!.length),
        );
      },
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
            Color badgeColor = status == "Approved" ? Colors.green : Colors.orange;
            
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
                        decoration: BoxDecoration(color: _brandBlue.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(Icons.description_outlined, color: _brandBlue, size: 20),
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
              _detailRow(Icons.category, "Tipe", item['type'] ?? "-"),
              _detailRow(Icons.info, "Status", item['status'] ?? "Pending"),
              const Divider(height: 30),
              _detailRow(Icons.calendar_today, "Mulai", item['start_date'] ?? "-"),
              _detailRow(Icons.event, "Selesai", item['end_date'] ?? "-"),
              _detailRow(Icons.notes, "Alasan", item['reason'] ?? "Tidak ada catatan"),
              if (item['attachment_url'] != null) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PdfViewerScreen(url: item['attachment_url'], title: "Lampiran Cuti"))),
                  icon: const Icon(Icons.picture_as_pdf), label: const Text("LIHAT LAMPIRAN PDF"),
                  style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
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
        Icon(icon, size: 18, color: _brandBlue), const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _darkAsphalt))])
      ]),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight; final double maxHeight; final Widget child;
  _SliverAppBarDelegate({required this.minHeight, required this.maxHeight, required this.child});
  @override double get minExtent => minHeight;
  @override double get maxExtent => maxHeight;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => maxHeight != oldDelegate.maxHeight || minHeight != oldDelegate.minHeight || child != oldDelegate.child;
}

// --- PAINTERS (AUTOMOTIVE PATTERNS) ---
class AutomotiveHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 40); // Start bottom left
    // Asymmetric Curve
    path.quadraticBezierTo(
      size.width * 0.25, size.height, 
      size.width * 0.6, size.height - 20
    );
    path.quadraticBezierTo(
      size.width * 0.85, size.height - 35, 
      size.width, size.height - 10
    );
    path.lineTo(size.width, 0); // To Top Right
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class CarbonFiberPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    
    const double spacing = 8.0;
    const double sizeSquare = 3.0;

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