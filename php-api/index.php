<?php
/**
 * واجهة الـ API الرئيسية لمتجر Flux — PHP (بديل متوافق 100% مع نسخة Django).
 *
 * المسارات المدعومة (نفس عقد الـ API الذي يستخدمه التطبيق):
 *   GET /flux/api/games/                قائمة الألعاب مع الفلاتر وتقسيم الصفحات
 *   GET /flux/api/games/{id}/           تفاصيل لعبة واحدة
 *   GET /flux/api/games/featured/       الألعاب المميزة فقط (للبانر المتحرك)
 *   GET /flux/api/games/{id}/refresh/   تحديث روابط التحميل القديمة من صفحات المصدر
 *                                       (ميديافاير/درايف) قبل بدء التحميل من التطبيق
 *
 * الفلاتر المدعومة في القائمة:
 *   search، category، min_price، max_price، featured، ordering، page، page_size
 */

// مستخرج الرابط المباشر (لتحديث روابط الصفحات القديمة تلقائيًا)
require_once __DIR__ . '/resolve.php';

// ترويسات CORS حتى يستطيع التطبيق والويب الاتصال مباشرة
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/db.php';

// ---------- تحليل المسار بعد مجلد flux/api ----------
$requestUri = (string) parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$scriptDir  = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'])), '/');

if ($scriptDir !== '' && $scriptDir !== '/' && strpos($requestUri, $scriptDir) === 0) {
    $route = substr($requestUri, strlen($scriptDir));
} else {
    $route = $requestUri;
}

$route = trim($route, '/');
$parts = ($route === '') ? array() : explode('/', $route);
// تجاهل اسم الملف نفسه إن استُدعي بشكل مباشر (index.php/games/5)
$parts = array_values(array_filter($parts, function ($p) {
    return $p !== '' && $p !== 'index.php';
}));

// ---------- فتح قاعدة البيانات (مع رسالة خطأ واضحة عند مشكلة بيئة الاستضافة) ----------
try {
    $pdo = flux_db();
} catch (Throwable $e) {
    flux_json(array(
        'error' => 'تعذر فتح قاعدة البيانات SQLite — تأكد من تفعيل pdo_sqlite في PHP ومن صلاحية الكتابة على مجلد data/',
    ), 500);
}

// ---------- التوجيه ----------
if (empty($parts) || $parts[0] !== 'games') {
    flux_json(array(
        'detail'   => 'المسار غير موجود — المسارات الصحيحة: /games/ و /games/{id}/ و /games/featured/',
        'endpoints' => array('games/', 'games/{id}/', 'games/featured/'),
    ), 404);
}

if (count($parts) === 1) {
    // القائمة الكاملة مع الفلاتر وتقسيم الصفحات
    flux_json(flux_games_list($pdo));
}

if ($parts[1] === 'featured') {
    // الألعاب المميزة (للبانر السينمائي في التطبيق)
    $_GET['featured'] = 'true';
    flux_json(flux_games_list($pdo));
}

if (ctype_digit($parts[1])) {
    // تفاصيل لعبة واحدة (مع ملفات التحميل ومساراتها المحسوبة)
    $gid = (int) $parts[1];
    $stmt = $pdo->prepare('SELECT * FROM games WHERE id = :id');
    $stmt->execute(array(':id' => $gid));
    $row = $stmt->fetch();
    if (!$row) {
        flux_json(array('detail' => 'اللعبة المطلوبة غير موجودة'), 404);
    }

    // ---------- تحديث روابط التحميل القديمة (games/{id}/refresh/) ----------
    // يستدعيها التطبيق قبل بدء التحميل: إذا كان الملف مأخوذًا من صفحة
    // (ميديافاير/modsfire/درايف) وقديمًا نستخرج الرابط المباشر من جديد.
    // الروابط الموقّعة المؤقتة (مثل modsfire R2) تعيد الاستخراج في كل تحميل
    // لأن صلاحيتها دقائق فقط، والبقية كل ساعتين.
    if (isset($parts[2]) && $parts[2] === 'refresh') {
        $stmt = $pdo->prepare('SELECT * FROM game_files WHERE game_id = :gid ORDER BY id ASC');
        $stmt->execute(array(':gid' => $gid));
        $rows = $stmt->fetchAll();
        $upd = $pdo->prepare("UPDATE game_files SET url = :url, size = :size, resolved_at = datetime('now') WHERE id = :id");
        $now = time();
        foreach ($rows as $frow) {
            $src = trim((string) $frow['source_url']);
            if ($src === '' || flux_is_file_url($src)) {
                continue; // بلا صفحة مصدر أو المصدر نفسه رابط مباشر — لا تحديث
            }
            if (flux_url_is_signed((string) $frow['url'])) {
                $stale = true; // رابط موقّع بصلاحية قصيرة — حدّث دائمًا
            } else {
                $resolvedAt = strtotime((string) $frow['resolved_at']);
                $stale = ($frow['resolved_at'] === '' || $resolvedAt === false || ($now - $resolvedAt) > 2 * 3600);
            }
            if (!$stale) {
                continue; // الرابط حديث — لا حاجة لإعادة الاستخراج
            }
            $res = flux_resolve_link($src);
            if (!empty($res['ok'])) {
                $newUrl = ($res['direct_url'] !== '') ? (string) $res['direct_url'] : (string) $frow['url'];
                $newSize = ((int) $res['size'] > 0) ? (int) $res['size'] : (int) $frow['size'];
                $upd->execute(array(':url' => $newUrl, ':size' => $newSize, ':id' => (int) $frow['id']));
            }
        }
        // إعادة القراءة بعد التحديث ثم إرجاع اللعبة بنفس صيغة التفاصيل
        $stmt = $pdo->prepare('SELECT * FROM games WHERE id = :id');
        $stmt->execute(array(':id' => $gid));
        $row = $stmt->fetch();
        $stmt = $pdo->prepare('SELECT * FROM game_files WHERE game_id = :gid ORDER BY id ASC');
        $stmt->execute(array(':gid' => $gid));
        $files = $stmt->fetchAll();
        $catSlugs = flux_game_category_slugs($pdo, array($gid));
        flux_json(flux_serialize_game($row, $files, isset($catSlugs[$gid]) ? $catSlugs[$gid] : array()));
    }

    $filesMap = flux_files_for_games($pdo, array($gid));
    $catSlugs = flux_game_category_slugs($pdo, array($gid));
    flux_json(flux_serialize_game($row, isset($filesMap[$gid]) ? $filesMap[$gid] : array(), isset($catSlugs[$gid]) ? $catSlugs[$gid] : array()));
}

// أي مسار آخر تحت /games
flux_json(array('detail' => 'المسار غير موجود'), 404);
