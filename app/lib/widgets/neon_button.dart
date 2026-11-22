import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// زر بثيم Flux: إما متدرج بتوهج نيون أو محدد (Outlined).
class NeonButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final Color glowColor;
  final bool outlined;
  final Color? outlineColor;
  final double height;

  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.gradient,
    this.glowColor = FluxColors.pink,
    this.outlined = false,
    this.outlineColor,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    // وضع المحدد: خلفية داكنة وإطار متوهج
    if (outlined) {
      final edge = outlineColor ?? FluxColors.cyan;
      return Opacity(
        opacity: enabled ? 1 : .5,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: FluxColors.surface.withOpacity(.6),
                border: Border.all(color: edge.withOpacity(.75), width: 1.4),
              ),
              child: Center(child: _buildRow(edge)),
            ),
          ),
        ),
      );
    }

    // الوضع الأساسي: تدرج وردي-بنفسجي بتوهج نيون
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: gradient ?? FluxColors.pinkPurple,
          boxShadow: enabled ? neonGlow(glowColor) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Center(child: _buildRow(FluxColors.textPrimary)),
          ),
        ),
      ),
    );
  }

  /// محتوى الزر: أيقونة + نص.
  Widget _buildRow(Color contentColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: contentColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: contentColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
