import 'package:flutter/material.dart';

/// JubiCare digital identity (original prototype palette):
/// navy "JUBI" + sky-blue "CARE", with teal / yellow / blue accent dots.
class JC {
  // Brand
  static const navy = Color(0xFF16357A); // deep blue ("JUBI")
  static const blue = Color(0xFF1E5BB8); // header / primary action
  static const sky = Color(0xFF34B6E4); // light blue ("CARE")
  static const teal = Color(0xFF2BB673); // green accent dot
  static const yellow = Color(0xFFFBB615); // yellow accent dot
  static const coral = Color(0xFFEF6B6B); // alerts / offline

  // Neutrals
  static const bg = Color(0xFFF4F7FB);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1F2A44);
  static const muted = Color(0xFF6B7A99);
  static const line = Color(0xFFE6ECF5);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, blue],
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: navy.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static BorderRadius get radius => BorderRadius.circular(16);
}

ThemeData buildJubiCareTheme() {
  final base = ThemeData(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: JC.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: JC.blue,
      primary: JC.blue,
      secondary: JC.sky,
      surface: JC.card,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: JC.line),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: JC.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: JC.blue, width: 1.6),
      ),
      hintStyle: const TextStyle(color: JC.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: JC.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
