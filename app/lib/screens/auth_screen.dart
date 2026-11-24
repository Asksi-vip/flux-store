import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_in_slide.dart';

/// شاشة تسجيل الدخول وإنشاء الحساب بأسلوب Epic Games:
/// - تسجيل الدخول برقم الهاتف وكلمة المرور
/// - إنشاء حساب جديد مع التحقق برمز OTP
/// - تسجيل الدخول السريع عبر رمز OTP
/// - إعادة تعيين كلمة المرور عبر رمز OTP
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialIsLogin = true});

  final bool initialIsLogin;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isLogin = widget.initialIsLogin;

  // حقول الإدخال
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String _countryCode = '+964'; // الافتراضي: العراق
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  static const List<Map<String, String>> _countries = [
    {'name': 'العراق', 'code': '+964', 'flag': '🇮🇶'},
    {'name': 'السعودية', 'code': '+966', 'flag': '🇸🇦'},
    {'name': 'مصر', 'code': '+20', 'flag': '🇪🇬'},
    {'name': 'الإمارات', 'code': '+971', 'flag': '🇦🇪'},
    {'name': 'الكويت', 'code': '+965', 'flag': '🇰🇼'},
    {'name': 'الأردن', 'code': '+962', 'flag': '🇯🇴'},
    {'name': 'عُمان', 'code': '+968', 'flag': '🇴🇲'},
    {'name': 'قطر', 'code': '+974', 'flag': '🇶🇦'},
    {'name': 'البحرين', 'code': '+973', 'flag': '🇧🇭'},
    {'name': 'اليمن', 'code': '+967', 'flag': '🇾🇪'},
    {'name': 'سوريا', 'code': '+963', 'flag': '🇸🇾'},
    {'name': 'لبنان', 'code': '+961', 'flag': '🇱🇧'},
    {'name': 'الجزائر', 'code': '+213', 'flag': '🇩🇿'},
    {'name': 'المغرب', 'code': '+212', 'flag': '🇲🇦'},
    {'name': 'تونس', 'code': '+216', 'flag': '🇹🇳'},
    {'name': 'ليبيا', 'code': '+218', 'flag': '🇱🇾'},
    {'name': 'السودان', 'code': '+249', 'flag': '🇸🇩'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _fullPhone {
    return AuthService.normalizePhone(_phoneController.text.trim(), countryCode: _countryCode);
  }

  // ---------- تنفيذ العمليات ----------

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    final String phone = _phoneController.text.trim();
    final String password = _passwordController.text.trim();

    if (phone.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال رقم الهاتف');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال كلمة المرور');
      return;
    }

    if (_isLogin) {
      // تسجيل الدخول برقم الهاتف وكلمة المرور
      setState(() => _isLoading = true);
      try {
        await AuthService.instance.loginWithPhoneAndPassword(
          phone: _fullPhone,
          password: password,
        );
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // إنشاء حساب: التحقق من الحقول أولاً ثم إرسال رمز OTP
      final String name = _nameController.text.trim();
      final String confirm = _confirmPasswordController.text.trim();

      if (name.isEmpty) {
        setState(() => _errorMessage = 'يرجى إدخال اسم اللاعب');
        return;
      }
      if (password.length < 6) {
        setState(() => _errorMessage = 'يجب أن تتكون كلمة المرور من 6 خانات على الأقل');
        return;
      }
      if (password != confirm) {
        setState(() => _errorMessage = 'كلمتا المرور غير متطابقتين');
        return;
      }

      _startRegisterWithOtp(name, _fullPhone, password);
    }
  }

  /// إرسال رمز OTP لإنشاء الحساب ثم فتح نافذة إدخال الرمز
  void _startRegisterWithOtp(String name, String phone, String password) {
    setState(() => _isLoading = true);
    AuthService.instance.sendOtp(
      phone: phone,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showOtpSheet(
          phone: phone,
          title: 'التحقق لإنشاء الحساب',
          onVerify: (code) async {
            await AuthService.instance.registerWithPhoneAndOtp(
              name: name,
              phone: phone,
              password: password,
              verificationId: verificationId,
              smsCode: code,
            );
            if (mounted) {
              Navigator.of(context).pop(); // غلق شيت الـ OTP
              Navigator.of(context).pop(true); // غلق شاشة المصادقة
            }
          },
        );
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = err;
        });
      },
    );
  }

  /// تسجيل الدخول السريع عبر رمز OTP دون كلمة مرور
  void _startOtpLogin() {
    setState(() => _errorMessage = null);
    final String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال رقم الهاتف أولاً');
      return;
    }

    setState(() => _isLoading = true);
    AuthService.instance.sendOtp(
      phone: _fullPhone,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showOtpSheet(
          phone: _fullPhone,
          title: 'تسجيل الدخول السريع',
          onVerify: (code) async {
            await AuthService.instance.loginWithOtp(
              phone: _fullPhone,
              verificationId: verificationId,
              smsCode: code,
            );
            if (mounted) {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            }
          },
        );
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = err;
        });
      },
    );
  }

  /// إعادة تعيين كلمة المرور عبر OTP
  void _startForgotPassword() {
    final TextEditingController resetPhoneCtrl = TextEditingController(text: _phoneController.text);
    String resetCountry = _countryCode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EpicColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool sending = false;
        String? errText;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: EpicColors.blue.withOpacity(.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.lock_reset_rounded, color: EpicColors.cyan, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'إعادة تعيين كلمة المرور',
                        style: TextStyle(color: EpicColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'أدخل رقم هاتفك المسجل وسنرسل لك رمز تحقق (OTP) لتعيين كلمة مرور جديدة.',
                    style: TextStyle(color: EpicColors.textSecondary, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  if (errText != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: EpicColors.danger.withOpacity(.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: EpicColors.danger.withOpacity(.5)),
                      ),
                      child: Text(errText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      _countryCodeDropdown(
                        selectedCode: resetCountry,
                        onChanged: (val) => setModalState(() => resetCountry = val),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _inputBox(
                          controller: resetPhoneCtrl,
                          hint: '770 123 4567',
                          keyboardType: TextInputType.phone,
                          icon: Icons.phone_android_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: sending
                        ? null
                        : () {
                            final String rawP = resetPhoneCtrl.text.trim();
                            if (rawP.isEmpty) {
                              setModalState(() => errText = 'يرجى إدخال رقم الهاتف');
                              return;
                            }
                            final String fullP = AuthService.normalizePhone(rawP, countryCode: resetCountry);
                            setModalState(() {
                              sending = true;
                              errText = null;
                            });

                            AuthService.instance.sendOtp(
                              phone: fullP,
                              onCodeSent: (verificationId, resendToken) {
                                Navigator.of(ctx).pop(); // غلق نافذة الهاتف
                                _showResetPasswordOtpSheet(fullP, verificationId);
                              },
                              onError: (err) {
                                setModalState(() {
                                  sending = false;
                                  errText = err;
                                });
                              },
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EpicColors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: sending
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('إرسال رمز التحقق (OTP)', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// نافذة إدخال OTP وكلمة المرور الجديدة لإعادة التعيين
  void _showResetPasswordOtpSheet(String phone, String verificationId) {
    final TextEditingController newPwdCtrl = TextEditingController();
    final TextEditingController confirmNewPwdCtrl = TextEditingController();
    String otpCode = '';
    // وضع التجربة: رمز التحقق يعود من الخادم مباشرة بدل الرسالة النصية
    final String? devCode = AuthService.instance.lastDevCode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EpicColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool saving = false;
        String? err;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'أدخل الرمز المرسل إلى $phone',
                      style: const TextStyle(color: EpicColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    if (devCode != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: EpicColors.cyan.withOpacity(.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: EpicColors.cyan.withOpacity(.4)),
                        ),
                        child: Text(
                          'وضع التجربة (بوابة الرسائل غير مفعلة) — رمز التحقق: $devCode',
                          style: const TextStyle(color: EpicColors.cyan, fontSize: 12, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (err != null) ...[
                      Text(err!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      const SizedBox(height: 10),
                    ],
                    _OtpInputWidget(
                      onChanged: (val) => otpCode = val,
                    ),
                    const SizedBox(height: 18),
                    _inputBox(
                      controller: newPwdCtrl,
                      hint: 'كلمة المرور الجديدة',
                      isPassword: true,
                      icon: Icons.lock_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    _inputBox(
                      controller: confirmNewPwdCtrl,
                      hint: 'تأكيد كلمة المرور الجديدة',
                      isPassword: true,
                      icon: Icons.lock_reset_rounded,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (otpCode.length < 6) {
                                setSheetState(() => err = 'يرجى إدخال رمز التحقق المكون من 6 أرقام');
                                return;
                              }
                              final String np = newPwdCtrl.text.trim();
                              if (np.length < 6) {
                                setSheetState(() => err = 'كلمة المرور يجب أن لا تقل عن 6 أحرف');
                                return;
                              }
                              if (np != confirmNewPwdCtrl.text.trim()) {
                                setSheetState(() => err = 'كلمتا المرور غير متطابقتين');
                                return;
                              }

                              setSheetState(() {
                                saving = true;
                                err = null;
                              });

                              try {
                                await AuthService.instance.resetPasswordWithOtp(
                                  phone: phone,
                                  verificationId: verificationId,
                                  smsCode: otpCode,
                                  newPassword: np,
                                );
                                if (mounted) {
                                  Navigator.of(ctx).pop();
                                  Navigator.of(context).pop(true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تمت إعادة تعيين كلمة المرور بنجاح وتسجيل الدخول ✓'),
                                      backgroundColor: EpicColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() {
                                  saving = false;
                                  err = e.toString().replaceAll('Exception: ', '');
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EpicColors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('حفظ كلمة المرور وتسجيل الدخول', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// نافذة منبثقة لإدخال رمز الـ OTP (للتسجيل أو الدخول السريع)
  void _showOtpSheet({
    required String phone,
    required String title,
    required Future<void> Function(String code) onVerify,
  }) {
    String otp = '';
    // وضع التجربة (بوابة SMS غير مفعلة على الخادم): الرمز يعود من الخادم مباشرة
    final String? devCode = AuthService.instance.lastDevCode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EpicColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool verifying = false;
        String? sheetError;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: EpicColors.cyan.withOpacity(.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.sms_rounded, color: EpicColors.cyan, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(color: EpicColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'أرسلنا رمز التحقق المكوّن من 6 أرقام إلى الرقم:\n$phone',
                    style: const TextStyle(color: EpicColors.textSecondary, fontSize: 13, height: 1.5),
                  ),
                  if (devCode != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: EpicColors.cyan.withOpacity(.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: EpicColors.cyan.withOpacity(.4)),
                      ),
                      child: Text(
                        'وضع التجربة (بوابة الرسائل غير مفعلة) — رمز التحقق: $devCode',
                        style: const TextStyle(color: EpicColors.cyan, fontSize: 12, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (sheetError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: EpicColors.danger.withOpacity(.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: EpicColors.danger.withOpacity(.5)),
                      ),
                      child: Text(sheetError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _OtpInputWidget(
                    onChanged: (val) {
                      otp = val;
                      if (val.length == 6) {
                        // إكمال تلقائي عند إدخال 6 أرقام
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: verifying
                        ? null
                        : () async {
                            if (otp.length < 6) {
                              setModalState(() => sheetError = 'يرجى كتابة رمز التحقق المكوّن من 6 أرقام');
                              return;
                            }
                            setModalState(() {
                              verifying = true;
                              sheetError = null;
                            });

                            try {
                              await onVerify(otp);
                            } catch (e) {
                              setModalState(() {
                                verifying = false;
                                sheetError = e.toString().replaceAll('Exception: ', '');
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EpicColors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: verifying
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('تأكيد ومتابعة', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------- واجهة المستخدم الرئيسية ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EpicColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: EpicColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الشعار والعنوان
              FadeInSlide(
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: EpicColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: EpicColors.blue.withOpacity(.5), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: EpicColors.blue.withOpacity(.25),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/brand/flux_badge.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _isLogin ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
                        style: const TextStyle(
                          color: EpicColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isLogin
                            ? 'أهلاً بعودتك! سجّل دخولك للوصول إلى ألعابك'
                            : 'انضم إلى مجتمع FLUX STORE واحفظ تقدمك',
                        style: const TextStyle(color: EpicColors.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // التبديل بين الدخول والإنشاء
              FadeInSlide(
                delay: const Duration(milliseconds: 100),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: EpicColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EpicColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _tabButton(
                          title: 'تسجيل الدخول',
                          active: _isLogin,
                          onTap: () => setState(() {
                            _isLogin = true;
                            _errorMessage = null;
                          }),
                        ),
                      ),
                      Expanded(
                        child: _tabButton(
                          title: 'إنشاء حساب',
                          active: !_isLogin,
                          onTap: () => setState(() {
                            _isLogin = false;
                            _errorMessage = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // رسالة الخطأ إن وجدت
              if (_errorMessage != null) ...[
                FadeInSlide(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: EpicColors.danger.withOpacity(.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: EpicColors.danger.withOpacity(.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // حقول الإنشاء (اسم اللاعب)
              if (!_isLogin) ...[
                FadeInSlide(
                  delay: const Duration(milliseconds: 150),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('اسم اللاعب', style: TextStyle(color: EpicColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _inputBox(
                        controller: _nameController,
                        hint: 'اسمك المستعار في المتجر',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ],

              // حقل رقم الهاتف مع كود الدولة
              FadeInSlide(
                delay: const Duration(milliseconds: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('رقم الهاتف', style: TextStyle(color: EpicColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _countryCodeDropdown(
                          selectedCode: _countryCode,
                          onChanged: (val) => setState(() => _countryCode = val),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _inputBox(
                            controller: _phoneController,
                            hint: '770 123 4567',
                            keyboardType: TextInputType.phone,
                            icon: Icons.phone_android_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // حقل كلمة المرور
              FadeInSlide(
                delay: const Duration(milliseconds: 250),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('كلمة المرور', style: TextStyle(color: EpicColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _inputBox(
                      controller: _passwordController,
                      hint: '••••••••',
                      isPassword: true,
                      obscureText: _obscurePassword,
                      onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icons.lock_outline_rounded,
                    ),
                  ],
                ),
              ),

              // تأكيد كلمة المرور في وضع الإنشاء
              if (!_isLogin) ...[
                const SizedBox(height: 14),
                FadeInSlide(
                  delay: const Duration(milliseconds: 300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تأكيد كلمة المرور', style: TextStyle(color: EpicColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _inputBox(
                        controller: _confirmPasswordController,
                        hint: '••••••••',
                        isPassword: true,
                        obscureText: _obscureConfirmPassword,
                        onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        icon: Icons.lock_reset_rounded,
                      ),
                    ],
                  ),
                ),
              ],

              // روابط مساعدة في وضع تسجيل الدخول
              if (_isLogin) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _startOtpLogin,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text(
                        'دخول سريع عبر OTP',
                        style: TextStyle(color: EpicColors.cyan, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: _startForgotPassword,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text(
                        'نسيت كلمة المرور؟',
                        style: TextStyle(color: EpicColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // زر الإرسال الأساسي
              FadeInSlide(
                delay: const Duration(milliseconds: 350),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EpicColors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _isLogin ? 'تسجيل الدخول' : 'المتابعة مع كود التحقق (OTP)',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // تسجيل الدخول كضيف
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'تخطي والمتابعة كضيف',
                    style: TextStyle(color: EpicColors.textSecondary, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- مكونات مساعدة ----------

  Widget _tabButton({required String title, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? EpicColors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : EpicColors.textSecondary,
            fontSize: 14,
            fontWeight: active ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _countryCodeDropdown({required String selectedCode, required ValueChanged<String> onChanged}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: EpicColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EpicColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCode,
          dropdownColor: EpicColors.surface,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: EpicColors.textSecondary, size: 18),
          items: _countries.map((c) {
            return DropdownMenuItem<String>(
              value: c['code'],
              child: Text(
                '${c['flag']} ${c['code']}',
                style: const TextStyle(color: EpicColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  Widget _inputBox({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: EpicColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EpicColors.border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(icon, color: EpicColors.textSecondary, size: 20),
            ),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: isPassword && obscureText,
              keyboardType: keyboardType,
              style: const TextStyle(color: EpicColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: EpicColors.textSecondary.withOpacity(.6), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (isPassword && onToggleVisibility != null) ...[
            IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: EpicColors.textSecondary,
                size: 20,
              ),
              onPressed: onToggleVisibility,
            ),
          ],
        ],
      ),
    );
  }
}

/// صندوق إدخال رمز التحقق OTP المكون من 6 أرقام مع التركيز التلقائي
class _OtpInputWidget extends StatefulWidget {
  const _OtpInputWidget({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_OtpInputWidget> createState() => _OtpInputWidgetState();
}

class _OtpInputWidgetState extends State<_OtpInputWidget> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _update() {
    final String code = _controllers.map((c) => c.text).join();
    widget.onChanged(code);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        return Container(
          width: 44,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: EpicColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focusNodes[i].hasFocus ? EpicColors.blue : EpicColors.border,
              width: _focusNodes[i].hasFocus ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              LengthLimitingTextInputFormatter(1),
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: const TextStyle(
              color: EpicColors.cyan,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) {
              if (val.isNotEmpty && i < 5) {
                _focusNodes[i + 1].requestFocus();
              } else if (val.isEmpty && i > 0) {
                _focusNodes[i - 1].requestFocus();
              }
              _update();
            },
          ),
        );
      }),
    );
  }
}
