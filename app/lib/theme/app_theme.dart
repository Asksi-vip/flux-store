import 'package:flutter/material.dart';

/// ألوان الهوية البصرية — مستخرجة من تحليل تطبيق Epic Games Store الرسمي
/// (app_background=#17242D، أخضر التثبيت #1D873B، أحمر الخطأ #D93025،
/// برتقالي التخفيضات #FF7043/#FF5722) بأسلوب clean-room لتطبيق Flux.
class EpicColors {
  EpicColors._();

  /// الخلفية الرئيسية — الكحلي الداكن المزرق الحقيقي لخلفية تطبيق Epic
  static const Color background = Color(0xFF17242D);

  /// لون الأسطح: البطاقات والشرائط والأشرطة العلوية (أفتح درجة من الخلفية)
  static const Color surface = Color(0xFF1C2B35);

  /// سطح مرفوع: الحقول والعناصر التفاعلية
  static const Color elevated = Color(0xFF253642);

  /// لون الحدود الرمادية الرقيقة
  static const Color border = Color(0xFF2E404D);

  /// الأزرق الرسمي لأزرار Epic
  static const Color blue = Color(0xFF0074E4);

  /// السماوي للروابط والألعاب المجانية
  static const Color cyan = Color(0xFF26BBFF);

  /// النص الأساسي الأبيض
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// النص الثانوي الرمادي (أسلوب Epic للنصوص الجانبية)
  static const Color textSecondary = Color(0xFFA9B2BA);

  /// لون النص فوق الشارات
  static const Color textOnBadge = Color(0xFFFFFFFF);

  /// برتقالي شارة التخفيض (مستخرج من ألوان Epic)
  static const Color saleOrange = Color(0xFFFF7043);

  /// البرتقالي العميق للخصومات الكبيرة
  static const Color saleDeepOrange = Color(0xFFFF5722);

  /// أخضر النجاح/التثبيت (اللون الأخضر الحقيقي من موارد Epic)
  static const Color success = Color(0xFF1D873B);

  /// أحمر الخطر (اللون الأحمر الحقيقي من موارد Epic)
  static const Color danger = Color(0xFFD93025);
}

/// ثيم التطبيق الكامل بأسلوب Epic Games.
ThemeData buildEpicTheme() {
  final ThemeData base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: EpicColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: EpicColors.blue,
      secondary: EpicColors.cyan,
      surface: EpicColors.surface,
      error: EpicColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: EpicColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: EpicColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
      iconTheme: IconThemeData(color: EpicColors.textPrimary),
    ),
    cardTheme: CardTheme(
      color: EpicColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: EpicColors.border,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: EpicColors.elevated,
      hintStyle: const TextStyle(color: EpicColors.textSecondary, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: EpicColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: EpicColors.blue, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: EpicColors.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: EpicColors.elevated,
      contentTextStyle: const TextStyle(
        color: EpicColors.textPrimary,
        fontSize: 14,
      ),
      actionTextColor: EpicColors.cyan,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: EpicColors.textPrimary,
      displayColor: EpicColors.textPrimary,
    ),
  );
}
