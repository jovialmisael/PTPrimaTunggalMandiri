import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart'; // 1. Tambahkan Import ini
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- MULAI SETUP ONESIGNAL ---

  // (Opsional) Hapus baris ini jika aplikasi sudah rilis production agar log tidak penuh
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

  // 2. Inisialisasi OneSignal
  // Ganti string di bawah ini dengan OneSignal App ID Anda
  OneSignal.initialize("c416960e-4878-4fea-a6b1-516d8ae62af1");

  // 3. Minta izin notifikasi kepada pengguna (Wajib untuk Android 13+ & iOS)
  OneSignal.Notifications.requestPermission(true);

  // --- SELESAI SETUP ONESIGNAL ---

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sumber Baru',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashScreen(),
    );
  }
}