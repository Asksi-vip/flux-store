import 'dart:async';

import 'package:flutter/material.dart';

import 'controllers/library_controller.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/download_manager.dart';
import 'services/library_service.dart';
import 'theme/app_theme.dart';

/// نقطة انطلاق تطبيق Flux — متجر ألعاب بأسلوب Epic Games.
/// الدخول مباشرة إلى الصفحة الرئيسية مع تهيئة المصادقة الذاتية (بديل Firebase).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // استعادة جلسة المستخدم (المصادقة الذاتية عبر سيرفر الخاص)
  unawaited(AuthService.instance.init());

  // استعادة التنزيلات المحفوظة واستكمالها تلقائيًا بعد إعادة فتح التطبيق (مثل Epic)
  unawaited(DownloadManager.instance.restore());

  runApp(
    FluxApp(controller: LibraryController(LibraryService())),
  );
}

class FluxApp extends StatelessWidget {
  const FluxApp({super.key, required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flux Games Store',
      debugShowCheckedModeBanner: false,
      theme: buildEpicTheme(),
      // واجهة عربية من اليمين إلى اليسار في كامل التطبيق
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: MainShell(controller: controller),
    );
  }
}
