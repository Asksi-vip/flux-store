import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'epic_button.dart';
import 'skeleton.dart';

/// شبكة هياكل تحميل (Skeleton) لمحاكاة شكل شبكة البطاقات أثناء الجلب.
class LoadingGrid extends StatelessWidget {
  const LoadingGrid({
    super.key,
    this.columns = 2,
    this.itemCount = 4,
    this.padding = EdgeInsets.zero,
  });

  final int columns;
  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 20,
          childAspectRatio: 0.55,
        ),
        itemBuilder: (context, int i) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(child: SkeletonBox(height: double.infinity, radius: 4)),
            SizedBox(height: 10),
            SkeletonBox(height: 12, radius: 3),
            SizedBox(height: 6),
            SkeletonBox(height: 10, radius: 3, width: 80),
          ],
        ),
      ),
    );
  }
}

/// شاشة الخطأ بأسلوب Epic: أيقونة داخل حلقة + رسالة + زر إعادة المحاولة.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: EpicColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: EpicColors.border),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: EpicColors.textSecondary,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'فشل الاتصال بالإنترنت',
              style: TextStyle(
                color: EpicColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: EpicButton(
                label: 'إعادة المحاولة',
                variant: EpicButtonVariant.secondary,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شاشة الحالة الفارغة بأسلوب Epic مع دعوة لاتخاذ إجراء.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: EpicColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: EpicColors.border),
              ),
              child: Icon(icon, color: EpicColors.textSecondary, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: EpicColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: EpicColors.textSecondary,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: EpicButton(
                  label: actionLabel!,
                  icon: Icons.storefront_rounded,
                  onPressed: onAction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
