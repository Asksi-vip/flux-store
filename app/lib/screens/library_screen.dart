import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/game.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_views.dart';
import 'game_details_screen.dart';

/// شاشة المكتبة: الألعاب المحفوظة محليًا على الجهاز (SharedPreferences).
class LibraryScreen extends StatelessWidget {
  final ApiService api;
  final LibraryController library;

  const LibraryScreen({super.key, required this.api, required this.library});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final games = library.games;
        return Scaffold(
          appBar: AppBar(title: const Text('مكتبتي')),
          body: games.isEmpty
              ? const EmptyView(
                  icon: Icons.gamepad_rounded,
                  title: 'مكتبتك فارغة',
                  subtitle: 'أضف ألعابًا من المتجر لتظهر هنا — تُحفظ على جهازك تلقائيًا',
                )
              : Column(
                  children: [
                    // ملخص المكتبة
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: FluxColors.pink.withOpacity(.15),
                              border: Border.all(color: FluxColors.pink.withOpacity(.4)),
                            ),
                            child: Text(
                              '${games.length} ${games.length == 1 ? 'لعبة' : 'ألعاب'}',
                              style: const TextStyle(
                                color: FluxColors.pink,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Spacer(),
                          _totalValue(games),
                        ],
                      ),
                    ),
                    // قائمة الألعاب
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                        itemCount: games.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _gameTile(context, games[i]),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  /// مجموع القيمة النهائية للألعاب غير المجانية.
  Widget _totalValue(List<Game> games) {
    final total = games.fold<double>(0, (sum, g) => sum + g.finalPrice);
    if (total <= 0) {
      return const Text(
        'كلها مجانية 🎉',
        style: TextStyle(color: FluxColors.cyan, fontSize: 12, fontWeight: FontWeight.bold),
      );
    }
    final text = total == total.roundToDouble()
        ? total.toStringAsFixed(0)
        : total.toStringAsFixed(2);
    return Text(
      'الإجمالي: \$$text',
      style: const TextStyle(color: FluxColors.textMuted, fontSize: 13),
    );
  }

  /// بطاقة لعبة داخل المكتبة مع إمكانية السحب للإزالة.
  Widget _gameTile(BuildContext context, Game game) {
    return Dismissible(
      key: ValueKey<int>(game.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => library.remove(game.id),
      background: Container(
        alignment: Alignment.centerEnd,
        padding: const EdgeInsets.only(left: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: FluxColors.pink.withOpacity(.25),
          border: Border.all(color: FluxColors.pink.withOpacity(.5)),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: FluxColors.pink, size: 26),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameDetailsScreen(game: game, api: api, library: library),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: FluxColors.card,
            border: Border.all(color: FluxColors.purple.withOpacity(.3)),
          ),
          child: Row(
            children: [
              // صورة مصغرة
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: game.image.isNotEmpty
                      ? Image.network(
                          game.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumbFallback(),
                        )
                      : _thumbFallback(),
                ),
              ),
              const SizedBox(width: 12),
              // الاسم والتصنيف والسعر
              Expanded(
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
                    const SizedBox(height: 6),
                    Text(
                      game.finalPriceLabel,
                      style: TextStyle(
                        color: game.isFree ? FluxColors.cyan : FluxColors.pink,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // زر الإزالة
              IconButton(
                onPressed: () => library.remove(game.id),
                icon: const Icon(Icons.delete_outline_rounded),
                color: FluxColors.pink.withOpacity(.8),
                tooltip: 'إزالة من المكتبة',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      color: FluxColors.surface,
      child: const Icon(Icons.sports_esports_rounded, color: FluxColors.purple, size: 26),
    );
  }
}
