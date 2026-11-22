import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game.dart';

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

  final DownloadFile file;
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
  });

  final Game game;
  final List<FileTask> files;
  DownloadTaskState state;
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

  /// هل انقطع الاتصال أثناء التحميل؟
  bool get waiting => state == DownloadTaskState.waitingNetwork;
}

/// مدير التحميلات داخل التطبيق (مثل Epic Games / App Store):
/// تحميل حقيقي بمقاطع، استئناف من نفس النقطة عبر Range، عودة تلقائية عند
/// عودة الشبكة بعد الانقطاع، حفظ حالة المهام وإكمالها بعد إعادة فتح التطبيق،
/// وحفظ ملفات OBB/Data في المسار الصحيح تلقائيًا عند توفر الصلاحية.
class DownloadManager extends ChangeNotifier {
  DownloadManager._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ));
  }

  static final DownloadManager instance = DownloadManager._();

  static const String _kStorage = 'flux_downloads_v1';
  static const Duration _retryDelay = Duration(seconds: 4);

  /// قناة خدمة الخلفية (Foreground Service على أندرويد) — تُبقي التحميل
  /// شغالًا حتى لو خرجت من التطبيق أو أطفأت الشاشة، مع إشعار تقدم.
  static const MethodChannel _bgChannel = MethodChannel('flux.background');

  late final Dio _dio;
  final Map<int, DownloadTask> _tasks = {};
  final Map<int, CancelToken> _tokens = {};
  final Map<int, Timer> _retryTimers = {};
  final Map<int, DateTime> _lastSpeedTick = {};
  final Map<int, int> _lastSpeedBytes = {};
  final Map<int, DateTime> _lastNotify = {};
  final Map<int, DateTime> _lastPersist = {};
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
    final DownloadInfo? dl = game.download;
    if (dl == null || !dl.available) return;
    await _ensurePermissions();

    final DownloadTask? existing = _tasks[game.id];
    if (existing != null && existing.state == DownloadTaskState.completed) {
      return; // مكتملة سابقًا
    }
    if (existing == null) {
      final List<FileTask> files = <FileTask>[];
      for (final DownloadFile f in dl.files) {
        files.add(FileTask(f, localPath: await _resolvePath(game, f)));
      }
      _tasks[game.id] =
          DownloadTask(game: game, files: files);
      await _persist();
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
    for (final FileTask f in t.files) {
      if (f.state == FileTaskState.downloading) f.state = FileTaskState.pending;
    }
    _bgStopIfNeeded();
    _persist();
    notifyListeners();
  }

  /// استكمال التحميل (من آخر بايت نزل فعليًا عبر Range).
  void resume(int gameId) => _run(gameId);

  /// إزالة المهمة مع حذف الملفات الجزئية.
  void remove(int gameId) {
    final DownloadTask? t = _tasks[gameId];
    if (t == null) return;
    _cancelToken(gameId);
    _cancelRetry(gameId);
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

  // ---------- خدمة الخلفية: إشعار تقدم + إبقاء العمل مستمرًا ----------

  void _bgStart(DownloadTask t) {
    try {
      _bgChannel.invokeMethod('start', {'title': 'تحميل ${t.game.name}'});
    } catch (_) {}
  }

  void _bgUpdate(DownloadTask t) {
    try {
      _bgChannel.invokeMethod('update', {
        'title': 'تحميل ${t.game.name}',
        'progress':
            '${(t.progress * 100).toStringAsFixed(0)}% — ${formatBytes(t.speed)}/ث',
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
            _tasks[game.id] = DownloadTask(game: game, files: files, state: st);
          } catch (_) {}
        }
      }
    } catch (_) {}
    notifyListeners();
    // مثل Epic: ما كان في انتظار الشبكة يُستكمل تلقائيًا عند فتح التطبيق
    for (final DownloadTask t in tasks) {
      if (t.waiting) resume(t.game.id);
    }
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> list = _tasks.values
          .map((DownloadTask t) => <String, dynamic>{
                'game': t.game.toJson(),
                'state': t.state.name,
                'files': t.files.map((FileTask f) => f.toJson()).toList(),
              })
          .toList();
      await prefs.setString(_kStorage, jsonEncode(list));
    } catch (_) {}
  }

  // ---------- المحرك: تنزيل فعلي بمقاطع مع استئناف ----------

  Future<void> _run(int gameId) async {
    final DownloadTask? t = _tasks[gameId];
    if (t == null) return;
    if (t.state == DownloadTaskState.downloading) return;
    t.state = DownloadTaskState.downloading;
    // تشغيل خدمة الخلفية: التحميل يكمل حتى بعد الخروج من التطبيق أو إطفاء الشاشة
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
  }

  /// تنزيل ملف واحد كاملًا مع دعم الاستئناف (Range) وإعادة المحاولة التلقائية.
  Future<bool> _downloadFile(DownloadTask t, FileTask ft) async {
    final CancelToken token = CancelToken();
    _tokens[t.game.id] = token;
    ft.state = FileTaskState.downloading;
    notifyListeners();

    while (true) {
      // مطابقة العداد مع الطول الفعلي للملف على القرص (حقيقة الاستئناف)
      try {
        final File f = File(ft.localPath ?? '');
        final int len = f.existsSync() ? f.lengthSync() : 0;
        if (len != ft.downloaded) ft.downloaded = len;
      } catch (_) {}

      final int resumeFrom = ft.downloaded;
      final Map<String, dynamic> headers = <String, dynamic>{};
      if (resumeFrom > 0) headers['Range'] = 'bytes=$resumeFrom-';

      IOSink? sink;
      try {
        final Response<ResponseBody> response = await _dio.get<ResponseBody>(
          ft.file.url,
          options: Options(
            responseType: ResponseType.stream,
            headers: headers,
            followRedirects: true,
            validateStatus: (int? s) => s != null && s >= 200 && s < 400,
          ),
          cancelToken: token,
        );
        final int status = response.statusCode ?? 0;

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
        if (e.type == DioExceptionType.cancel) {
          ft.state = FileTaskState.pending;
          return false; // إيقاف يدوي — يحتفظ بالجزء المنزّل
        }
        return _waitForNetwork(t); // انقطاع/مهلة — عودة تلقائية
      } catch (_) {
        try {
          await sink?.flush();
          await sink?.close();
        } catch (_) {}
        return _waitForNetwork(t);
      }
    }
  }

  /// انقطع الاتصال: جدولة عودة تلقائية بعد ثوانٍ — وعند عودة النت يكمل من
  /// نفس النقطة بالضبط (سلوك Epic Games).
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
        _run(t.game.id);
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
  /// - OBB ← /storage/emulated/0/Android/obb/<الحزمة>/main.<إصدار>.<الحزمة>.obb
  /// - Data ← /storage/emulated/0/Android/data/<الحزمة>/files/<الملف>
  /// - APK ← مجلد التطبيق FluxGames/<المعرف>/
  /// إن رفض أندرويد الكتابة المباشرة (أندرويد 11+) نستخدم مجلد التطبيق البديل.
  Future<String> _resolvePath(Game game, DownloadFile f) async {
    final String pkg = game.packageName.isNotEmpty
        ? game.packageName
        : (game.download?.packageName.isNotEmpty ?? false
            ? game.download!.packageName
            : 'com.fluxstore.games');

    String fileName;
    if (f.isObb) {
      final int vc = f.versionCode > 0
          ? f.versionCode
          : (game.download?.versionCode ?? 0);
      fileName = 'main.${vc > 0 ? vc : 1}.$pkg.obb';
    } else {
      fileName = _fileNameFromUrl(f.url);
      if (fileName.isEmpty) fileName = 'file_${f.id}.bin';
    }

    final List<String> preferred = <String>[
      if (f.isObb) '/storage/emulated/0/Android/obb/$pkg',
      if (f.isData) '/storage/emulated/0/Android/data/$pkg/files',
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
    super.dispose();
  }
}
