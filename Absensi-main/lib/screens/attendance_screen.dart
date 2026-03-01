import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_services.dart';

class AttendanceScreen extends StatefulWidget {
  final String token;
  final bool isMobile;

  const AttendanceScreen({
    super.key,
    required this.token,
    this.isMobile = false,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  File? _image;
  bool _isLoading = false;
  String _statusMessage = "Siap"; // Pesan status dinamis
  final ApiService _apiService = ApiService();

  // --- AUTOMOTIVE THEME COLORS (MATCHING LOGIN SCREEN) ---
  final Color _brandRed = const Color(0xFFE50000); 
  final Color _brandBlue = const Color(0xFF0044CC); 
  final Color _brandBlack = const Color(0xFF212121);
  final Color _darkAsphalt = const Color(0xFF1E1E1E);

  // --- LOGIC 1: PERMISSION & GPS HANDLER ---
  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackbar("GPS mati. Mohon nyalakan GPS/Lokasi Anda.");
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackbar("Izin lokasi ditolak.");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await _showPermissionDialog();
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      _showErrorSnackbar("Sinyal GPS lemah. Coba pindah ke area terbuka.");
      return null;
    }
  }

  Future<void> _showPermissionDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Izin Lokasi Dibutuhkan'),
          content: const Text('Mohon buka pengaturan dan izinkan akses lokasi.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Buka Settings'),
              onPressed: () {
                Geolocator.openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // --- LOGIC 2: PROSES ABSEN ---
  Future<void> _doAbsen() async {
    // START LOADING: MENDETEKSI LOKASI
    setState(() {
      _isLoading = true;
      _statusMessage = "Mendeteksi Lokasi...";
    });

    try {
      // 1. Cari Lokasi
      Position? pos = await _determinePosition();

      if (pos == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Persiapan Kamera
      setState(() => _statusMessage = "Menyiapkan Kamera...");
      await Future.delayed(const Duration(milliseconds: 500)); // Delay dikit biar transisi halus

      final XFile? photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 40,
        maxWidth: 600,
      );

      if (photo != null) {
        _image = File(photo.path);

        // 3. Mengirim Data (Status Upload)
        setState(() => _statusMessage = "Mengupload Data...");

        // Memanggil API
        Map<String, dynamic> result = await _apiService.postAttendance(
            widget.token,
            pos.latitude,
            pos.longitude,
            _image!
        );

        bool isSuccess = result['success'];
        String message = result['message'];

        if (!mounted) return;

        if (isSuccess) {
          // 4. Sukses
          setState(() => _statusMessage = "Berhasil!");
          await Future.delayed(const Duration(milliseconds: 1000)); // Tahan sebentar biar user liat "Berhasil"

          if(!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), backgroundColor: Colors.green)
          );
          Navigator.pop(context); // Kembali ke Home
        } else {
          // Gagal dari API
          _showErrorSnackbar(message);
          setState(() => _isLoading = false);
        }
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = "Absen Dibatalkan";
        });
      }
    } catch (e) {
      _showErrorSnackbar("Gagal: $e");
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: _brandRed)
    );
  }

  // --- BUILDER: TAMPILAN LOADING KEREN ---
  Widget _buildLoadingScreen() {
    // Tentukan Icon berdasarkan pesan status
    IconData statusIcon = Icons.hourglass_top;
    Color iconColor = _brandRed;

    if (_statusMessage.contains("Lokasi")) {
      statusIcon = Icons.location_searching;
      iconColor = Colors.orange;
    } else if (_statusMessage.contains("Kamera")) {
      statusIcon = Icons.camera_alt;
      iconColor = _brandBlack;
    } else if (_statusMessage.contains("Mengupload")) {
      statusIcon = Icons.cloud_upload;
      iconColor = _brandRed;
    } else if (_statusMessage.contains("Berhasil")) {
      statusIcon = Icons.check_circle;
      iconColor = Colors.green;
    }

    return Container(
      color: Colors.white, // Background putih bersih menutup layar belakang
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Card Melayang
          Container(
            padding: const EdgeInsets.all(30),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              children: [
                // Icon Animasi
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    statusIcon,
                    key: ValueKey<String>(_statusMessage),
                    size: 60,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 30),

                // Text Status
                Text(
                  "Mohon Tunggu",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _brandBlack
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 30),

                // Progress Bar
                LinearProgressIndicator(
                  backgroundColor: Colors.grey[100],
                  color: iconColor,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String infoText = widget.isMobile
        ? "Mode Lapangan: Lokasi Anda akan dicatat saat mengambil foto."
        : "Pastikan Anda berada di lokasi kantor sebelum absen.";

    return Scaffold(
      backgroundColor: Colors.white, // Clean White Background
      appBar: AppBar(
        title: const Text("Absensi", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: _brandBlack,
        elevation: 0,
        centerTitle: true,
      ),
      // MENGGUNAKAN STACK AGAR LOADING MUNCUL DI ATAS KONTEN
      body: Stack(
        children: [
          // --- BACKGROUND ELEMENTS (OFFICE & SALES THEME) ---
          
          // 1. Location Grid Pattern (Top Left & Center) - Represents Sales/Field Area
          Positioned(
            left: 0, top: 0, right: 0, height: 400,
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(painter: LocationGridPainter(color: _brandBlue)),
            ),
          ),

          // 2. City Skyline Abstract (Bottom) - Represents Office/Headquarters
          Positioned(
            bottom: 0, left: 0, right: 0, height: 150,
            child: CustomPaint(painter: CitySilhouettePainter(color: _brandRed.withOpacity(0.05))),
          ),

          // 3. Connectivity Lines (Top Right Gradient) - Represents Network/Data
          Positioned(
            top: -120, right: -100,
            child: Opacity(
              opacity: 0.08,
              child: Container(
                width: 350, height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_brandRed, Colors.white],
                    center: Alignment.center,
                    radius: 0.8,
                  ),
                ),
              ),
            ),
          ),

          // --- KONTEN UTAMA ---
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon Container dengan Efek Radar/Focus
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 140, height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _brandRed.withOpacity(0.1), width: 1),
                        ),
                      ),
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _brandRed.withOpacity(0.3), width: 1),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: _brandRed.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]
                        ),
                        child: Icon(
                            widget.isMobile ? Icons.map_outlined : Icons.domain_rounded, // Icon Kantor vs Lapangan
                            size: 60,
                            color: _brandRed
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    "Siap untuk Absen?",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _brandBlack, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    infoText,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
                  ),
                  const SizedBox(height: 50),
                  
                  // Tombol Aksi
                  Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_brandRed, _brandBlue]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: _brandBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                         _doAbsen();
                      },
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text("AMBIL FOTO SEKARANG", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. OVERLAY LOADING (Hanya muncul jika _isLoading = true)
          if (_isLoading)
            _buildLoadingScreen(),
        ],
      ),
    );
  }
}

// --- NEW PAINTERS (OFFICE & SALES THEME) ---

// Menggambar pola titik-titik grid (Representasi Peta/Area Sales)
class LocationGridPainter extends CustomPainter {
  final Color color;
  LocationGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    const double spacing = 30.0;
    const double dotSize = 2.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Buat variasi agar tidak terlalu kaku
        if ((x + y) % (spacing * 2) == 0) {
           canvas.drawCircle(Offset(x, y), dotSize, paint);
           
           // Gambar garis koneksi tipis sesekali
           if (x % (spacing * 3) == 0 && y < size.height - spacing) {
             final linePaint = Paint()..color = color.withOpacity(0.5)..strokeWidth = 0.5;
             canvas.drawLine(Offset(x, y), Offset(x, y + 10), linePaint); // Garis vertikal kecil
           }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Menggambar siluet gedung abstrak (Representasi Office)
class CitySilhouettePainter extends CustomPainter {
  final Color color;
  CitySilhouettePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    
    // Building 1
    path.lineTo(0, size.height * 0.7);
    path.lineTo(size.width * 0.1, size.height * 0.7);
    path.lineTo(size.width * 0.1, size.height * 0.5); // Tinggi
    path.lineTo(size.width * 0.25, size.height * 0.5);
    path.lineTo(size.width * 0.25, size.height * 0.8);
    
    // Building 2
    path.lineTo(size.width * 0.3, size.height * 0.8);
    path.lineTo(size.width * 0.3, size.height * 0.6);
    path.lineTo(size.width * 0.45, size.height * 0.55); // Slanted roof
    path.lineTo(size.width * 0.5, size.height * 0.85);

    // Building 3 (Wide)
    path.lineTo(size.width * 0.6, size.height * 0.85);
    path.lineTo(size.width * 0.6, size.height * 0.4);
    path.lineTo(size.width * 0.8, size.height * 0.4);
    path.lineTo(size.width * 0.8, size.height * 0.75);

    // Building 4
    path.lineTo(size.width * 0.85, size.height * 0.75);
    path.lineTo(size.width * 0.85, size.height * 0.6);
    path.lineTo(size.width, size.height * 0.6);
    path.lineTo(size.width, size.height);

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
