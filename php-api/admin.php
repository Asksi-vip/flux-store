<?php
/**
 * لوحة إدارة المتجر — إضافة/تعديل/حذف الألعاب من المتصفح.
 * الرابط: http://camillecyrm.serv00.net/flux/api/admin.php
 * كلمة المرور الافتراضية في config.php — غيّرها فورًا بعد الرفع.
 */

session_start();
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/db.php';
// مستخرج الرابط المباشر (ميديافاير / جوجل درايف / صفحات التحميل)
require_once __DIR__ . '/resolve.php';

header('Content-Type: text/html; charset=utf-8');

$msg     = '';
$error   = '';
$logged  = !empty($_SESSION['flux_admin_ok']);

// خروج
if (isset($_GET['logout'])) {
    $_SESSION['flux_admin_ok'] = false;
    session_destroy();
    header('Location: admin.php');
    exit;
}

// تسجيل الدخول
if (!$logged && $_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['password'])) {
    if ((string) $_POST['password'] === FLUX_ADMIN_PASSWORD) {
        $_SESSION['flux_admin_ok'] = true;
        $logged = true;
        header('Location: admin.php');
        exit;
    }
    $error = 'كلمة المرور غير صحيحة';
}

$pdo = null;
if ($logged) {
    try {
        $pdo = flux_db();
    } catch (Throwable $e) {
        $error = 'تعذر فتح قاعدة البيانات: تحقق من تفعيل pdo_sqlite وصلاحية الكتابة على مجلد data/';
    }
}

// ---------- العمليات: حفظ / حذف ----------
if ($logged && $pdo !== null && $_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    $action = (string) $_POST['action'];

    if ($action === 'save') {
        $fields = flux_collect_game_input($_POST);
        $id     = (int) (isset($_POST['id']) ? $_POST['id'] : 0);
        if ($fields === null) {
            $error = 'اسم اللعبة مطلوب';
        } else {
            $gid = 0;
            $msg = '';
            if ($id > 0) {
                $stmt = $pdo->prepare(
                    'UPDATE games SET name = :name, description = :description, price = :price,
                     discount_price = :discount_price, category = :category, rating = :rating,
                     image_url = :image_url, banner_url = :banner_url,
                     release_date = :release_date, is_featured = :is_featured,
                     package_name = :package_name, download_version = :download_version,
                     download_version_code = :download_version_code WHERE id = :id'
                );
                $params = flux_prefix_params($fields);
                $params[':id'] = $id;
                $stmt->execute($params);
                $gid = $id;
                $msg = 'تم تحديث اللعبة بنجاح';
            } else {
                try {
                    $stmt = $pdo->prepare(
                        'INSERT INTO games (name, description, price, discount_price, category, rating,
                         image_url, banner_url, release_date, is_featured,
                         package_name, download_version, download_version_code)
                         VALUES (:name, :description, :price, :discount_price, :category, :rating,
                         :image_url, :banner_url, :release_date, :is_featured,
                         :package_name, :download_version, :download_version_code)'
                    );
                    $stmt->execute(flux_prefix_params($fields));
                    $gid = (int) $pdo->lastInsertId();
                    $msg = 'تمت إضافة اللعبة بنجاح';
                } catch (Throwable $e) {
                    $error = 'تعذرت الإضافة — تأكد أن اسم اللعبة غير مكرر';
                }
            }

            // ملفات التحميل من النموذج (APK + OBB + صفوف Data) — الحزمة تشتق تلقائيًا من الروابط
            if ($gid > 0) {
                $files = flux_collect_files_input($_POST);
                $urlsForPkg = array();
                foreach ($files as $f) {
                    $urlsForPkg[] = $f['url'];
                }
                $pkg = flux_package_from_url($urlsForPkg);
                if ($pkg === '') {
                    // توافق مع النماذج القديمة أو الرابط الواضح داخل صفحة الملفات
                    $pkg = trim((string) (isset($_POST['package_name']) ? $_POST['package_name'] : ''));
                }
                if ($pkg !== '') {
                    $pdo->prepare('UPDATE games SET package_name = :p WHERE id = :id')
                        ->execute(array(':p' => $pkg, ':id' => $gid));
                }
                if (!empty($files)) {
                    // النموذج هو مصدر الحقيقة: يعيد بناء قائمة الملفات كاملة
                    // لكن نحافظ على رابط الصفحة المصدر للملفات التي لم يتغير رابطها المباشر
                    $oldSrc = array();
                    $stmt = $pdo->prepare('SELECT url, source_url, resolved_at FROM game_files WHERE game_id = :id');
                    $stmt->execute(array(':id' => $gid));
                    foreach ($stmt->fetchAll() as $of) {
                        $oldSrc[$of['url']] = $of;
                    }
                    $pdo->prepare('DELETE FROM game_files WHERE game_id = :id')
                        ->execute(array(':id' => $gid));
                    $ins = $pdo->prepare(
                        'INSERT INTO game_files (game_id, name, url, type, size, version_code, source_url, resolved_at)
                         VALUES (:gid, :name, :url, :type, :size, :vc, :src, :rs)'
                    );
                    foreach ($files as $f) {
                        $src = isset($oldSrc[$f['url']]) ? $oldSrc[$f['url']]['source_url'] : '';
                        $rs  = isset($oldSrc[$f['url']]) ? $oldSrc[$f['url']]['resolved_at'] : '';
                        $ins->execute(array(
                            ':gid'  => $gid,
                            ':name' => $f['name'],
                            ':url'  => $f['url'],
                            ':type' => $f['type'],
                            ':size' => $f['size'],
                            ':vc'   => $f['version_code'],
                            ':src'  => $src,
                            ':rs'   => $rs,
                        ));
                    }
                    $msg .= ' — وتم حفظ ' . count($files) . ' ملف تحميل';
                }
            }
            header('Location: admin.php?msg=' . urlencode($msg));
            exit;
        }
    }

    if ($action === 'delete') {
        $id = (int) (isset($_POST['id']) ? $_POST['id'] : 0);
        if ($id > 0) {
            $stmt = $pdo->prepare('DELETE FROM games WHERE id = :id');
            $stmt->execute(array(':id' => $id));
            $stmt = $pdo->prepare('DELETE FROM game_files WHERE game_id = :id');
            $stmt->execute(array(':id' => $id));
        }
        header('Location: admin.php?msg=' . urlencode('تم حذف اللعبة'));
        exit;
    }

    // ---------- عمليات ملفات التحميل (APK / OBB / Data) ----------
    if ($action === 'save_file') {
        $gid   = (int) (isset($_POST['game_id']) ? $_POST['game_id'] : 0);
        $fid   = (int) (isset($_POST['file_id']) ? $_POST['file_id'] : 0);
        $type  = (string) (isset($_POST['type']) ? $_POST['type'] : 'apk');
        if (!in_array($type, array('apk', 'obb', 'data'), true)) {
            $type = 'apk';
        }
        $fName = trim((string) (isset($_POST['file_name']) ? $_POST['file_name'] : ''));
        $fUrl  = trim((string) (isset($_POST['file_url']) ? $_POST['file_url'] : ''));
        $fSize = (int) round(((float) (isset($_POST['size_mb']) && $_POST['size_mb'] !== '' ? $_POST['size_mb'] : 0)) * 1024 * 1024);
        $fVc   = (int) (isset($_POST['version_code']) && $_POST['version_code'] !== '' ? $_POST['version_code'] : 0);

        if ($gid <= 0 || $fUrl === '') {
            $error = 'رابط الملف مطلوب';
        } else {
            if ($fName === '') {
                $fName = $type === 'apk' ? 'ملف تثبيت اللعبة APK' : ($type === 'obb' ? 'ملف البيانات OBB' : 'ملفات إضافية Data');
            }
            // رابط صفحة المصدر (يأتي من أداة الاستخراج عند استخدامها) + وقت الاستخراج
            $fSource = trim((string) (isset($_POST['source_url']) ? $_POST['source_url'] : ''));
            $fResolved = $fSource !== '' ? date('Y-m-d H:i:s') : '';

            if ($fid > 0) {
                $stmt = $pdo->prepare('UPDATE game_files SET name = :name, url = :url, type = :type, size = :size, version_code = :vc, source_url = :src, resolved_at = :rs WHERE id = :id');
                $stmt->execute(array(':name' => $fName, ':url' => $fUrl, ':type' => $type, ':size' => $fSize, ':vc' => $fVc, ':src' => $fSource, ':rs' => $fResolved, ':id' => $fid));
                $msg = 'تم تحديث الملف';
            } else {
                $stmt = $pdo->prepare('INSERT INTO game_files (game_id, name, url, type, size, version_code, source_url, resolved_at) VALUES (:gid, :name, :url, :type, :size, :vc, :src, :rs)');
                $stmt->execute(array(':gid' => $gid, ':name' => $fName, ':url' => $fUrl, ':type' => $type, ':size' => $fSize, ':vc' => $fVc, ':src' => $fSource, ':rs' => $fResolved));
                $msg = 'تمت إضافة الملف';
            }
            header('Location: admin.php?files=' . $gid . '&msg=' . urlencode($msg));
            exit;
        }
    }

    if ($action === 'delete_file') {
        $fid = (int) (isset($_POST['file_id']) ? $_POST['file_id'] : 0);
        $gid = (int) (isset($_POST['game_id']) ? $_POST['game_id'] : 0);
        if ($fid > 0) {
            $stmt = $pdo->prepare('DELETE FROM game_files WHERE id = :id');
            $stmt->execute(array(':id' => $fid));
        }
        header('Location: admin.php?files=' . $gid . '&msg=' . urlencode('تم حذف الملف'));
        exit;
    }

    // ---------- إعادة استخراج الرابط المباشر من صفحة المصدر المحفوظة ----------
    if ($action === 'refresh_file') {
        $fid = (int) (isset($_POST['file_id']) ? $_POST['file_id'] : 0);
        $gid = (int) (isset($_POST['game_id']) ? $_POST['game_id'] : 0);
        if ($fid > 0) {
            $stmt = $pdo->prepare('SELECT * FROM game_files WHERE id = :id');
            $stmt->execute(array(':id' => $fid));
            $row = $stmt->fetch();
            if ($row && trim((string) $row['source_url']) !== '') {
                $res = flux_resolve_link((string) $row['source_url']);
                if (!empty($res['ok'])) {
                    $newSize = (int) $res['size'] > 0 ? (int) $res['size'] : (int) $row['size'];
                    $stmt = $pdo->prepare(
                        "UPDATE game_files SET url = :url, size = :size,
                         resolved_at = datetime('now') WHERE id = :id"
                    );
                    $stmt->execute(array(':url' => $res['direct_url'], ':size' => $newSize, ':id' => $fid));
                    $note = 'تم تحديث الرابط المباشر';
                    if ((int) $res['size'] > 0) {
                        $note .= ' — الحجم ' . ($res['size_text'] !== '' ? $res['size_text'] : (string) $res['size'] . ' بايت');
                    }
                    header('Location: admin.php?files=' . $gid . '&msg=' . urlencode($note));
                    exit;
                }
                header('Location: admin.php?files=' . $gid . '&err=' . urlencode('فشل إعادة الاستخراج: ' . (isset($res['note']) ? $res['note'] : 'خطأ غير معروف')));
                exit;
            }
        }
        header('Location: admin.php?files=' . $gid . '&err=' . urlencode('الملف لا يملك رابط صفحة مصدر محفوظ'));
        exit;
    }
}

// رسالة نجاح بعد إعادة التوجيه
if (isset($_GET['msg'])) {
    $msg = (string) $_GET['msg'];
}
// رسالة خطأ بعد إعادة التوجيه (مثل فشل إعادة استخراج الرابط)
if (isset($_GET['err'])) {
    $error = (string) $_GET['err'];
}

// لعبة قيد التعديل
$editGame = null;
$editId   = 0;
if ($logged && $pdo !== null && isset($_GET['edit'])) {
    $editId = (int) $_GET['edit'];
    if ($editId > 0) {
        $stmt = $pdo->prepare('SELECT * FROM games WHERE id = :id');
        $stmt->execute(array(':id' => $editId));
        $editGame = $stmt->fetch() ?: null;
    }
}

// تعبئة حقول روابط التحميل في النموذج من ملفات اللعبة المحفوظة (APK/OBB/Data)
$apkPre  = array('url' => '', 'size' => '');
$obbPre  = array('url' => '', 'size' => '', 'vc' => '0');
$dataPre = array();
if ($logged && $pdo !== null && $editGame) {
    $stmt = $pdo->prepare('SELECT * FROM game_files WHERE game_id = :gid ORDER BY id ASC');
    $stmt->execute(array(':gid' => (int) $editGame['id']));
    foreach ($stmt->fetchAll() as $pf) {
        if ($pf['type'] === 'apk' && $apkPre['url'] === '') {
            $apkPre['url']  = $pf['url'];
            $apkPre['size'] = (int) $pf['size'] > 0 ? number_format($pf['size'] / 1048576, 2, '.', '') : '';
        } elseif ($pf['type'] === 'obb' && $obbPre['url'] === '') {
            $obbPre['url']  = $pf['url'];
            $obbPre['size'] = (int) $pf['size'] > 0 ? number_format($pf['size'] / 1048576, 2, '.', '') : '';
            $obbPre['vc']   = (string) (int) $pf['version_code'];
        } elseif ($pf['type'] === 'data') {
            $dataPre[] = array(
                'url'  => $pf['url'],
                'size' => (int) $pf['size'] > 0 ? number_format($pf['size'] / 1048576, 2, '.', '') : '',
            );
        }
    }
}

$games = array();
$filesCountMap = array();
if ($logged && $pdo !== null) {
    $games = $pdo->query('SELECT * FROM games ORDER BY id DESC')->fetchAll();
    // عدد ملفات التحميل لكل لعبة (لعرضه في الجدول)
    foreach ($pdo->query('SELECT game_id, COUNT(*) AS c FROM game_files GROUP BY game_id')->fetchAll() as $r) {
        $filesCountMap[(int) $r['game_id']] = (int) $r['c'];
    }
}
$categories = flux_categories();

// ---------- صفحة إدارة ملفات لعبة معينة (?files=<id>) ----------
$filesGame = null;
$gameFiles = array();
$editFile  = null;
if ($logged && $pdo !== null && isset($_GET['files'])) {
    $fgid = (int) $_GET['files'];
    if ($fgid > 0) {
        $stmt = $pdo->prepare('SELECT * FROM games WHERE id = :id');
        $stmt->execute(array(':id' => $fgid));
        $filesGame = $stmt->fetch() ?: null;
        if ($filesGame) {
            $stmt = $pdo->prepare('SELECT * FROM game_files WHERE game_id = :gid ORDER BY id ASC');
            $stmt->execute(array(':gid' => $fgid));
            $gameFiles = $stmt->fetchAll();
        }
    }
    if (isset($_GET['edit_file'])) {
        $efid = (int) $_GET['edit_file'];
        foreach ($gameFiles as $gf) {
            if ((int) $gf['id'] === $efid) {
                $editFile = $gf;
                break;
            }
        }
    }
}

/** هروب آمن لأي قيمة تُطبع في HTML. */
function e($v)
{
    return htmlspecialchars((string) $v, ENT_QUOTES, 'UTF-8');
}
?>
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>لوحة إدارة متجر FLUX</title>
<style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: #101014; color: #fff; font-family: "Segoe UI", Tahoma, sans-serif; padding: 24px 16px; }
    .wrap { max-width: 980px; margin: 0 auto; }
    h1 { font-size: 22px; margin-bottom: 4px; }
    .sub { color: #b8b8c1; font-size: 13px; margin-bottom: 20px; }
    .brand { display: inline-block; background: #202024; border: 1px solid #2a2a2a; padding: 6px 14px; border-radius: 4px; font-weight: 900; letter-spacing: 3px; margin-bottom: 14px; }
    .card { background: #18181c; border: 1px solid #2a2a2a; border-radius: 6px; padding: 20px; margin-bottom: 20px; }
    .alert-ok { background: rgba(47,191,113,.12); border: 1px solid #2fbf71; color: #2fbf71; padding: 10px 14px; border-radius: 4px; margin-bottom: 14px; font-size: 14px; }
    .alert-err { background: rgba(224,69,90,.12); border: 1px solid #e0455a; color: #ff8a99; padding: 10px 14px; border-radius: 4px; margin-bottom: 14px; font-size: 14px; }
    label { display: block; font-size: 12px; color: #b8b8c1; margin: 12px 0 6px; }
    input[type=text], input[type=password], input[type=number], input[type=date], input[type=url], select, textarea {
        width: 100%; background: #202024; border: 1px solid #2a2a2a; color: #fff;
        padding: 10px 12px; border-radius: 4px; font-size: 14px; font-family: inherit;
    }
    input:focus, select:focus, textarea:focus { outline: none; border-color: #0074e4; }
    textarea { min-height: 90px; resize: vertical; }
    .row { display: flex; gap: 12px; flex-wrap: wrap; }
    .row > div { flex: 1 1 150px; }
    .btn { display: inline-block; background: #0074e4; color: #fff; border: none; padding: 11px 26px;
           border-radius: 4px; font-size: 14px; font-weight: 700; cursor: pointer; margin-top: 16px; font-family: inherit; }
    .btn:hover { background: #1a85ee; }
    .btn-ghost { background: transparent; border: 1px solid #2a2a2a; color: #fff; }
    .btn-danger { background: transparent; border: 1px solid #e0455a; color: #ff8a99; padding: 6px 12px; margin: 0; font-size: 12px; }
    .btn-edit { background: transparent; border: 1px solid #2a2a2a; color: #26bbff; padding: 6px 12px; margin: 0; font-size: 12px; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th { text-align: right; color: #b8b8c1; font-weight: 600; padding: 8px; border-bottom: 1px solid #2a2a2a; }
    td { padding: 8px; border-bottom: 1px solid #1f1f24; vertical-align: middle; }
    td img { width: 44px; height: 60px; object-fit: cover; border-radius: 3px; display: block; }
    .tag { background: #0074e4; padding: 2px 8px; border-radius: 3px; font-size: 11px; font-weight: 700; }
    .tag-free { background: rgba(38,187,255,.15); border: 1px solid #26bbff; color: #26bbff; }
    .actions { display: flex; gap: 6px; }
    .check { display: flex; align-items: center; gap: 8px; margin-top: 14px; font-size: 14px; color: #fff; }
    .check input { width: auto; }
    @media (max-width: 640px) { td:nth-child(3), th:nth-child(3) { display: none; } }
</style>
</head>
<body>
<div class="wrap">
    <div class="brand">FLUX</div>
    <h1>لوحة إدارة المتجر</h1>
    <p class="sub">إضافة وتعديل وحذف ألعاب الـ API — التغييرات تظهر في التطبيق فورًا</p>

    <?php if ($msg !== '') { ?><div class="alert-ok"><?php echo e($msg); ?></div><?php } ?>
    <?php if ($error !== '') { ?><div class="alert-err"><?php echo e($error); ?></div><?php } ?>

    <?php if (!$logged) { ?>
        <!-- شاشة تسجيل الدخول -->
        <div class="card" style="max-width:420px;">
            <form method="post" action="admin.php">
                <label>كلمة مرور الإدارة</label>
                <input type="password" name="password" required autofocus>
                <button class="btn" type="submit">دخول</button>
            </form>
        </div>
    <?php } else { ?>

        <?php if ($pdo === null) { ?>
            <div class="card">لا يمكن الاتصال بقاعدة البيانات.</div>
        <?php } else { ?>

            <?php if ($filesGame === null) { ?>
            <!-- نموذج الإضافة/التعديل -->
            <div class="card">
                <h2 style="font-size:16px; margin-bottom:4px;">
                    <?php echo $editGame ? 'تعديل: ' . e($editGame['name']) : 'إضافة لعبة جديدة'; ?>
                </h2>
                <form method="post" action="admin.php">
                    <input type="hidden" name="action" value="save">
                    <input type="hidden" name="id" value="<?php echo $editGame ? (int) $editGame['id'] : 0; ?>">

                    <label>اسم اللعبة *</label>
                    <input type="text" name="name" required value="<?php echo $editGame ? e($editGame['name']) : ''; ?>">

                    <label>الوصف</label>
                    <textarea name="description"><?php echo $editGame ? e($editGame['description']) : ''; ?></textarea>

                    <div class="row">
                        <div>
                            <label>السعر ($)</label>
                            <input type="number" step="0.01" min="0" name="price" value="<?php echo $editGame ? e($editGame['price']) : '19.99'; ?>">
                        </div>
                        <div>
                            <label>سعر الخصم ($ — فارغ = بلا خصم)</label>
                            <input type="number" step="0.01" min="0" name="discount_price" value="<?php echo ($editGame && $editGame['discount_price'] !== null) ? e($editGame['discount_price']) : ''; ?>">
                        </div>
                        <div>
                            <label>التقييم (0 - 5)</label>
                            <input type="number" step="0.1" min="0" max="5" name="rating" value="<?php echo $editGame ? e($editGame['rating']) : '4.5'; ?>">
                        </div>
                        <div>
                            <label>التصنيف</label>
                            <select name="category">
                                <?php foreach ($categories as $value => $label) { ?>
                                    <option value="<?php echo e($value); ?>" <?php echo ($editGame && $editGame['category'] === $value) ? 'selected' : ''; ?>><?php echo e($label); ?></option>
                                <?php } ?>
                            </select>
                        </div>
                        <div>
                            <label>تاريخ الإصدار</label>
                            <input type="date" name="release_date" value="<?php echo $editGame ? e($editGame['release_date']) : '2024-01-01'; ?>">
                        </div>
                    </div>

                    <label>رابط صورة الغلاف (عمودية 600x900)</label>
                    <input type="url" name="image_url" value="<?php echo $editGame ? e($editGame['image_url']) : ''; ?>">

                    <label>رابط صورة البانر (عريضة library_hero)</label>
                    <input type="url" name="banner_url" value="<?php echo $editGame ? e($editGame['banner_url']) : ''; ?>">

                    <div class="row">
                        <div>
                            <label>إصدار التحميل (نص مثل 2.4.1)</label>
                            <input type="text" name="download_version" value="<?php echo $editGame ? e($editGame['download_version']) : ''; ?>">
                        </div>
                        <div>
                            <label>رقم الإصدار (لتسمية OBB تلقائيًا)</label>
                            <input type="number" min="0" name="download_version_code" value="<?php echo $editGame ? e($editGame['download_version_code']) : '0'; ?>">
                        </div>
                    </div>

                    <!-- روابط التحميل: APK + OBB + صفوف Data قابلة للتكرار — الحزمة تشتق تلقائيًا -->
                    <h3 style="font-size:13px; margin:18px 0 8px; color:#26bbff;">⬇ روابط التحميل (للألعاب المجانية)</h3>
                    <p class="sub" style="margin:0 0 10px;">حزمة أندرويد (لمسارات OBB/Data) تشتق تلقائيًا من الرابط — لا تحتاج إدخالها. حفظ النموذج مع أي رابط يعيد بناء قائمة الملفات كاملة.</p>
                    <div class="row">
                        <div>
                            <label>رابط ملف APK الأساسي <span style="color:#2fbf71;">— أو رابط صفحة التحميل ثم اضغط الاستخراج</span></label>
                            <input type="url" name="apk_url" value="<?php echo $apkPre['url']; ?>" placeholder="https://www.mediafire.com/file/xxxx/game.apk/file">
                            <button class="btn btn-ghost" type="button" onclick="fluxResolveRow(this)" style="margin:6px 0 0; font-size:11px; padding:4px 12px;">🔍 استخراج من صفحة</button>
                        </div>
                        <div style="flex:0 0 150px;">
                            <label>حجمه (ميغابايت)</label>
                            <input type="number" step="0.01" min="0" name="apk_size_mb" value="<?php echo $apkPre['size']; ?>">
                        </div>
                    </div>
                    <div class="row">
                        <div>
                            <label>رابط ملف OBB (إن وجد) — يقبل رابط صفحة مع الاستخراج</label>
                            <input type="url" name="obb_url" value="<?php echo $obbPre['url']; ?>" placeholder="https://site.com/main.120.com.example.game.obb">
                            <button class="btn btn-ghost" type="button" onclick="fluxResolveRow(this)" style="margin:6px 0 0; font-size:11px; padding:4px 12px;">🔍 استخراج من صفحة</button>
                        </div>
                        <div style="flex:0 0 150px;">
                            <label>حجمه (ميغابايت)</label>
                            <input type="number" step="0.01" min="0" name="obb_size_mb" value="<?php echo $obbPre['size']; ?>">
                        </div>
                        <div style="flex:0 0 150px;">
                            <label>رقم إصدار OBB</label>
                            <input type="number" min="0" name="obb_version_code" value="<?php echo $obbPre['vc']; ?>">
                        </div>
                    </div>
                    <div id="data-rows"></div>
                    <button class="btn btn-ghost" type="button" onclick="addDataRow('', '')" style="text-decoration:none; margin-top:10px;">+ إضافة ملف Data (يمكن تكرارها للعدة)</button>

                    <div class="check">
                        <input type="checkbox" name="is_featured" value="1" id="feat" <?php echo ($editGame && (int) $editGame['is_featured'] === 1) ? 'checked' : ''; ?>>
                        <label for="feat" style="margin:0;">لعبة مميزة (تظهر في البانر السينمائي)</label>
                    </div>

                    <button class="btn" type="submit"><?php echo $editGame ? 'حفظ التعديلات' : 'إضافة اللعبة'; ?></button>
                    <?php if ($editGame) { ?><a class="btn btn-ghost" href="admin.php" style="text-decoration:none;">إلغاء التعديل</a><?php } ?>
                </form>

                <script>
                // صفوف Data المتكررة: رابط + حجم لكل صف، مع زر حذف وزر استخراج
                function addDataRow(url, size) {
                    var wrap = document.getElementById('data-rows');
                    if (!wrap) return;
                    var div = document.createElement('div');
                    div.className = 'row';
                    div.style.marginTop = '8px';
                    div.innerHTML =
                        '<div><label>رابط ملف Data إضافي — أو رابط صفحة مع الاستخراج</label><input type="url" name="data_url[]" value="' + url + '" placeholder="https://www.mediafire.com/file/xxxx/patch.zip/file">' +
                        '<button type="button" class="btn btn-ghost" onclick="fluxResolveRow(this)" style="margin:6px 0 0; font-size:11px; padding:4px 12px;">🔍 استخراج من صفحة</button></div>' +
                        '<div style="flex:0 0 150px;"><label>حجمه (ميغابايت)</label><input type="number" step="0.01" min="0" name="data_size_mb[]" value="' + size + '"></div>' +
                        '<div style="flex:0 0 52px; align-self:flex-end; padding-bottom:6px;"><button type="button" class="btn-danger" onclick="this.closest(\'.row\').remove()">حذف</button></div>';
                    wrap.appendChild(div);
                }
                <?php foreach ($dataPre as $dp) { ?>
                addDataRow(<?php echo json_encode($dp['url']); ?>, <?php echo json_encode($dp['size']); ?>);
                <?php } ?>
                </script>
            </div>
            <?php } ?>

            <?php if ($filesGame !== null) { ?>
            <!-- ============ صفحة إدارة ملفات التحميل (APK / OBB / Data) ============ -->
            <div class="card">
                <h2 style="font-size:16px; margin-bottom:4px;">ملفات التحميل: <?php echo e($filesGame['name']); ?></h2>
                <p class="sub" style="margin-bottom:12px;">أول ملف APK = ملف اللعبة الرئيسي، وملفات OBB/Data تُحسب مسارات تثبيتها تلقائيًا حسب حزمة اللعبة.</p>
                <a class="btn btn-ghost" href="admin.php" style="text-decoration:none; margin:0;">← رجوع لقائمة الألعاب</a>

                <!-- ============ أداة استخراج الرابط المباشر (مثل سحب رابط التحميل من الصفحة) ============ -->
                <div style="background:#101014; border:1px solid #2a2a2a; border-radius:6px; padding:16px; margin-top:16px;">
                    <h3 style="font-size:14px; margin-bottom:4px; color:#2fbf71;">🔗 استخراج رابط التحميل المباشر</h3>
                    <p class="sub" style="margin:0 0 10px;">الصق رابط صفحة التحميل (ميديافاير، جوجل درايف، أو أي صفحة فيها زر تحميل) — يطلّع لك الرابط المباشر مع الاسم والحجم، وبضغطة تحطه بنموذج الملف تحت مباشرة.</p>
                    <div class="row">
                        <div>
                            <input type="url" id="resolve-url" placeholder="https://www.mediafire.com/file/xxxx/game.apk/file">
                        </div>
                        <div style="flex:0 0 190px;">
                            <button class="btn" type="button" id="resolve-btn" onclick="fluxResolvePage()" style="margin-top:0; width:100%;">استخراج الرابط المباشر</button>
                        </div>
                    </div>
                    <div id="resolve-status" style="font-size:12.5px; margin-top:10px; color:#b8b8c1;"></div>
                    <div id="resolve-result" style="display:none; margin-top:12px;">
                        <label style="margin-top:0;">الرابط المباشر المستخرج</label>
                        <input type="text" id="resolve-direct" readonly style="direction:ltr; text-align:left; color:#26bbff;">
                        <div class="row" style="margin-top:10px;">
                            <div style="flex:1 1 200px;">
                                <span style="font-size:12px; color:#b8b8c1;">الاسم: </span><span id="resolve-name" style="font-size:12.5px; direction:ltr; unicode-bidi:embed;"></span>
                            </div>
                            <div style="flex:0 0 120px;">
                                <span style="font-size:12px; color:#b8b8c1;">الحجم: </span><span id="resolve-size" style="font-size:12.5px;"></span>
                            </div>
                            <div style="flex:0 0 140px;">
                                <span style="font-size:12px; color:#b8b8c1;">المصدر: </span><span id="resolve-source" style="font-size:12.5px;"></span>
                            </div>
                        </div>
                        <button class="btn" type="button" onclick="fluxUseResult()" style="margin-top:14px;">استخدمه في نموذج الملف تحت ⬇</button>
                    </div>
                </div>

                <h3 style="font-size:14px; margin:18px 0 8px;"><?php echo $editFile ? 'تعديل الملف' : 'إضافة ملف تحميل'; ?></h3>
                <form method="post" action="admin.php" id="file-form">
                    <input type="hidden" name="action" value="save_file">
                    <input type="hidden" name="game_id" value="<?php echo (int) $filesGame['id']; ?>">
                    <input type="hidden" name="file_id" value="<?php echo $editFile ? (int) $editFile['id'] : 0; ?>">
                    <input type="hidden" name="source_url" id="source-url" value="">
                    <div class="row">
                        <div style="flex:0 0 110px;">
                            <label>النوع *</label>
                            <select name="type">
                                <option value="apk" <?php echo (!$editFile || $editFile['type'] === 'apk') ? 'selected' : ''; ?>>APK</option>
                                <option value="obb" <?php echo ($editFile && $editFile['type'] === 'obb') ? 'selected' : ''; ?>>OBB</option>
                                <option value="data" <?php echo ($editFile && $editFile['type'] === 'data') ? 'selected' : ''; ?>>Data</option>
                            </select>
                        </div>
                        <div>
                            <label>اسم الملف (للعرض)</label>
                            <input type="text" name="file_name" value="<?php echo $editFile ? e($editFile['name']) : ''; ?>">
                        </div>
                        <div>
                            <label>رابط التحميل المباشر * <span style="color:#2fbf71;">— أو رابط صفحة ثم استخرج</span></label>
                            <input type="url" name="file_url" required value="<?php echo $editFile ? e($editFile['url']) : ''; ?>">
                            <button class="btn btn-ghost" type="button" onclick="fluxResolveRow(this)" style="margin:6px 0 0; font-size:11px; padding:4px 12px;">🔍 استخراج من صفحة</button>
                        </div>
                        <div style="flex:0 0 140px;">
                            <label>الحجم (ميغابايت)</label>
                            <input type="number" step="0.01" min="0" name="size_mb" value="<?php echo $editFile ? e(number_format($editFile['size'] / 1048576, 2, '.', '')) : ''; ?>">
                        </div>
                        <div style="flex:0 0 150px;">
                            <label>رقم إصدار OBB (لتسمية الملف)</label>
                            <input type="number" min="0" name="version_code" value="<?php echo $editFile ? e($editFile['version_code']) : '0'; ?>">
                        </div>
                    </div>
                    <button class="btn" type="submit"><?php echo $editFile ? 'حفظ الملف' : 'إضافة الملف'; ?></button>
                    <?php if ($editFile) { ?><a class="btn btn-ghost" href="admin.php?files=<?php echo (int) $filesGame['id']; ?>" style="text-decoration:none;">إلغاء</a><?php } ?>
                </form>
            </div>

            <div class="card">
                <h2 style="font-size:16px; margin-bottom:12px;">ملفات اللعبة (<?php echo count($gameFiles); ?>)</h2>
                <div style="overflow-x:auto;">
                <table>
                    <tr>
                        <th>النوع</th>
                        <th>الاسم</th>
                        <th>الحجم</th>
                        <th>مسار التثبيت المحسوب تلقائيًا</th>
                        <th>إجراءات</th>
                    </tr>
                    <?php foreach ($gameFiles as $f) {
                        $fPath = flux_install_path($f['type'], $filesGame['package_name'], $f['version_code'], $f['url']);
                    ?>
                    <tr>
                        <td><span class="tag"><?php echo strtoupper(e($f['type'])); ?></span></td>
                        <td><?php echo e($f['name']); ?></td>
                        <td><?php echo (int) $f['size'] > 0 ? e(number_format($f['size'] / 1048576, 1)) . ' MB' : '—'; ?></td>
                        <td style="font-size:11px; direction:ltr; text-align:left; color:#26bbff;"><?php echo $fPath !== '' ? e($fPath) : 'تثبيت مباشر عبر مثبت النظام'; ?></td>
                        <td>
                            <div class="actions">
                                <a class="btn-edit" href="admin.php?files=<?php echo (int) $filesGame['id']; ?>&edit_file=<?php echo (int) $f['id']; ?>">تعديل</a>
                                <?php if (trim((string) $f['source_url']) !== '') { ?>
                                <form method="post" action="admin.php" onsubmit="return confirm('إعادة استخراج الرابط المباشر من صفحة المصدر المحفوظة؟');">
                                    <input type="hidden" name="action" value="refresh_file">
                                    <input type="hidden" name="file_id" value="<?php echo (int) $f['id']; ?>">
                                    <input type="hidden" name="game_id" value="<?php echo (int) $filesGame['id']; ?>">
                                    <button class="btn-edit" type="submit" style="color:#2fbf71;" title="المصدر: <?php echo e($f['source_url']); ?><?php echo $f['resolved_at'] !== '' ? ' — آخر استخراج: ' . e($f['resolved_at']) : ''; ?>">تحديث الرابط</button>
                                </form>
                                <?php } ?>
                                <form method="post" action="admin.php" onsubmit="return confirm('حذف هذا الملف؟');">
                                    <input type="hidden" name="action" value="delete_file">
                                    <input type="hidden" name="file_id" value="<?php echo (int) $f['id']; ?>">
                                    <input type="hidden" name="game_id" value="<?php echo (int) $filesGame['id']; ?>">
                                    <button class="btn-danger" type="submit">حذف</button>
                                </form>
                            </div>
                        </td>
                    </tr>
                    <?php } ?>
                    <?php if (empty($gameFiles)) { ?>
                    <tr><td colspan="5" style="color:#b8b8c1;">لا توجد ملفات بعد — أضف ملف APK حتى تصبح اللعبة قابلة للتحميل داخل التطبيق (للألعاب المجانية).</td></tr>
                    <?php } ?>
                </table>
                </div>
            </div>
            <?php } else { ?>
            <!-- جدول الألعاب -->
            <div class="card">
                <h2 style="font-size:16px; margin-bottom:12px;">الألعاب (<?php echo count($games); ?>)</h2>
                <div style="overflow-x:auto;">
                <table>
                    <tr>
                        <th>الغلاف</th>
                        <th>الاسم</th>
                        <th>التصنيف</th>
                        <th>السعر</th>
                        <th>التقييم</th>
                        <th>إجراءات</th>
                    </tr>
                    <?php foreach ($games as $g) {
                        $price    = (float) $g['price'];
                        $discount = $g['discount_price'] === null ? null : (float) $g['discount_price'];
                        $has      = $discount !== null && $discount < $price && $price > 0;
                    ?>
                    <tr>
                        <td>
                            <?php if ($g['image_url'] !== '') { ?>
                                <img src="<?php echo e($g['image_url']); ?>" alt="">
                            <?php } ?>
                        </td>
                        <td>
                            <?php echo e($g['name']); ?>
                            <?php if ((int) $g['is_featured'] === 1) { ?> <span class="tag">مميزة</span><?php } ?>
                        </td>
                        <td><?php echo isset($categories[$g['category']]) ? e($categories[$g['category']]) : e($g['category']); ?></td>
                        <td>
                            <?php if ($price <= 0) { ?>
                                <span class="tag tag-free">مجانية</span>
                            <?php } elseif ($has) { ?>
                                <span class="tag">-<?php echo (int) round((($price - $discount) / $price) * 100); ?>%</span>
                                <?php echo e(number_format($discount, 2)); ?>$
                            <?php } else { ?>
                                <?php echo e(number_format($price, 2)); ?>$
                            <?php } ?>
                        </td>
                        <td><?php echo e(number_format((float) $g['rating'], 1)); ?> ★</td>
                        <td>
                            <div class="actions">
                                <a class="btn-edit" href="admin.php?edit=<?php echo (int) $g['id']; ?>">تعديل</a>
                                <a class="btn-edit" href="admin.php?files=<?php echo (int) $g['id']; ?>" style="color:#2fbf71;">الملفات<?php echo isset($filesCountMap[(int) $g['id']]) ? ' (' . $filesCountMap[(int) $g['id']] . ')' : ''; ?></a>
                                <form method="post" action="admin.php" onsubmit="return confirm('تأكيد حذف: <?php echo e($g['name']); ?> ؟');">
                                    <input type="hidden" name="action" value="delete">
                                    <input type="hidden" name="id" value="<?php echo (int) $g['id']; ?>">
                                    <button class="btn-danger" type="submit">حذف</button>
                                </form>
                            </div>
                        </td>
                    </tr>
                    <?php } ?>
                </table>
                </div>
            </div>
            <?php } ?>

            <a class="btn btn-ghost" href="?logout=1" style="text-decoration:none;">تسجيل الخروج</a>
        <?php } ?>
    <?php } ?>
</div>

<script>
// ============ محرك استخراج الرابط المباشر (واجهة admin.php) ============
// الاتصال بـ resolve.php — الجلسة نفسها محمية، والنتيجة JSON

function fluxFmtSize(bytes) {
    if (!bytes || bytes <= 0) return '';
    var u = ['B', 'KB', 'MB', 'GB'];
    var v = bytes, i = 0;
    while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
    return (i === 0 || v >= 100 ? Math.round(v) : Math.round(v * 10) / 10) + ' ' + u[i];
}

function fluxResolveFetch(pageUrl) {
    var fd = new FormData();
    fd.append('url', pageUrl);
    return fetch('resolve.php', { method: 'POST', body: fd })
        .then(function (res) { return res.json(); });
}

// زر 🔍 داخل أي صف: يقرأ رابط الصفحة من حقل url في الصف نفسه ويملأ الرابط المباشر والحجم
function fluxResolveRow(btn) {
    var row = btn.closest('.row');
    if (!row) return;
    var urlInput = row.querySelector('input[type="url"]');
    var sizeInput = row.querySelector('input[type="number"]');
    if (!urlInput || !urlInput.value.trim()) {
        alert('الصق رابط صفحة التحميل في الحقل أولًا (ميديافاير / درايف / صفحة فيها زر تحميل)');
        return;
    }
    var oldText = btn.textContent;
    btn.disabled = true;
    btn.textContent = '⏳ جارٍ سحب الرابط المباشر...';
    fluxResolveFetch(urlInput.value.trim()).then(function (r) {
        btn.disabled = false;
        if (r && r.ok) {
            urlInput.value = r.direct_url;
            if (sizeInput && r.size > 0) sizeInput.value = (r.size / 1048576).toFixed(2);
            btn.textContent = '✅ تم — ' + (r.size_text || 'الرابط جاهز');
            setTimeout(function () { btn.textContent = oldText; }, 3000);
        } else {
            btn.textContent = oldText;
            alert('فشل الاستخراج: ' + (r && r.note ? r.note : 'خطأ غير معروف'));
        }
    }).catch(function (e) {
        btn.disabled = false;
        btn.textContent = oldText;
        alert('تعذر الاتصال بـ resolve.php — تأكد أن الملف مرفوع بجانب admin.php');
    });
}

// أداة بطاقة الاستخراج في صفحة الملفات: عرض النتيجة كاملة قبل استخدامها
function fluxResolvePage() {
    var input = document.getElementById('resolve-url');
    var status = document.getElementById('resolve-status');
    var result = document.getElementById('resolve-result');
    if (!input || !input.value.trim()) {
        status.textContent = 'الصق رابط صفحة التحميل أولًا';
        status.style.color = '#ff8a99';
        return;
    }
    var btn = document.getElementById('resolve-btn');
    btn.disabled = true;
    btn.textContent = '⏳ جارٍ التحليل...';
    status.textContent = 'نفتح الصفحة ونبحث عن زر التحميل المباشر... قد يأخذ ثوانٍ';
    status.style.color = '#b8b8c1';
    result.style.display = 'none';

    fluxResolveFetch(input.value.trim()).then(function (r) {
        btn.disabled = false;
        btn.textContent = 'استخراج الرابط المباشر';
        if (r && r.ok) {
            status.textContent = '✅ تم الاستخراج بنجاح';
            status.style.color = '#2fbf71';
            document.getElementById('resolve-direct').value = r.direct_url;
            document.getElementById('resolve-name').textContent = r.file_name || '—';
            document.getElementById('resolve-size').textContent = r.size_text || (r.size > 0 ? fluxFmtSize(r.size) : 'غير معروف');
            document.getElementById('resolve-source').textContent = r.source || '—';
            window._fluxResolvedSize = r.size || 0;
            window._fluxResolvedName = r.file_name || '';
            result.style.display = 'block';
        } else {
            status.textContent = '✗ ' + (r && r.note ? r.note : 'خطأ غير معروف');
            status.style.color = '#ff8a99';
        }
    }).catch(function (e) {
        btn.disabled = false;
        btn.textContent = 'استخراج الرابط المباشر';
        status.textContent = 'تعذر الاتصال بـ resolve.php — تأكد أن الملف مرفوع بجانب admin.php';
        status.style.color = '#ff8a99';
    });
}

// زر "استخدمه في نموذج الملف": يملأ الرابط المباشر + الحجم + الاسم + رابط المصدر
function fluxUseResult() {
    var direct = document.getElementById('resolve-direct');
    if (!direct || !direct.value) return;
    var form = document.getElementById('file-form');
    if (!form) return;
    var urlInput = form.querySelector('input[name="file_url"]');
    var sizeInput = form.querySelector('input[name="size_mb"]');
    var nameInput = form.querySelector('input[name="file_name"]');
    var srcInput = document.getElementById('source-url');
    if (urlInput) urlInput.value = direct.value;
    if (sizeInput && window._fluxResolvedSize > 0) sizeInput.value = (window._fluxResolvedSize / 1048576).toFixed(2);
    if (nameInput && window._fluxResolvedName && nameInput.value.trim() === '') nameInput.value = window._fluxResolvedName;
    if (srcInput) srcInput.value = document.getElementById('resolve-url').value.trim();
    form.scrollIntoView({ behavior: 'smooth', block: 'center' });
    if (urlInput) {
        urlInput.focus();
        urlInput.select();
    }
}
</script>
</body>
</html>
