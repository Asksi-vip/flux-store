import 'package:flutter/material.dart';

/// ألوان الهوية البصرية المستوحاة من متجر Epic Games Store.
class EpicColors {
  EpicColors._();

  /// الخلفية الرئيسية الداكنة (#101014 — لون Epic الأساسي)
  static const Color background = Color(0xFF101014);

  /// لون الأسطح: البطاقات والشرائط والأشرطة العلوية
  static const Color surface = Color(0xFF18181C);

  /// سطح مرفوع: الحقول والعناصر التفاعلية
  static const Color elevated = Color(0xFF202024);

  /// لون الحدود الرمادية الرقيقة
  static const Color border = Color(0xFF2A2A2A);

  /// الأزرق الرسمي لأزرار Epic
  static const Color blue = Color(0xFF0074E4);

  /// السماوي للروابط والألعاب المجانية
  static const Color cyan = Color(0xFF26BBFF);

  /// النص الأساسي الأبيض
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// النص الثانوي الرمادي (أسلوب Epic للنصوص الجانبية)
  static const Color textSecondary = Color(0xFFB8B8C1);

  /// لون النص فوق الشارات
  static const Color textOnBadge = Color(0xFFFFFFFF);

  /// أخضر النجاح (عنصر موجود في المكتبة / الخادم متصل)
  static const Color success = Color(0xFF2FBF71);

  /// أحمر الخطر (حذف من المكتبة / الخادم متوقف)
  static const Color danger = Color(0xFFE0455A);
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
      backgroundColor: EpicColors.surface,
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
