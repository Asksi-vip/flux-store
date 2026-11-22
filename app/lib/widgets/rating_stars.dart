import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// عرض التقييم بالنجوم (نجوم كاملة ونصفية حسب القيمة).
class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final Color? color;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? FluxColors.orange;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = rating >= i + 1;
        final half = !filled && rating > i + .2;
        return Icon(
          filled
              ? Icons.star_rounded
              : half
                  ? Icons.star_half_rounded
                  : Icons.star_border_rounded,
          color: filled || half
              ? starColor
              : FluxColors.textMuted.withOpacity(.35),
          size: size,
        );
      }),
    );
  }
}
