import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/page_fade_transition.dart';
import 'main_shell.dart';

/// شاشة الافتتاح بأسلوب Epic: شعار FLUX متوهج يظهر بحركة سلسة ثم الانتقال للمتجر.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<double> _scale = Tween<double>(begin: 0.85, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    unawaited(_enterApp());
  }

  /// تحميل المكتبة المحفوظة ثم الانتقال إلى المتجر بعد انتهاء العرض الافتتاحي.
  Future<void> _enterApp() async {
    final LibraryController controller = LibraryController(LibraryService());
    await controller.load();
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      epicRoute(MainShell(controller: controller)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EpicColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // الشعار مع توهج أزرق مزدوج (ظلال نص فوق بعضها)
                Text(
                  'FLUX',
                  style: TextStyle(
                    color: EpicColors.textPrimary,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 10,
                    shadows: [
                      Shadow(
                        color: EpicColors.blue.withOpacity(.9),
                        blurRadius: 36,
                      ),
                      Shadow(
                        color: EpicColors.blue.withOpacity(.5),
                        blurRadius: 80,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'GAMES STORE',
                  style: TextStyle(
                    color: EpicColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 140,
                  height: 3,
                  child: const _LoadingLine(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// شريط تحميل متحرك: قطعة زرقاء تنزلق ذهابًا وإيابًا داخل مسار رمادي.
class _LoadingLine extends StatefulWidget {
  const _LoadingLine();

  @override
  State<_LoadingLine> createState() => _LoadingLineState();
}

class _LoadingLineState extends State<_LoadingLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  late final Animation<double> _position = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final double barWidth = constraints.maxWidth * 0.45;
            final double travel = constraints.maxWidth - barWidth;
            return Stack(
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: EpicColors.elevated,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: travel * _position.value,
                  child: Container(
                    width: barWidth,
                    height: 3,
                    decoration: BoxDecoration(
                      color: EpicColors.blue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
