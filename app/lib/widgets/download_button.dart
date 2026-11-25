import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game.dart';
import '../services/download_manager.dart';
import '../theme/app_theme.dart';
import 'epic_button.dart';

/// منطقة زر التحميل في صفحة التفاصيل — آلة حالة التثبيت بنصوص Epic الحرفية:
/// Get/Install ← Downloading… % ← Download Paused ← paused waiting for Wi-Fi
/// ← Download Complete. Ready to Install. ← Installing… ← Open.
class DownloadButton extends StatelessWidget {
  const DownloadButton({super.key, required this.game, this.onClaim});

  final Game game;

  /// تُستدعى عند بدء التحميل — لإضافة اللعبة للمكتبة (مثل "استحواذ" Epic).
  final VoidCallback? onClaim;

  /// مفتاح تفضيل "Data downloads" — ON = لا نسأل، OFF = نسأل قبل كل بدء/استئناف.
  static const String _dataDownloadsKey = 'flux_data_downloads';

  /// حوار تأكيد التحميل عبر بيانات الجوال بنصوص Epic الحرفية.
  /// يظهر فقط عندما يكون إعداد Data downloads مطفأً.
  Future<bool> _confirmCellular(BuildContext context,
      {required bool resuming}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_dataDownloadsKey) ?? false) {
      return true; // الإعداد مفعّل — حمّل دائمًا بلا سؤال
    }
    if (!context.mounted) return false;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: EpicColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          title: Text(
            resuming
                ? 'Continue download using mobile data?'
                : 'Download using mobile data?',
            style: const TextStyle(
              color: EpicColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'You can change this anytime in Settings → Data downloads.',
            style: TextStyle(
              color: EpicColors.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: EpicColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: EpicColors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
    return ok ?? false;
  }

  Future<void> _start(BuildContext context) async {
    final bool ok = await _confirmCellular(context, resuming: false);
    if (!ok) return;
    DownloadManager.instance.start(game);
    onClaim?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DownloadManager.instance,
      builder: (context, _) {
        final DownloadTask? task = DownloadManager.instance.taskFor(game.id);
        if (task == null) {
          // الحالة الابتدائية: Get للألعاب المجانية وInstall للمدفوعة (نصوص Epic)
          return EpicButton(
            label: game.isFree ? 'Get' : 'Install',
            icon: Icons.download_rounded,
            onPressed: () => _start(context),
          );
        }
        switch (task.state) {
          case DownloadTaskState.downloading:
            return Column(
              children: [
                _statusHeader(
                  'Downloading… ${(task.progress * 100).toStringAsFixed(0)}%',
                  EpicColors.blue,
                ),
                const SizedBox(height: 8),
                _progressBar(task, EpicColors.blue),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _iconAction(
                      Icons.pause_rounded,
                      'Stop Download',
                      () => DownloadManager.instance.pause(game.id),
                    ),
                    const SizedBox(width: 10),
                    _iconAction(
                      Icons.delete_outline_rounded,
                      'Cancel install',
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
                _statusHeader('Download Paused', EpicColors.textSecondary),
                const SizedBox(height: 8),
                _progressBar(task, EpicColors.textSecondary),
                const SizedBox(height: 12),
                EpicButton(
                  label: 'Resume Download',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () async {
                    final bool ok =
                        await _confirmCellular(context, resuming: true);
                    if (ok) {
                      DownloadManager.instance.resume(game.id);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => DownloadManager.instance.remove(game.id),
                  child: const Text(
                    'Cancel install',
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
                      const Expanded(
                        child: Text(
                          'Download paused waiting for Wi-Fi.',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
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
                      'Stop Download',
                      () => DownloadManager.instance.pause(game.id),
                    ),
                    const SizedBox(width: 10),
                    _iconAction(
                      Icons.delete_outline_rounded,
                      'Cancel install',
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
                      Expanded(
                        child: Text(
                          task.moving
                              ? 'Installing…'
                              : task.installed
                                  ? 'Installed on this device'
                                  : 'Download Complete. Ready to Install.',
                          style: const TextStyle(
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
                if (task.installed)
                  EpicButton(
                    label: 'Open',
                    icon: Icons.play_arrow_rounded,
                    variant: EpicButtonVariant.success,
                    onPressed: () async {
                      final bool ok =
                          await DownloadManager.instance.launchGame(task.package);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Open the game from its icon on your home screen',
                              ),
                            ),
                          );
                      }
                    },
                  )
                else
                  EpicButton(
                    label: task.moving ? 'Installing…' : 'Install',
                    icon: task.moving
                        ? Icons.hourglass_top_rounded
                        : Icons.install_mobile_rounded,
                    onPressed: task.moving
                        ? null
                        : () async {
                            final bool ok = await DownloadManager.instance
                                .openInstaller(game.id);
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'APK file not found — download again and retry',
                                    ),
                                  ),
                                );
                            }
                          },
                  ),
                const SizedBox(height: 10),
                ..._filesRows(context, task),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => DownloadManager.instance.remove(game.id),
                  child: const Text(
                    'Remove from Downloads',
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

  /// سطر حالة علوي بنص Epic (Downloading… %، Download Paused…).
  Widget _statusHeader(String text, Color color) {
    return Row(
      children: [
        Icon(
          text.startsWith('Downloading')
              ? Icons.downloading_rounded
              : Icons.pause_circle_outline_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

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
              '${formatBytes(task.downloadedBytes)} of ${formatBytes(task.totalBytes)}',
              style: const TextStyle(
                color: EpicColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (task.state == DownloadTaskState.downloading)
              Text(
                '${formatBytes(task.speed)}/s',
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
                'Saved to: $savedPath',
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
                task.installed
                    ? 'Moved to: $target'
                    : 'Will be moved after install to: $target',
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
            const SnackBar(content: Text('Path copied to clipboard')),
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
