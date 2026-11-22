import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game.dart';
import '../services/download_manager.dart';
import '../theme/app_theme.dart';
import 'epic_button.dart';

/// منطقة زر التحميل في صفحة التفاصيل — تتغير حالتها مباشرة مثل Epic Games:
/// تحميل مجاني ← جارٍ (تقدم + سرعة) ← بانتظار الشبكة (استكمال تلقائي) ← متوقف ← مكتمل.
class DownloadButton extends StatelessWidget {
  const DownloadButton({super.key, required this.game, this.onClaim});

  final Game game;

  /// تُستدعى عند بدء التحميل — لإضافة اللعبة للمكتبة (مثل "استحواذ" Epic).
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DownloadManager.instance,
      builder: (context, _) {
        final DownloadTask? task = DownloadManager.instance.taskFor(game.id);
        if (task == null) {
          return EpicButton(
            label: 'تثبيت مباشر',
            icon: Icons.download_rounded,
            onPressed: () {
              DownloadManager.instance.start(game);
              onClaim?.call();
            },
          );
        }
        switch (task.state) {
          case DownloadTaskState.downloading:
            return Column(
              children: [
                _progressBar(task, EpicColors.blue),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _iconAction(
                      Icons.pause_rounded,
                      'إيقاف مؤقت',
                      () => DownloadManager.instance.pause(game.id),
                    ),
                    const SizedBox(width: 10),
                    _iconAction(
                      Icons.delete_outline_rounded,
                      'إلغاء التحميل',
                      () => DownloadManager.instance.remove(game.id),
                      danger: true,
                    ),
                  ],
                ),
              ],
            );
          case DownloadTaskState.paused:
            return Column(
              children: [
                _progressBar(task, EpicColors.textSecondary),
                const SizedBox(height: 12),
                EpicButton(
                  label: 'متابعة التحميل',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => DownloadManager.instance.resume(game.id),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => DownloadManager.instance.remove(game.id),
                  child: const Text(
                    'إلغاء وحذف الملفات',
                    style: TextStyle(
                      color: EpicColors.danger,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          case DownloadTaskState.waitingNetwork:
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(.08),
                    border: Border.all(color: Colors.orange.withOpacity(.6)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'انقطع الاتصال — سيستكمل التحميل تلقائيًا من نفس النقطة عند عودة الشبكة',
                          style: TextStyle(
                            color: Colors.orange.shade200,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _progressBar(task, Colors.orange),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _iconAction(
                      Icons.pause_rounded,
                      'إيقاف مؤقت',
                      () => DownloadManager.instance.pause(game.id),
                    ),
                    const SizedBox(width: 10),
                    _iconAction(
                      Icons.delete_outline_rounded,
                      'إلغاء التحميل',
                      () => DownloadManager.instance.remove(game.id),
                      danger: true,
                    ),
                  ],
                ),
              ],
            );
          case DownloadTaskState.completed:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: EpicColors.success.withOpacity(.1),
                    border: Border.all(color: EpicColors.success),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: EpicColors.success, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'تم تحميل اللعبة بنجاح',
                          style: TextStyle(
                            color: EpicColors.success,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        formatBytes(task.totalBytes),
                        style: const TextStyle(
                          color: EpicColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ..._filesRows(context, task),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => DownloadManager.instance.remove(game.id),
                  child: const Text(
                    'إزالة من قائمة التنزيلات',
                    style: TextStyle(
                      color: EpicColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
        }
      },
    );
  }

  // ---------- عناصر مساعدة ----------

  Widget _progressBar(DownloadTask task, Color color) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: task.progress,
            minHeight: 5,
            backgroundColor: EpicColors.elevated,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${formatBytes(task.downloadedBytes)} من ${formatBytes(task.totalBytes)}',
              style: const TextStyle(
                color: EpicColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (task.state == DownloadTaskState.downloading)
              Text(
                '${formatBytes(task.speed)}/ث',
                style: const TextStyle(
                  color: EpicColors.cyan,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _iconAction(IconData icon, String tooltip, VoidCallback onTap,
      {bool danger = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: EpicColors.elevated,
          border: Border.all(
            color: danger ? EpicColors.danger.withOpacity(.6) : EpicColors.border,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 20,
          color: danger ? EpicColors.danger : EpicColors.textPrimary,
        ),
      ),
    );
  }

  /// صفوف الملفات المكتملة مع مساراتها وأزرار النسخ.
  List<Widget> _filesRows(BuildContext context, DownloadTask task) {
    return task.files.map((FileTask f) {
      final IconData icon =
          f.file.isApk ? Icons.android_rounded : Icons.folder_zip_rounded;
      final String savedPath = f.localPath ?? '';
      final String target = f.file.installPath;
      final bool movedOutside = target.isNotEmpty &&
          savedPath.isNotEmpty &&
          !_samePath(savedPath, target);
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: EpicColors.surface,
          border: Border.all(color: EpicColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: EpicColors.cyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${f.file.name} — ${formatBytes(f.size)}',
                    style: const TextStyle(
                      color: EpicColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _copyButton(context, movedOutside ? target : savedPath),
              ],
            ),
            if (savedPath.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'حُفظ في: $savedPath',
                style: const TextStyle(
                  color: EpicColors.textSecondary,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
            ],
            if (movedOutside) ...[
              const SizedBox(height: 4),
              Text(
                'انقله بعد التثبيت إلى: $target',
                style: const TextStyle(
                  color: EpicColors.cyan,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  bool _samePath(String a, String b) {
    String norm(String s) => s.replaceAll('\\', '/').toLowerCase();
    return norm(a) == norm(b);
  }

  Widget _copyButton(BuildContext context, String path) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: path));
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('تم نسخ المسار إلى الحافظة')),
          );
      },
      child: const Icon(
        Icons.copy_rounded,
        size: 15,
        color: EpicColors.cyan,
      ),
    );
  }
}
