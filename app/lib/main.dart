import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'controllers/library_controller.dart';
import 'firebase_options.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/download_manager.dart';
import 'services/library_service.dart';
import 'theme/app_theme.dart';

/// نقطة انطلاق تطبيق Flux — متجر ألعاب بأسلوب Epic Games.
/// الدخول مباشرة إلى الصفحة الرئيسية مع تهيئة Firebase والمصادقة.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase لمصادقة رقم الهاتف و OTP
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }

  // استعادة جلسة المستخدم
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
      title: 'Flux — متجر الألعاب',
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
