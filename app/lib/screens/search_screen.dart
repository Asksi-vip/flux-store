import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_in_slide.dart';
import '../widgets/game_card.dart';
import '../widgets/page_fade_transition.dart';
import '../widgets/status_views.dart';
import 'game_details_screen.dart';

/// شاشة تصفح وبحث الألعاب بأسلوب Epic: بحث فوري مع فلاتر فئات وسعر.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.initialCategory,
    required this.onOpenGame,
  });

  /// فئة مبدئية عند الفتح من شريحة فئة في الرئيسية.
  final String? initialCategory;
  final ValueChanged<Game> onOpenGame;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String? _category;
  String _priceFilter = 'all';
  late Future<List<Game>> _future;

  /// فئات الـ API الثمانية المعروفة (القيمة ← الاسم المعروض).
  static const List<(String, String)> _categories = [
    ('action', 'أكشن'),
    ('adventure', 'مغامرات'),
    ('rpg', 'ألعاب أدوار'),
    ('racing', 'سباقات'),
    ('shooter', 'تصويب'),
    ('sports', 'رياضة'),
    ('strategy', 'استراتيجية'),
    ('sandbox', 'عالم مفتوح'),
  ];

  /// خيارات فلترة السعر المربوطة بمعاملات الـ API الفعلية.
  static const List<(String, String)> _priceOptions = [
    ('all', 'كل الأسعار'),
    ('free', 'مجاني'),
    ('low', 'أقل من 20\$'),
    ('mid', '20\$ - 50\$'),
    ('high', 'أكثر من 50\$'),
  ];

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _future = _fetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// بناء الطلب الحالي حسب البحث والفئة والسعر المختارين.
  Future<List<Game>> _fetch() async {
    double? minPrice;
    double? maxPrice;
    switch (_priceFilter) {
      case 'free':
        minPrice = 0;
        maxPrice = 0;
        break;
      case 'low':
        maxPrice = 20;
        break;
      case 'mid':
        minPrice = 20;
        maxPrice = 50;
        break;
      case 'high':
        minPrice = 50;
        break;
      default:
        break;
    }
    return ApiService.instance.getGames(
      search: _searchController.text,
      category: _category,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        setState(() {
          _future = _fetch();
        });
      }
    });
  }

  void _applyFilters() {
    _debounce?.cancel();
    setState(() {
      _future = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EpicColors.background,
      appBar: AppBar(
        automaticallyImplyLeading:
            ModalRoute.of(context)?.isFirst != true,
        title: const Text('تصفح الألعاب'),
      ),
      body: Column(
        children: [
          // حقل البحث
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: EpicColors.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'ابحث عن لعبة بالاسم أو الوصف...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: EpicColors.textSecondary,
                  size: 20,
                ),
                isDense: true,
              ),
            ),
          ),
          _chipRow(
            height: 44,
            children: [
              _chip(
                label: 'الكل',
                selected: _category == null,
                onTap: () {
                  _category = null;
                  _applyFilters();
                },
              ),
              for (final (String value, String label) in _categories)
                _chip(
                  label: label,
                  selected: _category == value,
                  onTap: () {
                    _category = value;
                    _applyFilters();
                  },
                ),
            ],
          ),
          _chipRow(
            height: 40,
            children: [
              for (final (String value, String label) in _priceOptions)
                _priceChip(
                  label: label,
                  selected: _priceFilter == value,
                  onTap: () {
                    _priceFilter = value;
                    _applyFilters();
                  },
                ),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<Game>>(
              future: _future,
              builder: (context, AsyncSnapshot<List<Game>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingGrid(itemCount: 6);
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message: snapshot.error.toString(),
                    onRetry: _applyFilters,
                  );
                }
                final List<Game> results = snapshot.data ?? const <Game>[];
                if (results.isEmpty) {
                  return const EmptyView(
                    icon: Icons.search_off_rounded,
                    title: 'لا توجد نتائج',
                    message: 'جرّب كلمة بحث مختلفة أو غيّر الفلاتر المختارة',
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: results.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.55,
                  ),
                  itemBuilder: (context, int i) {
                    return FadeInSlide(
                      delay: Duration(milliseconds: 40 * (i % 6)),
                      child: GameCard(
                        game: results[i],
                        onTap: () => widget.onOpenGame(results[i]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// صف شرائح أفقي قابل للتمرير.
  Widget _chipRow({required double height, required List<Widget> children}) {
    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: children,
      ),
    );
  }

  /// شريحة فئة بأسلوب Epic: تتحول للأزرق عند الاختيار.
  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? EpicColors.blue : EpicColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected ? EpicColors.blue : EpicColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? EpicColors.textOnBadge : EpicColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  /// شريحة السعر بنمط ثانوي أخف.
  Widget _priceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? EpicColors.elevated : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected ? EpicColors.cyan : EpicColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? EpicColors.cyan : EpicColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
