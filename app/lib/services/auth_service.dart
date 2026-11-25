import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/user_model.dart';

/// خدمة المصادقة الذاتية على سيرفر الخاص (بديل Firebase):
/// - توليد رمز التحقق OTP على الخادم وإرساله عبر بوابة SMS التي تديرها انت
/// - تسجيل الدخول وإنشاء الحساب برقم الهاتف + OTP + كلمة المرور
/// - إعادة تعيين كلمة المرور عبر كود OTP المرسل للهاتف
/// - جلسات محفوظة محليًا مع Bearer token من الخادم
class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _kStorageKey = 'flux_auth_user_v1';
  static const String _kTokenKey = 'flux_auth_token_v1';
  static const String _kPasswordMapKey = 'flux_user_pwd_hashes';

  final Dio _dio = Dio(
    BaseOptions(
      // ملف المصادقة على خادمك: <apiBaseUrl>/auth.php?action=...
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
      // نقبل كل الحالات ونفحص ok/error يدويًا برسائل عربية واضحة
      validateStatus: (code) => code != null && code >= 200 && code < 600,
    ),
  );

  UserModel? _currentUser;
  String? _token;
  bool _initialized = false;

  /// المستخدم الحالي المسجل
  UserModel? get currentUser => _currentUser;

  /// هل المستخدم مسجل الدخول؟
  bool get isLoggedIn => _currentUser != null;

  /// رمز التجربة من وضع debug (يظهر داخل شاشة إدخال الرمز فقط عندما
  /// لا تكون بوابة SMS مفعلة على الخادم — مرة واحدة لكل طلب)
  String? lastDevCode;

  /// ثواني الانتظار قبل طلب رمز جديد (يعود من الخادم عند تجاوز الحد)
  int? lastResendAfter;

  /// تهيئة الخدمة واستعادة الجلسة السابقة
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_kStorageKey);
      if (raw != null && raw.isNotEmpty) {
        _currentUser = UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
      _token = prefs.getString(_kTokenKey);
    } catch (_) {}
    notifyListeners();

    // تحقق صامت من صلاحية الجلسة: إن رفض الخادم الجلسة صراحة نلغيها محليًا
    if (_token != null) {
      unawaited(_validateSession());
    }
  }

  Future<void> _validateSession() async {
    try {
      final Response<Map<String, dynamic>> res = await _dio.get(
        '/auth.php',
        queryParameters: {'action': 'me'},
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
      final data = res.data;
      if (data != null && data['ok'] != true) {
        // الجلسة منتهية أو غير صالحة على الخادم — خروج صامت
        _currentUser = null;
        _token = null;
        await _persist();
        notifyListeners();
      }
    } catch (_) {
      // تعذر الاتصال: نبقي الجلسة المحلية (وضع عدم الاتصال)
    }
  }

  /// تنظيف وتوحيد رقم الهاتف بالصيغة الدولية E.164 (مثل +9647701234567)
  static String normalizePhone(String phone, {String countryCode = '+964'}) {
    String clean = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (clean.startsWith('+')) return clean;
    if (clean.startsWith('00')) return '+${clean.substring(2)}';
    if (clean.startsWith('0')) clean = clean.substring(1);
    final String cc = countryCode.startsWith('+') ? countryCode : '+$countryCode';
    return '$cc$clean';
  }

  /// إزالة الرموز للحصول على أرقام فقط
  static String cleanDigits(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  // ---------- طبقة الاتصال بالخادم ----------

  /// طلب POST موحد: يفحص ok/error ويعيد البيانات أو يرمي استثناء برسالة عربية
  Future<Map<String, dynamic>> _post(String action, Map<String, dynamic> body) async {
    final Response<Map<String, dynamic>> res = await _dio.post(
      '/auth.php',
      queryParameters: {'action': action},
      data: body,
    );
    final Map<String, dynamic> data = res.data ?? <String, dynamic>{};

    final bool ok = data['ok'] == true;
    if (!ok) {
      final int code = res.statusCode ?? 500;
      String msg = (data['error'] as String?) ?? 'An unexpected error occurred. Please try again.';
      if (data['resend_after'] is int) {
        lastResendAfter = data['resend_after'] as int;
      }
      if (code >= 500) {
        msg = 'Auth server unreachable right now. Try again later.';
      }
      throw Exception(msg);
    }
    return data;
  }

  /// رسالة تعذر الاتصال (بلا إنترنت / خادم متوقف)
  Exception _networkError(Object e) {
    return Exception('Cannot reach the server — check your internet connection and try again.');
  }

  // ---------- العمليات ----------

  /// إرسال رمز التحقق (OTP) إلى رقم الهاتف عبر خادمك الخاص
  Future<void> sendOtp({
    required String phone,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
    void Function(PhoneAuthCredential credential)? onAutoVerify,
  }) async {
    final String normalized = normalizePhone(phone);

    try {
      final Map<String, dynamic> data = await _post('otp_request', {
        'phone': normalized,
        'purpose': 'register',
      });

      lastDevCode = data['dev_code'] as String?;
      final int? resend = data['resend_after'] is int ? data['resend_after'] as int : null;
      lastResendAfter = resend;
      onCodeSent((data['session'] as String?) ?? '', resend);
    } on Exception catch (e) {
      onError(e.toString().replaceAll('Exception: ', ''));
    } catch (e) {
      onError(_networkError(e).toString().replaceAll('Exception: ', ''));
    }
  }

  /// إنشاء حساب جديد برقم الهاتف ورمز OTP وكلمة المرور
  Future<void> registerWithPhoneAndOtp({
    required String name,
    required String phone,
    required String password,
    required String verificationId,
    required String smsCode,
  }) async {
    final String normalized = normalizePhone(phone);

    try {
      final Map<String, dynamic> data = await _post('register', {
        'name': name.trim(),
        'phone': normalized,
        'password': password,
        'session': verificationId,
        'code': smsCode.trim(),
      });

      await _applySession(data, fallbackPhone: normalized, fallbackName: name.trim());
    } on Exception {
      rethrow;
    } catch (e) {
      throw _networkError(e);
    }
  }

  /// تسجيل الدخول برقم الهاتف وكلمة المرور
  Future<void> loginWithPhoneAndPassword({
    required String phone,
    required String password,
  }) async {
    final String normalized = normalizePhone(phone);

    try {
      final Map<String, dynamic> data = await _post('login', {
        'phone': normalized,
        'password': password,
      });

      await _applySession(data, fallbackPhone: normalized);
    } on Exception catch (e) {
      // احتياط عدم الاتصال: كلمة المرور المحفوظة محليًا تفتح جلسة بلا خادم
      final bool localMatch = await _verifyLocalPassword(normalized, password);
      if (localMatch) {
        _currentUser = UserModel(
          uid: 'flux_${cleanDigits(normalized)}',
          name: _currentUser?.name ?? 'FLUX Player',
          phone: normalized,
        );
        await _persist();
        notifyListeners();
        return;
      }
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    } catch (e) {
      // الخادم غير متصل: جرّب النسخة المحلية الاحتياطية
      final bool localMatch = await _verifyLocalPassword(normalized, password);
      if (localMatch) {
        _currentUser = UserModel(
          uid: 'flux_${cleanDigits(normalized)}',
          name: _currentUser?.name ?? 'FLUX Player',
          phone: normalized,
        );
        await _persist();
        notifyListeners();
        return;
      }
      throw _networkError(e);
    }
  }

  /// تسجيل الدخول المباشر برمز OTP (بدون كلمة مرور) — ينشئ حسابًا تلقائيًا لرقم جديد
  Future<void> loginWithOtp({
    required String phone,
    required String verificationId,
    required String smsCode,
  }) async {
    final String normalized = normalizePhone(phone);

    try {
      final Map<String, dynamic> data = await _post('otp_login', {
        'phone': normalized,
        'session': verificationId,
        'code': smsCode.trim(),
      });

      await _applySession(data, fallbackPhone: normalized);
    } on Exception {
      rethrow;
    } catch (e) {
      throw _networkError(e);
    }
  }

  /// إعادة تعيين كلمة المرور عبر رمز OTP تم التحقق منه
  Future<void> resetPasswordWithOtp({
    required String phone,
    required String verificationId,
    required String smsCode,
    required String newPassword,
  }) async {
    final String normalized = normalizePhone(phone);

    try {
      final Map<String, dynamic> data = await _post('reset_password', {
        'phone': normalized,
        'session': verificationId,
        'code': smsCode.trim(),
        'new_password': newPassword,
      });

      await _applySession(data, fallbackPhone: normalized);
      await _saveLocalPassword(normalized, newPassword);
    } on Exception {
      rethrow;
    } catch (e) {
      throw _networkError(e);
    }
  }

  /// تغيير كلمة المرور للمستخدم المسجل حاليًا
  Future<void> changePassword(String newPassword) async {
    if (_currentUser == null) {
      throw Exception('Sign in first');
    }
    final String phone = _currentUser!.phone;

    try {
      await _post('change_password', {'new_password': newPassword});
      await _saveLocalPassword(phone, newPassword);
    } on Exception {
      // الخادم رفض (مثلاً 401) — رسالته أوضح للمستخدم
      rethrow;
    } catch (e) {
      // تعذر الاتصال: نحدّث النسخة المحلية على الأقل حتى تُرفع لاحقًا
      await _saveLocalPassword(phone, newPassword);
      throw _networkError(e);
    }
  }

  /// تسجيل الخروج
  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kStorageKey);
      await prefs.remove(_kTokenKey);
    } catch (_) {}

    notifyListeners();
  }

  // ---------- إدارة الجلسة ----------

  /// تطبيق جلسة ناجحة من الخادم: حفظ المستخدم + الرمز
  Future<void> _applySession(
    Map<String, dynamic> data, {
    required String fallbackPhone,
    String? fallbackName,
  }) async {
    final Map<String, dynamic> userMap =
        (data['user'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    _token = data['token'] as String?;
    _currentUser = UserModel(
      uid: (userMap['uid'] as String?) ?? 'flux_${cleanDigits(fallbackPhone)}',
      name: (userMap['name'] as String?) ?? fallbackName ?? 'FLUX Player',
      phone: (userMap['phone'] as String?) ?? fallbackPhone,
      createdAt: userMap['created_at'] is String && (userMap['created_at'] as String).isNotEmpty
          ? DateTime.tryParse(userMap['created_at'] as String)
          : DateTime.now(),
    );

    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        await prefs.setString(_kStorageKey, jsonEncode(_currentUser!.toJson()));
      } else {
        await prefs.remove(_kStorageKey);
      }
      if (_token != null) {
        await prefs.setString(_kTokenKey, _token!);
      } else {
        await prefs.remove(_kTokenKey);
      }
    } catch (_) {}
  }

  Future<void> _saveLocalPassword(String phone, String password) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String raw = prefs.getString(_kPasswordMapKey) ?? '{}';
      final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
      map[cleanDigits(phone)] = password;
      await prefs.setString(_kPasswordMapKey, jsonEncode(map));
    } catch (_) {}
  }

  Future<bool> _verifyLocalPassword(String phone, String password) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_kPasswordMapKey);
      if (raw == null) return false;
      final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
      return map[cleanDigits(phone)] == password;
    } catch (_) {
      return false;
    }
  }
}

/// عنصر بديل عن نوع Firebase المحذوف — لم يعد مستخدمًا فعليًا لكنه يحفظ
/// توقيع الدالة sendOtp كما هو دون أي اعتماد خارجي.
class PhoneAuthCredential {
  const PhoneAuthCredential();
}
