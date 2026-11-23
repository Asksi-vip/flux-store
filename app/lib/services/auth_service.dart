import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

/// خدمة المصادقة عبر Firebase:
/// - تسجيل الدخول وإنشاء الحساب عبر رقم الهاتف + رمز التحقق (OTP)
/// - دعم الدخول بكلمة المرور أو برمز OTP المباشر
/// - إعادة تعيين كلمة المرور عبر كود OTP مرسل للهاتف
/// - حفظ الجلسة محليًا واستعادتها تلقائيًا
class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _kStorageKey = 'flux_auth_user_v1';
  static const String _kPasswordMapKey = 'flux_user_pwd_hashes';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserModel? _currentUser;
  bool _initialized = false;

  /// المستخدم الحالي المسجل
  UserModel? get currentUser => _currentUser;

  /// هل المستخدم مسجل الدخول؟
  bool get isLoggedIn => _currentUser != null || _auth.currentUser != null;

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
    } catch (_) {}

    // مراقبة تغيرات حالة Firebase Auth
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        if (_currentUser == null || _currentUser!.uid != user.uid) {
          _currentUser = UserModel(
            uid: user.uid,
            name: user.displayName ?? _currentUser?.name ?? 'لاعب FLUX',
            phone: user.phoneNumber ?? _currentUser?.phone ?? '',
            email: user.email,
          );
          _persist();
        }
      } else {
        // المستخدم سجل الخروج من Firebase
        if (_currentUser != null) {
          _currentUser = null;
          _persist();
        }
      }
      notifyListeners();
    });
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

  /// إزالة الرموز للحصول على أرقام فقط (لتوليد إيميل داخلي آمن لربط كلمة المرور)
  static String cleanDigits(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  /// إرسال رمز التحقق (OTP) إلى رقم الهاتف عبر Firebase Phone Auth
  Future<void> sendOtp({
    required String phone,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
    void Function(PhoneAuthCredential credential)? onAutoVerify,
  }) async {
    final String normalized = normalizePhone(phone);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: normalized,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (onAutoVerify != null) {
            onAutoVerify(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(_mapFirebaseError(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // انتهاء مهلة الالتقاط التلقائي للرمز
        },
      );
    } catch (e) {
      onError('فشل إرسال رمز التحقق: $e');
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
    final PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );

    // 1) تسجيل الدخول برمز الهاتف إلى Firebase Auth
    final UserCredential userCred = await _auth.signInWithCredential(credential);
    final User? user = userCred.user;
    if (user == null) {
      throw Exception('فشل إنشاء الحساب عبر Firebase');
    }

    // 2) تحديث اسم المستخدم
    await user.updateDisplayName(name.trim());

    // 3) ربط كلمة المرور بحساب المستخدم عبر البريد الداخلي الآمن
    final String virtualEmail = '${cleanDigits(normalized)}@fluxgames.store';
    try {
      await user.linkWithCredential(
        EmailAuthProvider.credential(
          email: virtualEmail,
          password: password,
        ),
      );
    } catch (_) {
      // إذا كان مرتبطًا سابقًا أو حدث تعارض، نحدّث كلمة المرور مباشرة
      try {
        await user.updatePassword(password);
      } catch (_) {}
    }

    // 4) حفظ كلمة المرور محليًا كنسخة احتياطية لتسجيل الدخول السريع
    await _saveLocalPassword(normalized, password);

    // 5) تحديث نموذج المستخدم وحفظه
    _currentUser = UserModel(
      uid: user.uid,
      name: name.trim(),
      phone: normalized,
      email: virtualEmail,
      createdAt: DateTime.now(),
    );

    await _persist();
    notifyListeners();
  }

  /// تسجيل الدخول برقم الهاتف وكلمة المرور
  Future<void> loginWithPhoneAndPassword({
    required String phone,
    required String password,
  }) async {
    final String normalized = normalizePhone(phone);
    final String virtualEmail = '${cleanDigits(normalized)}@fluxgames.store';

    try {
      // محاولة تسجيل الدخول عبر Firebase Auth
      final UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: virtualEmail,
        password: password,
      );

      final User? user = cred.user;
      if (user != null) {
        _currentUser = UserModel(
          uid: user.uid,
          name: user.displayName ?? _currentUser?.name ?? 'لاعب FLUX',
          phone: normalized,
          email: virtualEmail,
        );
        await _persist();
        notifyListeners();
        return;
      }
    } on FirebaseAuthException catch (e) {
      // فحص إذا كانت كلمة المرور مطابقة للمحفوظة محليًا
      final bool localMatch = await _verifyLocalPassword(normalized, password);
      if (localMatch) {
        _currentUser = UserModel(
          uid: 'flux_${cleanDigits(normalized)}',
          name: _currentUser?.name ?? 'لاعب FLUX',
          phone: normalized,
          email: virtualEmail,
        );
        await _persist();
        notifyListeners();
        return;
      }

      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        throw Exception('لا يوجد حساب مسجل بهذا الرقم، أو كلمة المرور غير صحيحة.');
      } else if (e.code == 'wrong-password') {
        throw Exception('كلمة المرور غير صحيحة، يرجى المحاولة مرة أخرى.');
      } else {
        throw Exception(_mapFirebaseError(e));
      }
    } catch (e) {
      // فحص النسخة المحلية الاحتياطية
      final bool localMatch = await _verifyLocalPassword(normalized, password);
      if (localMatch) {
        _currentUser = UserModel(
          uid: 'flux_${cleanDigits(normalized)}',
          name: _currentUser?.name ?? 'لاعب FLUX',
          phone: normalized,
          email: virtualEmail,
        );
        await _persist();
        notifyListeners();
        return;
      }
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// تسجيل الدخول المباشر برمز OTP (بدون كلمة مرور)
  Future<void> loginWithOtp({
    required String phone,
    required String verificationId,
    required String smsCode,
  }) async {
    final String normalized = normalizePhone(phone);
    final PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );

    final UserCredential cred = await _auth.signInWithCredential(credential);
    final User? user = cred.user;
    if (user == null) {
      throw Exception('فشل التحقق من رمز OTP');
    }

    _currentUser = UserModel(
      uid: user.uid,
      name: user.displayName ?? _currentUser?.name ?? 'لاعب FLUX',
      phone: normalized,
      email: user.email,
    );

    await _persist();
    notifyListeners();
  }

  /// إعادة تعيين كلمة المرور عبر رمز OTP تم التحقق منه
  Future<void> resetPasswordWithOtp({
    required String phone,
    required String verificationId,
    required String smsCode,
    required String newPassword,
  }) async {
    final String normalized = normalizePhone(phone);
    final PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );

    // 1) تأكيد هوية مالك الهاتف بالرمز
    final UserCredential cred = await _auth.signInWithCredential(credential);
    final User? user = cred.user;
    if (user == null) {
      throw Exception('رمز التحقق غير صحيح أو منتهي الصلاحية');
    }

    // 2) تحديث كلمة المرور في Firebase
    final String virtualEmail = '${cleanDigits(normalized)}@fluxgames.store';
    try {
      await user.updatePassword(newPassword);
    } catch (_) {
      try {
        await user.linkWithCredential(
          EmailAuthProvider.credential(email: virtualEmail, password: newPassword),
        );
      } catch (_) {}
    }

    // 3) تحديث كلمة المرور محليًا
    await _saveLocalPassword(normalized, newPassword);

    _currentUser = UserModel(
      uid: user.uid,
      name: user.displayName ?? _currentUser?.name ?? 'لاعب FLUX',
      phone: normalized,
      email: virtualEmail,
    );

    await _persist();
    notifyListeners();
  }

  /// تغيير كلمة المرور للمستخدم المسجل حاليًا
  Future<void> changePassword(String newPassword) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
      if (_currentUser?.phone.isNotEmpty == true) {
        await _saveLocalPassword(_currentUser!.phone, newPassword);
      }
    } else {
      if (_currentUser?.phone.isNotEmpty == true) {
        await _saveLocalPassword(_currentUser!.phone, newPassword);
      } else {
        throw Exception('يجب تسجيل الدخول أولًا');
      }
    }
  }

  /// تسجيل الخروج
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (_) {}

    _currentUser = null;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kStorageKey);
    } catch (_) {}

    notifyListeners();
  }

  // ---------- حفظ واسترجاع محلي ----------

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        await prefs.setString(_kStorageKey, jsonEncode(_currentUser!.toJson()));
      } else {
        await prefs.remove(_kStorageKey);
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

  /// تحويل رسائل أخطاء Firebase إلى العربية واضحة
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'رقم الهاتف غير صالح، يرجى كتابة الرقم بالصيغة الدولية الصحيحة.';
      case 'invalid-verification-code':
        return 'رمز التحقق (OTP) غير صحيح، يرجى التأكد من الرمز وإعادة المحاولة.';
      case 'session-expired':
        return 'انتهت صلاحية رمز التحقق، يرجى طلب رمز جديد.';
      case 'too-many-requests':
        return 'تم إرسال طلبات كثيرة جدًا في وقت قصير. يرجى الانتظار دقيقة ثم المحاولة.';
      case 'quota-exceeded':
        return 'تم استهلاك الحصة المؤقتة لإرسال رسائل التحقق، حاول لاحقًا.';
      case 'network-request-failed':
        return 'تعذر الاتصال بالخادم، يرجى التحقق من اتصال الإنترنت.';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب، يرجى التواصل مع الدعم الفني.';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة.';
      case 'user-not-found':
        return 'لا يوجد حساب مرتبط برقم الهاتف هذا.';
      default:
        return e.message ?? 'حدث خطأ غير متوقع أثناء معالجة الطلب.';
    }
  }
}
