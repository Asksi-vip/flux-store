import 'package:dio/dio.dart';

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

  /// تحويل أخطاء dio إلى رسائل عربية مفهومة للمستخدم.
  String _friendlyError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'انتهت مهلة الاتصال بالخادم، تحقق من الإنترنت وحاول مجددًا';
      case DioExceptionType.connectionError:
        return 'تعذر الوصول إلى الخادم — تأكد من تشغيل الـ API ومن صحة العنوان في lib/config.dart';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        if (code == 404) return 'العنصر المطلوب غير موجود';
        if (code >= 500) return 'خطأ في الخادم، حاول بعد قليل';
        return 'فشل الطلب (رمز $code)';
      default:
        return 'حدث خطأ غير متوقع، حاول مجددًا';
    }
  }

  /// جلب قائمة الألعاب مع دعم البحث والفلترة والترتيب.
  ///
  /// [search] بحث بالاسم، [category] تصنيف، [minPrice]/[maxPrice] نطاق السعر،
  /// [featured] المميزة فقط، [page] رقم الصفحة.
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
          'page': page,
        },
      );
      final data = response.data;
      // استجابة تقسيم الصفحات تحتوي results، والاستجابة غير المقسمة قائمة مباشرة
      final List items =
          (data is Map && data['results'] is List) ? data['results'] : (data as List? ?? []);
      return items.map((e) => Game.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException(_friendlyError(e));
    } catch (_) {
      throw ApiException('تعذر تحليل بيانات الألعاب، حاول مجددًا');
    }
  }

  /// جلب تفاصيل لعبة واحدة حسب المعرف.
  Future<Game> getGame(int id) async {
    try {
      final response = await _dio.get('/games/$id/');
      return Game.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException(_friendlyError(e));
    } catch (_) {
      throw ApiException('تعذر تحميل تفاصيل اللعبة');
    }
  }

  /// جلب الألعاب المميزة (للبانر المتحرك).
  Future<List<Game>> getFeatured() => getGames(featured: true);

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
