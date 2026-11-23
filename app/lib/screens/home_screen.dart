import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/game.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_in_slide.dart';
import '../widgets/game_card.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/page_fade_transition.dart';
import '../widgets/price_tag.dart';
import '../widgets/rating_stars.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_views.dart';
import 'game_details_screen.dart';
import 'search_screen.dart';

/// الشاشة الرئيسية بأسلوب متجر Epic Games: بانر سينمائي، خصومات، فئات، الأكثر رواجًا.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onOpenGame,
  });

  final LibraryController controller;
  final ValueChanged<Game> onOpenGame;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Game>> _future = ApiService.instance.getGames();

  Future<void> _reload() async {
    setState(() {
      _future = ApiService.instance.getGames();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: EpicColors.blue,
      backgroundColor: EpicColors.surface,
      onRefresh: _reload,
      child: FutureBuilder<List<Game>>(
        future: _future,
        builder: (context, AsyncSnapshot<List<Game>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _HomeSkeleton();
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
                ErrorView(message: snapshot.error.toString(), onRetry: _reload),
              ],
            );
          }
          final List<Game> games = snapshot.data ?? const <Game>[];
          if (games.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                EmptyView(
                  icon: Icons.storefront_rounded,
                  title: 'المتجر فارغ حاليًا',
                  message:
                      'أضف ألعابًا من لوحة تحكم Django أو نفّذ أمر seed_games لتعبئتها ببيانات تجريبية',
                ),
              ],
            );
          }
          return _buildStore(games);
        },
      ),
    );
  }

  Widget _buildStore(List<Game> games) {
    // البانر: المميزة أولًا، وإن لم توجد نعرض أول خمس ألعاب
    final List<Game> featured =
        games.where((Game g) => g.isFeatured).toList(growable: false);
    final List<Game> carousel =
        featured.length >= 2 ? featured : games.take(5).toList();

    // 1) عروض حصرية: ألعاب ذات خصم مرتبة من الأعلى خصمًا (بأسلوب Epic Exclusive Deals)
    final List<Game> exclusiveDeals = games.where((Game g) => g.hasDiscount).toList()
      ..sort(
        (Game a, Game b) => b.discountPercent.compareTo(a.discountPercent),
      );

    // 2) أحداث الإصدار: مرتبة حسب أحدث تاريخ إصدار (بأسلوب Epic Launch Events)
    final List<Game> launchEvents = [...games]
      ..sort((Game a, Game b) => b.releaseDate.compareTo(a.releaseDate));

    // 3) الألعاب المجانية: ألعاب مجانية بأسلوب Epic Free Games
    final List<Game> freeGames = games.where((Game g) => g.isFree).toList();

    // 4) الأكثر رواجًا: مرتبة حسب التقييم
    final List<Game> topRated = [...games]
      ..sort((Game a, Game b) => b.rating.compareTo(a.rating));

    // الفئات الموجودة فعليًا في البيانات: اسم العرض ← قيمة الفئة
    final Map<String, String> catValue = <String, String>{};
    for (final Game g in games) {
      catValue.putIfAbsent(g.categoryDisplay, () => g.category);
    }
    final List<String> catNames = catValue.keys.toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // ترويسة المتجر
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'اكتشف الألعاب',
                style: TextStyle(
                  color: EpicColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'عروض حصرية وأحدث الإصدارات في متجر FLUX',
                style: TextStyle(
                  color: EpicColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        // البانر السينمائي المتحرك
        HeroCarousel(games: carousel, onOpenGame: widget.onOpenGame),
        const SizedBox(height: 28),

        // 🎁 قسم الألعاب المجانية الأيقوني بأسلوب Epic Games
        if (freeGames.isNotEmpty) ...[
          _epicFreeGamesSection(freeGames),
          const SizedBox(height: 28),
        ],

        // 🔥 قسم العروض الحصرية بأسلوب Epic Games
        if (exclusiveDeals.isNotEmpty) ...[
          _exclusiveDealsSection(exclusiveDeals),
          const SizedBox(height: 28),
        ],

        // 🚀 قسم أحداث الإصدار وأحدث العناوين بأسلوب Epic Games
        if (launchEvents.isNotEmpty) ...[
          _launchEventsSection(launchEvents),
          const SizedBox(height: 28),
        ],

        // 🏷️ قسم استكشاف الفئات
        if (catNames.isNotEmpty) ...[
          _categoriesSection(catNames, catValue),
          const SizedBox(height: 28),
        ],

        // ⭐ الأكثر رواجًا
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الأكثر رواجًا',
                style: TextStyle(
                  color: EpicColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'أعلى تقييمات اللاعبين الآن',
                style: TextStyle(color: EpicColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topRated.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.55,
                ),
                itemBuilder: (context, int i) {
                  return FadeInSlide(
                    delay: Duration(milliseconds: 50 * (i % 6)),
                    child: GameCard(
                      game: topRated[i],
                      onTap: () => widget.onOpenGame(topRated[i]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  /// قسم الألعاب المجانية بأسلوب Epic Games الأيقوني (Free Games Blade).
  Widget _epicFreeGamesSection(List<Game> freeGames) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: EpicColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: EpicColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [EpicColors.blue, EpicColors.cyan],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: EpicColors.elevated,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: EpicColors.border),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: EpicColors.cyan,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ألعاب مجانية',
                          style: TextStyle(
                            color: EpicColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'ألعاب مجانية حصرية — احصل عليها واحتفظ بها للأبد',
                          style: TextStyle(
                            color: EpicColors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 215,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                scrollDirection: Axis.horizontal,
                itemCount: freeGames.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, int i) {
                  final Game g = freeGames[i];
                  return GestureDetector(
                    onTap: () => widget.onOpenGame(g),
                    child: Container(
                      width: 160,
                      decoration: BoxDecoration(
                        color: EpicColors.elevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EpicColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                buildGameCover(g),
                                PositionedDirectional(
                                  top: 8,
                                  start: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: EpicColors.blue,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: const Text(
                                      'مجانية الآن',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: EpicColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'متاحة دائمًا في مكتبتك',
                                  style: TextStyle(
                                    color: EpicColors.cyan,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GamePricePill(
                                  game: g,
                                  onOpenGame: () => widget.onOpenGame(g),
                                  fontSize: 12,
                                  compact: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// قسم العروض الحصرية بأسلوب متجر Epic Games (Exclusive Offers Blade).
  Widget _exclusiveDealsSection(List<Game> deals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: EpicColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: EpicColors.border),
                ),
                child: const Icon(
                  Icons.local_offer_rounded,
                  color: EpicColors.blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'عروض حصرية',
                      style: TextStyle(
                        color: EpicColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'أقوى الخصومات الحصرية لفترة محدودة على كبرى العناوين',
                      style: TextStyle(
                        color: EpicColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 195,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: deals.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, int i) {
              final Game g = deals[i];
              return FadeInSlide(
                delay: Duration(milliseconds: 60 * (i % 6)),
                child: GestureDetector(
                  onTap: () => widget.onOpenGame(g),
                  child: Container(
                    width: 300,
                    decoration: BoxDecoration(
                      color: EpicColors.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: EpicColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        buildGameCover(g, fit: BoxFit.cover),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0x88101014),
                                Color(0xF5101014),
                              ],
                              stops: [0.0, 0.45, 0.85],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          left: 10,
                          child: Row(
                            children: [
                              DiscountBadge(
                                percent: g.discountPercent,
                                fontSize: 11.5,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: EpicColors.elevated.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(
                                    color: EpicColors.blue.withOpacity(0.6),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 11,
                                      color: EpicColors.cyan,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'عرض حصري',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: const Text(
                                  'لفترة محدودة',
                                  style: TextStyle(
                                    color: EpicColors.textSecondary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                g.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: EpicColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    g.categoryDisplay,
                                    style: const TextStyle(
                                      color: EpicColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  RatingStars(rating: g.rating, size: 12),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    g.priceLabel,
                                    style: const TextStyle(
                                      color: EpicColors.textSecondary,
                                      fontSize: 12,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    g.finalPriceLabel,
                                    style: const TextStyle(
                                      color: EpicColors.textPrimary,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'وفّر \$${(g.price - g.finalPrice).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: EpicColors.cyan,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  GamePricePill(
                                    game: g,
                                    onOpenGame: () => widget.onOpenGame(g),
                                    fontSize: 12,
                                    compact: true,
                                  ),
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
            },
          ),
        ),
      ],
    );
  }

  /// قسم أحداث الإصدار وأحدث الألعاب بأسلوب متجر Epic Games (Launch Events Blade).
  Widget _launchEventsSection(List<Game> launchEvents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: EpicColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: EpicColors.border),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: EpicColors.cyan,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'أحداث الإصدار',
                      style: TextStyle(
                        color: EpicColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'أحدث العناوين والإطلاقات الكبرى المتاحة الآن على المتجر',
                      style: TextStyle(
                        color: EpicColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 275,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: launchEvents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, int i) {
              final Game g = launchEvents[i];
              return FadeInSlide(
                delay: Duration(milliseconds: 60 * (i % 6)),
                child: GestureDetector(
                  onTap: () => widget.onOpenGame(g),
                  child: Container(
                    width: 180,
                    decoration: BoxDecoration(
                      color: EpicColors.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: EpicColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              buildGameCover(g),
                              PositionedDirectional(
                                top: 8,
                                start: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: EpicColors.blue,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'إصدار جديد',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: EpicColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 10,
                                      color: EpicColors.cyan,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      g.releaseDate.isNotEmpty
                                          ? g.releaseDate
                                          : 'إصدار حديث',
                                      style: const TextStyle(
                                        color: EpicColors.cyan,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (g.developer.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    g.developer,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: EpicColors.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Row(
                                  children: [
                                    if (g.hasDiscount) ...[
                                      DiscountBadge(
                                        percent: g.discountPercent,
                                        fontSize: 10,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Expanded(
                                      child: GamePricePill(
                                        game: g,
                                        onOpenGame: () => widget.onOpenGame(g),
                                        fontSize: 12,
                                        compact: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
      ],
    );
  }

  /// قسم الفئات: شرائح بأسلوب Epic تنقلك للتصفح المفلتر.
  Widget _categoriesSection(
    List<String> catNames,
    Map<String, String> catValue,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'استكشف الفئات',
                style: TextStyle(
                  color: EpicColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'تصفح المتجر حسب النوع المفضل لديك',
                style: TextStyle(color: EpicColors.textSecondary, fontSize: 12),
              ),
              SizedBox(height: 14),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final String name in catNames) _categoryChip(name, catValue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryChip(String name, Map<String, String> catValue) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          epicRoute(
            SearchScreen(
              initialCategory: catValue[name],
              onOpenGame: (Game g) {
                Navigator.of(context).push(
                  epicRoute(
                    GameDetailsScreen(game: g, controller: widget.controller),
                  ),
                );
              },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: EpicColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: EpicColors.border),
        ),
        child: Text(
          name,
          style: const TextStyle(
            color: EpicColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// هيكل تحميل الرئيسية يحاكي شكل المحتوى النهائي (بانر + صور مصغرة + شبكة).
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonBox(height: 26, width: 180),
              SizedBox(height: 8),
              SkeletonBox(height: 14, width: 260),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SkeletonBox(height: 230, radius: 4),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 64,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, __) => const SkeletonBox(width: 104, height: 64),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SkeletonBox(height: 20, width: 140),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: LoadingGrid(itemCount: 4),
        ),
      ],
    );
  }
}
