import 'package:flutter/material.dart';

/// ألوان هوية Flux المستوحاة من أجواء GTA 6 / Vice City.
class FluxColors {
  static const Color background = Color(0xFF0D0B1E);
  static const Color surface = Color(0xFF181233);
  static const Color card = Color(0xFF1C1538);
  static const Color pink = Color(0xFFFF2D78);
  static const Color purple = Color(0xFF8B2FF7);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color orange = Color(0xFFFF7A18);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFA99FD6);

  /// التدرج الأساسي (وردي ← بنفسجي) للأزرار والعناوين
  static const LinearGradient pinkPurple = LinearGradient(
    colors: [pink, purple],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  /// تدرج سماوي للعناصر الثانوية
  static const LinearGradient cyanGlow = LinearGradient(
    colors: [cyan, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// توهج نيون حول العناصر (بطاقات، أزرار، شعارات).
List<BoxShadow> neonGlow(Color color, {double blur = 18}) => [
      BoxShadow(
        color: color.withOpacity(.45),
        blurRadius: blur,
        spreadRadius: 1,
        offset: const Offset(0, 4),
      ),
    ];

/// بناء ثيم التطبيق الداكن بألوان Flux.
ThemeData buildFluxTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: FluxColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: FluxColors.pink,
      secondary: FluxColors.cyan,
      surface: FluxColors.surface,
      onSurface: FluxColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: FluxColors.textPrimary,
      titleTextStyle: TextStyle(
        color: FluxColors.textPrimary,
        fontSize: 19,
        fontWeight: FontWeight.bold,
        letterSpacing: .3,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FluxColors.surface,
      hintStyle: const TextStyle(color: FluxColors.textMuted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: FluxColors.purple.withOpacity(.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: FluxColors.pink, width: 1.4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: FluxColors.surface,
      contentTextStyle: const TextStyle(color: FluxColors.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: FluxColors.pink.withOpacity(.5)),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: FluxColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: FluxColors.pink.withOpacity(.4)),
      ),
      titleTextStyle: const TextStyle(
        color: FluxColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: const TextStyle(
        color: FluxColors.textMuted,
        fontSize: 14,
        height: 1.7,
      ),
    ),
  );
}
