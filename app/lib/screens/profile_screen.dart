import 'package:flutter/material.dart';

import '../config.dart';
import '../controllers/library_controller.dart';
import '../models/game.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_in_slide.dart';
import 'auth_screen.dart';

/// حساب اللاعب بأسلوب Epic Games:
/// - ملف تعريف اللاعب المرتبط بحساب سيرفر الخاص (بديل Firebase)
/// - تسجيل الدخول وإنشاء الحساب برقم الهاتف و OTP
/// - تغيير كلمة المرور وتسجيل الخروج
/// - إحصائيات المكتبة وحالة خادم الـ API
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});

  final LibraryController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<bool> _serverFuture = ApiService.instance.isServerOnline();

  Future<void> _refreshServer() async {
    setState(() {
      _serverFuture = ApiService.instance.isServerOnline();
    });
  }

  void _openAuth({bool isLogin = true}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthScreen(initialIsLogin: isLogin),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final TextEditingController newPwdCtrl = TextEditingController();
    final TextEditingController confirmPwdCtrl = TextEditingController();
    String? err;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: EpicColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: EpicColors.cyan, size: 22),
                  SizedBox(width: 8),
                  Text('تغيير كلمة المرور', style: TextStyle(color: EpicColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (err != null) ...[
                    Text(err!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: newPwdCtrl,
                    obscureText: true,
                    style: const TextStyle(color: EpicColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'كلمة المرور الجديدة (6 خانات+)',
                      hintStyle: TextStyle(color: EpicColors.textSecondary.withOpacity(.6), fontSize: 12),
                      filled: true,
                      fillColor: EpicColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: EpicColors.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPwdCtrl,
                    obscureText: true,
                    style: const TextStyle(color: EpicColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'تأكيد كلمة المرور الجديدة',
                      hintStyle: TextStyle(color: EpicColors.textSecondary.withOpacity(.6), fontSize: 12),
                      filled: true,
                      fillColor: EpicColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: EpicColors.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء', style: TextStyle(color: EpicColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final String p = newPwdCtrl.text.trim();
                          if (p.length < 6) {
                            setDialogState(() => err = 'يجب أن لا تقل كلمة المرور عن 6 خانات');
                            return;
                          }
                          if (p != confirmPwdCtrl.text.trim()) {
                            setDialogState(() => err = 'كلمتا المرور غير متطابقتين');
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                            err = null;
                          });

                          try {
                            await AuthService.instance.changePassword(p);
                            if (mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم تغيير كلمة المرور بنجاح ✓'),
                                  backgroundColor: EpicColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                              err = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EpicColors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: saving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('حفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EpicColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('تسجيل الخروج', style: TextStyle(color: EpicColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟', style: TextStyle(color: EpicColors.textSecondary, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(color: EpicColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.instance.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EpicColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('خروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, AuthService.instance]),
      builder: (context, _) {
        final List<Game> games = widget.controller.games;
        final double totalValue = games.fold<double>(
          0,
          (double s, Game g) => s + g.finalPrice,
        );
        final double savings = games.fold<double>(
          0,
          (double s, Game g) => s + (g.price - g.finalPrice),
        );
        final double avgRating = games.isEmpty
            ? 0
            : games.map((Game g) => g.rating).reduce((double a, double b) => a + b) /
                games.length;

        final UserModel? user = AuthService.instance.currentUser;
        final bool loggedIn = user != null;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            // بطاقة الملف الشخصي (متغير حسب تسجيل الدخول)
            FadeInSlide(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: EpicColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: loggedIn ? EpicColors.blue.withOpacity(.4) : EpicColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: loggedIn
                                  ? const [EpicColors.blue, EpicColors.cyan]
                                  : const [EpicColors.elevated, EpicColors.border],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (loggedIn ? EpicColors.blue : Colors.transparent).withOpacity(.35),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: Text(
                            loggedIn && user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'F',
                            style: TextStyle(
                              color: loggedIn ? Colors.white : EpicColors.textSecondary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      loggedIn ? user.name : 'لاعب ضيف',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: EpicColors.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (loggedIn) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: EpicColors.success.withOpacity(.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: EpicColors.success.withOpacity(.5)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified_rounded, color: EpicColors.success, size: 12),
                                          SizedBox(width: 3),
                                          Text(
                                            'موثق',
                                            style: TextStyle(color: EpicColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loggedIn
                                    ? (user.phone.isNotEmpty ? user.phone : 'مسجل عبر الهاتف')
                                    : 'سجّل حسابك لحفظ ألعابك من أي جهاز',
                                style: const TextStyle(
                                  color: EpicColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // أزرار الحساب
                    if (loggedIn) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showChangePasswordDialog,
                              icon: const Icon(Icons.lock_outline_rounded, size: 16, color: EpicColors.cyan),
                              label: const Text('تغيير كلمة المرور', style: TextStyle(color: EpicColors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: EpicColors.cyan.withOpacity(.4)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _showLogoutDialog,
                            icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
                            label: const Text('خروج', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.redAccent.withOpacity(.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: () => _openAuth(isLogin: true),
                        icon: const Icon(Icons.login_rounded, size: 18, color: Colors.white),
                        label: const Text('تسجيل الدخول / إنشاء حساب', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EpicColors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // الإحصائيات الحقيقية
            const Text(
              'إحصائياتي',
              style: TextStyle(
                color: EpicColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'أرقام محسوبة مباشرة من مكتبتك',
              style: TextStyle(color: EpicColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
              padding: EdgeInsets.zero,
              children: [
                _statCard(
                  'ألعابي',
                  '${games.length}',
                  Icons.video_library_rounded,
                ),
                _statCard(
                  'قيمة المكتبة',
                  '\$${totalValue.toStringAsFixed(2)}',
                  Icons.account_balance_wallet_rounded,
                ),
                _statCard(
                  'إجمالي التوفير',
                  '\$${savings.toStringAsFixed(2)}',
                  Icons.local_offer_rounded,
                ),
                _statCard(
                  'متوسط التقييم',
                  avgRating.toStringAsFixed(1),
                  Icons.star_rounded,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // حالة الاتصال بالخادم
            const Text(
              'الاتصال والخادم',
              style: TextStyle(
                color: EpicColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'حالة خادم الـ API ومعلومات الربط',
              style: TextStyle(color: EpicColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            FadeInSlide(
              child: FutureBuilder<bool>(
                future: _serverFuture,
                builder: (context, AsyncSnapshot<bool> snapshot) {
                  final bool online = snapshot.data == true;
                  final Color dotColor = online
                      ? EpicColors.success
                      : EpicColors.danger;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: EpicColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: EpicColors.border),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: online
                                ? EpicColors.success
                                : (snapshot.connectionState ==
                                        ConnectionState.waiting
                                    ? EpicColors.textSecondary
                                    : EpicColors.danger),
                            boxShadow: [
                              BoxShadow(
                                color: dotColor.withOpacity(.6),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            snapshot.connectionState == ConnectionState.waiting
                                ? 'جارٍ فحص الخادم...'
                                : (online ? 'الخادم متصل ويعمل' : 'تعذر الوصول إلى الخادم'),
                            style: const TextStyle(
                              color: EpicColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _refreshServer,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: EpicColors.textSecondary,
                            size: 20,
                          ),
                          tooltip: 'إعادة الفحص',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _infoRow('نظام المصادقة', 'مصادقة ذاتية OTP عبر خادم الخاص'),
            _infoRow('عنوان الخادم', AppConfig.baseUrl),
            _infoRow('نقطة الألعاب', '${AppConfig.apiBaseUrl}/games/'),
            _infoRow('إصدار التطبيق', '1.0.18'),
          ],
        );
      },
    );
  }

  /// بطاقة إحصائية صغيرة: أيقونة + قيمة كبيرة + وصف.
  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EpicColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EpicColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: EpicColors.cyan, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: EpicColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: EpicColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// صف معلومة: وصف رمادي فوق القيمة.
  Widget _infoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: EpicColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EpicColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: EpicColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: EpicColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
