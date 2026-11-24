import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../models/game.dart';
import '../theme/app_theme.dart';
import '../widgets/game_card.dart';
import '../widgets/page_fade_transition.dart';
import '../widgets/price_tag.dart';
import '../widgets/status_views.dart';

/// شاشة قائمة المفضلة (Wishlist) بأسلوب Epic:
/// صف أفقي لكل لعبة (غلاف عمودي مصغر + الاسم + الفئة + السعر مع شارة الخصم)
/// مع إزالة عبر السحب أو الزر وزر تراجع، مثل صفوف المكتبة.
class WishlistScreen extends StatelessWidget {
  const WishlistScreen({
    super.key,
    required this.libraryController,
    required this.onBrowse,
  });

  final LibraryController libraryController;
  final VoidCallback onBrowse;

  void _openGame(BuildContext context, Game game) {
    Navigator.of(context).push(
      epicRoute(
        GameDetailsScreen(game: game, controller: libraryController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WishlistController wishlist = WishlistController.instance;
    return ListenableBuilder(
      listenable: wishlist,
      builder: (context, _) {
        final List<Game> games = wishlist.games;
        if (games.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 110),
              EmptyView(
                icon: Icons.favorite_outline_rounded,
                title: 'قائمة المفضلة فارغة',
                message:
                    'اضغط على القلب في أي لعبة لتحفظها هنا وتتابع سعرها وخصوماتها',
                actionLabel: 'تصفح المتجر',
                onAction: onBrowse,
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'قائمة المفضلة',
              style: TextStyle(
                color: EpicColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${games.length} لعبة محفوظة — تابع أسعارها وخصوماتها من هنا',
              style: const TextStyle(
                color: EpicColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < games.length; i++)
              FadeInSlide(
                delay: Duration(milliseconds: 40 * (i % 8)),
                child: _WishRow(
                  game: games[i],
                  onOpen: () => _openGame(context, games[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// صف لعبة مفضلة: غلاف + بيانات + سعر + قلب مملوء لإزالتها.
class _WishRow extends StatelessWidget {
  const _WishRow({required this.game, required this.onOpen});

  final Game game;
  final VoidCallback onOpen;

  void _remove(BuildContext context) {
    WishlistController.instance.remove(game.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('تمت الإزالة من قائمة المفضلة'),
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () => WishlistController.instance.add(game),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey<int>(game.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _remove(context),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: EpicColors.danger.withOpacity(.18),
          border: Border.all(color: EpicColors.danger.withOpacity(.5)),
        ),
        child: const Icon(
          Icons.heart_broken_rounded,
          color: EpicColors.danger,
          size: 24,
        ),
      ),
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: EpicColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: EpicColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  width: 64,
                  height: 84,
                  child: buildGameCover(game),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: EpicColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.categoryDisplay,
                      style: const TextStyle(
                        color: EpicColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (game.hasDiscount) ...[
                          DiscountBadge(
                            percent: game.discountPercent,
                            fontSize: 10,
                          ),
                          const SizedBox(width: 8),
                        ],
                        PriceTag(game: game, fontSize: 12.5, showBadge: false),
                      ],
                    ),
                  ],
                ),
              ),
              // القلب المملوء: الضغط عليه يزيل اللعبة من المفضلة
              IconButton(
                onPressed: () => _remove(context),
                icon: const Icon(
                  Icons.favorite_rounded,
                  color: EpicColors.cyan,
                  size: 22,
                ),
                tooltip: 'إزالة من المفضلة',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
