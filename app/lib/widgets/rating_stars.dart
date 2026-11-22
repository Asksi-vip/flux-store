import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// نجوم التقييم بسماوي Epic مع عرض الرقم بجانبها (اختياري).
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.showValue = false,
  });

  final double rating;
  final double size;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final double clamped = rating.clamp(0, 5).toDouble();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          Icon(
            clamped >= i
                ? Icons.star_rounded
                : (clamped >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_border_rounded),
            size: size,
            color: clamped >= i - 0.5 ? EpicColors.cyan : EpicColors.border,
          ),
        if (showValue) ...[
          const SizedBox(width: 6),
          Text(
            clamped.toStringAsFixed(1),
            style: const TextStyle(
              color: EpicColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
