import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/game.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_card.dart';
import '../widgets/status_views.dart';
import 'game_details_screen.dart';

/// شاشة البحث: كتابة اسم اللعبة + فلترة حسب التصنيف + عرض النتائج.
class SearchScreen extends StatefulWidget {
  final ApiService api;
  final LibraryController library;

  const SearchScreen({super.key, required this.api, required this.library});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  String _category = '';
  bool _loading = false;
  bool _searched = false;
  String? _error;
  List<Game> _results = [];

  /// التصنيفات المدعومة للفلترة (القيمة + الاسم المعروض).
  static const List<(String, String)> _categories = [
    ('', 'الكل'),
    ('action', 'أكشن'),
    ('adventure', 'مغامرات'),
    ('rpg', 'RPG'),
    ('racing', 'سباقات'),
    ('shooter', 'تصويب'),
    ('sports', 'رياضة'),
    ('strategy', 'استراتيجية'),
    ('sandbox', 'عالم مفتوح'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// بحث مؤجل (Debounce) حتى يتوقف المستخدم عن الكتابة.
  void _onQueryChanged(String value) {
    setState(() {}); // لتحديث زر المسح
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _runSearch);
  }

  /// تنفيذ البحث حسب النص والتصنيف المحدد.
  Future<void> _runSearch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.api.getGames(
        search: _controller.text.trim(),
        category: _category,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _searched = true;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _searched = true;
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
      appBar: AppBar(title: const Text('البحث')),
      body: Column(
        children: [
          // حقل البحث
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onQueryChanged,
              style: const TextStyle(color: FluxColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ابحث باسم اللعبة...',
                prefixIcon: const Icon(Icons.search_rounded, color: FluxColors.cyan, size: 22),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, color: FluxColors.textMuted, size: 20),
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                          _runSearch();
                        },
                      ),
              ),
            ),
          ),
          // شرائح التصنيفات
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (value, label) = _categories[i];
                final selected = value == _category;
                return GestureDetector(
                  onTap: () {
                    setState(() => _category = value);
                    _runSearch();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: selected ? FluxColors.pinkPurple : null,
                      color: selected ? null : FluxColors.surface,
                      border: selected
                          ? null
                          : Border.all(color: FluxColors.textMuted.withOpacity(.3)),
                      boxShadow: selected ? neonGlow(FluxColors.pink, blur: 12) : null,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? FluxColors.textPrimary : FluxColors.textMuted,
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // منطقة النتائج
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  /// عرض النتائج حسب الحالة الحالية.
  Widget _buildResults() {
    if (_loading) return const LoadingView();
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _runSearch);
    }
    if (!_searched) {
      return const EmptyView(
        icon: Icons.search_rounded,
        title: 'ابحث عن لعبتك المفضلة',
        subtitle: 'اكتب اسم اللعبة أو اختر تصنيفًا من الأعلى',
      );
    }
    if (_results.isEmpty) {
      return const EmptyView(
        icon: Icons.search_off_rounded,
        title: 'لا توجد نتائج مطابقة',
        subtitle: 'جرّب كلمة أخرى أو تصنيفًا مختلفًا',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: .66,
      ),
      itemCount: _results.length,
      itemBuilder: (context, i) => GameCard(
        game: _results[i],
        onTap: () => _openDetails(_results[i]),
      ),
    );
  }
}
