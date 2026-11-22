import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../services/api_service.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

/// الهيكل الرئيسي: يربط الشاشات الأربع مع شريط التنقل السفلي.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final ApiService _api = ApiService.instance;
  late final LibraryController _library = LibraryController(LibraryService());
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _library.load();
  }

  // الشاشات الأربعة — تُبنى مرة واحدة وتُحفظ حالتها عبر IndexedStack
  late final List<Widget> _screens = [
    HomeScreen(api: _api, library: _library),
    SearchScreen(api: _api, library: _library),
    LibraryScreen(api: _api, library: _library),
    ProfileScreen(api: _api, library: _library),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: FluxColors.surface,
          border: Border(
            top: BorderSide(color: FluxColors.pink.withOpacity(.35)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.5),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: FluxColors.pink,
          unselectedItemColor: FluxColors.textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: 'البحث',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.videogame_asset_rounded),
              label: 'المكتبة',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'حسابي',
            ),
          ],
        ),
      ),
    );
  }
}
