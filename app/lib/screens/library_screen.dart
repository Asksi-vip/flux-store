import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/game.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_in_slide.dart';
import '../widgets/game_card.dart';
import '../widgets/page_fade_transition.dart';
import '../widgets/price_tag.dart';
import '../widgets/status_views.dart';
import 'game_details_screen.dart';

/// مكتبة اللاعب بأسلوب Epic: صفوف أنيقة مع سحب للحذف وزر تراجع.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    required this.controller,
    required this.onBrowse,
  });

  final LibraryController controller;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final List<Game> games = controller.games;
        if (games.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 110),
              EmptyView(
                icon: Icons.video_library_outlined,
                title: 'مكتبتك فارغة',
                message: 'أضف ألعابك المفضلة من المتجر لتظهر هنا وتُحفظ على جهازك',
                actionLabel: 'تصفح المتجر',
                onAction: onBrowse,
              ),
            ],
          );
        }
        final double totalValue =
            games.fold<double>(0, (double s, Game g) => s + g.finalPrice);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مكتبتي',
                        style: TextStyle(
                          color: EpicColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${games.length} لعبة — قيمة المكتبة \$${totalValue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: EpicColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < games.length; i++)
              FadeInSlide(
                delay: Duration(milliseconds: 40 * (i % 8)),
                child: _GameRow(
                  game: games[i],
                  controller: controller,
                  onOpen: (Game g) {
                    Navigator.of(context).push(
                      epicRoute(
                        GameDetailsScreen(game: g, controller: controller),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// صف لعبة في المكتبة: غلاف مصغر + بيانات + حذف بالسحب أو بالزر.
class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.game,
    required this.controller,
    required this.onOpen,
  });

  final Game game;
  final LibraryController controller;
  final ValueChanged<Game> onOpen;

  void _remove(BuildContext context) {
    controller.remove(game.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('تمت إزالة اللعبة من المكتبة'),
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () => controller.add(game),
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: EpicColors.danger.withOpacity(.18),
          border: Border.all(color: EpicColors.danger.withOpacity(.5)),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: EpicColors.danger,
          size: 26,
        ),
      ),
      child: GestureDetector(
        onTap: () => onOpen(game),
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
                    PriceTag(game: game, fontSize: 12, showBadge: false),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _remove(context),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: EpicColors.textSecondary,
                  size: 20,
                ),
                tooltip: 'إزالة من المكتبة',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
