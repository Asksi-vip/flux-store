import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/game.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/game_card.dart';
import '../widgets/status_views.dart';
import 'game_details_screen.dart';
import 'search_screen.dart';

/// الشاشة الرئيسية: شريط علوي بالبحث + بانر متحرك + شبكة الألعاب.
class HomeScreen extends StatefulWidget {
  final ApiService api;
  final LibraryController library;

  const HomeScreen({super.key, required this.api, required this.library});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;
  List<Game> _featured = [];
  List<Game> _games = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// تحميل المميزة والألعاب معًا (تُستخدم أيضًا للسحب للتحديث).
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.getFeatured(),
        widget.api.getGames(),
      ]);
      if (!mounted) return;
      setState(() {
        _featured = results[0];
        _games = results[1];
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// فتح شاشة تفاصيل اللعبة.
  void _openDetails(Game game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameDetailsScreen(
          game: game,
          api: widget.api,
          library: widget.library,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: FluxColors.pink,
          backgroundColor: FluxColors.surface,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // الشريط العلوي: الشعار
              SliverToBoxAdapter(child: _buildHeader()),
              // حقل البحث
              SliverToBoxAdapter(child: _buildSearchField()),
              // المحتوى حسب الحالة
              if (_loading)
                const SliverFillRemaining(hasScrollBody: false, child: LoadingView())
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(message: _error!, onRetry: _load),
                )
              else if (_games.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    icon: Icons.sports_esports_rounded,
                    title: 'لا توجد ألعاب بعد',
                    subtitle: 'تأكد من تشغيل الخادم ثم اسحب للأسفل للتحديث',
                  ),
                )
              else ...[
                // البانر المتحرك للألعاب المميزة
                if (_featured.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                      child: BannerCarousel(games: _featured, onGameTap: _openDetails),
                    ),
                  ),
                // عنوان القسم
                SliverToBoxAdapter(child: _sectionTitle('كل الألعاب', '${_games.length} لعبة')),
                // شبكة الألعاب
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: .66,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => GameCard(
                        game: _games[i],
                        onTap: () => _openDetails(_games[i]),
                      ),
                      childCount: _games.length,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// الشريط العلوي: شعار FLUX بتدرج نيوني.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => FluxColors.pinkPurple.createShader(bounds),
                child: const Text(
                  'FLUX',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: FluxColors.textPrimary,
                  ),
                ),
              ),
              const Text(
                'متجرك للألعاب الأسطورية',
                style: TextStyle(color: FluxColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FluxColors.surface,
              border: Border.all(color: FluxColors.purple.withOpacity(.5)),
            ),
            child: const Icon(Icons.notifications_none_rounded, color: FluxColors.cyan, size: 22),
          ),
        ],
      ),
    );
  }

  /// حقل البحث (فتح شاشة البحث عند الضغط).
  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SearchScreen(api: widget.api, library: widget.library)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 50,
          decoration: BoxDecoration(
            color: FluxColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FluxColors.purple.withOpacity(.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: FluxColors.cyan, size: 22),
              SizedBox(width: 10),
              Text(
                'ابحث عن لعبة...',
                style: TextStyle(color: FluxColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// عنوان قسم مع عدد العناصر.
  Widget _sectionTitle(String title, String count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: FluxColors.pinkPurple,
              boxShadow: neonGlow(FluxColors.pink, blur: 8),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: FluxColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            count,
            style: const TextStyle(color: FluxColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
