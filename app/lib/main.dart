import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';

/// نقطة انطلاق تطبيق Flux — متجر الألعاب النيوني.
void main() {
  runApp(const FluxApp());
}

class FluxApp extends StatelessWidget {
  const FluxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flux — متجر الألعاب',
      debugShowCheckedModeBanner: false,
      theme: buildFluxTheme(),
      // واجهة عربية من اليمين إلى اليسار في كامل التطبيق
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const SplashScreen(),
    );
  }
}
