import 'package:flutter/material.dart';

import '../models/game.dart';
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

/// شارة "مجاني" السماوية للألعاب ذات السعر الصفري.
class FreeBadge extends StatelessWidget {
  const FreeBadge({super.key, this.fontSize = 12});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: EpicColors.cyan.withOpacity(.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: EpicColors.cyan),
      ),
      child: Text(
        'مجاني',
        style: TextStyle(
          color: EpicColors.cyan,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// صف السعر بأسلوب Epic: شارة الخصم + السعر الأصلي مشطوب + السعر النهائي.
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
    if (game.isFree) {
      return FreeBadge(fontSize: fontSize);
    }
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
