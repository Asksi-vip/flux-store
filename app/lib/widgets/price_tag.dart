import 'package:flutter/material.dart';

import '../models/game.dart';
import '../services/download_manager.dart';
import '../theme/app_theme.dart';

/// شارة الخصم الزرقاء المربعة بأسلوب Epic: ‎-40%
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.percent, this.fontSize = 12});

  final int percent;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: const BoxDecoration(color: EpicColors.blue),
      child: Text(
        '-$percent%',
        style: TextStyle(
          color: EpicColors.textOnBadge,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// حبة السعر بأسلوب تطبيق Epic للجوال:
/// - لعبة مجانية → زر "تثبيت" سماوي داخل حبة رمادية (بدون كلمة مجاني)
/// - لعبة مدفوعة → السعر بالدولار داخل حبة رمادية بحواف دائرية
class GamePricePill extends StatelessWidget {
  const GamePricePill({
    super.key,
    required this.game,
    this.onOpenGame,
    this.fontSize = 13,
    this.compact = false,
  });

  final Game game;

  /// تُستدعى عند لمس الزر وهي لعبة غير قابلة للتحميل (فتح التفاصيل مثلًا)
  final VoidCallback? onOpenGame;

  final double fontSize;

  /// وضع مضغوط داخل البطاقات الصغيرة
  final bool compact;

  Future<void> _handleTap(BuildContext context) async {
    // لعبة مكتملة التحميل → نافذة تثبيت أندرويد مثل Epic، وبعد التثبيت → تشغيل مباشر
    final DownloadTask? task = DownloadManager.instance.taskFor(game.id);
    if (task != null && task.state == DownloadTaskState.completed) {
      if (task.installed) {
        await DownloadManager.instance.launchGame(task.package);
        return;
      }
      final bool ok = await DownloadManager.instance.openInstaller(game.id);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'APK file not found — download again from the details page',
              ),
            ),
          );
      }
      return;
    }
    if (game.isDownloadable) {
      DownloadManager.instance.start(game);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
              content: Text('Downloading ${game.name} — continues even offline')),
        );
      return;
    }
    onOpenGame?.call();
  }

  @override
  Widget build(BuildContext context) {
    final DownloadTask? taskNow = DownloadManager.instance.taskFor(game.id);
    final Widget child = game.isFree
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                taskNow?.installed == true
                    ? Icons.play_arrow_rounded
                    : Icons.download_rounded,
                color: EpicColors.cyan,
                size: fontSize + 4,
              ),
              const SizedBox(width: 5),
              Text(
                taskNow?.installed == true ? 'Open' : 'Install',
                style: TextStyle(
                  color: EpicColors.cyan,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          )
        : Text(
            game.finalPriceLabel,
            style: TextStyle(
              color: EpicColors.cyan,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          );

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 6 : 9,
        ),
        decoration: BoxDecoration(
          color: EpicColors.elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EpicColors.border),
        ),
        child: child,
      ),
    );
  }
}

/// صف السعر بأسلوب Epic (للألعاب المدفوعة): شارة الخصم + السعر الأصلي مشطوب + النهائي.
class PriceTag extends StatelessWidget {
  const PriceTag({
    super.key,
    required this.game,
    this.fontSize = 14,
    this.showBadge = true,
  });

  final Game game;
  final double fontSize;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    if (game.hasDiscount && showBadge) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DiscountBadge(percent: game.discountPercent, fontSize: fontSize - 1),
          const SizedBox(width: 8),
          Text(
            game.priceLabel,
            style: TextStyle(
              color: EpicColors.textSecondary,
              fontSize: fontSize - 2,
              decoration: TextDecoration.lineThrough,
              decorationColor: EpicColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            game.finalPriceLabel,
            style: TextStyle(
              color: EpicColors.textPrimary,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }
    return Text(
      game.finalPriceLabel,
      style: TextStyle(
        color: EpicColors.textPrimary,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
