import 'package:flutter/material.dart';

import '../models/game.dart';
import '../theme/app_theme.dart';
import 'price_tag.dart';

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
  return Image.network(
    url,
    fit: fit,
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

/// بطاقة لعبة بأسلوب Epic Games: غلاف حاد الزوايا بنسبة 3:4 مع شارة خصم ومؤثر ضغط.
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
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  buildGameCover(game),
                  if (game.hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: DiscountBadge(percent: game.discountPercent),
                    ),
                ],
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
            const SizedBox(height: 6),
            PriceTag(game: game, fontSize: 13),
          ],
        ),
      ),
    );
  }
}
