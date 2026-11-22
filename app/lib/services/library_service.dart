import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game.dart';

/// خدمة حفظ المكتبة محليًا على الجهاز عبر SharedPreferences.
class LibraryService {
  /// مفتاح التخزين المحلي
  static const String _storageKey = 'flux_library_games';

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
}
