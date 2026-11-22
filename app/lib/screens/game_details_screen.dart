import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/game.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/rating_stars.dart';

/// شاشة تفاصيل اللعبة: غلاف كبير، وصف، تقييم بالنجوم، سعر، وأزرار الشراء والإضافة للمكتبة.
class GameDetailsScreen extends StatefulWidget {
  final Game game;
  final ApiService api;
  final LibraryController library;

  const GameDetailsScreen({
    super.key,
    required this.game,
    required this.api,
    required this.library,
  });

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  late Game _game = widget.game;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// تحديث بيانات اللعبة من الخادم بصمت (إن فشل نبقى على البيانات الحالية).
  Future<void> _refresh() async {
    try {
      final fresh = await widget.api.getGame(widget.game.id);
      if (!mounted) return;
      setState(() => _game = fresh);
    } catch (_) {
      // نتجاهل الخطأ ونعرض البيانات القادمة من القائمة
    }
  }

  /// حوار تأكيد الشراء ثم إضافة اللعبة للمكتبة.
  void _buy() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الشراء'),
        content: Text(
          _game.isFree
              ? 'هل تريد الحصول على "${_game.name}" مجانًا؟'
              : 'سيتم شراء "${_game.name}" بمبلغ ${_game.finalPriceLabel}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: FluxColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.library.add(_game);
              _showToast(_game.isFree ? 'أصبحت اللعبة في مكتبتك الآن 🎮' : 'تم الشراء وأُضيفت اللعبة إلى مكتبتك 🎮');
            },
            child: const Text(
              'تأكيد',
              style: TextStyle(color: FluxColors.pink, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// رسالة تأكيد سفلية.
  void _showToast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.library,
      builder: (context, _) {
        final inLibrary = widget.library.contains(_game.id);
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // غلاف اللعبة مع شريط علوي متدرج
              SliverAppBar(
                pinned: true,
                expandedHeight: 300,
                iconTheme: const IconThemeData(color: FluxColors.textPrimary),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      _coverImage(),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              FluxColors.background,
                              FluxColors.background.withOpacity(.3),
                              Colors.transparent,
                            ],
                            stops: const [0, .4, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // محتوى التفاصيل
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // التصنيف + شارة المميزة
                      Row(
                        children: [
                          _chip(
                            _game.categoryDisplay,
                            FluxColors.pink.withOpacity(.18),
                            FluxColors.pink,
                          ),
                          const SizedBox(width: 8),
                          if (_game.isFeatured)
                            _chip(
                              'لعبة مميزة',
                              FluxColors.cyan.withOpacity(.15),
                              FluxColors.cyan,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // الاسم
                      Text(
                        _game.name,
                        style: const TextStyle(
                          color: FluxColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // التقييم + تاريخ الإصدار
                      Row(
                        children: [
                          RatingStars(rating: _game.rating, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _game.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: FluxColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Icon(Icons.calendar_month_rounded, size: 15, color: FluxColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            _game.releaseDate,
                            style: const TextStyle(color: FluxColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // الوصف
                      const Text(
                        'عن اللعبة',
                        style: TextStyle(
                          color: FluxColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _game.description,
                        style: const TextStyle(
                          color: FluxColors.textMuted,
                          fontSize: 14,
                          height: 1.9,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // بطاقة السعر
                      _priceCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // أزرار الإضافة للمكتبة والشراء
          bottomNavigationBar: Container(
            color: FluxColors.background,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _outlinedActionButton(inLibrary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _buy,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: FluxColors.pinkPurple,
                            boxShadow: neonGlow(FluxColors.pink),
                          ),
                          child: Center(
                            child: Text(
                              _game.isFree ? 'احصل عليها مجانًا' : 'شراء الآن',
                              style: const TextStyle(
                                color: FluxColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// زر الإضافة/الإزالة من المكتبة.
  Widget _outlinedActionButton(bool inLibrary) {
    final edge = inLibrary ? FluxColors.cyan : FluxColors.textMuted;
    return GestureDetector(
      onTap: () async {
        await widget.library.toggle(_game);
        if (!mounted) return;
        _showToast(inLibrary ? 'تمت إزالة اللعبة من مكتبتك' : 'تمت إضافة اللعبة إلى مكتبتك');
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: FluxColors.surface.withOpacity(.6),
          border: Border.all(color: edge.withOpacity(.75), width: 1.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              inLibrary ? Icons.check_rounded : Icons.bookmark_add_rounded,
              size: 20,
              color: edge,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                inLibrary ? 'في مكتبتك' : 'أضف للمكتبة',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: edge,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بطاقة السعر مع شارة نسبة التوفير.
  Widget _priceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: FluxColors.surface,
        border: Border.all(color: FluxColors.pink.withOpacity(.35)),
        boxShadow: [BoxShadow(color: FluxColors.pink.withOpacity(.12), blurRadius: 20)],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('السعر', style: TextStyle(color: FluxColors.textMuted, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (_game.hasDiscount) ...[
                    Text(
                      _game.priceLabel,
                      style: const TextStyle(
                        color: FluxColors.textMuted,
                        fontSize: 14,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _game.finalPriceLabel,
                    style: TextStyle(
                      color: _game.isFree ? FluxColors.cyan : FluxColors.pink,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          if (_game.hasDiscount)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: FluxColors.orange.withOpacity(.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FluxColors.orange.withOpacity(.5)),
              ),
              child: Text(
                'وفّر ${_game.discountPercent}%',
                style: const TextStyle(
                  color: FluxColors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// صورة الغلاف الكبيرة.
  Widget _coverImage() {
    if (_game.banner.isEmpty && _game.image.isEmpty) {
      return Container(
        color: FluxColors.card,
        child: const Center(
          child: Icon(Icons.videogame_asset_rounded, size: 70, color: FluxColors.purple),
        ),
      );
    }
    final url = _game.banner.isNotEmpty ? _game.banner : _game.image;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: FluxColors.card,
        child: const Center(
          child: Icon(Icons.videogame_asset_rounded, size: 70, color: FluxColors.purple),
        ),
      ),
      loadingBuilder: (context, child, progress) =>
          progress == null
              ? child
              : Container(
                  color: FluxColors.card,
                  child: const Center(
                    child: CircularProgressIndicator(color: FluxColors.pink),
                  ),
                ),
    );
  }

  /// شارة صغيرة ملونة.
  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
