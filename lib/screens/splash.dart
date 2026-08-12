import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'unified_login.dart';

/// Splash shown for ~1 second on launch (JubiCare name + official logo),
/// then routes straight to the unified login screen. The role (counsellor /
/// doctor / pharmacist) is determined from the credentials the user enters.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JC.bg,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/jubicare_logo.png', height: 120, fit: BoxFit.contain),
          const SizedBox(height: 18),
          const Text('JubiCare',
              style: TextStyle(color: JC.ink, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 6),
          const Text('Mobile Medical Unit',
              style: TextStyle(color: JC.muted, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 2)),
          const SizedBox(height: 28),
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
        ]),
      ),
    );
  }
}
