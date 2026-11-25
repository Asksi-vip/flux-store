import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// مراقبة دورة حياة التطبيق (العودة من نافذة التثبيت) لنقل الملفات تلقائيًا
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game.dart';
import 'api_service.dart';

/// حالة ملف واحد داخل مهمة التحميل.
enum FileTaskState { pending, downloading, completed }

/// حالة مهمة اللعبة كاملة (مثل Epic: جارٍ، متوقف، بانتظار الشبكة، مكتمل).
enum DownloadTaskState { downloading, paused, waitingNetwork, completed }

/// تنسيق حجم البايتات لعرضه (B / KB / MB / GB).
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const List<String> units = ['B', 'KB', 'MB', 'GB'];
  double v = bytes.toDouble();
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

/// مهمة ملف واحد (APK أو OBB أو Data) مع تقدمه ومساره المحلي.
class FileTask {
  FileTask(this.file, {this.downloaded = 0, this.state = FileTaskState.pending, this.localPath});

  DownloadFile file; // قابل للتحديث عند استخراج روابط جديدة طازجة
  int downloaded; // البايتات المنزلة فعليًا (للاستئناف من نفس النقطة)
  FileTaskState state;
  String? localPath; // المسار المحلي الحقيقي للملف

  int get size => file.size;
  double get progress => size > 0 ? (downloaded / size).clamp(0.0, 1.0) : 0.0;
  bool get done => state == FileTaskState.completed;

  Map<String, dynamic> toJson() => {
        'file': file.toJson(),
        'downloaded': downloaded,
        'state': state.name,
        'local_path': localPath ?? '',
      };

  factory FileTask.fromJson(Map<String, dynamic> json) => FileTask(
        DownloadFile.fromJson(Map<String, dynamic>.from(json['file'] as Map)),
        downloaded: (json['downloaded'] as num?)?.toInt() ?? 0,
        state: FileTaskState.values.firstWhere(
          (e) => e.name == json['state'],
          orElse: () => FileTaskState.pending,
        ),
        localPath: (json['local_path'] as String?)?.isEmpty == true
            ? null
            : json['local_path'] as String?,
      );
}

/// مهمة تحميل لعبة كاملة: كل ملفاتها تُحمّل بالتتابع (مثل Epic Games).
class DownloadTask {
  DownloadTask({
    required this.game,
    required this.files,
    this.state = DownloadTaskState.paused,
    this.installed = false,
    bool? nativeEngine,
  }) : nativeEngine = nativeEngine ?? Platform.isAndroid;

  final Game game;
  final List<FileTask> files;
  DownloadTaskState state;

  /// هل اللعبة مثبتة فعليًا على الجهاز (بعد تثبيت الـ APK)؟
  bool installed;

  /// التحميل يعمل بمحرك Kotlin الأصلي (خدمة الخلفية) — يكمل حتى بعد
  /// الخروج من التطبيق، مع إشعار نظام حقيقي بشريط تقدم.
  bool nativeEngine;

  /// جارٍ نقل ملفات OBB/Data تلقائيًا إلى مكانها الصحيح بعد التثبيت.
  bool moving = false;
  int speed = 0; // بايت/ثانية (آخر قياس)

  int get totalBytes {
    int t = 0;
    for (final f in files) {
      t += f.size;
    }
    return t;
  }

  int get downloadedBytes {
    int d = 0;
    for (final f in files) {
      d += f.downloaded;
    }
    return d;
  }

  double get progress {
    final int t = totalBytes;
    return t > 0 ? (downloadedBytes / t).clamp(0.0, 1.0) : 0.0;
  }

  /// الملف الجاري تحميله حاليًا (أول ملف غير مكتمل).
  FileTask? get activeFile {
    for (final f in files) {
      if (!f.done) return f;
    }
    return null;
  }

  /// حزمة اللعبة المستهدفة — لمسارات OBB/Data وكشف التثبيت والتشغيل.
  String get package {
    final String g = game.packageName;
    if (g.isNotEmpty) return g;
    final String d = game.download?.packageName ?? '';
    return d.isNotEmpty ? d : 'com.fluxstore.games';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'game': game.toJson(),
        'state': state.name,
        'installed': installed,
        'native': nativeEngine,
        'files': files.map((FileTask f) => f.toJson()).toList(),
      };

  /// هل انقطع الاتصال أثناء التحميل؟
  bool get waiting => state == DownloadTaskState.waitingNetwork;
}

/// مدير التحميلات داخل التطبيق (مثل Epic Games / App Store):
///
/// على أندرويد يعمل التحميل بمحرك Kotlin أصلي داخل خدمة أمامية (Foreground
/// Service) — التحميل يكمل بالخلفية حتى لو خرجت من التطبيق أو أطفأت الشاشة،
/// مع إشعار نظام حقيقي (أيقونة اللعبة + الاسم + النسبة + شريط تقدم) مثل سوق
/// أبل، ويكمل تلقائيًا عند انقطاع وعودة الشبكة.
///
/// التقدم يُشارك بين الخدمة الأصلية والواجهة عبر مزامنة كل ثانية، والحالة
/// تُحفظ في SharedPreferences وتُستعاد بعد إعادة فتح التطبيق.
class DownloadManager extends ChangeNotifier with WidgetsBindingObserver {
  DownloadManager._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 45),
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
        'Accept': '*/*',
        'Accept-Encoding': 'identity',
      },
    ));
    _bgChannel.setMethodCallHandler(_handleNativeCall);
    // مراقبة دورة الحياة: عند العودة من نافذة تثبيت أندرويد ننقل OBB/Data تلقائيًا
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
    // مزامنة دورية مع محرك الخلفية الأصلي (كل ثانية)
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_syncFromNative());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_postInstallFlow());
      // عند العودة للتطبيق نزامن فورًا مع محرك الخلفية (لا انتظار للثانية القادمة)
      unawaited(_syncFromNative());
    }
  }

  static final DownloadManager instance = DownloadManager._();

  static const String _kStorage = 'flux_downloads_v1';
  static const Duration _retryDelay = Duration(seconds: 4);

  /// قناة خدمة الخلفية الأصلية (Foreground Service على أندرويد):
  /// التحميل الفعلي يعمل داخل الخدمة بمحرك Kotlin — يبقى شغالًا حتى لو خرجت
  /// من التطبيق أو أطفأت الشاشة، مع إشعار تقدم حقيقي في شريط النظام.
  static const MethodChannel _bgChannel = MethodChannel('flux.background');

  late final Dio _dio;
  final Map<int, DownloadTask> _tasks = {};
  final Map<int, CancelToken> _tokens = {};
  final Map<int, Timer> _retryTimers = {};
  final Map<int, DateTime> _lastSpeedTick = {};
  final Map<int, int> _lastSpeedBytes = {};
  final Map<int, DateTime> _lastNotify = {};
  final Map<int, DateTime> _lastPersist = {};
  Timer? _syncTimer;
  bool _restored = false;

  /// قائمة المهام (للقراءة).
  List<DownloadTask> get tasks => _tasks.values.toList();

  /// مهمة لعبة معينة (أو null).
  DownloadTask? taskFor(int gameId) => _tasks[gameId];

  /// هل هناك تنزيلات نشطة (لنقطة التبويب)؟
  bool get hasActive => _tasks.values
      .any((t) => t.state == DownloadTaskState.downloading || t.waiting);

  // ---------- بدء / إيقاف / استكمال / إزالة ----------

  /// بدء تحميل لعبة مجانية (أو استكمال مهمة موجودة).
  Future<void> start(Game game) async {
    DownloadInfo? dl = game.download;
    if (dl == null || !dl.available) return;
    await _ensurePermissions();

    final DownloadTask? existing = _tasks[game.id];
    if (existing != null && existing.state == DownloadTaskState.completed) {
      return; // مكتملة سابقًا
    }

    // تحديث روابط صفحات المصدر (ميديافاير/درايف) إذا كانت قديمة أو منتهية —
    // الخادم يعيد استخراج الرابط المباشر عند القِدم فقط، والفشل يُتجاهل بهدوء
    try {
      final Game? fresh = await ApiService.instance.refreshDownloadLinks(game.id);
      if (fresh != null &&
          fresh.download != null &&
          fresh.download!.available) {
        game = fresh;
        dl = fresh.download;
        // إذا كانت المهمة موجودة سابقًا، نحدّث روابط الملفات داخلها فورًا لضمان عدم انتهاء الصلاحية
        if (existing != null) {
          for (final freshFile in dl!.files) {
            for (final ef in existing.files) {
              if (ef.file.id == freshFile.id || ef.file.type == freshFile.type) {
                ef.file = freshFile;
              }
            }
          }
        }
      }
    } catch (_) {}

    if (existing == null) {
      final List<FileTask> files = <FileTask>[];
      for (final DownloadFile f in dl!.files) {
        files.add(FileTask(f, localPath: await _resolvePath(game, f)));
      }
      _tasks[game.id] = DownloadTask(
        game: game,
        files: files,
        nativeEngine: Platform.isAndroid,
      );
      await _persist();
    } else {
      existing.nativeEngine = Platform.isAndroid;
    }
    resume(game.id);
  }

  /// إيقاف مؤقت (يحتفظ بالجزء المنزّل ويستكمل لاحقًا من نفس النقطة).
  void pause(int gameId) {
    final DownloadTask? t = _tasks[gameId];
    if (t == null || t.state == DownloadTaskState.completed) return;
    _cancelToken(gameId);
    _cancelRetry(gameId);
    t.state = DownloadTaskState.paused;
    t.speed = 0;
    for (final FileTask f in t.files) {
      if (f.state == FileTaskState.downloading) f.state = FileTaskState.pending;
    }
    if (t.nativeEngine) _nativeCall('pause', {'gameId': gameId});
    _bgStopIfNeeded();
    _persist();
    notifyListeners();
  }

  /// استكمال التحميل (من آخر بايت نزل فعليًا عبر Range).
  void resume(int gameId) {
    final DownloadTask? t = _tasks[gameId];
    if (t == null || t.state == DownloadTaskState.downloading) return;
    // محرك الخلفية الأصلي: الخدمة الكوتلين تحمّل وتدير الإشعار بنفسها
    if (t.nativeEngine && _nativeDispatch(t)) {
      t.state = DownloadTaskState.downloading;
      _persist();
      notifyListeners();
      return;
    }
    // محرك dio الاحتياطي (منصات غير أندرويد أو فشل المحرك الأصلي)
    t.nativeEngine = false;
    _run(gameId);
  }

  /// إزالة المهمة مع حذف الملفات الجزئية.
  void remove(int gameId) {
    final DownloadTask? t = _tasks[gameId];
    if (t == null) return;
    _cancelToken(gameId);
    _cancelRetry(gameId);
    if (t.nativeEngine) _nativeCall('cancel', {'gameId': gameId});
    for (final FileTask f in t.files) {
      final String? p = f.localPath;
      if (p != null) {
        try {
          final File file = File(p);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
    }
    _tasks.remove(gameId);
    _bgStopIfNeeded();
    _persist();
    notifyListeners();
  }

  // ---------- المحرك الأصلي (خدمة الخلفية الكوتلين) ----------

  /// استدعاء قناة أندرويد مع كتم أي خطأ (منصات غير أندرويد / خدمة غير متاحة).
  Future<Object?> _nativeCall(String method, Map<String, dynamic> args) async {
    try {
      return await _bgChannel.invokeMethod<Object?>(method, args);
    } catch (_) {
      return null;
    }
  }

  /// إرسال مهمة التحميل إلى خدمة الخلفية الأصلية — تعيد true عند النجاح.
  bool _nativeDispatch(DownloadTask t) {
    unawaited(_nativeDispatchAsync(t));
    // التحسين: نفترض النجاح على أندرويد؛ إن فشل الإرسال تتحول المهمة
    // تلقائيًا إلى محرك dio في المزامنة القادمة (_fallbackIfNeeded).
    return Platform.isAndroid;
  }

  Future<void> _nativeDispatchAsync(DownloadTask t) async {
    final List<Map<String, dynamic>> files = <Map<String, dynamic>>[];
    for (final FileTask f in t.files) {
      files.add(<String, dynamic>{
        'url': f.file.url,
        'path': f.localPath ?? f.file.installPath,
        'size': f.file.size,
      });
    }
    final Object? ok = await _nativeCall('download', <String, dynamic>{
      'gameId': t.game.id,
      'name': t.game.name,
      'icon': t.game.image,
      // JSON مُشفَّر هنا في Dart — يقرؤه الكوتلين مباشرة بـ org.json
      'filesJson': jsonEncode(files),
    });
    if (!(ok is bool && ok)) {
      // الخدمة الأصلية غير متاحة أو رفضت المهمة — نرجع لمحرك dio الاحتياطي
      final DownloadTask? cur = _tasks[t.game.id];
      if (cur != null && cur.state == DownloadTaskState.downloading) {
        cur.nativeEngine = false;
        _run(t.game.id);
      }
    }
  }

  /// مزامنة التقدم الحقيقي من محرك الخلفية الأصلي إلى مهام الواجهة.
  ///
  /// الخدمة الأصلية تكتب حالة كل مهمة (النسبة، السرعة، الحالة) كل ثانية،
  /// ونحن ندمجها هنا فتبقى الواجهة محدثة حتى لو اكتمل التحميل بالخلفية.
  Future<void> _syncFromNative() async {
    if (_tasks.values.every((t) => !t.nativeEngine)) return;
    final Object? raw = await _nativeCall('getState', const {});
    if (raw is! String || raw.isEmpty) return;
    Map<String, dynamic> jobs;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map && decoded['jobs'] is Map) {
        jobs = Map<String, dynamic>.from(decoded['jobs'] as Map);
      } else {
        return;
      }
    } catch (_) {
      return;
    }

    bool changed = false;
    for (final DownloadTask t in _tasks.values) {
      if (!t.nativeEngine) continue;
      final dynamic entry = jobs[t.game.id.toString()];
      if (entry == null) continue;
      final Map<String, dynamic> m =
          Map<String, dynamic>.from(entry as Map);
      // المستخدم أوقفها يدويًا — نواياه هي الأهم حتى لو ما زال المحرك يلفّ
      if (t.state == DownloadTaskState.paused) continue;

      // البايتات لكل ملف
      final List<dynamic>? fileBytes = m['files'] as List<dynamic>?;
      if (fileBytes != null) {
        for (int i = 0; i < t.files.length && i < fileBytes.length; i++) {
          final int b = (fileBytes[i] as num?)?.toInt() ?? 0;
          if (t.files[i].downloaded != b) {
            t.files[i].downloaded = b;
            changed = true;
          }
          if (t.files[i].file.size > 0 && b >= t.files[i].file.size) {
            if (t.files[i].state != FileTaskState.completed) {
              t.files[i].state = FileTaskState.completed;
              changed = true;
            }
          }
        }
      }

      final String st = m['state']?.toString() ?? '';
      switch (st) {
        case 'downloading':
          if (t.state != DownloadTaskState.downloading) {
            t.state = DownloadTaskState.downloading;
            changed = true;
          }
          break;
        case 'waiting':
          if (t.state != DownloadTaskState.waitingNetwork) {
            t.state = DownloadTaskState.waitingNetwork;
            t.speed = 0;
            changed = true;
          }
          break;
        case 'completed':
          if (t.state != DownloadTaskState.completed) {
            t.state = DownloadTaskState.completed;
            t.speed = 0;
            changed = true;
            // مثل Epic: فتح نافذة تثبيت أندرويد تلقائيًا بعد الاكتمال،
            // ثم نقل OBB/Data (إذا كانت اللعبة مثبتة من تحديث سابق)
            unawaited(openInstaller(t.game.id));
            unawaited(_postInstallFlow());
          }
          break;
      }

      final int sp = (m['speed'] as num?)?.toInt() ?? 0;
      if (sp != t.speed) {
        t.speed = sp;
        changed = true;
      }
    }

    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  // ---------- خدمة الخلفية الاحتياطية (مسار dio) ----------

  void _bgStart(DownloadTask t) {
    try {
      _bgChannel.invokeMethod('start', {'title': 'Downloading ${t.game.name}'});
    } catch (_) {}
  }

  void _bgUpdate(DownloadTask t) {
    try {
      _bgChannel.invokeMethod('update', {
        'title': 'Downloading ${t.game.name}',
        'progress':
            '${(t.progress * 100).toStringAsFixed(0)}% — ${formatBytes(t.speed)}/s',
      });
    } catch (_) {}
  }

  void _bgStopIfNeeded() {
    if (!hasActive) {
      try {
        _bgChannel.invokeMethod('stop');
      } catch (_) {}
    }
  }

  // ---------- التثبيت التلقائي بعد اكتمال التحميل ----------

  /// فتح مثبّت أندرويد ("هل تريد تثبيت هذا التطبيق؟") لملف APK المنزّل —
  /// نفس نافذة التثبيت التي يفتحها Epic Games بعد اكتمال التحميل.
  /// ذاتي الإصلاح: إذا الملف غير موجود بالمسار المحفوظ نبحث عنه فعليًا
  /// في مجلد FluxGames/<المعرف>/ وأي مسار محسوب من جديد (يتعافى بعد
  /// تحديث التطبيق أو تغيّر المسارات) قبل إعلان الفشل.
  /// يعيد true إذا فُتحت النافذة فعليًا.
  Future<bool> openInstaller(int gameId) async {
    if (!Platform.isAndroid) return false;
    final DownloadTask? t = _tasks[gameId];
    if (t == null || t.state != DownloadTaskState.completed) return false;
    final File apk = _findApk(t);
    if (apk.existsSync() && apk.lengthSync() > 0) {
      // صحّح المسار المحفوظ إن اختلف (شفاء ذاتي دائم)
      final FileTask? apkTask = _apkTaskOf(t);
      if (apkTask != null && apkTask.localPath != apk.path) {
        apkTask.localPath = apk.path;
        await _persist();
      }
      try {
        final bool? ok = await _bgChannel.invokeMethod<bool>(
          'installApk',
          <String, dynamic>{
            'path': apk.path,
            'pkg': t.package,
            'name': t.game.name,
            'gameId': t.game.id,
          },
        );
        return ok ?? false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// استقبال إشعارات حالة التثبيت المباشرة من نظام أندرويد (PackageInstaller Session)
  /// مثل Epic Games Store تمامًا عند اكتمال التثبيت الصامت أو اليدوي.
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onInstallResult') {
      final Map args = (call.arguments as Map?) ?? const {};
      final String pkg = args['pkg']?.toString() ?? '';
      final int gameId = (args['gameId'] as num?)?.toInt() ?? 0;
      final bool success = args['success'] == true;

      if (success) {
        DownloadTask? task = _tasks[gameId];
        if (task == null && pkg.isNotEmpty) {
          for (final t in _tasks.values) {
            if (t.package == pkg) {
              task = t;
              break;
            }
          }
        }
        if (task != null) {
          task.installed = true;
          await _persist();
          notifyListeners();
          unawaited(_postInstallFlow());
        }
      }
    }
    return null;
  }

  /// مهمة ملف الـ APK داخل المهمة.
  FileTask? _apkTaskOf(DownloadTask t) {
    for (final FileTask f in t.files) {
      if (f.file.type == 'apk') return f;
    }
    return null;
  }

  /// إيجاد ملف APK الفعلي: المسار المحفوظ أولًا، ثم مسح مجلد FluxGames
  /// للمهمة، ثم إعادة حساب المسار من جديد — الأحدث والأكبر يفوز.
  File _findApk(DownloadTask t) {
    final FileTask? ft = _apkTaskOf(t);
    if (ft != null && ft.localPath != null) {
      final File f = File(ft.localPath!);
      if (f.existsSync() && f.lengthSync() > 0) return f;
    }
    final candidates = <File>[];
    // 1) مجلد التطبيق المخصص للألعاب (مكان الحفظ الافتراضي)
    try {
      final Directory? ext = _lastExternalDir;
      if (ext != null) {
        final Directory d = Directory('${ext.path}/FluxGames/${t.game.id}');
        if (d.existsSync()) {
          for (final FileSystemEntity e in d.listSync()) {
            if (e is File &&
                e.path.toLowerCase().endsWith('.apk') &&
                e.lengthSync() > 0) {
              candidates.add(e);
            }
          }
        }
      }
    } catch (_) {}
    // 2) المسار المعاد حسابه (مثلًا بعد تغيّر مجلد التطبيق بعد تحديث)
    if (ft != null) {
      try {
        final String recomputed = _resolvePathSync(t.game, ft.file);
        if (recomputed.isNotEmpty) {
          final File f = File(recomputed);
          if (f.existsSync() && f.lengthSync() > 0) candidates.add(f);
        }
      } catch (_) {}
    }
    if (candidates.isEmpty) {
      return File(ft?.localPath ?? '');
    }
    // الأحدث يفوز
    candidates.sort((a, b) =>
        b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return candidates.first;
  }

  /// آخر مجلد خارجي معروف (يُخزّن من _appGamesDir للوصول المتزامن لاحقًا).
  Directory? _lastExternalDir;

  /// حساب مسار ملف بشكل متزامن (بدون await) — يُستخدم للشفاء الذاتي.
  String _resolvePathSync(Game game, DownloadFile f) {
    final String pkg = game.packageName.isNotEmpty
        ? game.packageName
        : (game.download?.packageName.isNotEmpty ?? false
            ? game.download!.packageName
            : 'com.fluxstore.games');
    String fileName;
    if (f.isObb) {
      final int vc =
          f.versionCode > 0 ? f.versionCode : (game.download?.versionCode ?? 0);
      fileName = 'main.${vc > 0 ? vc : 1}.$pkg.obb';
    } else {
      fileName = _fileNameFromUrl(f.url);
      if (fileName.isEmpty) fileName = 'file_${f.id}.bin';
    }
    final Directory? extDir = _lastExternalDir;
    if (f.isApk && extDir != null) {
      return '${extDir.path}/FluxGames/${game.id}/$fileName';
    }
    return '';
  }

  /// هل اللعبة مثبتة على الجهاز؟ (فحص حقيقي عبر PackageManager)
  Future<bool> isGameInstalled(String pkg) async {
    if (!Platform.isAndroid || pkg.isEmpty) return false;
    try {
      final bool? ok = await _bgChannel.invokeMethod<bool>(
        'isPackageInstalled',
        <String, dynamic>{'pkg': pkg},
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// تشغيل اللعبة المثبتة (أيقونتها في مشغّل النظام).
  Future<bool> launchGame(String pkg) async {
    if (!Platform.isAndroid || pkg.isEmpty) return false;
    try {
      final bool? ok = await _bgChannel.invokeMethod<bool>(
        'launchApp',
        <String, dynamic>{'pkg': pkg},
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  // ---------- نقل ملفات OBB/Data تلقائيًا بعد التثبيت (بدون تدخل المستخدم) ----------

  bool _postInstallRunning = false;

  /// عند العودة من نافذة التثبيت (أو فتح التطبيق): لكل لعبة مكتملة ومثبتة —
  /// ننقل OBB/Data من مجلد التطبيق البديل إلى Android/obb و Android/data
  /// مباشرة، فتصبح اللعبة جاهزة للتشغيل دون أي خطوة يدوية.
  Future<void> _postInstallFlow() async {
    if (_postInstallRunning || !Platform.isAndroid) return;
    _postInstallRunning = true;
    try {
      for (final DownloadTask t in List<DownloadTask>.from(_tasks.values)) {
        if (t.state != DownloadTaskState.completed) continue;
        final String pkg = t.package;
        final bool wasInstalled = t.installed;
        if (!await isGameInstalled(pkg)) continue;
        t.installed = true;

        bool moved = false;
        for (final FileTask f in t.files) {
          if (!(f.file.isObb || f.file.isData) || f.localPath == null) continue;
          final String target = _properTargetPath(t.game, f.file);
          if (target.isEmpty || _samePath(f.localPath!, target)) continue;

          final String dir = target.substring(0, target.lastIndexOf('/'));
          if (!_canWriteSync(dir)) {
            // الصلاحية غير ممنوحة بعد — طلبها الآن (تعود النتيجة عند الرجوع)
            await _ensurePermissions();
            if (!_canWriteSync(dir)) continue; // نحاول مجددًا عند العودة القادمة
          }
          t.moving = true;
          notifyListeners();
          final bool ok = await _moveFile(f.localPath!, target);
          if (ok) {
            f.localPath = target;
            moved = true;
          }
        }
        t.moving = false;
        if (!wasInstalled || moved) {
          await _persist();
          notifyListeners();
          // إشعار نظام: اللعبة جاهزة للتشغيل الآن
          try {
            _bgChannel.invokeMethod(
              'notifyReady',
              <String, dynamic>{'title': '${t.game.name} is ready to play ✓'},
            );
          } catch (_) {}
        }
      }
    } catch (_) {}
    _postInstallRunning = false;
  }

  /// المسار الصحيح النهائي للملف داخل مجلدات النظام (نفس منطق _resolvePath).
  /// باكج نيم اللعبة مفقود؟ نعيد نصًا فارغًا — لا ننقل OBB إلى مكان خاطئ
  /// (المسار يُحدد بعد ضبط الباكج نيم من لوحة الإدارة أو التعبئة الذكية).
  String _properTargetPath(Game game, DownloadFile f) {
    final String pkg = game.packageName.isNotEmpty
        ? game.packageName
        : (game.download?.packageName.isNotEmpty ?? false
            ? game.download!.packageName
            : '');
    if (pkg.isEmpty) return '';
    if (f.isObb) {
      final int vc = f.versionCode > 0
          ? f.versionCode
          : (game.download?.versionCode ?? 0);
      return '/storage/emulated/0/Android/obb/$pkg/main.${vc > 0 ? vc : 1}.$pkg.obb';
    }
    if (f.isData) {
      String name = _fileNameFromUrl(f.url);
      if (name.isEmpty) name = 'file_${f.id}.bin';
      return '/storage/emulated/0/Android/data/$pkg/files/$name';
    }
    return '';
  }

  /// نقل ملف فعلي (rename أو نسخ+حذف عبر نقاط تحميل مختلفة).
  Future<bool> _moveFile(String from, String to) async {
    try {
      final File src = File(from);
      if (!src.existsSync() || src.lengthSync() <= 0) return false;
      final Directory dir = Directory(to.substring(0, to.lastIndexOf('/')));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final File dst = File(to);
      if (dst.existsSync()) dst.deleteSync();
      try {
        src.renameSync(to);
        return true;
      } catch (_) {
        final IOSink sink = dst.openWrite(mode: FileMode.write);
        await sink.addStream(src.openRead());
        await sink.flush();
        await sink.close();
        src.deleteSync();
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  bool _samePath(String a, String b) {
    String norm(String s) => s.replaceAll('\\', '/').toLowerCase();
    return norm(a) == norm(b);
  }

  // ---------- الاستعادة من التخزين المحلي ----------

  /// استعادة المهام بعد إعادة فتح التطبيق + إكمال ما كان بانتظار الشبكة.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_kStorage);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        for (final dynamic item in list) {
          try {
            final Map<String, dynamic> map =
                Map<String, dynamic>.from(item as Map);
            final Game game =
                Game.fromJson(Map<String, dynamic>.from(map['game'] as Map));
            final List<FileTask> files = ((map['files'] as List?) ?? const [])
                .map((dynamic e) =>
                    FileTask.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
            if (game.id == 0 || files.isEmpty) continue;
            // الحالة المحفوظة: ما كان جارًٍا عند إغلاق التطبيق يعود بانتظار الشبكة
            // ويُستكمل تلقائيًا عند الفتح (مثل Epic) — المتوقف يدويًا يبقى متوقفًا
            final String saved = map['state']?.toString() ?? 'paused';
            DownloadTaskState st = DownloadTaskState.values.firstWhere(
              (e) => e.name == saved,
              orElse: () => DownloadTaskState.paused,
            );
            if (st == DownloadTaskState.downloading) {
              st = DownloadTaskState.waitingNetwork;
            }
            _tasks[game.id] = DownloadTask(
              game: game,
              files: files,
              state: st,
              installed: map['installed'] == true,
              nativeEngine: map['native'] != null ? (map['native'] == true) : Platform.isAndroid,
            );
          } catch (_) {}
        }
      }
    } catch (_) {}
    notifyListeners();

    // مزامنة فورية مع محرك الخلفية الأصلي: ربما اكتمل التحميل والتطبيق مغلق
    await _syncFromNative();

    // مثل Epic: ما كان في انتظار الشبكة يُستكمل تلقائيًا عند فتح التطبيق
    for (final DownloadTask t in tasks) {
      if (t.waiting) resume(t.game.id);
    }
    // نقل تلقائي لأي لعبة مثبتة ما زالت ملفاتها في مجلد التطبيق البديل
    unawaited(_postInstallFlow());
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> list = _tasks.values
          .map((DownloadTask t) => t.toJson())
          .toList();
      await prefs.setString(_kStorage, jsonEncode(list));
    } catch (_) {}
  }

  // ---------- المحرك الاحتياطي: تنزيل فعلي بمقاطع مع استئناف ----------

  Future<void> _run(int gameId) async {
    final DownloadTask? t = _tasks[gameId];
    if (t == null) return;
    if (t.state == DownloadTaskState.downloading) return;
    t.state = DownloadTaskState.downloading;
    // تشغيل خدمة الخلفية الاحتياطية: إشعار تقدم + إبقاء العمل مستمرًا
    _bgStart(t);
    notifyListeners();

    for (final FileTask ft in t.files) {
      if (ft.done) continue;
      final bool ok = await _downloadFile(t, ft);
      if (!ok) return; // أُلغيت أو بانتظار الشبكة — الحالة مضبوطة داخليًا
    }

    t.state = DownloadTaskState.completed;
    t.speed = 0;
    _bgStopIfNeeded();
    await _persist();
    notifyListeners();
    // مثل Epic Games: فتح نافذة تثبيت أندرويد تلقائيًا بعد اكتمال التحميل،
    // ثم نقل OBB/Data تلقائيًا (إن كانت اللعبة مثبتة من تحديث سابق)
    await openInstaller(t.game.id);
    unawaited(_postInstallFlow());
  }

  /// تنزيل ملف واحد كاملًا مع دعم الاستئناف (Range) ومحاولات صامتة مجهرية (مثل Epic Games).
  Future<bool> _downloadFile(DownloadTask t, FileTask ft) async {
    final CancelToken token = CancelToken();
    _tokens[t.game.id] = token;
    ft.state = FileTaskState.downloading;
    notifyListeners();

    int silentRetries = 0;
    const int maxSilentRetries = 4;

    while (true) {
      // مطابقة العداد مع الطول الفعلي للملف على القرص (حقيقة الاستئناف)
      try {
        final File f = File(ft.localPath ?? '');
        final int len = f.existsSync() ? f.lengthSync() : 0;
        if (len != ft.downloaded) ft.downloaded = len;
      } catch (_) {}

      final int resumeFrom = ft.downloaded;
      if (ft.file.size > 0 && resumeFrom >= ft.file.size) {
        ft.state = FileTaskState.completed;
        await _persist();
        notifyListeners();
        return true;
      }

      final Map<String, dynamic> headers = <String, dynamic>{
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
        'Accept': '*/*',
        'Accept-Encoding': 'identity',
      };
      if (resumeFrom > 0) headers['Range'] = 'bytes=$resumeFrom-';

      IOSink? sink;
      try {
        final Response<ResponseBody> response = await _dio.get<ResponseBody>(
          ft.file.url,
          options: Options(
            responseType: ResponseType.stream,
            headers: headers,
            followRedirects: true,
            maxRedirects: 8,
            validateStatus: (int? s) =>
                s != null && ((s >= 200 && s < 400) || s == 416),
          ),
          cancelToken: token,
        );
        final int status = response.statusCode ?? 0;

        if (status == 416) {
          // المدى المطلوب خارج نهاية الملف — الملف مكتمل بالفعل
          final File f = File(ft.localPath ?? '');
          if (f.existsSync() && f.lengthSync() > 0) {
            ft.downloaded = f.lengthSync();
            ft.state = FileTaskState.completed;
            await _persist();
            notifyListeners();
            return true;
          }
        }

        final File f = File(ft.localPath ?? '');
        if (resumeFrom > 0 && status == 206) {
          // الخادم أكد الاستئناف — نضيف من نفس النقطة
          sink = f.openWrite(mode: FileMode.append);
        } else {
          if (resumeFrom > 0) {
            // الخادم لا يدعم الاستئناف (أعاد 200) — نبدأ من الصفر
            ft.downloaded = 0;
          }
          sink = f.openWrite(mode: FileMode.write);
        }

        _lastSpeedBytes[t.game.id] = ft.downloaded;
        _lastSpeedTick[t.game.id] = DateTime.now();

        await for (final List<int> chunk in response.data!.stream) {
          if (token.isCancelled) break;
          sink.add(chunk);
          ft.downloaded += chunk.length;
          silentRetries = 0; // تصفير عداد المحاولات عند تدفق البيانات بنجاح
          _updateSpeed(t, ft);
          await sink.flush();
        }
        await sink.flush();
        await sink.close();
        sink = null;

        if (token.isCancelled) {
          ft.state = FileTaskState.pending;
          return false;
        }
        ft.state = FileTaskState.completed;
        await _persist();
        notifyListeners();
        return true;
      } on DioException catch (e) {
        try {
          await sink?.flush();
          await sink?.close();
        } catch (_) {}
        if (e.type == DioExceptionType.cancel || token.isCancelled) {
          ft.state = FileTaskState.pending;
          return false; // إيقاف يدوي — يحتفظ بالجزء المنزّل
        }
        silentRetries++;
        if (silentRetries <= maxSilentRetries) {
          // محاولة صامتة تلقائية دون الانتقال إلى waitingNetwork فورًا (مثل Epic Games)
          await Future<void>.delayed(Duration(milliseconds: silentRetries * 1200));
          continue;
        }
        return _waitForNetwork(t); // انقطاع حقيقي مستمر بعد استنفاذ المحاولات
      } catch (_) {
        try {
          await sink?.flush();
          await sink?.close();
        } catch (_) {}
        if (token.isCancelled) {
          ft.state = FileTaskState.pending;
          return false;
        }
        silentRetries++;
        if (silentRetries <= maxSilentRetries) {
          await Future<void>.delayed(Duration(milliseconds: silentRetries * 1200));
          continue;
        }
        return _waitForNetwork(t);
      }
    }
  }

  /// انقطع الاتصال بعد استنفاذ كافة المحاولات الصامتة: جدولة عودة تلقائية بعد ثوانٍ —
  /// وعند عودة النت يكمل من نفس النقطة بالضبط (سلوك Epic Games).
  Future<bool> _waitForNetwork(DownloadTask t) async {
    final DownloadTask? task = _tasks[t.game.id];
    if (task == null) return false;
    task.state = DownloadTaskState.waitingNetwork;
    task.speed = 0;
    for (final FileTask f in task.files) {
      if (f.state == FileTaskState.downloading) f.state = FileTaskState.pending;
    }
    _persist();
    notifyListeners();
    _retryTimers[t.game.id]?.cancel();
    _retryTimers[t.game.id] = Timer(_retryDelay, () {
      final DownloadTask? cur = _tasks[t.game.id];
      if (cur != null && cur.state == DownloadTaskState.waitingNetwork) {
        resume(t.game.id); // استدعاء resume بدلاً من _run لضمان استخدام المحرك الأصلي أولًا
      }
    });
    return false;
  }

  void _updateSpeed(DownloadTask t, FileTask ft) {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastSpeedTick[t.game.id];
    if (last == null) return;
    final int dt = now.difference(last).inMilliseconds;
    if (dt >= 500) {
      final int delta = ft.downloaded - (_lastSpeedBytes[t.game.id] ?? 0);
      t.speed = (delta * 1000 / dt).round();
      _lastSpeedBytes[t.game.id] = ft.downloaded;
      _lastSpeedTick[t.game.id] = now;
      _throttledNotify(t.game.id);
    }
  }

  /// تهدئة إشعارات الواجهة (200ms) وحفظ الحالة دوريًا (كل 3 ثوانٍ) وتحديث إشعار الخلفية.
  void _throttledNotify(int gameId) {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastNotify[gameId];
    if (last == null || now.difference(last).inMilliseconds >= 200) {
      _lastNotify[gameId] = now;
      final DownloadTask? t = _tasks[gameId];
      if (t != null && t.state == DownloadTaskState.downloading) {
        _bgUpdate(t);
      }
      notifyListeners();
    }
    final DateTime? lp = _lastPersist[gameId];
    if (lp == null || now.difference(lp).inMilliseconds >= 3000) {
      _lastPersist[gameId] = now;
      _persist();
    }
  }

  void _cancelToken(int gameId) {
    _tokens[gameId]?.cancel('pause');
    _tokens.remove(gameId);
  }

  void _cancelRetry(int gameId) {
    _retryTimers[gameId]?.cancel();
    _retryTimers.remove(gameId);
  }

  // ---------- المسارات: OBB/Data في مكانها الصحيح تلقائيًا ----------

  /// حساب المسار المحلي لكل ملف:
  /// - OBB ← /storage/emulated/0/Android/obb/<الحزمة>/main.<رقم الإصدار>.<الحزمة>.obb
  /// - Data ← /storage/emulated/0/Android/data/<الحزمة>/files/<الملف>
  /// - APK ← مجلد التطبيق FluxGames/<المعرف>/
  /// باكج نيم اللعبة مفقود؟ نحفظ في مجلد التطبيق مباشرة (لا مكان خاطئ) —
  /// والنقل يصير تلقائيًا بعد ضبط الباكج نيم من اللوحة.
  Future<String> _resolvePath(Game game, DownloadFile f) async {
    final String pkg = game.packageName.isNotEmpty
        ? game.packageName
        : (game.download?.packageName.isNotEmpty ?? false
            ? game.download!.packageName
            : '');

    String fileName;
    if (f.isObb) {
      final int vc = f.versionCode > 0
          ? f.versionCode
          : (game.download?.versionCode ?? 0);
      fileName = 'main.${vc > 0 ? vc : 1}.${pkg.isNotEmpty ? pkg : 'pending'}.obb';
    } else {
      fileName = _fileNameFromUrl(f.url);
      if (fileName.isEmpty) fileName = 'file_${f.id}.bin';
    }

    final List<String> preferred = <String>[
      if (f.isObb && pkg.isNotEmpty) '/storage/emulated/0/Android/obb/$pkg',
      if (f.isData && pkg.isNotEmpty) '/storage/emulated/0/Android/data/$pkg/files',
    ];
    for (final String dir in preferred) {
      if (_canWriteSync(dir)) return '$dir/$fileName';
    }

    final String fallback = await _appGamesDir(game.id);
    return '$fallback/$fileName';
  }

  /// اختبار كتابة فعلي في المجلد (الطريقة الموثوقة لاكتشاف الصلاحية).
  bool _canWriteSync(String dirPath) {
    try {
      final Directory d = Directory(dirPath);
      if (!d.existsSync()) d.createSync(recursive: true);
      final File probe = File('$dirPath/.flux_probe');
      probe.writeAsStringSync('x', flush: true);
      probe.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _appGamesDir(int gameId) async {
    String base;
    try {
      final Directory? ext = await getExternalStorageDirectory();
      base = ext?.path ?? (await getApplicationDocumentsDirectory()).path;
      _lastExternalDir = ext; // نحفظه للبحث المتزامن في المثبّت الذاتي
    } catch (_) {
      base = (await getApplicationDocumentsDirectory()).path;
    }
    final Directory dir = Directory('$base/FluxGames/$gameId');
    try {
      if (!dir.existsSync()) dir.createSync(recursive: true);
    } catch (_) {}
    return dir.path;
  }

  /// استخراج اسم الملف من الرابط (مع محاولة معاملات الرابط مثل ?f=patch.zip).
  String _fileNameFromUrl(String url) {
    try {
      final Uri u = Uri.parse(url);
      String base = u.pathSegments
          .where((String s) => s.isNotEmpty)
          .fold('', (String _, String s) => s);
      if (base.isEmpty || !base.contains('.')) {
        for (final String key in u.queryParameters.keys) {
          final String v = u.queryParameters[key] ?? '';
          if (v.contains('.') && v.length <= 200 && v.contains('/')) {
            final String cand = v.split('/').last;
            if (cand.contains('.')) {
              base = cand;
              break;
            }
          }
        }
      }
      return Uri.decodeComponent(base);
    } catch (_) {
      return '';
    }
  }

  /// طلب صلاحيات التخزين والإشعارات قبل أول تحميل.
  Future<void> _ensurePermissions() async {
    if (!Platform.isAndroid) return;
    try {
      // أندرويد 11+: صلاحية كل الملفات (تفتح إعدادات النظام للموافقة)
      final PermissionStatus manage = await Permission.manageExternalStorage.request();
      if (!manage.isGranted) {
        // أندرويد 10 وما قبل: صلاحية التخزين العادية
        await Permission.storage.request();
      }
      // أندرويد 13+: إذن إشعارات شريط التقدم بالخلفية
      await Permission.notification.request();
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final Timer timer in _retryTimers.values) {
      timer.cancel();
    }
    _syncTimer?.cancel();
    super.dispose();
  }
}
