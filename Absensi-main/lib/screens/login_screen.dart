import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_device_info/my_device_info.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'dart:math' as math; // Import math for rotation
import '../services/api_services.dart';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'mobile_home_screen.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  // Controller
  final _nikController = TextEditingController();
  final _passController = TextEditingController();
  final ApiService _apiService = ApiService();

  // Animation Controllers
  late AnimationController _mainController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _lineAnimation;
  late Animation<double> _formFadeAnimation;
  late Animation<Offset> _formSlideAnimation;
  late Animation<double> _bgElementsFade;

  // State
  bool _isLoading = false;
  final ValueNotifier<bool> _obscurePasswordNotifier = ValueNotifier(true);

  // Variable Device Data
  String? _deviceImei;
  String? _onesignalId;
  String _appVersion = "";

  // Colors - Automotive Theme
  final Color _brandRed = const Color(0xFFE50000); // Racing Red
  final Color _brandBlue = const Color(0xFF0044CC); // Mechanic Blue
  final Color _brandBlack = const Color(0xFF212121); // Asphalt
  final Color _brandSilver = const Color(0xFFF5F5F5); // Silver/Metal
  final double _logoWidth = 260.0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initDeviceId();
    _initOneSignalId();
    _getAppVersion();
  }

  Future<void> _getAppVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
      });
    }
  }

  // --- FUNGSI AMBIL DEVICE ID ---
  Future<void> _initDeviceId() async {
    try {
      String? deviceId = await MyDeviceInfo.deviceIMEINumber;
      if (mounted) {
        setState(() => _deviceImei = deviceId);
        print("Device IMEI didapat: $_deviceImei");
      }
    } catch (e) {
      print("Gagal mengambil Device ID: $e");
      if (mounted) setState(() => _deviceImei = "unknown_device");
    }
  }

  // --- FUNGSI AMBIL ONESIGNAL ID ---
  Future<void> _initOneSignalId() async {
    var id = OneSignal.User.pushSubscription.id;
    if (mounted) {
      setState(() => _onesignalId = id);
      print("OneSignal ID Awal: $_onesignalId");
    }
    OneSignal.User.pushSubscription.addObserver((state) {
      if (state.current.id != null) {
        print("OneSignal ID Updated: ${state.current.id}");
        if (mounted) {
          setState(() => _onesignalId = state.current.id);
        }
      }
    });
  }

  void _setupAnimations() {
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1500), // Durasi dikurangi agar lebih responsif
      vsync: this,
    );

    // 1. Logo: Hero akan menangani transisi, jadi kita biarkan statis (Scale 1.0, Opacity 1.0)
    // atau animasi sangat halus jika Hero tidak bekerja sempurna.
    _logoScaleAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutQuart),
      ),
    );
    _logoOpacityAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // 2. Garis Bergerak (0.2 - 0.6) - Lebih cepat
    _lineAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic),
    );

    // 3. Form Input Muncul (0.4 - 1.0) - Muncul setelah logo settle
    _formFadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutQuart),
    );
    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08), 
      end: Offset.zero,
    ).animate(_formFadeAnimation);

    // 4. Background Elemen
    _bgElementsFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mainController.forward();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _nikController.dispose();
    _passController.dispose();
    _obscurePasswordNotifier.dispose();
    super.dispose();
  }

  void _navigateBasedOnRole(String token, String name, bool isMobile) {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        isMobile ? MobileHomeScreen(token: token, name: name) : HomeScreen(token: token, name: name),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var curve = Curves.easeInOutCubic; 
          var tween = Tween(begin: const Offset(0.0, 0.05), end: Offset.zero).chain(CurveTween(curve: curve)); 

          return FadeTransition( 
            opacity: animation,
            child: SlideTransition(position: animation.drive(tween), child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 1000), // Durasi navigasi standar
      ),
    );
  }

  Future<void> _handleLogin() async {
    final nik = _nikController.text.trim();
    final pass = _passController.text.trim();

    if (nik.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("NIK dan Password harus diisi"), backgroundColor: Colors.red),
      );
      return;
    }

    String finalImei = _deviceImei ?? "unknown_device";
    String finalOneSignalId = _onesignalId ?? OneSignal.User.pushSubscription.id ?? "";

    setState(() => _isLoading = true);

    try {
      LoginResponse res = await _apiService.login(nik, pass, finalImei, finalOneSignalId);

      if (res.success && res.accessToken != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', res.accessToken!);
        await prefs.setString('name', res.name ?? "User");
        await prefs.setString('nik', nik);
        await prefs.setString('device_imei', finalImei);

        if (res.isOldPass) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ResetPasswordScreen(token: res.accessToken!)),
          );
          return;
        }

        var profileData = await _apiService.getProfile(res.accessToken!);

        if (!mounted) return;
        setState(() => _isLoading = false);

        bool isMobile = false;
        String userName = res.name ?? "User";

        if (profileData != null) {
          final position = profileData['position'];
          if (position != null && position['is_mobile'] == true) {
            isMobile = true;
          }
          if (profileData['name'] != null) {
            userName = profileData['name'];
          }
        }

        _navigateBasedOnRole(res.accessToken!, userName, isMobile);

      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Terjadi kesalahan: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, 
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // --- AUTOMOTIVE BACKGROUND (STATIC LAYER) ---
          RepaintBoundary(
            child: FadeTransition(
              opacity: _bgElementsFade,
              child: Stack(
                children: [
                  // 1. Faint Tire Tracks (Left Side Vertical)
                  Positioned(
                    left: 20,
                    top: 0,
                    bottom: 0,
                    child: _buildVerticalTireTrack(),
                  ),

                  // 2. Bottom Wave Shape (Fondasi Bawah)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 200,
                    child: CustomPaint(
                      painter: BottomWavePainter(color: _brandBlue.withOpacity(0.05)),
                    ),
                  ),

                  // 3. Bottom Tech Grid (Pola Grill/Mesh di kanan bawah)
                  Positioned(
                    bottom: 20,
                    right: 0,
                    width: 150,
                    height: 100,
                    child: Opacity(
                      opacity: 0.1,
                      child: CustomPaint(
                        painter: DotGridPainter(color: _brandBlack),
                      ),
                    ),
                  ),

                  // 4. Horizontal Tire Track (Bottom Center)
                  Positioned(
                    bottom: 10,
                    left: 50,
                    right: 50,
                    child: Opacity(
                      opacity: 0.03,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(10, (index) => 
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 20, height: 6,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(2)
                            ),
                          )
                        ),
                      ),
                    ),
                  ),

                  // 5. Dynamic Racing Curves (Top Right)
                  Positioned(
                    top: -100,
                    right: -80,
                    child: Transform.rotate(
                      angle: -0.2, // Tilted speed look
                      child: Opacity(
                        opacity: 0.1,
                        child: Container(
                          width: 300,
                          height: 500,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(150),
                            gradient: LinearGradient(
                              colors: [_brandRed, _brandBlue],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 6. Speed Lines (Accent Stripes)
                  Positioned(
                    top: 60,
                    right: 0,
                    child: _buildSpeedStripe(_brandRed, width: 120),
                  ),
                  Positioned(
                    top: 80,
                    right: 0,
                    child: _buildSpeedStripe(_brandBlue, width: 80),
                  ),

                  // 7. Floating Elements (Scattered Circles/Nuts)
                  Positioned(
                    top: 150, left: 60,
                    child: _buildDot(12, _brandBlue.withOpacity(0.4)),
                  ),
                  Positioned(
                    top: 180, left: 40,
                    child: _buildDot(6, _brandRed.withOpacity(0.3)),
                  ),
                  Positioned(
                    bottom: 120, right: 50,
                    child: _buildDot(20, _brandBlack.withOpacity(0.05)),
                  ),
                  Positioned(
                    bottom: 80, left: 80, // Tambahan di bawah
                    child: _buildDot(15, _brandRed.withOpacity(0.08)),
                  ),
                  Positioned(
                    bottom: 160, right: 80,
                    child: _buildDot(8, _brandRed.withOpacity(0.4)),
                  ),
                ],
              ),
            ),
          ),

          // --- CONTENT (ANIMATED LAYER) ---
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      // --- LOGO IMAGE ---
                      FadeTransition(
                        opacity: _logoOpacityAnimation,
                        child: ScaleTransition(
                          scale: _logoScaleAnimation,
                          child: Hero(
                            tag: 'app_logo',
                            child: Image.asset(
                              "lib/assets/logo-1024x544.png",
                              height: 100,
                              width: 250,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.image_not_supported, size: 100, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // --- ANIMATED LINE (GRADIENT) ---
                      RepaintBoundary(
                        child: Center(
                          child: SizedBox(
                            width: _logoWidth,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AnimatedBuilder(
                                animation: _lineAnimation,
                                builder: (context, child) {
                                  return Container(
                                    height: 4,
                                    width: _logoWidth * _lineAnimation.value,
                                    decoration: BoxDecoration(
                                      // Gradient from Red to Blue
                                      gradient: LinearGradient(
                                        colors: [_brandRed, _brandBlue],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // --- FORM CONTENT ---
                      FadeTransition(
                        opacity: _formFadeAnimation,
                        child: SlideTransition(
                          position: _formSlideAnimation,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                "ABSENSI",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: _brandBlack,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Masukan Data Diri",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 40),

                              // INPUT NIK (Red Icon)
                              _buildTextField(
                                controller: _nikController,
                                label: "Nomor Induk Karyawan (NIK)",
                                icon: Icons.badge_outlined,
                                iconColor: _brandRed,
                                isPassword: false,
                              ),
                              const SizedBox(height: 20),

                              // INPUT PASSWORD (Blue Icon)
                              ValueListenableBuilder<bool>(
                                valueListenable: _obscurePasswordNotifier,
                                builder: (context, isObscure, child) {
                                  return _buildTextField(
                                    controller: _passController,
                                    label: "Kata Sandi",
                                    icon: Icons.lock_outline,
                                    iconColor: _brandBlue, // Blue lock icon
                                    isPassword: true,
                                    isObscure: isObscure,
                                    onToggleVisibility: () {
                                      _obscurePasswordNotifier.value = !isObscure;
                                    },
                                  );
                                },
                              ),

                              const SizedBox(height: 32),

                              // TOMBOL LOGIN (Gradient)
                              Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_brandRed, _brandBlue],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _brandBlue.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                      : const Text(
                                    "MASUK",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),
                              Center(
                                child: Text(
                                  "Versi $_appVersion",
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- BACKGROUND HELPER WIDGETS ---

  Widget _buildVerticalTireTrack() {
    return Opacity(
      opacity: 0.05,
      child: Column(
        children: List.generate(20, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            width: 40,
            height: 8,
            child: CustomPaint(
              painter: ChevronPainter(),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSpeedStripe(Color color, {required double width}) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(-5, 5),
          )
        ],
      ),
    );
  }

  Widget _buildDot(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isPassword,
    bool isObscure = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? isObscure : false,
        keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.text,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 14),
          floatingLabelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          prefixIcon: Icon(icon, color: iconColor),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              isObscure ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey[400],
            ),
            onPressed: onToggleVisibility,
          )
              : null,
          border: OutlineInputBorder(
             borderRadius: BorderRadius.circular(16),
             borderSide: BorderSide(color: iconColor.withOpacity(0.3), width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(16),
             borderSide: BorderSide(color: iconColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(16),
             borderSide: BorderSide(color: iconColor, width: 2.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        ),
      ),
    );
  }
}

// Custom Painter for Tire Marks (Chevron)
class ChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.3);
    path.lineTo(size.width / 2, size.height * 1.3); // Sharp point
    path.lineTo(0, size.height * 0.3);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter for Bottom Wave
class BottomWavePainter extends CustomPainter {
  final Color color;
  BottomWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.6);
    
    // Wave Curve
    path.cubicTo(
      size.width * 0.3, size.height * 0.3, // Control Point 1
      size.width * 0.7, size.height * 0.9, // Control Point 2
      size.width, size.height * 0.5        // End Point
    );
    
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter for Dot Grid (Tech Pattern)
class DotGridPainter extends CustomPainter {
  final Color color;
  DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    const double spacing = 15.0;
    const double dotSize = 2.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Draw diagonal pattern cutoff
        if (x + y > size.width * 0.5) {
           canvas.drawCircle(Offset(x, y), dotSize, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}