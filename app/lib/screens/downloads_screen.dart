import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/library_controller.dart';
import '../models/game.dart';
import '../services/download_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/page_fade_transition.dart';
import 'library_screen.dart';

/// شاشة التنزيلات — إدارة كل تحميلات الألعاب داخل التطبيق مثل Epic Games:
/// تقدم حقيقي، سرعة، إيقاف/استكمال، وعودة تلقائية بعد انقطاع الشبكة.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key, required this.controller});

  final LibraryController controller;

  void _openLibrary(BuildContext context) {
    Navigator.of(context).push(
      epicRoute(
        LibraryScreen(
          controller: controller,
          onBrowse: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DownloadManager.instance,
      builder: (context, _) {
        final List<DownloadTask> tasks = DownloadManager.instance.tasks;
        if (tasks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: EpicColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: EpicColors.border),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      color: EpicColors.textSecondary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'لا توجد تنزيلات بعد',
                    style: TextStyle(
                      color: EpicColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'الألعاب المجانية تُثبّت مباشرة من صفحتها مثل Epic Games —\nواستكمالها تلقائيًا حتى بعد انقطاع النت أو إغلاق التطبيق',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: EpicColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => _openLibrary(context),
                    icon: const Icon(
                      Icons.video_library_rounded,
                      size: 18,
                      color: EpicColors.cyan,
                    ),
                    label: const Text(
                      'عرض مكتبتي',
                      style: TextStyle(
                        color: EpicColors.cyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: TextButton.icon(
                  onPressed: () => _openLibrary(context),
                  icon: const Icon(
                    Icons.video_library_rounded,
                    size: 16,
                    color: EpicColors.cyan,
                  ),
                  label: const Text(
                    'عرض مكتبتي',
                    style: TextStyle(
                      color: EpicColors.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: tasks.length,
                itemBuilder: (context, int i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TaskCard(task: tasks[i]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// بطاقة مهمة تحميل واحدة.
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final DownloadTaskState state = task.state;
    final (String label, Color color) = state == DownloadTaskState.completed &&
            task.installed
        ? ('مثبتة', EpicColors.success)
        : switch (state) {
            DownloadTaskState.downloading => ('جارٍ التحميل', EpicColors.blue),
            DownloadTaskState.waitingNetwork =>
              ('بانتظار الشبكة', Colors.orange),
            DownloadTaskState.paused => ('متوقف مؤقتًا', EpicColors.textSecondary),
            DownloadTaskState.completed => ('مكتمل', EpicColors.success),
          };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EpicColors.surface,
        border: Border.all(color: EpicColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس البطاقة: غلاف + اسم + حالة
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  width: 46,
                  height: 62,
                  child: task.game.image.isEmpty
                      ? Container(
                          color: EpicColors.elevated,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.sports_esports_outlined,
                            color: EpicColors.border,
                            size: 22,
                          ),
                        )
                      : Image.network(
                          task.game.image,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: EpicColors.elevated,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.sports_esports_outlined,
                              color: EpicColors.border,
                              size: 22,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.game.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: EpicColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(.12),
                        border: Border.all(color: color),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // شريط التقدم + الأرقام
          if (state != DownloadTaskState.completed) ...[
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
                if (state == DownloadTaskState.downloading)
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
            if (state == DownloadTaskState.waitingNetwork) ...[
              const SizedBox(height: 8),
              Text(
                'انقطع الاتصال — سيستكمل التحميل تلقائيًا من نفس النقطة عند عودة الشبكة…',
                style: TextStyle(
                  color: Colors.orange.shade200,
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _pillButton(
                  icon: state == DownloadTaskState.downloading
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: state == DownloadTaskState.downloading
                      ? 'إيقاف'
                      : 'متابعة',
                  onTap: () {
                    if (state == DownloadTaskState.downloading) {
                      DownloadManager.instance.pause(task.game.id);
                    } else {
                      DownloadManager.instance.resume(task.game.id);
                    }
                  },
                ),
                const SizedBox(width: 10),
                _pillButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'حذف',
                  danger: true,
                  onTap: () => DownloadManager.instance.remove(task.game.id),
                ),
              ],
            ),
          ] else ...[
            Text(
              'الحجم الكلي: ${formatBytes(task.totalBytes)}',
              style: const TextStyle(
                color: EpicColors.textSecondary,
                fontSize: 11.5,
              ),
            ),
            if (task.moving) ...[
              const SizedBox(height: 8),
              Text(
                'جارٍ نقل ملفات اللعبة إلى مكانها تلقائيًا…',
                style: TextStyle(
                  color: Colors.orange.shade200,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _pillButton(
                  icon: task.installed
                      ? Icons.play_arrow_rounded
                      : Icons.install_mobile_rounded,
                  label: task.installed ? 'تشغيل' : 'تثبيت',
                  onTap: () async {
                    if (task.installed) {
                      await DownloadManager.instance.launchGame(task.package);
                    } else {
                      await DownloadManager.instance.openInstaller(task.game.id);
                    }
                  },
                ),
                const SizedBox(width: 10),
                _pillButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'حذف',
                  danger: true,
                  onTap: () => DownloadManager.instance.remove(task.game.id),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          // صفوف الملفات الفردية (APK / OBB / Data)
          ...task.files.map((FileTask f) => _FileRow(fileTask: f)),
        ],
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final Color color = danger ? EpicColors.danger : EpicColors.cyan;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: EpicColors.elevated,
          border: Border.all(color: color.withOpacity(.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// صف ملف واحد داخل المهمة (حالته + مساره).
class _FileRow extends StatelessWidget {
  const _FileRow({required this.fileTask});

  final FileTask fileTask;

  @override
  Widget build(BuildContext context) {
    final DownloadFile f = fileTask.file;
    final IconData icon = f.isApk
        ? Icons.android_rounded
        : f.isObb
            ? Icons.layers_rounded
            : Icons.folder_open_rounded;
    final String statusText = fileTask.done
        ? 'مكتمل'
        : fileTask.state == FileTaskState.downloading
            ? 'جارٍ…'
            : 'بالانتظار';
    final Color statusColor = fileTask.done
        ? EpicColors.success
        : fileTask.state == FileTaskState.downloading
            ? EpicColors.blue
            : EpicColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EpicColors.elevated.withOpacity(.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: EpicColors.cyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${f.name} (${f.type.toUpperCase()}) — ${formatBytes(f.size)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: EpicColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (!fileTask.done && f.size > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '${(fileTask.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: EpicColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  final String path = fileTask.localPath ?? f.installPath;
                  if (path.isEmpty) return;
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
                  size: 13,
                  color: EpicColors.cyan,
                ),
              ),
            ],
          ),
          if (f.installPath.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'مسار التثبيت: ${f.installPath}',
              style: const TextStyle(
                color: EpicColors.textSecondary,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
