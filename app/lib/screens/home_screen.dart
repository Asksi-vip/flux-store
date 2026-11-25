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
import '../widgets/skeleton.dart';
import '../widgets/status_views.dart';
import 'game_details_screen.dart';
import 'search_screen.dart';

/// شاشة المتجر بأسلوب Epic Games للجوال: تابا Browse وDiscover،
/// بانر سينمائي، صف FREE NOW، العروض، أحدث الإصدارات بشارة New.
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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Game>> _future = ApiService.instance.getGames();
  late final TabController _storeTabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _storeTabs.dispose();
    super.dispose();
  }

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
                  title: 'Nothing here yet',
                  message: 'Get started by browsing games, apps, and more.',
                ),
              ],
            );
          }
          return Column(
            children: [
              _storeTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _storeTabs,
                  children: [
                    RefreshIndicator(
                      color: EpicColors.blue,
                      backgroundColor: EpicColors.surface,
                      onRefresh: _reload,
                      child: _buildBrowseTab(games),
                    ),
                    _buildDiscoverTab(games),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// تابا المتجر (Browse / Discover) بأسلوب Epic: مؤشر أزرق سميك.
  Widget _storeTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: EpicColors.background,
        border: Border(bottom: BorderSide(color: EpicColors.border)),
      ),
      child: TabBar(
        controller: _storeTabs,
        indicatorColor: EpicColors.blue,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: EpicColors.textPrimary,
        unselectedLabelColor: EpicColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Browse'),
          Tab(text: 'Discover'),
        ],
      ),
    );
  }

  // ==================== تاب Browse ====================

  Widget _buildBrowseTab(List<Game> games) {
    // البانر: المميزة أولًا، وإن لم توجد نعرض أول خمس ألعاب
    final List<Game> featured =
        games.where((Game g) => g.isFeatured).toList(growable: false);
    final List<Game> carousel =
        featured.length >= 2 ? featured : games.take(5).toList();

    // 1) On Sale: ألعاب ذات خصم مرتبة من الأعلى خصمًا (Epic Exclusive Deals)
    final List<Game> onSale = games.where((Game g) => g.hasDiscount).toList()
      ..sort(
        (Game a, Game b) => b.discountPercent.compareTo(a.discountPercent),
      );

    // 2) New Releases: مرتبة حسب أحدث تاريخ إصدار
    final List<Game> newReleases = [...games]
      ..sort((Game a, Game b) => b.releaseDate.compareTo(a.releaseDate));

    // 3) FREE NOW: الألعاب المجانية
    final List<Game> freeGames = games.where((Game g) => g.isFree).toList();

    // 4) Top Rated: مرتبة حسب التقييم
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
        // البانر السينمائي المتحرك
        HeroCarousel(games: carousel, onOpenGame: widget.onOpenGame),
        const SizedBox(height: 28),

        // 🎁 FREE NOW — القسم الأيقوني للألعاب المجانية بأسلوب Epic
        if (freeGames.isNotEmpty) ...[
          _freeNowSection(freeGames),
          const SizedBox(height: 28),
        ],

        // 🔥 On Sale — العروض والخصومات
        if (onSale.isNotEmpty) ...[
          _onSaleSection(onSale),
          const SizedBox(height: 28),
        ],

        // 🚀 New Releases — أحدث الإصدارات بشارة New
        if (newReleases.isNotEmpty) ...[
          _newReleasesSection(newReleases),
          const SizedBox(height: 28),
        ],

        // 🏷️ Browse by Genre — شرائح الفئات
        if (catNames.isNotEmpty) ...[
          _genresSection(catNames, catValue),
          const SizedBox(height: 28),
        ],

        // ⭐ Top Rated — الأكثر رواجًا
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Top Rated', 'Highest player ratings right now'),
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

  /// عنوان قسم موحد بأسلوب Epic: عنوان ثقيل + سطر ثانوي رمادي.
  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: EpicColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: EpicColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  /// قسم FREE NOW بأسلوب Epic: شريط توهج أزرق + شارة FREE NOW على الكروت.
  Widget _freeNowSection(List<Game> freeGames) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Free Games', 'Grab them now and keep them forever'),
          const SizedBox(height: 14),
          Container(
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
                SizedBox(
                  height: 215,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    scrollDirection: Axis.horizontal,
                    itemCount: freeGames.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, int i) {
                      final Game g = freeGames[i];
                      return FadeInSlide(
                        delay: Duration(milliseconds: 60 * (i % 6)),
                        child: GestureDetector(
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
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                          child: const Text(
                                            'FREE NOW',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        'Keep it forever',
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
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// قسم On Sale بأسلوب Epic: كروت عريضة بشارة خصم برتقالية و"Save $X".
  Widget _onSaleSection(List<Game> deals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _sectionTitle('On Sale', 'Biggest discounts on top titles'),
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
                                Color(0x8817242D),
                                Color(0xF517242D),
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
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 11,
                                      color: EpicColors.cyan,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Deal',
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
                                  'Limited time',
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
                                    'Save \$${(g.price - g.finalPrice).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: EpicColors.saleOrange,
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

  /// قسم New Releases بأسلوب Epic: شارة New بيضاء على الغلاف.
  Widget _newReleasesSection(List<Game> launchEvents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _sectionTitle(
              'New Releases', 'Fresh drops and the latest launches'),
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
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const Text(
                                    'New',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                    ),
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
                                    Expanded(
                                      child: Text(
                                        g.releaseDate.isNotEmpty
                                            ? g.releaseDate
                                            : 'Recently released',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: EpicColors.cyan,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
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

  // ==================== تاب Discover ====================

  /// تاب Discover: شبكة أنواع بأسلوب Epic — بلاطات عمودية بتدرج وعدد الألعاب.
  Widget _buildDiscoverTab(List<Game> games) {
    final Map<String, List<Game>> byCategory = <String, List<Game>>{};
    for (final Game g in games) {
      byCategory.putIfAbsent(g.categoryDisplay, () => <Game>[]).add(g);
    }
    final List<String> cats = byCategory.keys.toList()..sort();

    if (cats.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          EmptyView(
            icon: Icons.explore_rounded,
            title: 'Nothing here yet',
            message: 'Get started by browsing games, apps, and more.',
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _sectionTitle('Discover', 'Browse the store by your favorite genre'),
        const SizedBox(height: 16),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cats.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, int i) {
            final String cat = cats[i];
            final List<Game> items = byCategory[cat]!;
            final Game cover = items.first;
            return FadeInSlide(
              delay: Duration(milliseconds: 45 * (i % 8)),
              child: GestureDetector(
                onTap: () => _openCategory(cat, games),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EpicColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      buildGameCover(cover, fit: BoxFit.cover),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0xAA17242D),
                              Color(0xE617242D),
                            ],
                            stops: [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        bottom: 10,
                        start: 12,
                        end: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cat,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: EpicColors.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                              style: const TextStyle(
                                color: EpicColors.textSecondary,
                                fontSize: 11,
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
        const SizedBox(height: 24),
        // صف اكتشاف إضافي: مختارات المتجر في شبكة مصغرة
        _sectionTitle("Editor's Picks", 'Hand-picked titles from the store'),
        const SizedBox(height: 14),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: games.length.clamp(0, 4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 20,
            childAspectRatio: 0.55,
          ),
          itemBuilder: (context, int i) {
            final Game g = games[i];
            return FadeInSlide(
              delay: Duration(milliseconds: 50 * (i % 6)),
              child: GameCard(
                game: g,
                onTap: () => widget.onOpenGame(g),
              ),
            );
          },
        ),
      ],
    );
  }

  void _openCategory(String name, List<Game> games) {
    final Map<String, String> catValue = <String, String>{};
    for (final Game g in games) {
      catValue.putIfAbsent(g.categoryDisplay, () => g.category);
    }
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
  }

  /// قسم الفئات داخل Browse: شرائح تنقلك للتصفح المفلتر.
  Widget _genresSection(
    List<String> catNames,
    Map<String, String> catValue,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _sectionTitle('Browse by Genre', 'Explore the store by type'),
        ),
        const SizedBox(height: 14),
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

/// هيكل تحميل المتجر يحاكي شكل المحتوى النهائي (تابات + بانر + صفوف + شبكة).
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // موضع تابات Browse/Discover
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: const [
              SkeletonBox(height: 18, width: 70),
              SizedBox(width: 24),
              SkeletonBox(height: 18, width: 84),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SkeletonBox(height: 230, radius: 4),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SkeletonBox(height: 20, width: 150),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 215,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => const SkeletonBox(width: 160, height: 215),
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
