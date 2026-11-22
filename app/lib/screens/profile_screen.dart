import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// شاشة الملف الشخصي: بطاقة اللاعب، إحصائيات المكتبة، وحالة الخادم.
class ProfileScreen extends StatefulWidget {
  final ApiService api;
  final LibraryController library;

  const ProfileScreen({super.key, required this.api, required this.library});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool? _serverOnline;
  bool _checking = false;

  /// فحص اتصال التطبيق بخادم الـ API.
  Future<void> _checkServer() async {
    setState(() => _checking = true);
    final ok = await widget.api.isServerOnline();
    if (!mounted) return;
    setState(() {
      _serverOnline = ok;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.library,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('حسابي')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // بطاقة اللاعب المتوهجة
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: FluxColors.surface,
                  border: Border.all(color: FluxColors.pink.withOpacity(.4)),
                  boxShadow: [BoxShadow(color: FluxColors.pink.withOpacity(.15), blurRadius: 24)],
                ),
                child: Column(
                  children: [
                    // الصورة الرمزية بإطار متدرج
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: FluxColors.pinkPurple,
                      ),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: FluxColors.card,
                        ),
                        child: const Icon(Icons.person_rounded, color: FluxColors.textPrimary, size: 34),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Flux Player',
                      style: TextStyle(
                        color: FluxColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Text(
                      'لاعب أسطوري منذ 2026',
                      style: TextStyle(color: FluxColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // الإحصائيات
              Row(
                children: [
                  _statCard(
                    icon: Icons.videogame_asset_rounded,
                    color: FluxColors.pink,
                    value: '${widget.library.games.length}',
                    label: 'ألعابي',
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    icon: Icons.timer_rounded,
                    color: FluxColors.cyan,
                    value: '128',
                    label: 'ساعة لعب',
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    icon: Icons.local_fire_department_rounded,
                    color: FluxColors.orange,
                    value: '4.8',
                    label: 'مستواي',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // حالة الخادم
              _infoTile(
                icon: Icons.dns_rounded,
                color: FluxColors.cyan,
                title: 'حالة الخادم',
                subtitle: _checking
                    ? 'جارٍ الفحص...'
                    : _serverOnline == null
                        ? 'اضغط للفحص'
                        : _serverOnline!
                            ? 'متصل — الـ API يعمل بنجاح ✅'
                            : 'غير متصل — تأكد من تشغيل الخادم ❌',
                onTap: _checking ? null : _checkServer,
                trailing: _checking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: FluxColors.cyan, strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, color: FluxColors.textMuted, size: 22),
              ),
              _infoTile(
                icon: Icons.info_outline_rounded,
                color: FluxColors.purple,
                title: 'عن Flux',
                subtitle: 'الإصدار 1.0.0 — متجر ألعاب تجريبي متصل بـ Django REST API',
              ),
              _infoTile(
                icon: Icons.settings_rounded,
                color: FluxColors.orange,
                title: 'الإعدادات',
                subtitle: 'قريبًا...',
              ),
            ],
          ),
        );
      },
    );
  }

  /// بطاقة إحصائية صغيرة.
  Widget _statCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: FluxColors.card,
          border: Border.all(color: color.withOpacity(.35)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: FluxColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            Text(label, style: const TextStyle(color: FluxColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  /// بطاقة معلومات/إجراء.
  Widget _infoTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: FluxColors.card,
            border: Border.all(color: color.withOpacity(.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: color.withOpacity(.15),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: FluxColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: FluxColors.textMuted, fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }
}
