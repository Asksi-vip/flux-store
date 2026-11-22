import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/game.dart';
import '../theme/app_theme.dart';
import '../widgets/page_fade_transition.dart';
import 'game_details_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

/// الهيكل الرئيسي بأسلوب Epic: شريط علوي بشعار FLUX + تنقل سفلي متحرك.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.controller});

  final LibraryController controller;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const List<IconData> _icons = [
    Icons.storefront_rounded,
    Icons.search_rounded,
    Icons.video_library_rounded,
    Icons.person_rounded,
  ];

  static const List<String> _labels = ['المتجر', 'البحث', 'المكتبة', 'حسابي'];

  static const List<String> _titles = [
    'متجر FLUX',
    'تصفح الألعاب',
    'مكتبتي',
    'حسابي',
  ];

  void _setTab(int i) => setState(() => _index = i);

  /// فتح صفحة تفاصيل لعبة من أي قسم.
  void _openGame(Game game) {
    Navigator.of(context).push(
      epicRoute(GameDetailsScreen(game: game, controller: widget.controller)),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: EpicColors.elevated,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: EpicColors.border),
              ),
              child: const Text(
                'FLUX',
                style: TextStyle(
                  color: EpicColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _titles[_index],
              style: const TextStyle(
                color: EpicColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _setTab(1),
            icon: const Icon(Icons.search_rounded, size: 22),
            tooltip: 'البحث',
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(controller: widget.controller, onOpenGame: _openGame),
          SearchScreen(
            initialCategory: null,
            onOpenGame: _openGame,
          ),
          LibraryScreen(
            controller: widget.controller,
            onBrowse: () => _setTab(0),
          ),
          ProfileScreen(controller: widget.controller),
        ],
      ),
      bottomNavigationBar: _bottomNav(),
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

  Widget _navItem(int i) {
    final bool selected = i == _index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setTab(i),
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
              child: Icon(
                _icons[i],
                size: 22,
                color: selected
                    ? EpicColors.textPrimary
                    : EpicColors.textSecondary,
              ),
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
