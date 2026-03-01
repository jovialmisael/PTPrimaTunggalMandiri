import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_services.dart';

class VisitDetailScreen extends StatefulWidget {
  final Map<String, dynamic> visitData;
  final String token;

  const VisitDetailScreen({super.key, required this.visitData, required this.token});

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  final ApiService _apiService = ApiService();

  // --- AUTOMOTIVE THEME COLORS (SALES BLUE) ---
  final Color _brandBlue = const Color(0xFF0044CC);
  final Color _brandCyan = const Color(0xFF00BCD4);
  final Color _brandBlack = const Color(0xFF212121);
  final Color _darkAsphalt = const Color(0xFF1E1E1E);
  final Color _silverMetal = const Color(0xFFF5F5F5);
  final Color _successGreen = const Color(0xFF2E7D32);
  final Color _brandRed = const Color(0xFFE50000); // For end visit button

  bool _isLoadingCheckIn = false;
  bool _isLoadingCheckOut = false;
  bool _hasCheckedIn = false;
  bool _hasCheckedOut = false;

  @override
  void initState() {
    super.initState();
    String status = widget.visitData['status'] ?? "Pending";

    if (status == "In Progress" || status == "in_progress") {
      _hasCheckedIn = true;
    } else if (status == "Completed" || status == "Done" || status == "completed") {
      _hasCheckedIn = true;
      _hasCheckedOut = true;
    }
  }

  // --- 1. GET GPS ---
  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _showSnack('GPS tidak aktif. Mohon aktifkan GPS.', Colors.orange);
      return null;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // --- 2. AMBIL FOTO KAMERA ---
  Future<File?> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (photo != null) return File(photo.path);
    return null;
  }

  // --- 3. DIALOG INPUT CATATAN ---
  Future<String?> _showNoteDialog(String title, String hint) async {
    TextEditingController noteController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: TextStyle(color: _brandBlack, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: noteController,
            style: TextStyle(color: _brandBlack),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              child: Text("BATAL", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)), 
              onPressed: () => Navigator.pop(context)
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text("SIMPAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
              onPressed: () => Navigator.pop(context, noteController.text)
            ),
          ],
        );
      },
    );
  }

  // --- 4. PROSES CLOCK IN ---
  Future<void> _handleCheckIn() async {
    File? photo = await _takePhoto();
    if (photo == null) return;

    setState(() => _isLoadingCheckIn = true);

    try {
      Position? position = await _determinePosition();
      if (position != null) {
        var res = await _apiService.clockInVisit(
            widget.token,
            widget.visitData['id'].toString(),
            position.latitude.toString(),
            position.longitude.toString(),
            photo
        );

        if (res['success'] == true) {
          setState(() => _hasCheckedIn = true);
          if (mounted) _showSnack("Check-In Berhasil! Selamat bekerja.", _successGreen);
        } else {
          if (mounted) _showSnack(res['message'] ?? "Gagal Check-In", _brandRed);
        }
      }
    } catch (e) {
      if (mounted) _showSnack("Error: $e", _brandRed);
    } finally {
      if (mounted) setState(() => _isLoadingCheckIn = false);
    }
  }

  // --- 5. PROSES CLOCK OUT ---
  Future<void> _handleCheckOut() async {
    File? photo = await _takePhoto();
    if (photo == null) return;

    String? resultNote = await _showNoteDialog("Laporan Kunjungan", "Tulis hasil kunjungan, misal: Toko order 50 karton...");
    if (resultNote == null || resultNote.isEmpty) {
      if (mounted) _showSnack("Hasil kunjungan wajib diisi!", Colors.orange);
      return;
    }

    setState(() => _isLoadingCheckOut = true);

    try {
      Position? position = await _determinePosition();
      if (position != null) {
        var res = await _apiService.clockOutVisit(
            widget.token,
            widget.visitData['id'].toString(),
            position.latitude.toString(),
            position.longitude.toString(),
            photo,
            resultNote
        );

        if (res['success'] == true) {
          setState(() => _hasCheckedOut = true);
          if (mounted) {
            _showSnack("Kunjungan Selesai! Terima kasih.", _successGreen);
            Navigator.pop(context); 
          }
        } else {
          if (mounted) _showSnack(res['message'] ?? "Gagal Check-Out", _brandRed);
        }
      }
    } catch (e) {
      if (mounted) _showSnack("Error: $e", _brandRed);
    } finally {
      if (mounted) setState(() => _isLoadingCheckOut = false);
    }
  }

  // --- 6. NAVIGASI GOOGLE MAPS ---
  Future<void> _openGoogleMaps(String? lat, String? lng) async {
    if (lat == null || lng == null) {
      _showSnack("Koordinat lokasi tidak tersedia", Colors.orange);
      return;
    }
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) _showSnack("Tidak dapat membuka Google Maps", _brandRed);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _silverMetal,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_brandBlue, Colors.blueAccent.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text("DETAIL KUNJUNGAN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
        leading: const BackButton(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background Decoration
          Positioned(
            top: -50, right: -50,
            child: Opacity(
              opacity: 0.05,
              child: Icon(Icons.location_on_outlined, size: 300, color: _brandBlue),
            ),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. INFO CARD ---
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Container(
                         padding: const EdgeInsets.all(20),
                         decoration: BoxDecoration(
                           gradient: LinearGradient(colors: [_brandBlue.withOpacity(0.1), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                           borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                         ),
                         child: Row(
                           children: [
                             Container(
                               padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _brandBlue.withOpacity(0.1), blurRadius: 8)]),
                               child: Icon(Icons.storefront_rounded, color: _brandBlue, size: 28),
                             ),
                             const SizedBox(width: 15),
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                     widget.visitData['customer_name'] ?? "Tanpa Nama", 
                                     style: TextStyle(color: _brandBlack, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                                   ),
                                   const SizedBox(height: 4),
                                   Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                     decoration: BoxDecoration(color: _brandBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                     child: Text(
                                       "Jadwal: ${widget.visitData['time'] ?? '--:--'} WIB", 
                                       style: TextStyle(color: _brandBlue, fontSize: 12, fontWeight: FontWeight.bold)
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                           ],
                         ),
                       ),
                       Padding(
                         padding: const EdgeInsets.all(20),
                         child: Column(
                           children: [
                            _detailRow(Icons.location_on_outlined, "Alamat Lengkap", widget.visitData['address'] ?? "-"),
                            const Divider(height: 24),
                            _detailRow(Icons.person_pin_circle_outlined, "Kontak (PIC)", widget.visitData['contact'] ?? "-"),
                            const Divider(height: 24),
                            _detailRow(Icons.sticky_note_2_outlined, "Catatan Kunjungan", widget.visitData['notes'] ?? "-"),
                           ],
                         ),
                       )
                    ],
                  ),
                ),
                
                const SizedBox(height: 25),

                // --- 2. NAVIGASI MAPS ---
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _brandBlue,
                      elevation: 2,
                      shadowColor: _brandBlue.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _brandBlue, width: 1.5)),
                    ),
                    onPressed: () => _openGoogleMaps(widget.visitData['latitude']?.toString(), widget.visitData['longitude']?.toString()),
                    icon: const Icon(Icons.map_rounded),
                    label: const Text("NAVIGASI KE LOKASI (MAPS)", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(height: 25),

                // --- 3. ACTION BUTTONS (GRID) ---
                Row(
                  children: [
                    // CLOCK IN BUTTON
                    Expanded(
                      child: _buildActionButton(
                        label: _hasCheckedIn ? "SEDANG VISIT" : "MULAI VISIT",
                        icon: Icons.login_rounded,
                        color: _hasCheckedIn ? Colors.grey : _successGreen,
                        isLoading: _isLoadingCheckIn,
                        onPressed: (_isLoadingCheckIn || _hasCheckedIn) ? null : _handleCheckIn,
                      ),
                    ),
                    const SizedBox(width: 15),
                    // CLOCK OUT BUTTON
                    Expanded(
                       child: _buildActionButton(
                        label: _hasCheckedOut ? "SELESAI" : "AKHIRI VISIT",
                        icon: Icons.check_circle_outline_rounded,
                        color: (_hasCheckedOut || !_hasCheckedIn) ? Colors.grey : _brandRed,
                        isLoading: _isLoadingCheckOut,
                        onPressed: (_isLoadingCheckOut || _hasCheckedOut || !_hasCheckedIn) ? null : _handleCheckOut,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required bool isLoading, VoidCallback? onPressed}) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: onPressed == null ? 0 : 4,
          shadowColor: color.withOpacity(0.4),
        ),
        onPressed: onPressed,
        child: isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                ],
              ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[400], size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)), 
          const SizedBox(height: 4), 
          Text(value, style: TextStyle(color: _brandBlack, fontSize: 14, fontWeight: FontWeight.w600, height: 1.3))
        ])),
      ],
    );
  }
}
