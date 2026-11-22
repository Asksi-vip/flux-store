import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// نمط زر Epic: أساسي أزرق، ثانوي محدد بحدود، أو نجاح أخضر.
enum EpicButtonVariant { primary, secondary, success }

/// زر CTA الرسمي بأسلوب Epic Games مع مؤثر ضغط (تصغير خفيف عند اللمس).
class EpicButton extends StatefulWidget {
  const EpicButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = EpicButtonVariant.primary,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final EpicButtonVariant variant;
  final bool expanded;

  @override
  State<EpicButton> createState() => _EpicButtonState();
}

class _EpicButtonState extends State<EpicButton> {
  bool _pressed = false;

  Color get _background {
    switch (widget.variant) {
      case EpicButtonVariant.primary:
        return EpicColors.blue;
      case EpicButtonVariant.secondary:
        return Colors.transparent;
      case EpicButtonVariant.success:
        return Colors.transparent;
    }
  }

  Color get _foreground {
    switch (widget.variant) {
      case EpicButtonVariant.primary:
        return EpicColors.textOnBadge;
      case EpicButtonVariant.secondary:
        return EpicColors.textPrimary;
      case EpicButtonVariant.success:
        return EpicColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onPressed!();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 46,
            width: widget.expanded ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: widget.variant == EpicButtonVariant.primary
                    ? Colors.transparent
                    : EpicColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18, color: _foreground),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
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
