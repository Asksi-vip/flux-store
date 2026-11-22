import 'package:flutter/material.dart';

import '../config.dart';
import '../controllers/library_controller.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_in_slide.dart';

/// حساب اللاعب بأسلوب Epic: إحصائيات حقيقية من المكتبة + حالة الخادم + معلومات الربط.
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
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

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            // بطاقة الملف الشخصي
            FadeInSlide(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: EpicColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: EpicColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [EpicColors.blue, EpicColors.cyan],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: EpicColors.blue.withOpacity(.4),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: const Text(
                        'F',
                        style: TextStyle(
                          color: EpicColors.textOnBadge,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'لاعب FLUX',
                            style: TextStyle(
                              color: EpicColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'حساب محلي — مكتبتك محفوظة على جهازك',
                            style: TextStyle(
                              color: EpicColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            // حالة الاتصال بالخادم
            const Text(
              'الاتصال',
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
                      borderRadius: BorderRadius.circular(4),
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
            _infoRow('عنوان الخادم', AppConfig.baseUrl),
            _infoRow('نقطة الألعاب', '${AppConfig.apiBaseUrl}/games/'),
            _infoRow('إصدار التطبيق', '1.0.0'),
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
        borderRadius: BorderRadius.circular(4),
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
        borderRadius: BorderRadius.circular(4),
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
