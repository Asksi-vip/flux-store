import 'package:flutter/material.dart';

import '../models/game.dart';
import '../theme/app_theme.dart';

/// بطاقة لعبة تُعرض في شبكة الألعاب (صورة + اسم + تصنيف + تقييم + سعر).
class GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;

  const GameCard({super.key, required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // إطار متدرج متوهج حول البطاقة
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: FluxColors.pinkPurple,
          boxShadow: neonGlow(FluxColors.purple, blur: 14),
        ),
        padding: const EdgeInsets.all(1.4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            color: FluxColors.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // صورة الغلاف
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                  child: game.image.isNotEmpty
                      ? Image.network(
                          game.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imageFallback(),
                          loadingBuilder: (context, child, progress) =>
                              progress == null ? child : _imageFallback(),
                        )
                      : _imageFallback(),
                ),
              ),
              // معلومات اللعبة
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FluxColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.categoryDisplay,
                      style: const TextStyle(color: FluxColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: FluxColors.orange, size: 16),
                        const SizedBox(width: 3),
                        Text(
                          game.rating.toStringAsFixed(1),
                          style: const TextStyle(color: FluxColors.textMuted, fontSize: 11),
                        ),
                        const Spacer(),
                        _priceWidget(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// عرض السعر: مجاني / سعر نهائي / سعر قديم مشطوب + سعر الخصم.
  Widget _priceWidget() {
    if (game.isFree) {
      return const Text(
        'مجاني',
        style: TextStyle(
          color: FluxColors.cyan,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (game.hasDiscount) ...[
          Text(
            game.priceLabel,
            style: const TextStyle(
              color: FluxColors.textMuted,
              fontSize: 10,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          game.finalPriceLabel,
          style: const TextStyle(
            color: FluxColors.pink,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// بديل الصورة عند عدم توفرها.
  Widget _imageFallback() {
    return Container(
      color: FluxColors.surface,
      child: const Center(
        child: Icon(Icons.sports_esports_rounded, size: 44, color: FluxColors.purple),
      ),
    );
  }
}
