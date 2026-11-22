import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game.dart';
import '../theme/app_theme.dart';
import 'game_card.dart';
import 'price_tag.dart';

/// البانر السينمائي بأسلوب Epic Games: شرائح تتبدل تلقائيًا + صور مصغرة للتحكم اليدوي.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key, required this.games, required this.onOpenGame});

  final List<Game> games;
  final ValueChanged<Game> onOpenGame;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.93);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _nextPage());
  }

  void _nextPage() {
    if (!mounted || !_pageController.hasClients || widget.games.isEmpty) return;
    final int next = (_index + 1) % widget.games.length;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.games.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.games.length,
            onPageChanged: (int i) {
              setState(() => _index = i);
              _startTimer();
            },
            itemBuilder: (context, int i) => _slide(widget.games[i]),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 68,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: widget.games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, int i) {
              final bool selected = i == _index;
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeInOut,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 104,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? EpicColors.blue : EpicColors.border,
                      width: 2,
                    ),
                  ),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: selected ? 1 : 0.45,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: buildGameCover(widget.games[i]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// شريحة البانر الكاملة: بطاقة بحواف دائرية وإطار + تدرج سفلي + اسم وحبة سعر/تثبيت.
  Widget _slide(Game game) {
    final String url = game.banner.isNotEmpty ? game.banner : game.image;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () => widget.onOpenGame(game),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: EpicColors.border),
            color: EpicColors.surface,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url.isEmpty)
                Container(
                  color: EpicColors.surface,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.sports_esports,
                    color: EpicColors.border,
                    size: 44,
                  ),
                )
              else
                FadeInNetworkImage(url: url, fit: BoxFit.cover),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.35, 1],
                    colors: [Colors.transparent, Colors.black.withOpacity(.85)],
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: 16,
                start: 16,
                end: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      game.categoryDisplay,
                      style: const TextStyle(
                        color: EpicColors.cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      game.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: EpicColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GamePricePill(
                      game: game,
                      onOpenGame: () => widget.onOpenGame(game),
                      fontSize: 13.5,
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
}
