import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'main_shell.dart';

/// شاشة البداية: شعار Flux متوهج ثم الانتقال تلقائيًا إلى الرئيسية.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // ظهور تدريجي للشعار
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _visible = true);
    });
    // الانتقال إلى الشاشة الرئيسية بعد ثانيتين ونصف
    Timer(const Duration(seconds: 2, milliseconds: 500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // خلفية بتدرج دائري بنفسجي داكن
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            radius: 1.2,
            colors: [Color(0xFF2A1650), FluxColors.background],
          ),
        ),
        child: Center(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // بطاقة الشعار المتوهجة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: FluxColors.surface.withOpacity(.6),
                    border: Border.all(color: FluxColors.pink.withOpacity(.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: FluxColors.pink.withOpacity(.5),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        FluxColors.pinkPurple.createShader(bounds),
                    child: const Text(
                      'FLUX',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: FluxColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'متجرك للألعاب الأسطورية 🎮',
                  style: TextStyle(color: FluxColors.textMuted, fontSize: 15),
                ),
                const SizedBox(height: 36),
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: FluxColors.cyan,
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
