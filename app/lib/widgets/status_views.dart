import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// شاشة الحالة: جارٍ التحميل.
class LoadingView extends StatelessWidget {
  final String? message;

  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: FluxColors.pink, strokeWidth: 3),
          const SizedBox(height: 14),
          Text(
            message ?? 'جارٍ التحميل...',
            style: const TextStyle(color: FluxColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// شاشة الحالة: خطأ شبكة/خادم مع زر إعادة المحاولة.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FluxColors.surface,
                border: Border.all(color: FluxColors.pink.withOpacity(.5)),
                boxShadow: neonGlow(FluxColors.pink, blur: 22),
              ),
              child: const Icon(Icons.wifi_off_rounded, color: FluxColors.pink, size: 36),
            ),
            const SizedBox(height: 18),
            const Text(
              'تعذر تحميل البيانات',
              style: TextStyle(
                color: FluxColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FluxColors.textMuted, fontSize: 13, height: 1.7),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('إعادة المحاولة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FluxColors.cyan,
                  side: BorderSide(color: FluxColors.cyan.withOpacity(.7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// شاشة الحالة: لا يوجد محتوى (نتائج فارغة، مكتبة فارغة...).
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FluxColors.surface,
                border: Border.all(color: FluxColors.cyan.withOpacity(.5)),
                boxShadow: neonGlow(FluxColors.cyan, blur: 22),
              ),
              child: Icon(icon, color: FluxColors.cyan, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: FluxColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: FluxColors.textMuted, fontSize: 13, height: 1.7),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
