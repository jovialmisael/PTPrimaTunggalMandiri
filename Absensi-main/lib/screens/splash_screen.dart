import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// Import Service & Screens
import '../services/api_services.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'mobile_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Durasi animasi logo (2 detik cukup, jangan terlalu lama agar tidak membosankan)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Fade In: Menggunakan easeInOut agar masuk dan keluarnya halus
    _opacityAnimation = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInOut) 
    );

    // Scale halus: 0.95 ke 1.0 (Zoom in pelan)
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
    _startCheckSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // PRECACHE IMAGE: Mencegah lag saat pertama kali render gambar
    precacheImage(const AssetImage("lib/assets/logo-1024x544.png"), context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startCheckSession() async {
    try {
      // Jalankan logika paralel
      final List<dynamic> results = await Future.wait([
        Future.delayed(const Duration(milliseconds: 2200)), // Sedikit buffer setelah animasi selesai
        _getSessionData(),
      ]);

      final sessionData = results[1] as Map<String, dynamic>?;

      if (!mounted) return;

      if (sessionData != null && sessionData['valid'] == true) {
        bool isMobile = sessionData['isMobile'];
        String token = sessionData['token'];
        String name = sessionData['name'];

        Widget nextPage = isMobile
            ? MobileHomeScreen(token: token, name: name)
            : HomeScreen(token: token, name: name);
        
        _smoothNavigate(nextPage);
      } else {
        _smoothNavigate(const LoginScreen());
      }
    } catch (e) {
      print("Error Splash: $e");
      if (mounted) _smoothNavigate(const LoginScreen());
    }
  }

  // --- TRANSISI HALUS ---
  void _smoothNavigate(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        // Durasi transisi halaman (1.2 detik = Smooth tanpa terasa draggy)
        transitionDuration: const Duration(milliseconds: 1200),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Fade Transition sederhana adalah yang paling ringan untuk GPU
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation, 
              curve: Curves.easeInOut, // Kurva standard yang paling mulus
            ),
            child: child,
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>?> _getSessionData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw "Timeout Prefs",
      );

      String? token = prefs.getString('token');
      if (token == null || token.isEmpty) return null;

      final profileData = await _apiService.getProfile(token).timeout(
          const Duration(seconds: 5),
          onTimeout: () => null
      );

      if (profileData != null) {
        bool isMobile = false;
        if (profileData['position'] != null && profileData['position']['is_mobile'] == true) {
          isMobile = true;
        }
        String name = profileData['name'] ?? "User";
        await prefs.setString('name', name);

        return {
          'valid': true,
          'token': token,
          'name': name,
          'isMobile': isMobile,
        };
      }
    } catch (e) {
      print("Session Check Error: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        // RepaintBoundary: KUNCI AGAR ANIMASI RINGAN (Cache GPU)
        child: RepaintBoundary(
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    "lib/assets/logo-1024x544.png",
                    width: 250,
                    // Pastikan gaplessPlayback true agar tidak kedip saat reload
                    gaplessPlayback: true, 
                    errorBuilder: (ctx, err, stack) => const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  // Loading Indicator Ringan
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Color(0xFFE50000), strokeWidth: 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
