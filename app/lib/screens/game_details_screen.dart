import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../models/game.dart';
import '../services/api_service.dart';
import '../services/download_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/download_button.dart';
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

  /// لعبة مجانية بلا ملفات تحميل — رسالة واضحة بدل الفشل الصامت.
  void _installNotAvailable() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'ملفات التحميل غير مضافة لهذه اللعبة بعد — أضف رابط APK من لوحة الإدارة',
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
                          // قلب المفضلة بأسلوب Epic في ترويسة البانر
                          _WishCircleButton(game: game),
                          if (game.hasDiscount) ...[
                            const SizedBox(width: 10),
                            DiscountBadge(
                              percent: game.discountPercent,
                              fontSize: 14,
                            ),
                          ],
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
                    // التصنيفات المتعددة (أو الأساسية احتياطيًا)
                    _categoriesChips(),
                    const SizedBox(height: 8),
                    if (game.developer.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          game.developer,
                          style: const TextStyle(
                            color: EpicColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
                      child: game.isDownloadable
                          ? KeyedSubtree(
                              key: const ValueKey<String>('dl'),
                              child: DownloadButton(
                                game: game,
                                onClaim: () {
                                  // مثل "الاستحواذ" في Epic: اللعبة تدخل المكتبة عند بدء التحميل
                                  if (!widget.controller.contains(game.id)) {
                                    widget.controller.add(game);
                                  }
                                },
                              ),
                            )
                          : inLibrary
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
                              child: game.isFree
                                  ? EpicButton(
                                      label: 'تثبيت مباشر',
                                      icon: Icons.download_rounded,
                                      onPressed: _installNotAvailable,
                                    )
                                  : EpicButton(
                                      label: 'أضف إلى المكتبة',
                                      icon: Icons.add_circle_outline_rounded,
                                      onPressed: _toggleLibrary,
                                    ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    // صف السعر — للألعاب المدفوعة فقط (المجانية زر تثبيت مباشر بدل السعر)
                    if (!game.isFree)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: EpicColors.surface,
                          borderRadius: BorderRadius.circular(12),
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
                            const SizedBox(width: 10),
                            // قلب المفضلة داخل مربع السعر أيضًا
                            _WishCircleButton(game: game),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    // بطاقة معلومات بنمط سوق أبِل: المطور، التواريخ، الحجم، الإصدار، الحزمة
                    if (_hasInfoRows()) ...[
                      const Text(
                        'معلومات',
                        style: TextStyle(
                          color: EpicColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: EpicColors.surface,
                          border: Border.all(color: EpicColors.border),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: _infoRows(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // معلومات التحميل: الإصدار، الحجم، وملفات OBB/Data بمساراتها التلقائية
                    if (game.download != null && game.download!.available) ...[
                      const Text(
                        'معلومات التحميل',
                        style: TextStyle(
                          color: EpicColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: EpicColors.surface,
                          border: Border.all(color: EpicColors.border),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.download_rounded,
                                  color: EpicColors.cyan,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    game.download!.version.isNotEmpty
                                        ? 'الإصدار ${game.download!.version}'
                                        : 'متاحة للتحميل المباشر',
                                    style: const TextStyle(
                                      color: EpicColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatBytes(game.download!.files.fold<int>(
                                    0,
                                    (int s, DownloadFile f) => s + f.size,
                                  )),
                                  style: const TextStyle(
                                    color: EpicColors.cyan,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            ...game.download!.files
                                .where((DownloadFile f) => !f.isApk)
                                .map(
                                  (DownloadFile f) => Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${f.name} (${f.type.toUpperCase()} — ${formatBytes(f.size)})',
                                          style: const TextStyle(
                                            color: EpicColors.textSecondary,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'يُحفظ تلقائيًا في: ${f.installPath}',
                                          style: const TextStyle(
                                            color: EpicColors.textSecondary,
                                            fontSize: 10,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            const SizedBox(height: 6),
                            const Text(
                              'استكمال تلقائي: إذا انقطع الإنترنت أو أُغلق التطبيق، يكمل التحميل من نفس النقطة عند العودة',
                              style: TextStyle(
                                color: EpicColors.textSecondary,
                                fontSize: 10.5,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

  // ---------- شرائح التصنيفات وبطاقة المعلومات (نمط سوق أبِل) ----------

  /// شرائح التصنيفات المتعددة — احتياطيًا التصنيف الأساسي.
  Widget _categoriesChips() {
    final List<String> names = widget.game.categoriesDisplay.isNotEmpty
        ? widget.game.categoriesDisplay
        : (widget.game.categoryDisplay.isNotEmpty ? <String>[widget.game.categoryDisplay] : <String>[]);
    if (names.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: names
          .map(
            (String n) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: EpicColors.cyan.withOpacity(.12),
                border: Border.all(color: EpicColors.cyan.withOpacity(.6)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                n,
                style: const TextStyle(
                  color: EpicColors.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  /// هل توجد صفوف معلومات كافية للعرض؟
  bool _hasInfoRows() =>
      widget.game.developer.isNotEmpty ||
      widget.game.releaseDate.isNotEmpty ||
      widget.game.lastUpdated.isNotEmpty ||
      widget.game.packageName.isNotEmpty ||
      (widget.game.download?.version.isNotEmpty ?? false);

  /// صف بطاقة المعلومات.
  static Widget _infoRow(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: last
              ? BorderSide.none
              : BorderSide(color: EpicColors.border.withOpacity(.6)),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: EpicColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: EpicColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// صفوف بطاقة المعلومات (تظهر فقط للحقول المعبأة).
  List<Widget> _infoRows() {
    final List<MapEntry<String, String>> items = <MapEntry<String, String>>[];
    void add(String label, String value) {
      if (value.isEmpty) return;
      items.add(MapEntry<String, String>(label, value));
    }

    add('المطوّر', widget.game.developer);
    add('تاريخ الإصدار', _fmtDate(widget.game.releaseDate));
    add('آخر تحديث', _fmtDate(widget.game.lastUpdated));
    if (widget.game.download != null && widget.game.download!.version.isNotEmpty) {
      add('الإصدار', widget.game.download!.version);
    }
    add('الحزمة', widget.game.packageName);

    return List<Widget>.generate(items.length, (int i) {
      return _infoRow(items[i].key, items[i].value, last: i == items.length - 1);
    });
  }

  /// تنسيق تاريخ YYYY-MM-DD إلى صيغة عربية مقروءة (12 مايو 2024).
  String _fmtDate(String iso) {
    if (iso.isEmpty) return '';
    final RegExpMatch? m =
        RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
    if (m == null) return iso;
    const List<String> months = <String>[
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final int mi = (int.tryParse(m.group(2) ?? '') ?? 1) - 1;
    return '${int.tryParse(m.group(3) ?? '') ?? ''} ${mi >= 0 && mi < 12 ? months[mi] : ''} ${m.group(1)}';
  }
}

/// زر قلب المفضلة الدائري في صفحة التفاصيل: دائرة داكنة على البانر تتحول لقلب
/// مملوء سماوي عند الحفظ، مع إشعار وزر تراجع — بنمط متجر Epic.
class _WishCircleButton extends StatelessWidget {
  const _WishCircleButton({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WishlistController.instance,
      builder: (context, _) {
        final bool saved = WishlistController.instance.contains(game.id);
        return GestureDetector(
          onTap: () async {
            final bool added = await WishlistController.instance.toggle(game);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    added ? 'أُضيفت إلى قائمة المفضلة' : 'أُزيلت من قائمة المفضلة',
                  ),
                  action: SnackBarAction(
                    label: added ? 'تراجع' : 'استعادة',
                    onPressed: () => WishlistController.instance.toggle(game),
                  ),
                ),
              );
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: saved
                  ? EpicColors.cyan.withOpacity(.18)
                  : Colors.black.withOpacity(.45),
              border: Border.all(
                color: saved ? EpicColors.cyan : Colors.white.withOpacity(.4),
                width: 1,
              ),
            ),
            child: Icon(
              saved ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
              size: 19,
              color: saved ? EpicColors.cyan : Colors.white,
            ),
          ),
        );
      },
    );
  }
}
