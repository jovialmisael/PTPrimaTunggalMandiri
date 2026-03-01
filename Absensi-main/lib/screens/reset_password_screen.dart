import 'package:flutter/material.dart';
import '../services/api_services.dart';
import 'home_screen.dart';
import 'mobile_home_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;
  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> with SingleTickerProviderStateMixin {
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Animation Controller
  late AnimationController _mainController;
  late Animation<double> _formFadeAnimation;
  late Animation<Offset> _formSlideAnimation;

  // Colors - Automotive Theme (Same as Login)
  final Color _brandRed = const Color(0xFFE50000); 
  final Color _brandBlue = const Color(0xFF0044CC); 
  final Color _brandBlack = const Color(0xFF212121);
  final Color _silverMetal = const Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _formFadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );
    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(_formFadeAnimation);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mainController.forward();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _submitChangePassword() async {
    if (_currentPassController.text.isEmpty ||
        _newPassController.text.isEmpty ||
        _confirmPassController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Semua kolom harus diisi"), backgroundColor: Colors.red),
      );
      return;
    }

    if (_newPassController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password baru dan konfirmasi tidak sama"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool success = await _apiService.changePassword(
      widget.token,
      _currentPassController.text,
      _newPassController.text,
      _confirmPassController.text,
    );

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password berhasil diperbarui!"), backgroundColor: Colors.green),
      );

      var profileData = await _apiService.getProfile(widget.token);
      if (!mounted) return;
      
      setState(() => _isLoading = false);

      bool isMobile = false;
      String userName = profileData?['name'] ?? "User";

      if (profileData != null &&
          profileData['position'] != null &&
          profileData['position']['is_mobile'] == true) {
        isMobile = true;
      }

      if (!mounted) return;

      if (isMobile) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MobileHomeScreen(token: widget.token, name: userName)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(token: widget.token, name: userName)),
        );
      }

    } else {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal memperbarui password. Cek password lama Anda."), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // --- BACKGROUND ELEMENTS (MATCHING LOGIN SCREEN) ---
          Positioned(
            left: 20, top: 0, bottom: 0,
            child: Opacity(
              opacity: 0.05,
              child: Column(
                children: List.generate(20, (index) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  width: 40, height: 8,
                  child: CustomPaint(painter: ChevronPainter()),
                )),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0, height: 200,
            child: CustomPaint(painter: BottomWavePainter(color: _brandBlue.withOpacity(0.05))),
          ),
          Positioned(
            top: -120, right: -100,
            child: Transform.rotate(
              angle: -0.2,
              child: Opacity(
                opacity: 0.1,
                child: Container(
                  width: 350, height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [_brandRed, _brandBlue], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  ),
                ),
              ),
            ),
          ),

          // --- CONTENT ---
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: FadeTransition(
                    opacity: _formFadeAnimation,
                    child: SlideTransition(
                      position: _formSlideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header Icon
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [BoxShadow(color: _brandRed.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))]
                            ),
                            child: Icon(Icons.lock_reset_rounded, size: 60, color: _brandRed),
                          ),
                          const SizedBox(height: 25),
                          
                          // Title
                          Text(
                            "RESET PASSWORD",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              color: _brandBlack,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Demi keamanan, silakan ganti password lama Anda dengan yang baru.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 40),

                          _buildPasswordField(
                            controller: _currentPassController,
                            label: "Password Lama",
                            isObscure: _obscureCurrent,
                            iconColor: Colors.grey,
                            onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                          ),
                          const SizedBox(height: 20),

                          _buildPasswordField(
                            controller: _newPassController,
                            label: "Password Baru",
                            isObscure: _obscureNew,
                            iconColor: _brandBlue,
                            onToggle: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                          const SizedBox(height: 20),

                          _buildPasswordField(
                            controller: _confirmPassController,
                            label: "Konfirmasi Password",
                            isObscure: _obscureConfirm,
                            iconColor: _brandBlue,
                            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          const SizedBox(height: 40),

                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [_brandRed, _brandBlue]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: _brandBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _isLoading ? null : _submitChangePassword,
                              child: _isLoading
                                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text("SIMPAN PASSWORD BARU", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isObscure,
    required Color iconColor,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
          prefixIcon: Icon(Icons.lock_outline, color: iconColor),
          suffixIcon: IconButton(
            icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey[400]),
            onPressed: onToggle,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: iconColor.withOpacity(0.3))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: iconColor, width: 1.5)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }
}

// --- PAINTERS (COPIED FROM LOGIN SCREEN) ---
class ChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, 0); path.lineTo(size.width / 2, size.height); path.lineTo(size.width, 0); path.lineTo(size.width, size.height * 0.3);
    path.lineTo(size.width / 2, size.height * 1.3); path.lineTo(0, size.height * 0.3); path.close();
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BottomWavePainter extends CustomPainter {
  final Color color;
  BottomWavePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height); path.lineTo(0, size.height * 0.6);
    path.cubicTo(size.width * 0.3, size.height * 0.3, size.width * 0.7, size.height * 0.9, size.width, size.height * 0.5);
    path.lineTo(size.width, size.height); path.close();
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
