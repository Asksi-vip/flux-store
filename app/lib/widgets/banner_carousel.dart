import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game.dart';
import '../theme/app_theme.dart';

/// بانر متحرك تلقائيًا يعرض الألعاب المميزة في الشاشة الرئيسية.
class BannerCarousel extends StatefulWidget {
  final List<Game> games;
  final void Function(Game game) onGameTap;

  const BannerCarousel({
    super.key,
    required this.games,
    required this.onGameTap,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late final PageController _controller = PageController(viewportFraction: .88);
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // إعادة الضبط عند تغير قائمة الألعاب (مثلًا بعد سحب للتحديث)
    if (oldWidget.games.length != widget.games.length) {
      _current = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// تمرير تلقائي كل 4 ثوانٍ.
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.games.isEmpty || !_controller.hasClients) return;
      final next = (_current + 1) % widget.games.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.games.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 195,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.games.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) {
              final game = widget.games[i];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                margin: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: _current == i ? 0 : 10,
                ),
                child: GestureDetector(
                  onTap: () => widget.onGameTap(game),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // خلفية البانر
                        _bannerBackground(game),
                        // تدرج داكن لوضوح النصوص
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(.85),
                                Colors.black.withOpacity(.25),
                                Colors.transparent,
                              ],
                              stops: const [0, .5, 1],
                            ),
                          ),
                        ),
                        // نصوص البانر
                        Positioned(
                          right: 18,
                          bottom: 16,
                          left: 18,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _tag(
                                    game.categoryDisplay,
                                    FluxColors.pink.withOpacity(.9),
                                  ),
                                  const SizedBox(width: 8),
                                  if (game.isFeatured)
                                    _tag('مميزة', FluxColors.cyan.withOpacity(.85)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                game.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: FluxColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                game.finalPriceLabel,
                                style: TextStyle(
                                  color: game.isFree ? FluxColors.cyan : FluxColors.pink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // مؤشر النقاط
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.games.length, (i) {
            final active = i == _current;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? FluxColors.pink
                    : FluxColors.textPrimary.withOpacity(.3),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// خلفية البانر: صورة إن وُجدت وإلا تدرج نيوني مع أيقونة.
  Widget _bannerBackground(Game game) {
    if (game.banner.isEmpty) return _bannerFallback();
    return Image.network(
      game.banner,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _bannerFallback(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _bannerFallback(),
    );
  }

  Widget _bannerFallback() {
    return Container(
      color: FluxColors.card,
      child: const Center(
        child: Icon(Icons.videogame_asset_rounded, size: 52, color: FluxColors.purple),
      ),
    );
  }

  /// شارة صغيرة (تصنيف / مميزة).
  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: FluxColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
