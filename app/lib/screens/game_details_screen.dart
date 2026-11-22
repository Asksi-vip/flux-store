import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/game.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/epic_button.dart';
import '../widgets/game_card.dart';
import '../widgets/page_fade_transition.dart';
import '../widgets/price_tag.dart';
import '../widgets/rating_stars.dart';
import 'search_screen.dart';

/// صفحة تفاصيل اللعبة بأسلوب Epic: بانر سينمائي، سعر وخصم، زر إضافة متحرك، ومقترحات.
class GameDetailsScreen extends StatefulWidget {
  const GameDetailsScreen({
    super.key,
    required this.game,
    required this.controller,
  });

  final Game game;
  final LibraryController controller;

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  bool _expanded = false;
  late final Future<List<Game>> _similarFuture =
      ApiService.instance.getGames(category: widget.game.category);

  /// إضافة/إزالة اللعبة من المكتبة مع تأكيد متحرك وزر تراجع.
  Future<void> _toggleLibrary() async {
    final Game game = widget.game;
    final bool wasIn = widget.controller.contains(game.id);
    await widget.controller.toggle(game);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            wasIn ? 'تمت الإزالة من المكتبة' : 'تمت الإضافة إلى مكتبتك',
          ),
          action: SnackBarAction(
            label: wasIn ? 'تراجع' : 'إزالة',
            onPressed: () {
              if (wasIn) {
                widget.controller.add(game);
              } else {
                widget.controller.remove(game.id);
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final Game game = widget.game;
    final String bannerUrl = game.banner.isNotEmpty ? game.banner : game.image;
    final String releaseYear = game.releaseDate.split('-').first;

    return Scaffold(
      backgroundColor: EpicColors.background,
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final bool inLibrary = widget.controller.contains(game.id);
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // البانر السينمائي مع زر الرجوع وشارة الخصم
              Stack(
                children: [
                  SizedBox(
                    height: 280,
                    width: double.infinity,
                    // زوم سينمائي: البانر يبدأ مكبرًا 8% ثم يتقلص بسلاسة (إحساس Epic)
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 1.08, end: 1.0),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, double scale, Widget? child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: bannerUrl.isEmpty
                          ? Container(
                              color: EpicColors.surface,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.sports_esports,
                                color: EpicColors.border,
                                size: 48,
                              ),
                            )
                          : FadeInNetworkImage(
                              url: bannerUrl,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Container(
                    height: 280,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.3, 1],
                        colors: [
                          Colors.transparent,
                          EpicColors.background.withOpacity(.95),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          _circleButton(
                            Icons.arrow_forward_rounded,
                            () => Navigator.of(context).maybePop(),
                          ),
                          const Spacer(),
                          if (game.hasDiscount)
                            DiscountBadge(
                              percent: game.discountPercent,
                              fontSize: 14,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.categoryDisplay,
                      style: const TextStyle(
                        color: EpicColors.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      game.name,
                      style: const TextStyle(
                        color: EpicColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        RatingStars(rating: game.rating, showValue: true),
                        const SizedBox(width: 12),
                        if (releaseYear.isNotEmpty)
                          Text(
                            'الإصدار: $releaseYear',
                            style: const TextStyle(
                              color: EpicColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // زر الإضافة / الإزالة مع انتقال متحرك بين الحالتين
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (Widget child, Animation<double> anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: .96, end: 1).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: inLibrary
                          ? KeyedSubtree(
                              key: const ValueKey<String>('in'),
                              child: EpicButton(
                                label: 'في المكتبة',
                                variant: EpicButtonVariant.success,
                                icon: Icons.check_circle_outline_rounded,
                                onPressed: _toggleLibrary,
                              ),
                            )
                          : KeyedSubtree(
                              key: const ValueKey<String>('out'),
                              child: EpicButton(
                                label: game.isFree
                                    ? 'احصل عليها مجانًا'
                                    : 'أضف إلى المكتبة',
                                icon: Icons.add_circle_outline_rounded,
                                onPressed: _toggleLibrary,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    // صف السعر مع قيمة التوفير
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: EpicColors.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EpicColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: PriceTag(game: game, fontSize: 16)),
                          if (game.hasDiscount)
                            Text(
                              'وفّر \$${(game.price - game.finalPrice).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: EpicColors.cyan,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // الوصف مع إمكانية التوسيع (انتقال متحرك)
                    const Text(
                      'عن اللعبة',
                      style: TextStyle(
                        color: EpicColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: _expanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: Text(
                        game.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: EpicColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.7,
                        ),
                      ),
                      secondChild: Text(
                        game.description,
                        style: const TextStyle(
                          color: EpicColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.7,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        _expanded ? 'عرض أقل' : 'اقرأ المزيد',
                        style: const TextStyle(
                          color: EpicColors.cyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // مقترحات من نفس الفئة
                    Text(
                      'قد يعجبك أيضًا',
                      style: const TextStyle(
                        color: EpicColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'من فئة ${game.categoryDisplay}',
                      style: const TextStyle(
                        color: EpicColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FutureBuilder<List<Game>>(
                      future: _similarFuture,
                      builder: (context, AsyncSnapshot<List<Game>> snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 150,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: EpicColors.blue,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        }
                        final List<Game> similar = (snapshot.data ?? const <Game>[])
                            .where((Game g) => g.id != game.id)
                            .take(10)
                            .toList();
                        if (similar.isEmpty) {
                          return const Text(
                            'لا توجد ألعاب مشابهة بعد',
                            style: TextStyle(
                              color: EpicColors.textSecondary,
                              fontSize: 13,
                            ),
                          );
                        }
                        return SizedBox(
                          height: 235,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.zero,
                            itemCount: similar.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, int i) {
                              return SizedBox(
                                width: 120,
                                child: GameCard(
                                  game: similar[i],
                                  onTap: () {
                                    Navigator.of(context).push(
                                      epicRoute(
                                        GameDetailsScreen(
                                          game: similar[i],
                                          controller: widget.controller,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// زر دائري شفاف فوق البانر (رجوع).
  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, size: 20, color: EpicColors.textPrimary),
      ),
    );
  }
}
