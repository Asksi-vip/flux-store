import 'package:flutter/foundation.dart';

import '../models/game.dart';
import '../services/library_service.dart';

/// مدير المكتبة: يربط الخدمة المحلية بالواجهات ويُعلمها عند أي تغيير.
class LibraryController extends ChangeNotifier {
  LibraryController(this._service);

  final LibraryService _service;
  final List<Game> _games = [];
  bool _loaded = false;

  /// قائمة الألعاب الحالية (للقراءة فقط).
  List<Game> get games => List.unmodifiable(_games);

  /// هل تم تحميل المكتبة من التخزين المحلي؟
  bool get loaded => _loaded;

  /// هل اللعبة موجودة في المكتبة؟
  bool contains(int id) => _games.any((g) => g.id == id);

  /// تحميل المكتبة مرة واحدة عند بدء التطبيق.
  Future<void> load() async {
    if (_loaded) return;
    _games
      ..clear()
      ..addAll(await _service.loadGames());
    _loaded = true;
    notifyListeners();
  }

  /// إضافة لعبة إلى المكتبة.
  Future<void> add(Game game) async {
    if (contains(game.id)) return;
    _games.insert(0, game);
    notifyListeners();
    await _service.saveGames(_games);
  }

  /// إزالة لعبة من المكتبة حسب المعرف.
  Future<void> remove(int id) async {
    _games.removeWhere((g) => g.id == id);
    notifyListeners();
    await _service.saveGames(_games);
  }

  /// إضافة أو إزالة حسب الحالة الحالية.
  Future<void> toggle(Game game) async {
    if (contains(game.id)) {
      await remove(game.id);
    } else {
      await add(game);
    }
  }
}
