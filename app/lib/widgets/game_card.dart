import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/wishlist_controller.dart';
import '../models/game.dart';
import '../theme/app_theme.dart';
import 'price_tag.dart';

/// صورة شبكية تظهر بتلاشٍ ناعم بعد اكتمال التحميل (سلاسة Epic)
/// مع مؤشر تحميل أزرق وبديل أنيق عند الفشل.
class FadeInNetworkImage extends StatelessWidget {
  const FadeInNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
  });

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          child: child,
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: EpicColors.elevated,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: EpicColors.blue,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: EpicColors.elevated,
        alignment: Alignment.center,
        child: const Icon(
          Icons.videogame_asset_outlined,
          color: EpicColors.border,
          size: 34,
        ),
      ),
    );
  }
}

/// صورة غلاف اللعبة مع بديل أنيق عند غياب الرابط أو فشل التحميل.
/// (دالة عامة لأن الكاروسيل والمكتبة وصفحة التفاصيل كلها تستخدمها)
Widget buildGameCover(Game game, {BoxFit fit = BoxFit.cover}) {
  final String url = game.image.isNotEmpty ? game.image : game.banner;
  if (url.isEmpty) {
    return Container(
      color: EpicColors.elevated,
      alignment: Alignment.center,
      child: const Icon(
        Icons.sports_esports_outlined,
        color: EpicColors.border,
        size: 34,
      ),
    );
  }
  return FadeInNetworkImage(url: url, fit: fit);
}

/// بطاقة لعبة بأسلوب تطبيق Epic للجوال: غلاف بحواف دائرية وإطار رقيق + حبة سعر/تثبيت.
class GameCard extends StatefulWidget {
  const GameCard({super.key, required this.game, this.onTap});

  final Game game;
  final VoidCallback? onTap;

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Game game = widget.game;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // الغلاف بحواف دائرية وإطار مثل بطاقات Epic
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: EpicColors.border),
                  color: EpicColors.surface,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    buildGameCover(game),
                    if (game.hasDiscount)
                      PositionedDirectional(
                        top: 8,
                        start: 8,
                        child: DiscountBadge(percent: game.discountPercent),
                      ),
                    // زر قلب المفضلة بأسلوب Epic: قلب صغير فوق الغلاف
                    PositionedDirectional(
                      top: 6,
                      end: 6,
                      child: _WishHeart(game: game),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              game.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: EpicColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              game.categoryDisplay,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: EpicColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            GamePricePill(
              game: game,
              onOpenGame: widget.onTap,
              fontSize: 13,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// زر قلب المفضلة فوق غلاف البطاقة: قلب شفاف على دائرة داكنة، يتحول لقلب
/// مملوء سماوي عند الحفظ — بنمط بطاقات متجر Epic.
class _WishHeart extends StatelessWidget {
  const _WishHeart({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WishlistController.instance,
      builder: (context, _) {
        final bool saved = WishlistController.instance.contains(game.id);
        return GestureDetector(
          onTap: () async {
            HapticFeedback.selectionClick();
            final bool added =
                await WishlistController.instance.toggle(game);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    added
                        ? 'أُضيفت "${game.name}" إلى قائمة المفضلة'
                        : 'أُزيلت "${game.name}" من قائمة المفضلة',
                  ),
                ),
              );
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.45),
              border: Border.all(
                color: saved
                    ? EpicColors.cyan.withOpacity(0.9)
                    : Colors.white.withOpacity(0.35),
                width: 1,
              ),
            ),
            child: Icon(
              saved ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
              size: 15,
              color: saved ? EpicColors.cyan : Colors.white,
            ),
          ),
        );
      },
    );
  }
}
