import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/game.dart';
import '../services/download_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/page_fade_transition.dart';
import 'library_screen.dart';

/// شاشة التنزيلات بأسلوب سوق أبل (App Store):
/// بحث داخل التنزيلات فقط، صف لكل لعبة (أيقونة + اسم + حجم + نسبة التقدم
/// + شريط تحميل + زر دائري إيقاف/متابعة/تثبيت)، والضغط على اللعبة يفتح
/// صفحة معلوماتها الكاملة.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({
    super.key,
    required this.controller,
    required this.onOpenGame,
    required this.searchFocus,
  });

  final LibraryController controller;
  final ValueChanged<Game> onOpenGame;
  final FocusNode searchFocus;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openLibrary() {
    Navigator.of(context).push(
      epicRoute(
        LibraryScreen(
          controller: widget.controller,
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
        // البحث داخل التنزيلات فقط (على الألعاب المحمّلة فعليًا)
        final List<DownloadTask> filtered = _query.isEmpty
            ? tasks
            : tasks
                .where((DownloadTask t) => t.game.name
                    .toLowerCase()
                    .contains(_query.toLowerCase()))
                .toList();

        return Column(
          children: [
            // حقل بحث داخل التنزيلات — يبحث على المحمّل فقط دون الانتقال لصفحة أخرى
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchController,
                focusNode: widget.searchFocus,
                onChanged: (String v) => setState(() => _query = v),
                style: const TextStyle(
                  color: EpicColors.textPrimary,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  hintText: 'بحث في التنزيلات',
                  hintStyle: const TextStyle(
                    color: EpicColors.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: EpicColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: EpicColors.textSecondary,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: EpicColors.surface,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: EpicColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: EpicColors.blue),
                  ),
                ),
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? _EmptyDownloads(controller: widget.controller)
                  : _buildList(filtered),
            ),
          ],
        );
      },
    );
  }

  Widget _buildList(List<DownloadTask> tasks) {
    if (tasks.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 60),
          Center(
            child: Text(
              'لا توجد نتائج مطابقة في تنزيلاتك',
              style: TextStyle(
                color: EpicColors.textSecondary,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: tasks.length + 1,
      itemBuilder: (context, int i) {
        // رابط "عرض مكتبتي" أسفل القائمة
        if (i == tasks.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton.icon(
              onPressed: _openLibrary,
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
          );
        }
        final DownloadTask task = tasks[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Dismissible(
            key: ValueKey<int>(task.game.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: AlignmentDirectional.centerEnd,
              padding: const EdgeInsetsDirectional.only(end: 20),
              decoration: BoxDecoration(
                color: EpicColors.danger.withOpacity(.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: EpicColors.danger,
                size: 24,
              ),
            ),
            onDismissed: (_) => DownloadManager.instance.remove(task.game.id),
            child: _TaskRow(
              task: task,
              onOpen: () => widget.onOpenGame(task.game),
            ),
          ),
        );
      },
    );
  }
}

/// الحالة الفارغة عندما لا توجد أي تنزيلات.
class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
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
              'الألعاب المجانية تُحمَّل مباشرة من صفحتها —\nويكمل التحميل بالخلفية حتى لو خرجت من التطبيق',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: EpicColors.textSecondary,
                fontSize: 12.5,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  epicRoute(
                    LibraryScreen(
                      controller: controller,
                      onBrowse: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              },
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
}

/// صف لعبة واحدة بأسلوب سوق أبل: أيقونة + اسم + حالة/حجم + شريط تقدم +
/// زر دائري (إيقاف / متابعة / تثبيت / تشغيل). الضغط على الصف يفتح معلومات اللعبة.
class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onOpen});

  final DownloadTask task;
  final VoidCallback onOpen;

  (String, Color) get _status {
    if (task.moving) return ('جارٍ تثبيت ملفات اللعبة…', EpicColors.blue);
    switch (task.state) {
      case DownloadTaskState.downloading:
        return ('جارٍ التحميل…', EpicColors.blue);
      case DownloadTaskState.waitingNetwork:
        return ('بانتظار الشبكة — سيستكمل تلقائيًا', Colors.orange);
      case DownloadTaskState.paused:
        return ('متوقف مؤقتًا', EpicColors.textSecondary);
      case DownloadTaskState.completed:
        return task.installed ? ('مثبتة على جهازك', EpicColors.success) : ('مكتمل', EpicColors.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (String status, Color color) = _status;
    final bool done = task.state == DownloadTaskState.completed;

    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EpicColors.surface,
          border: Border.all(color: EpicColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // أيقونة اللعبة — الضغط عليها يفتح معلومات اللعبة أيضًا
            GestureDetector(
              onTap: onOpen,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: task.game.image.isEmpty
                      ? Container(
                          color: EpicColors.elevated,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.sports_esports_outlined,
                            color: EpicColors.border,
                            size: 26,
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
                              size: 26,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // الاسم + الحالة + شريط التقدم + النسبة والحجم
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
                  const SizedBox(height: 3),
                  Text(
                    done
                        ? '$status — ${formatBytes(task.totalBytes)}'
                        : '$status · ${formatBytes(task.downloadedBytes)} من ${formatBytes(task.totalBytes)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: done ? 1.0 : task.progress,
                      minHeight: 4,
                      backgroundColor: EpicColors.elevated,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        done
                            ? (task.installed ? 'جاهزة للتشغيل' : 'جاهزة للتثبيت')
                            : '${(task.progress * 100).toStringAsFixed(0)}%'
                                '${task.state == DownloadTaskState.downloading ? ' — ${formatBytes(task.speed)}/ث' : ''}',
                        style: TextStyle(
                          color: task.state == DownloadTaskState.downloading
                              ? EpicColors.cyan
                              : EpicColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // الزر الدائري: إيقاف/متابعة أثناء التحميل، تثبيت/تشغيل بعد الاكتمال
            _CircleAction(task: task),
          ],
        ),
      ),
    );
  }
}

/// الزر الدائري على يسار الصف (نمط سوق أبل).
class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final bool done = task.state == DownloadTaskState.completed;

    // مكتملة: زر تثبيت / تشغيل بحجم صغير (قرص أزرق مثل سوق أبل)
    if (done || task.moving) {
      if (task.moving) {
        return const SizedBox(
          width: 34,
          height: 34,
          child: Padding(
            padding: EdgeInsets.all(6),
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(EpicColors.blue),
            ),
          ),
        );
      }
      return GestureDetector(
        onTap: () async {
          if (task.installed) {
            await DownloadManager.instance.launchGame(task.package);
          } else {
            await DownloadManager.instance.openInstaller(task.game.id);
          }
        },
        child: Container(
          width: 44,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: EpicColors.blue,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            task.installed ? 'تشغيل' : 'تثبيت',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    // جارية أو متوقفة: زر دائري إيقاف/متابعة
    final bool isDownloading = task.state == DownloadTaskState.downloading;
    return GestureDetector(
      onTap: () {
        if (isDownloading) {
          DownloadManager.instance.pause(task.game.id);
        } else {
          DownloadManager.instance.resume(task.game.id);
        }
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: EpicColors.blue, width: 1.8),
        ),
        child: Icon(
          isDownloading
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          color: EpicColors.blue,
          size: 19,
        ),
      ),
    );
  }
}
