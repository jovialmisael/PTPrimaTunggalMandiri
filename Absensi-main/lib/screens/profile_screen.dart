import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_services.dart';
import 'login_screen.dart';
import 'dart:math' as math;

class ProfileScreen extends StatefulWidget {
  final String token;

  const ProfileScreen({super.key, required this.token});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late Future<Map<String, dynamic>?> _profileFuture;

  // Colors - Automotive Theme (Balanced)
  final Color _brandRed = const Color(0xFFE50000);
  final Color _brandBlue = const Color(0xFF0044CC);
  final Color _darkAsphalt = const Color(0xFF1E1E1E); // Header Dark
  final Color _silverMetal = const Color(0xFFF5F5F5); // Body Light
  final Color _chromeWhite = const Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _profileFuture = _apiService.getProfile(widget.token);
    });
    try {
      await _profileFuture;
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  // --- EDIT DATA DIALOG ---
  void _showEditDialog(String title, String fieldName, String currentValue) {
    TextEditingController controller = TextEditingController(text: currentValue == "-" ? "" : currentValue);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("Ubah $title", style: TextStyle(fontWeight: FontWeight.bold, color: _darkAsphalt)),
          content: TextField(
            controller: controller,
            keyboardType: title == "Telepon" ? TextInputType.phone : TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: "Masukkan $title baru",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _brandRed, width: 2),
              ),
              filled: true,
              fillColor: _chromeWhite,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _saveData(fieldName, controller.text);
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveData(String field, String value) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menyimpan data...")));

    bool success = await _apiService.updateProfile(widget.token, field, value);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil disimpan"), backgroundColor: Colors.green));
      _refreshData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menyimpan data."), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _silverMetal,
      body: Stack(
        children: [
          // 1. BACKGROUND LAYERS
          Column(
            children: [
              // HEADER IMAGE & GRADIENT
              Container(
                height: 320, // Tall header for image
                width: double.infinity,
                color: _darkAsphalt,
                child: Stack(
                  children: [
                    // Background Image
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.6,
                        child: Image.asset(
                          'lib/assets/Gemini_Generated_Image_7461ma7461ma7461.png',
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Image.asset('lib/assets/spooring-berkala.jpg', fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: _darkAsphalt)),
                        ),
                      ),
                    ),
                    // Gradient Overlay (To make text pop)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.8),
                              _silverMetal, // Blend into body
                            ],
                            stops: const [0.0, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Carbon Fiber Texture Overlay (Subtle)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.1,
                        child: CustomPaint(painter: CarbonFiberPainter()),
                      ),
                    ),
                  ],
                ),
              ),
              // BODY TEXTURE (Tire Tracks)
              Expanded(
                child: Container(
                  color: _silverMetal,
                  child: Stack(
                    children: [
                      // Modern Speed Shape (Subtle Geometric) instead of Tire Tracks
                      Positioned(
                        top: 0, right: 0,
                        child: CustomPaint(
                          size: const Size(200, 300),
                          painter: SpeedShapePainter(color: Colors.black.withOpacity(0.03)),
                        ),
                      ),
                      // Watermark Logo Bottom Left
                      Positioned(
                        bottom: -30, left: -40,
                        child: Opacity(
                          opacity: 0.05,
                          child: Image.asset('lib/assets/logo-1024x544.png', width: 300),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. SCROLLABLE CONTENT
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      const Text("PROFIL PENGEMUDI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
                    ],
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshData,
                    color: _brandRed,
                    child: FutureBuilder<Map<String, dynamic>?>(
                      future: _profileFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                          return Center(child: CircularProgressIndicator(color: _brandRed));
                        }
                        
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                          return _buildErrorState();
                        }

                        var data = snapshot.data!;
                        String name = data['name'] ?? "User";
                        String role = data['position'] != null ? data['position']['name'] : "Staff";
                        String nik = data['nik'] ?? "-";
                        String email = data['email'] ?? "-";
                        String phone = data['phone'] ?? "-";

                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              const SizedBox(height: 10),
                              // --- PROFILE CARD (FLOATING) ---
                              Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  // Card Background
                                  Container(
                                    margin: const EdgeInsets.only(top: 50),
                                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(name.toUpperCase(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _darkAsphalt), textAlign: TextAlign.center),
                                        const SizedBox(height: 5),
                                        Text(role, style: TextStyle(fontSize: 14, color: _brandRed, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(color: _silverMetal, borderRadius: BorderRadius.circular(8)),
                                          child: Text("NIK: $nik", style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Avatar (Overlapping)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white, // Border putih
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                                    ),
                                    child: CircleAvatar(
                                      radius: 45,
                                      backgroundColor: _darkAsphalt,
                                      child: Text(
                                        name.isNotEmpty ? name[0] : "?",
                                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 25),

                              // --- STATS ROW ---
                              Row(
                                children: [
                                  _buildStatCard("Sisa Cuti", data['leave_quota']?.toString() ?? "0", "Hari", Colors.orange),
                                  const SizedBox(width: 15),
                                  _buildStatCard("Terlambat", data['debt_hours']?.toString() ?? "0", "Jam", _brandRed),
                                ],
                              ),

                              const SizedBox(height: 25),

                              // --- CONTACT INFO ---
                              _buildSectionHeader("KONTAK PRIBADI", Icons.person_pin_circle_outlined),
                              _buildInfoTile(Icons.email_outlined, "Email", email, isEditable: true, onTap: () => _showEditDialog("Email", "email", email)),
                              _buildInfoTile(Icons.phone_iphone_rounded, "Telepon", phone, isEditable: true, onTap: () => _showEditDialog("Telepon", "phone", phone)),

                              const SizedBox(height: 20),

                              // --- COMPANY INFO ---
                              _buildSectionHeader("DATA PERUSAHAAN", Icons.domain_rounded),
                              _buildInfoTile(Icons.store_mall_directory_outlined, "Cabang", data['branch'] != null ? data['branch']['name'] : "-"),
                              _buildInfoTile(Icons.map_outlined, "Homebase", data['homebase'] != null ? data['homebase']['name'] : "-"),
                              _buildInfoTile(Icons.calendar_today_rounded, "Bergabung", data['join_date'] ?? "-"),

                              const SizedBox(height: 35),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _brandRed),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _darkAsphalt, letterSpacing: 0.8)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
          border: Border(left: BorderSide(color: color, width: 5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _darkAsphalt)),
            const SizedBox(height: 4),
            Text("$label ($unit)", style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value, {bool isEditable = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _silverMetal, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: _darkAsphalt.withOpacity(0.7), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(color: _darkAsphalt, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
            if (isEditable)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _brandRed.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.edit, size: 16, color: _brandRed),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, color: _brandRed, size: 50),
          const SizedBox(height: 10),
          Text("Gagal memuat profil", style: const TextStyle(color: Colors.grey)),
          TextButton(
            onPressed: _refreshData,
            child: Text("Coba Lagi", style: TextStyle(color: _brandRed)),
          )
        ],
      ),
    );
  }
}

// --- NEW MODERN PAINTERS ---

class SpeedShapePainter extends CustomPainter {
  final Color color;
  SpeedShapePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Abstract geometric shape (Modern Speed Design)
    final path = Path();
    path.moveTo(size.width, 0);
    path.lineTo(size.width * 0.2, 0);
    path.lineTo(size.width, size.height * 0.6);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CarbonFiberPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    const double sizeSquare = 4.0;
    const double spacing = 8.0;

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
