import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/library_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../models/game.dart';
import '../services/auth_service.dart';
import '../services/download_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/page_fade_transition.dart';
import 'downloads_screen.dart';
import 'game_details_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'wishlist_screen.dart';

/// الهيكل الرئيسي بأسلوب Epic: شريط علوي بشعار FLUX + تنقل سفلي متحرك.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.controller});

  final LibraryController controller;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  FocusNode _downloadsSearchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // تحميل المكتبة والمفضلة المحفوظتين محليًا عند بدء التطبيق
    widget.controller.load();
    WishlistController.instance.load();
  }

  @override
  void dispose() {
    _downloadsSearchFocus.dispose();
    super.dispose();
  }

  // أربعة تبويبات بأسلوب تطبيق Epic للجوال: المتجر، المكتبة، المفضلة، التنزيلات
  // (البحث والحساب عبر أزرار الترويسة)
  static const List<IconData> _icons = [
    Icons.storefront_rounded,
    Icons.video_library_rounded,
    Icons.favorite_outline_rounded,
    Icons.download_rounded,
  ];

  static const List<String> _labels = [
    'Store',
    'Library',
    'Wishlist',
    'Downloads',
  ];

  void _setTab(int i) => setState(() => _index = i);

  /// فتح صفحة تفاصيل لعبة من أي قسم.
  void _openGame(Game game) {
    Navigator.of(context).push(
      epicRoute(GameDetailsScreen(game: game, controller: widget.controller)),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      epicRoute(
        SearchScreen(initialCategory: null, onOpenGame: _openGame),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      epicRoute(ProfileScreen(controller: widget.controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EpicColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            // شعار FLUX (الصورة المرفوعة) بدل النص القديم
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/brand/flux_badge.png',
                height: 34,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            // كلمة STORE بخط غامق بجانب الشعار
            const Text(
              'STORE',
              style: TextStyle(
                color: EpicColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
              ),
            ),
            if (_index == 3) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: EpicColors.elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: EpicColors.border),
                ),
                child: const Text(
                  'Downloads',
                  style: TextStyle(
                    color: EpicColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            // في تبويب التنزيلات: البحث يفلتر التنزيلات المحملة داخل القسم نفسه
            onPressed: () {
              if (_index == 3) {
                _downloadsSearchFocus.requestFocus();
              } else {
                _openSearch();
              }
            },
            icon: const Icon(Icons.search_rounded, size: 22),
            tooltip: 'Search',
          ),
          ListenableBuilder(
            listenable: AuthService.instance,
            builder: (context, _) {
              final user = AuthService.instance.currentUser;
              final bool loggedIn = user != null;
              return IconButton(
                onPressed: _openProfile,
                icon: loggedIn && user.name.isNotEmpty
                    ? Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [EpicColors.blue, EpicColors.cyan],
                          ),
                        ),
                        child: Text(
                          user.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : const Icon(Icons.person_outline_rounded, size: 22),
                tooltip: loggedIn ? user.name : 'Account',
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(controller: widget.controller, onOpenGame: _openGame),
          // تبويب المكتبة — نفس شاشة مكتبة اللاعب مع زر تصفح يعيد للمتجر
          LibraryScreen(
            controller: widget.controller,
            onBrowse: () => _setTab(0),
          ),
          // تبويب قائمة المفضلة بأسلوب Epic
          WishlistScreen(
            libraryController: widget.controller,
            onBrowse: () => _setTab(0),
          ),
          DownloadsScreen(
            controller: widget.controller,
            onOpenGame: _openGame,
            searchFocus: _downloadsSearchFocus,
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([
          DownloadManager.instance,
          WishlistController.instance,
        ]),
        builder: (context, _) => _bottomNav(),
      ),
    );
  }

  /// شريط التنقل السفلي المخصص: مؤشر أزرق متحرك + تكبير الأيقونة المختارة.
  Widget _bottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: EpicColors.surface,
        border: Border(top: BorderSide(color: EpicColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (int i = 0; i < _labels.length; i++) Expanded(child: _navItem(i)),
          ],
        ),
      ),
    );
  }

  /// أيقونة التبويب — تبويب التنزيلات نقطة زرقاء عند وجود تنزيلات نشطة،
  /// وتبويب المفضلة شارة بعدد الألعاب المحفوظة (بأسلوب Epic).
  Widget _navIcon(int i, bool selected) {
    final Widget icon = Icon(
      _icons[i],
      size: 22,
      color: selected ? EpicColors.textPrimary : EpicColors.textSecondary,
    );

    // شارة عدد المفضلة على تبويب القلب
    if (i == 2) {
      final int count = WishlistController.instance.count;
      if (count > 0) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            PositionedDirectional(
              top: -4,
              end: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 15),
                decoration: BoxDecoration(
                  color: EpicColors.blue,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: EpicColors.surface, width: 1.5),
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        );
      }
      return icon;
    }

    // نقطة التنزيلات النشطة
    if (i == 3 && DownloadManager.instance.hasActive) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            top: -2,
            left: -4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: EpicColors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: EpicColors.surface, width: 1.5),
              ),
            ),
          ),
        ],
      );
    }
    return icon;
  }

  Widget _navItem(int i) {
    final bool selected = i == _index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        _setTab(i);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: selected ? 22 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: selected ? EpicColors.blue : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: _navIcon(i, selected),
            ),
            const SizedBox(height: 4),
            Text(
              _labels[i],
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? EpicColors.textPrimary
                    : EpicColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
