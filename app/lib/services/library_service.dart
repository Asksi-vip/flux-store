import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game.dart';

/// خدمة حفظ المكتبة محليًا على الجهاز عبر SharedPreferences.
class LibraryService {
  /// مفتاح التخزين المحلي
  static const String _storageKey = 'flux_library_games';

  /// مفتاح تخزين معرفات مفضلة المكتبة
  static const String _favoritesKey = 'flux_library_favorites';

  /// تحميل قائمة الألعاب المحفوظة (تتجاهل أي سجل تالف).
  Future<List<Game>> loadGames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? const [];
    return raw
        .map((item) {
          try {
            return Game.fromJson(jsonDecode(item) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Game>()
        .toList();
  }

  /// حفظ القائمة كاملة في التخزين المحلي.
  Future<void> saveGames(List<Game> games) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = games.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList(_storageKey, raw);
  }

  /// تحميل معرفات المفضلة المحفوظة (مفاتيح قلب المكتبة بأسلوب Epic).
  Future<Set<int>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favoritesKey) ?? const [];
    return raw
        .map((item) {
          try {
            return int.parse(item);
          } catch (_) {
            return null;
          }
        })
        .whereType<int>()
        .toSet();
  }

  /// حفظ معرفات المفضلة في التخزين المحلي.
  Future<void> saveFavorites(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _favoritesKey, ids.map((int id) => '$id').toList());
  }
}
