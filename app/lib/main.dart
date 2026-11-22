import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/download_manager.dart';
import 'theme/app_theme.dart';

/// نقطة انطلاق تطبيق Flux — متجر ألعاب بأسلوب Epic Games.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // استعادة التنزيلات المحفوظة واستكمالها تلقائيًا بعد إعادة فتح التطبيق (مثل Epic)
  DownloadManager.instance.restore();
  runApp(const FluxApp());
}

class FluxApp extends StatelessWidget {
  const FluxApp({super.key});

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
      home: const SplashScreen(),
    );
  }
}
