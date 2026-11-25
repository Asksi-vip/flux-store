import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/game.dart';
import '../services/download_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_in_slide.dart';
import '../widgets/game_card.dart';
import '../widgets/page_fade_transition.dart';
import '../widgets/price_tag.dart';
import '../widgets/status_views.dart';
import 'game_details_screen.dart';

/// شاشة المكتبة بأسلوب Epic للجوال: تابات (All/Favorite/Installed/Not Installed)
/// + بحث + ترتيب + bottom sheet لكل عنصر + حالات فارغة Epic حرفيًا.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.controller,
    required this.onBrowse,
  });

  final LibraryController controller;
  final VoidCallback onBrowse;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

enum _LibraryTab { all, favorite, installed, notInstalled }

enum _LibrarySort { favorites, aToZ, recentlyAdded }

class _LibraryScreenState extends State<LibraryScreen> {
  _LibraryTab _tab = _LibraryTab.all;
  _LibrarySort _sort = _LibrarySort.favorites;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isInstalled(Game g) =>
      DownloadManager.instance.taskFor(g.id)?.installed ?? false;

  List<Game> get _filtered {
    final LibraryController c = widget.controller;
    List<Game> games = c.games;
    switch (_tab) {
      case _LibraryTab.all:
        break;
      case _LibraryTab.favorite:
        games = games.where((Game g) => c.isFavorite(g.id)).toList();
        break;
      case _LibraryTab.installed:
        games = games.where(_isInstalled).toList();
        break;
      case _LibraryTab.notInstalled:
        games = games.where((Game g) => !_isInstalled(g)).toList();
        break;
    }
    if (_query.trim().isNotEmpty) {
      final String q = _query.trim().toLowerCase();
      games = games
          .where((Game g) =>
              g.name.toLowerCase().contains(q) ||
              g.categoryDisplay.toLowerCase().contains(q))
          .toList();
    }
    switch (_sort) {
      case _LibrarySort.favorites:
        games = [...games]
          ..sort((Game a, Game b) {
            final int fa = c.isFavorite(a.id) ? 0 : 1;
            final int fb = c.isFavorite(b.id) ? 0 : 1;
            return fa.compareTo(fb);
          });
        break;
      case _LibrarySort.aToZ:
        games = [...games]
          ..sort((Game a, Game b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _LibrarySort.recentlyAdded:
        // القائمة تُدرج الأحدث إضافة في المقدمة أصلًا — نعرضها كما هي
        break;
    }
    return games;
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: EpicColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Text(
                  'Sort',
                  style: TextStyle(
                    color: EpicColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final _LibrarySort s in _LibrarySort.values)
                ListTile(
                  leading: Icon(
                    _sort == s
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: _sort == s ? EpicColors.blue : EpicColors.textSecondary,
                    size: 20,
                  ),
                  title: Text(
                    switch (s) {
                      _LibrarySort.favorites => 'Favorites',
                      _LibrarySort.aToZ => 'A-Z',
                      _LibrarySort.recentlyAdded => 'Recently Added',
                    },
                    style: const TextStyle(
                      color: EpicColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    setState(() => _sort = s);
                    Navigator.of(ctx).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Bottom sheet تفاصيل العنصر بأسلوب Epic (Install size / Last updated / See more).
  void _showItemSheet(Game g) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: EpicColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (BuildContext ctx) {
        final bool fav = widget.controller.isFavorite(g.id);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        width: 52,
                        height: 68,
                        child: buildGameCover(g),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: EpicColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (g.download?.version.isNotEmpty ?? false) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Version ${g.download!.version}',
                              style: const TextStyle(
                                color: EpicColors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_installSize(g) > 0)
                  Text(
                    'Install size: ${_formatBytes(_installSize(g))}',
                    style: const TextStyle(
                      color: EpicColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                if (g.lastUpdated.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Last updated: ${g.lastUpdated}',
                    style: const TextStyle(
                      color: EpicColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: EpicColors.textPrimary,
                          side: const BorderSide(color: EpicColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          widget.controller.toggleFavorite(g);
                          setState(() {});
                        },
                        icon: Icon(
                          fav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 18,
                          color: fav ? EpicColors.danger : EpicColors.textSecondary,
                        ),
                        label: Text(fav ? 'Remove from Favorites' : 'Add to Favorites'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: EpicColors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            epicRoute(
                              GameDetailsScreen(
                                  game: g, controller: widget.controller),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_rounded, size: 18),
                        label: const Text('See more'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const List<String> units = ['B', 'KB', 'MB', 'GB'];
    double v = bytes.toDouble();
    int u = 0;
    while (v >= 1024 && u < units.length - 1) {
      v /= 1024;
      u++;
    }
    return '${v.toStringAsFixed(v >= 100 || u == 0 ? 0 : 1)} ${units[u]}';
  }

  /// حجم التنصيب التقديري: مجموع أحجام ملفات التحميل إن توفرت.
  static int _installSize(Game g) {
    final List<DownloadFile> files = g.download?.files ?? const <DownloadFile>[];
    if (files.isEmpty) return g.download?.size ?? 0;
    return files.fold<int>(0, (int s, DownloadFile f) => s + f.size);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        DownloadManager.instance,
      ]),
      builder: (context, _) {
        final List<Game> games = _filtered;
        return Column(
          children: [
            // بحث + ترتيب بأسلوب Epic
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (String v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: EpicColors.textSecondary,
                          size: 20,
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
                ],
              ),
            ),
            // التابات الأربعة بأسلوب Epic
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _LibraryTab.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, int i) {
                    final _LibraryTab t = _LibraryTab.values[i];
                    final bool selected = _tab == t;
                    return GestureDetector(
                      onTap: () => setState(() => _tab = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? EpicColors.blue : EpicColors.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: selected
                                ? EpicColors.blue
                                : EpicColors.border,
                          ),
                        ),
                        child: Text(
                          switch (t) {
                            _LibraryTab.all => 'All',
                            _LibraryTab.favorite => 'Favorite',
                            _LibraryTab.installed => 'Installed',
                            _LibraryTab.notInstalled => 'Not Installed',
                          },
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : EpicColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: games.isEmpty
                  ? _buildEmpty()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      children: [
                        for (int i = 0; i < games.length; i++)
                          FadeInSlide(
                            delay: Duration(milliseconds: 40 * (i % 8)),
                            child: _GameRow(
                              game: games[i],
                              controller: widget.controller,
                              onOpen: _openGame,
                              onSheet: () => _showItemSheet(games[i]),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  void _openGame(Game g) {
    Navigator.of(context).push(
      epicRoute(GameDetailsScreen(game: g, controller: widget.controller)),
    );
  }

  /// حالات الفراغ بأسلوب Epic حرفيًا لكل تاب وبحث.
  Widget _buildEmpty() {
    final bool searching = _query.trim().isNotEmpty;
    if (searching) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 110),
          EmptyView(
            icon: Icons.search_off_rounded,
            title: 'No results found',
            message: 'Try different search terms.',
            actionLabel: 'Reset search',
            onAction: () {
              _searchCtrl.clear();
              setState(() => _query = '');
            },
          ),
        ],
      );
    }
    switch (_tab) {
      case _LibraryTab.all:
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 110),
            EmptyView(
              icon: Icons.video_library_outlined,
              title: 'Nothing here yet',
              message: 'Get started by browsing games, apps, and more.',
              actionLabel: 'Browse store',
              onAction: widget.onBrowse,
            ),
          ],
        );
      case _LibraryTab.favorite:
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 110),
            EmptyView(
              icon: Icons.favorite_border_rounded,
              title: 'No favorites yet',
              message: 'Select the heart on an item to add it here.',
              actionLabel: 'Browse your library',
              onAction: () => setState(() => _tab = _LibraryTab.all),
            ),
          ],
        );
      case _LibraryTab.installed:
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 110),
            EmptyView(
              icon: Icons.download_done_rounded,
              title: 'Nothing here yet',
              message: 'Get started by browsing games, apps, and more.',
              actionLabel: 'Browse store',
              onAction: widget.onBrowse,
            ),
          ],
        );
      case _LibraryTab.notInstalled:
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 110),
            EmptyView(
              icon: Icons.cloud_download_outlined,
              title: 'Not installed yet',
              message: "Some of your games aren't installed yet.",
              actionLabel: 'Browse your library',
              onAction: () => setState(() => _tab = _LibraryTab.all),
            ),
          ],
        );
    }
  }
}

/// صف لعبة في المكتبة: غلاف مصغر + بيانات + قلب مفضلة + قائمة تفاصيل + سحب للحذف.
class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.game,
    required this.controller,
    required this.onOpen,
    required this.onSheet,
  });

  final Game game;
  final LibraryController controller;
  final ValueChanged<Game> onOpen;
  final VoidCallback onSheet;

  void _remove(BuildContext context) {
    controller.remove(game.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Removed from library'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => controller.add(game),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bool fav = controller.isFavorite(game.id);
    final bool installed =
        DownloadManager.instance.taskFor(game.id)?.installed ?? false;
    return Dismissible(
      key: ValueKey<int>(game.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _remove(context),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: EpicColors.danger.withOpacity(.18),
          border: Border.all(color: EpicColors.danger.withOpacity(.5)),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: EpicColors.danger,
          size: 26,
        ),
      ),
      child: GestureDetector(
        onTap: () => onOpen(game),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: EpicColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: EpicColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  width: 64,
                  height: 84,
                  child: buildGameCover(game),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: EpicColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.categoryDisplay,
                      style: const TextStyle(
                        color: EpicColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (installed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2.5),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: EpicColors.success,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Text(
                              'Installed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        PriceTag(game: game, fontSize: 12, showBadge: false),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => controller.toggleFavorite(game),
                icon: Icon(
                  fav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: fav ? EpicColors.danger : EpicColors.textSecondary,
                  size: 20,
                ),
                tooltip: fav
                    ? 'Remove from Favorites'
                    : 'Add to Favorites',
              ),
              IconButton(
                onPressed: onSheet,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: EpicColors.textSecondary,
                  size: 20,
                ),
                tooltip: 'See more',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
