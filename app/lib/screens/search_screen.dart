import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_in_slide.dart';
import '../widgets/game_card.dart';
import '../widgets/page_fade_transition.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_views.dart';
import 'game_details_screen.dart';

/// شاشة البحث والتصفح بأسلوب Epic: Recent Searches + Sort Modal (4 خيارات)
/// + Filter Modal (Price/Genres) + حالات الفراغ الثلاث الحرفية.
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

enum _SearchSort { none, aToZ, zToA, priceLow, priceHigh }

class _SearchScreenState extends State<SearchScreen> {
  static const String _recentKey = 'flux_recent_searches';
  static const int _recentLimit = 8;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String? _category;
  String _priceFilter = 'all';
  bool _discountedOnly = false;
  _SearchSort _sort = _SearchSort.none;
  late Future<List<Game>> _future;
  List<String> _recent = <String>[];

  /// فئات الـ API الثمانية المعروفة (القيمة ← الاسم المعروض).
  static const List<(String, String)> _categories = [
    ('action', 'Action'),
    ('adventure', 'Adventure'),
    ('rpg', 'RPG'),
    ('racing', 'Racing'),
    ('shooter', 'Shooter'),
    ('sports', 'Sports'),
    ('strategy', 'Strategy'),
    ('sandbox', 'Sandbox'),
  ];

  /// خيارات فلترة السعر بنصوص Epic الحرفية.
  static const List<(String, String)> _priceOptions = [
    ('all', 'All'),
    ('free', 'Free'),
    ('low', 'Under \$20'),
    ('mid', '\$20 - \$50'),
    ('high', '\$50 and above'),
  ];

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _future = _fetch();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recent = prefs.getStringList(_recentKey) ?? const <String>[];
    });
  }

  Future<void> _saveRecent(String query) async {
    final String q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recent
        ..removeWhere((String s) => s.toLowerCase() == q.toLowerCase())
        ..insert(0, q);
      if (_recent.length > _recentLimit) {
        _recent = _recent.sublist(0, _recentLimit);
      }
    });
    await prefs.setStringList(_recentKey, _recent);
  }

  Future<void> _clearRecent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _recent = <String>[]);
    await prefs.setStringList(_recentKey, _recent);
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

  /// تطبيق الترتيب وفلتر الخصم على النتائج القادمة من الخادم (جانب العميل).
  List<Game> _postProcess(List<Game> games) {
    List<Game> out = games;
    if (_discountedOnly) {
      out = out.where((Game g) => g.hasDiscount).toList();
    }
    switch (_sort) {
      case _SearchSort.none:
        break;
      case _SearchSort.aToZ:
        out = [...out]
          ..sort((Game a, Game b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SearchSort.zToA:
        out = [...out]
          ..sort((Game a, Game b) =>
              b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case _SearchSort.priceLow:
        out = [...out]..sort((Game a, Game b) =>
            a.finalPrice.compareTo(b.finalPrice));
        break;
      case _SearchSort.priceHigh:
        out = [...out]..sort((Game a, Game b) =>
            b.finalPrice.compareTo(a.finalPrice));
        break;
    }
    return out;
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

  bool get _hasActiveFilters =>
      _category != null ||
      _priceFilter != 'all' ||
      _discountedOnly ||
      _sort != _SearchSort.none;

  // ==================== Sort Modal بأسلوب Epic ====================

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: EpicColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (BuildContext sheetCtx, StateSetter setSheet) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sort',
                      style: TextStyle(
                        color: EpicColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final (_SearchSort s, String label) in <(_SearchSort, String)>[
                      (_SearchSort.aToZ, 'A-Z'),
                      (_SearchSort.zToA, 'Z-A'),
                      (_SearchSort.priceLow, 'Price: Low to High'),
                      (_SearchSort.priceHigh, 'Price: High to Low'),
                    ])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          _sort == s
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: _sort == s
                              ? EpicColors.blue
                              : EpicColors.textSecondary,
                          size: 20,
                        ),
                        title: Text(
                          label,
                          style: const TextStyle(
                            color: EpicColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        onTap: () {
                          setSheet(() => _sort = s);
                          _applyFilters();
                          Navigator.of(sheetCtx).pop();
                        },
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: EpicColors.textPrimary,
                              side: const BorderSide(color: EpicColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                            ),
                            onPressed: () {
                              setSheet(() => _sort = _SearchSort.none);
                              _applyFilters();
                              Navigator.of(sheetCtx).pop();
                            },
                            child: const Text(
                              'Clear sorting',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: EpicColors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                            ),
                            onPressed: () {
                              _applyFilters();
                              Navigator.of(sheetCtx).pop();
                            },
                            child: FutureBuilder<List<Game>>(
                              future: _future,
                              builder: (context,
                                  AsyncSnapshot<List<Game>> snap) {
                                final int n =
                                    snap.data?.length ?? 0;
                                return Text(
                                  'Sort ($n) results',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ==================== Filter Modal بأسلوب Epic ====================

  void _showFilterSheet() {
    String? tempCategory = _category;
    String tempPrice = _priceFilter;
    bool tempDiscount = _discountedOnly;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: EpicColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (BuildContext sheetCtx, StateSetter setSheet) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter',
                        style: TextStyle(
                          color: EpicColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // قسم السعر بنصوص Epic الحرفية
                      const Text(
                        'Price',
                        style: TextStyle(
                          color: EpicColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (String value, String label)
                              in _priceOptions)
                            _modalChip(
                              label: label,
                              selected: tempPrice == value,
                              onTap: () =>
                                  setSheet(() => tempPrice = value),
                            ),
                          _modalChip(
                            label: 'Discounted',
                            selected: tempDiscount,
                            onTap: () => setSheet(
                                () => tempDiscount = !tempDiscount),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // قسم الأنواع
                      const Text(
                        'Genres',
                        style: TextStyle(
                          color: EpicColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _modalChip(
                            label: 'All',
                            selected: tempCategory == null,
                            onTap: () =>
                                setSheet(() => tempCategory = null),
                          ),
                          for (final (String value, String label)
                              in _categories)
                            _modalChip(
                              label: label,
                              selected: tempCategory == value,
                              onTap: () =>
                                  setSheet(() => tempCategory = value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: EpicColors.textPrimary,
                                side: const BorderSide(
                                    color: EpicColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 13),
                              ),
                              onPressed: () {
                                setSheet(() {
                                  tempCategory = null;
                                  tempPrice = 'all';
                                  tempDiscount = false;
                                });
                              },
                              child: const Text(
                                'Reset filters',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: EpicColors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 13),
                              ),
                              onPressed: () {
                                setState(() {
                                  _category = tempCategory;
                                  _priceFilter = tempPrice;
                                  _discountedOnly = tempDiscount;
                                });
                                _applyFilters();
                                Navigator.of(sheetCtx).pop();
                              },
                              child: const Text(
                                'See results',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// شريحة داخل الـ modals بأسلوب Epic.
  Widget _modalChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? EpicColors.blue : EpicColors.elevated,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? EpicColors.blue : EpicColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : EpicColors.textPrimary,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EpicColors.background,
      appBar: AppBar(
        automaticallyImplyLeading:
            ModalRoute.of(context)?.isFirst != true,
        title: const Text('Browse'),
      ),
      body: Column(
        children: [
          // حقل البحث + زرا Sort وFilter بأسلوب Epic
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: _saveRecent,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(
                      color: EpicColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: EpicColors.textSecondary,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: EpicColors.textSecondary,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _showSortSheet,
                  icon: const Icon(Icons.sort_rounded, size: 22),
                  color: EpicColors.textPrimary,
                  tooltip: 'Sort',
                ),
                IconButton(
                  onPressed: _showFilterSheet,
                  icon: const Icon(Icons.tune_rounded, size: 22),
                  color: EpicColors.textPrimary,
                  tooltip: 'Filter',
                ),
              ],
            ),
          ),
          // Recent Searches بأسلوب Epic (تظهر فقط بدون استعلام حالي)
          if (_recent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Searches',
                      style: TextStyle(
                        color: EpicColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearRecent,
                    child: const Text(
                      'Clear Recent Searches',
                      style: TextStyle(
                        color: EpicColors.cyan,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_recent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recent.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, int i) {
                    return GestureDetector(
                      onTap: () {
                        _searchController.text = _recent[i];
                        _searchController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _recent[i].length),
                        );
                        _applyFilters();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: EpicColors.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: EpicColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.history_rounded,
                              size: 13,
                              color: EpicColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _recent[i],
                              style: const TextStyle(
                                color: EpicColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Game>>(
              future: _future,
              builder: (context, AsyncSnapshot<List<Game>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: LoadingGrid(itemCount: 6),
                  );
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message: snapshot.error.toString(),
                    onRetry: _applyFilters,
                  );
                }
                final List<Game> results =
                    _postProcess(snapshot.data ?? const <Game>[]);
                if (results.isEmpty) {
                  final String q = _searchController.text.trim();
                  if (q.isNotEmpty && !_hasActiveFilters) {
                    // حالة: لا نتائج بحث (نص Epic الحرفي)
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 110),
                        EmptyView(
                          icon: Icons.search_off_rounded,
                          title: 'No results for "$q"',
                          message: 'Check your spelling and try again!',
                        ),
                      ],
                    );
                  }
                  // حالة: الفلاتر تمنع النتائج (نص Epic الحرفي)
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 110),
                      EmptyView(
                        icon: Icons.filter_alt_off_rounded,
                        title: 'Sorry, nothing matched.',
                        message: 'Edit your filters to see more results.',
                        actionLabel: 'Reset all filters',
                        onAction: () {
                          setState(() {
                            _searchController.clear();
                            _category = null;
                            _priceFilter = 'all';
                            _discountedOnly = false;
                            _sort = _SearchSort.none;
                          });
                          _applyFilters();
                        },
                      ),
                    ],
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
}
