import 'package:flutter/foundation.dart';

import '../models/game.dart';
import '../services/wishlist_service.dart';

/// مدير قائمة المفضلة (Wishlist) بأسلوب Epic: مفردة عامة تُعلم كل الشاشات
/// عند أي إضافة أو إزالة، وتُحفظ محليًا على الجهاز.
class WishlistController extends ChangeNotifier {
  WishlistController._(this._service);

  static final WishlistController instance =
      WishlistController._(WishlistService());

  final WishlistService _service;
  final List<Game> _games = [];
  bool _loaded = false;

  /// قائمة المفضلة الحالية (للقراءة فقط).
  List<Game> get games => List.unmodifiable(_games);

  /// عدد العناصر — يُستخدم لشارة تبويب المفضلة في الشريط السفلي.
  int get count => _games.length;

  /// هل تم تحميل المفضلة من التخزين المحلي؟
  bool get loaded => _loaded;

  /// هل اللعبة موجودة في المفضلة؟
  bool contains(int id) => _games.any((g) => g.id == id);

  /// تحميل المفضلة مرة واحدة عند بدء التطبيق.
  Future<void> load() async {
    if (_loaded) return;
    _games
      ..clear()
      ..addAll(await _service.loadGames());
    _loaded = true;
    notifyListeners();
  }

  /// إضافة لعبة إلى المفضلة.
  Future<void> add(Game game) async {
    if (contains(game.id)) return;
    _games.insert(0, game);
    notifyListeners();
    await _service.saveGames(_games);
  }

  /// إزالة لعبة من المفضلة حسب المعرف.
  Future<void> remove(int id) async {
    _games.removeWhere((g) => g.id == id);
    notifyListeners();
    await _service.saveGames(_games);
  }

  /// إضافة أو إزالة حسب الحالة الحالية — يعيد الحالة بعد التغيير.
  Future<bool> toggle(Game game) async {
    if (contains(game.id)) {
      await remove(game.id);
      return false;
    }
    await add(game);
    return true;
  }
}
