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
    // Durasi animasi dipercepat (1.2 detik)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Fade In: Logo muncul perlahan
    _opacityAnimation = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn) 
    );

    // Scale: Efek zoom-out halus agar terlihat elegan (breathing effect)
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _startCheckSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage("lib/assets/logo-1024x544.png"), context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startCheckSession() async {
    try {
      // Tunggu animasi + proses cek sesi
      final List<dynamic> results = await Future.wait([
        Future.delayed(const Duration(milliseconds: 2000)), // Tahan logo selama 2 detik total
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

  // --- TRANSISI HALUS (FADE) ---
  void _smoothNavigate(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1000), // Transisi 1 detik
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Hanya Fade, agar logo di LoginScreen (Hero) bisa menyambung sempurna
          return FadeTransition(
            opacity: animation,
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
        child: RepaintBoundary(
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              // HANYA LOGO (Tanpa Loading Indicator)
              child: Hero(
                tag: 'app_logo', 
                child: Image.asset(
                  "lib/assets/logo-1024x544.png",
                  width: 280, // Ukuran disesuaikan agar pas
                  gaplessPlayback: true, 
                  errorBuilder: (ctx, err, stack) => const SizedBox(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
