import 'package:flutter/material.dart';

/// انتقال صفحات بأسلوب Epic: تلاشٍ سريع مع ارتفاع خفيف وتكبير من 0.94 —
/// حركة سلسة متسارعة ثم مزاحمة (decelerate) تعطي إحساس العمق دون بطء.
Route<T> epicRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // الحركة: تسارع عند الرجوع، وتباطؤ أنيق عند الدخول
      final CurvedAnimation curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      // التلاشٍ يكتمل مبكرًا حتى تظهر الصفحة سريعًا ثم تكمل حركتها
      final CurvedAnimation fadeCurve = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: fadeCurve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
