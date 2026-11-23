import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/game.dart';

/// استثناء مخصص برسائل عربية واضحة تُعرض للمستخدم مباشرة.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// خدمة الاتصال بـ API متجر Flux (حزمة dio).
///
/// كل البيانات تُحفظ في SharedPreferences: عند نجاح الطلب تُحدَّث نسخة الكاش،
/// وعند فشل الاتصال تُعاد البيانات المحفوظة فورًا (مع تطبيق البحث والفلاتر
/// محليًا) — فلا يعيد التطبيق تحميل كل شيء من الصفر في كل مرة.
class ApiService {
  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
        // أي استجابة 400+ تُعتبر خطأ حتى تُعالج برسالة واضحة
        validateStatus: (code) => code != null && code < 400,
      ),
    );
  }

  /// نسخة وحيدة لكل التطبيق
  static final ApiService instance = ApiService._internal();

  late final Dio _dio;

  // ---------- مفاتيح الكاش المحلي (SharedPreferences) ----------

  /// الكاش الكامل لقائمة الألعاب (يسدّ كل طلبات getGames)
  static const String _kGamesCache = 'flux_cache_games_v1';

  /// الكاش الكامل لقائمة المميزة (البانر المتحرك)
  static const String _kFeaturedCache = 'flux_cache_featured_v1';

  /// وقت آخر تحديث ناجح للكاش
  static const String _kCacheStamp = 'flux_cache_stamp_v1';

  /// بادئة كاش تفاصيل كل لعبة: flux_cache_game_<المعرف>
  static const String _kGamePrefix = 'flux_cache_game_';

  /// الرسالة الموحدة عند انقطاع الإنترنت — بدل رسائل الخادم التقنية القديمة.
  static const String offlineMessage = 'فشل الاتصال بالإنترنت';

  /// تحويل أخطاء dio إلى رسائل عربية مفهومة للمستخدم.
  String _friendlyError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        // رسالة واضحة وموحدة عند انقطاع الشبكة (بدون تفاصيل الخادم)
        return offlineMessage;
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        if (code == 404) return 'العنصر المطلوب غير موجود';
        if (code >= 500) return 'خطأ في الخادم، حاول بعد قليل';
        return 'فشل الطلب (رمز $code)';
      default:
        return offlineMessage;
    }
  }

  // ---------- الكاش: حفظ واسترجاع ----------

  /// حفظ قائمة الألعاب في الكاش المحلي بعد نجاح الجلب.
  Future<void> _cacheGames(List<Game> games) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> plain = games
          .map((Game g) => g.toJson())
          .toList();
      await prefs.setString(_kGamesCache, jsonEncode(plain));
      await prefs.setString(
        _kCacheStamp,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {
      // فشل الكاش لا يفسد النتيجة
    }
  }

  /// قراءة قائمة الألعاب المحفوظة محليًا (أو قائمة فارغة).
  Future<List<Game>> cachedGames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_kGamesCache);
      if (raw == null || raw.isEmpty) return const [];
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((dynamic e) =>
              Game.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// حفظ تفاصيل لعبة واحدة في الكاش.
  Future<void> _cacheGame(Game game) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kGamePrefix + game.id.toString(),
          jsonEncode(game.toJson()));
    } catch (_) {}
  }

  /// قراءة تفاصيل لعبة محفوظة محليًا (أو null).
  Future<Game?> cachedGame(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_kGamePrefix + id.toString());
      if (raw == null || raw.isEmpty) return null;
      return Game.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  /// آخر وقت تحديث ناجح للكاش (أو null إذا لم يوجد كاش).
  Future<DateTime?> cacheStamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_kCacheStamp);
      if (raw == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(int.parse(raw));
    } catch (_) {
      return null;
    }
  }

  /// تطبيق فلاتر البحث والفئة والسعر محليًا على قائمة ألعاب الكاش —
  /// يُستخدم عند انقطاع الشبكة حتى تعمل كل الصفحات من البيانات المحفوظة.
  List<Game> _filterLocally(
    List<Game> games, {
    String? search,
    String? category,
    double? minPrice,
    double? maxPrice,
    bool? featured,
  }) {
    Iterable<Game> out = games;
    if (search != null && search.isNotEmpty) {
      final String q = search.toLowerCase();
      out = out.where((Game g) => g.name.toLowerCase().contains(q));
    }
    if (category != null && category.isNotEmpty) {
      out = out.where((Game g) => g.category == category);
    }
    if (minPrice != null) {
      out = out.where((Game g) => g.finalPrice >= minPrice);
    }
    if (maxPrice != null) {
      out = out.where((Game g) => g.finalPrice <= maxPrice);
    }
    if (featured == true) {
      out = out.where((Game g) => g.isFeatured);
    }
    return out.toList();
  }

  // ---------- الطلبات مع الكاش ----------

  /// جلب قائمة الألعاب مع دعم البحث والفلترة والترتيب.
  ///
  /// نجح الاتصال: تُحدَّث نسخة الكاش وتُعاد النتائج الطازجة.
  /// فشل الاتصال: تُعاد بيانات الكاش مع تطبيق نفس الفلاتر محليًا،
  /// وإن لم يوجد كاش أصلًا يُرمى استثناء برسالة [offlineMessage].
  Future<List<Game>> getGames({
    String? search,
    String? category,
    double? minPrice,
    double? maxPrice,
    bool? featured,
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '/games/',
        queryParameters: <String, dynamic>{
          if (search != null && search.isNotEmpty) 'search': search,
          if (category != null && category.isNotEmpty) 'category': category,
          if (minPrice != null) 'min_price': minPrice,
          if (maxPrice != null) 'max_price': maxPrice,
          if (featured != null && featured) 'featured': 'true',
          'page_size': 50,
          'page': page,
        },
      );
      final data = response.data;
      // استجابة تقسيم الصفحات تحتوي results، والاستجابة غير المقسمة قائمة مباشرة
      final List items =
          (data is Map && data['results'] is List) ? data['results'] : (data as List? ?? []);
      final List<Game> games =
          items.map((e) => Game.fromJson(e as Map<String, dynamic>)).toList();
      await _cacheGames(games);
      return games;
    } on DioException catch (e) {
      // انقطاع الشبكة: نرجع بيانات الكاش المحفوظة مع نفس الفلاتر
      final List<Game> cached = await cachedGames();
      if (cached.isNotEmpty) {
        return _filterLocally(
          cached,
          search: search,
          category: category,
          minPrice: minPrice,
          maxPrice: maxPrice,
          featured: featured,
        );
      }
      throw ApiException(_friendlyError(e));
    } catch (_) {
      final List<Game> cached = await cachedGames();
      if (cached.isNotEmpty) {
        return _filterLocally(
          cached,
          search: search,
          category: category,
          minPrice: minPrice,
          maxPrice: maxPrice,
          featured: featured,
        );
      }
      throw ApiException(offlineMessage);
    }
  }

  /// جلب تفاصيل لعبة واحدة حسب المعرف (شبكة ← كاش عند الفشل).
  Future<Game> getGame(int id) async {
    try {
      final response = await _dio.get('/games/$id/');
      final Game game =
          Game.fromJson(response.data as Map<String, dynamic>);
      await _cacheGame(game);
      return game;
    } on DioException {
      final Game? cached = await cachedGame(id);
      if (cached != null) return cached;
      throw ApiException(offlineMessage);
    } catch (_) {
      final Game? cached = await cachedGame(id);
      if (cached != null) return cached;
      throw ApiException(offlineMessage);
    }
  }

  /// طلب تحديث روابط التحميل من صفحات المصدر (ميديافاير/درايف) قبل البدء.
  ///
  /// الخادم يعيد استخراج الرابط المباشر فقط إذا كان قديمًا (أكثر من ساعتين)،
  /// ويعيد بيانات اللعبة بنفس صيغة التفاصيل. عند أي فشل تعيد null
  /// ويتابع التطبيق بالروابط المحفوظة كما هي.
  Future<Game?> refreshDownloadLinks(int gameId) async {
    try {
      final response = await _dio.get('/games/$gameId/refresh/');
      final data = response.data;
      if (data is Map && data['id'] != null) {
        return Game.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// جلب الألعاب المميزة (للبانر المتحرك) — من الشبكة أو من الكاش المخصص.
  Future<List<Game>> getFeatured() async {
    try {
      final response = await _dio.get(
        '/games/',
        queryParameters: <String, dynamic>{'featured': 'true', 'page_size': 50},
      );
      final data = response.data;
      final List items =
          (data is Map && data['results'] is List) ? data['results'] : (data as List? ?? []);
      final List<Game> games =
          items.map((e) => Game.fromJson(e as Map<String, dynamic>)).toList();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _kFeaturedCache,
          jsonEncode(games.map((Game g) => g.toJson()).toList()),
        );
      } catch (_) {}
      return games;
    } on DioException {
      final List<Game> cached = await cachedGames();
      final List<Game> featured =
          cached.where((Game g) => g.isFeatured).toList();
      if (featured.isNotEmpty) return featured;
      if (cached.isNotEmpty) return cached.take(5).toList();
      throw ApiException(offlineMessage);
    } catch (_) {
      throw ApiException(offlineMessage);
    }
  }

  /// فحص حالة الخادم (تُستخدم في شاشة الملف الشخصي).
  Future<bool> isServerOnline() async {
    try {
      final response = await _dio.get('/games/', queryParameters: {'page': 1});
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
