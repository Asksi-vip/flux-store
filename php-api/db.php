<?php
/**
 * طبقة البيانات: اتصال SQLite + إنشاء الجدول + تعبئة تجريبية + دوال مشتركة.
 * يستخدمها index.php (الـ API) و admin.php (لوحة الإدارة).
 */

require_once __DIR__ . '/config.php';

/** تصنيفات الألعاب الافتراضية عند أول تشغيل (القيمة ← الاسم المعروض كما في التطبيق). */
function flux_categories()
{
    return array(
        'action'    => 'أكشن',
        'adventure' => 'مغامرات',
        'rpg'       => 'لعب أدوار (RPG)',
        'racing'    => 'سباقات',
        'shooter'   => 'تصويب',
        'sports'    => 'رياضة',
        'strategy'  => 'استراتيجية',
        'sandbox'   => 'عالم مفتوح',
    );
}

/** إنشاء جداول التصنيفات + تعبئة الافتراضية عند أول تشغيل (تصنيفات قابلة للإضافة والحذف). */
function flux_ensure_categories(PDO $pdo)
{
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS categories (
            id   INTEGER PRIMARY KEY AUTOINCREMENT,
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            sort INTEGER NOT NULL DEFAULT 0
        )
    ");
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS game_categories (
            game_id     INTEGER NOT NULL,
            category_id INTEGER NOT NULL,
            PRIMARY KEY (game_id, category_id)
        )
    ");
    $count = (int) $pdo->query('SELECT COUNT(*) FROM categories')->fetchColumn();
    if ($count === 0) {
        $ins = $pdo->prepare('INSERT INTO categories (slug, name, sort) VALUES (:slug, :name, :sort)');
        $i = 0;
        foreach (flux_categories() as $slug => $name) {
            $ins->execute(array(':slug' => $slug, ':name' => $name, ':sort' => $i++));
        }
    }
}

/** كل التصنيفات الحالية من القاعدة مرتبة (id, slug, name, sort). */
function flux_categories_rows(PDO $pdo)
{
    return $pdo->query('SELECT * FROM categories ORDER BY sort ASC, id ASC')->fetchAll();
}

/** تصنيفات كل لعبة من المجموعة دفعة واحدة → [game_id ← [slug, slug, ...]]. */
function flux_game_category_slugs(PDO $pdo, array $ids)
{
    $ids = array_values(array_filter(array_map('intval', $ids)));
    if (empty($ids)) {
        return array();
    }
    $marks = array();
    $params = array();
    foreach ($ids as $i => $v) {
        $marks[] = ':g' . $i;
        $params[':g' . $i] = $v;
    }
    $stmt = $pdo->prepare(
        'SELECT gc.game_id, c.slug FROM game_categories gc
         JOIN categories c ON c.id = gc.category_id
         WHERE gc.game_id IN (' . implode(',', $marks) . ')
         ORDER BY c.sort ASC, c.id ASC'
    );
    $stmt->execute($params);
    $map = array();
    foreach ($stmt->fetchAll() as $row) {
        $map[(int) $row['game_id']][] = $row['slug'];
    }
    return $map;
}

/** حفظ تصنيفات لعبة واحدة (قائمة slugs) — تحل القديمة بالكامل، والأساسي يُخزن بأول واحدة. */
function flux_set_game_categories(PDO $pdo, $gameId, array $slugs)
{
    $pdo->prepare('DELETE FROM game_categories WHERE game_id = :gid')->execute(array(':gid' => (int) $gameId));
    $slugs = array_values(array_filter(array_map('trim', $slugs)));
    if (empty($slugs)) {
        return;
    }
    $ins = $pdo->prepare('INSERT OR IGNORE INTO game_categories (game_id, category_id) SELECT :gid, id FROM categories WHERE slug = :slug');
    foreach ($slugs as $slug) {
        $ins->execute(array(':gid' => (int) $gameId, ':slug' => $slug));
    }
}

/** إن لم تحددها اللعبة من جدول التصنيفات بعد، نصل القديم بالجديد (ترحيل تلقائي مرة واحدة). */
function flux_migrate_legacy_categories(PDO $pdo)
{
    $n = (int) $pdo->query('SELECT COUNT(*) FROM game_categories')->fetchColumn();
    if ($n > 0) {
        return;
    }
    $ins = $pdo->prepare('INSERT OR IGNORE INTO game_categories (game_id, category_id) SELECT :gid, id FROM categories WHERE slug = :slug');
    foreach ($pdo->query('SELECT id, category FROM games')->fetchAll() as $g) {
        $ins->execute(array(':gid' => (int) $g['id'], ':slug' => (string) $g['category']));
    }
}

/** اتصال PDO بقاعدة SQLite + إنشاء الجدول + تعبئة البيانات التجريبية عند أول تشغيل. */
function flux_db()
{
    $dir = dirname(FLUX_DB_PATH);
    if (!is_dir($dir)) {
        @mkdir($dir, 0775, true);
    }
    // درع حماية دائم: منع فتح قاعدة البيانات من المتصفح مباشرة
    $ht = $dir . '/.htaccess';
    if (!file_exists($ht)) {
        @file_put_contents($ht, "# منع الوصول المباشر لملفات قاعدة البيانات عبر المتصفح\nRequire all denied\n");
    }

    $pdo = new PDO('sqlite:' . FLUX_DB_PATH);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS games (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            name           TEXT NOT NULL UNIQUE,
            description    TEXT NOT NULL DEFAULT '',
            price          REAL NOT NULL DEFAULT 0,
            discount_price REAL,
            category       TEXT NOT NULL DEFAULT 'action',
            rating         REAL NOT NULL DEFAULT 0,
            image_url      TEXT NOT NULL DEFAULT '',
            banner_url     TEXT NOT NULL DEFAULT '',
            release_date   TEXT NOT NULL DEFAULT '2024-01-01',
            is_featured    INTEGER NOT NULL DEFAULT 0,
            created_at     TEXT NOT NULL DEFAULT (datetime('now'))
        )
    ");

    // ترقية قواعد بيانات النسخ القديمة: أعمدة التحميل + أعمدة مستخرج الرابط المباشر
    flux_migrate($pdo);

    // التصنيفات الديناميكية (إضافة/تعديل/حذف من اللوحة) + الربط المتعدد للألعاب
    flux_ensure_categories($pdo);
    flux_migrate_legacy_categories($pdo);

    // ملفات التحميل لكل لعبة (APK أساسي + ملفات إضافية OBB/Data مع المسار المحسوب)
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS game_files (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            game_id      INTEGER NOT NULL,
            name         TEXT NOT NULL DEFAULT '',
            url          TEXT NOT NULL DEFAULT '',
            type         TEXT NOT NULL DEFAULT 'apk',
            size         INTEGER NOT NULL DEFAULT 0,
            version_code INTEGER NOT NULL DEFAULT 0,
            source_url   TEXT NOT NULL DEFAULT '',
            resolved_at  TEXT NOT NULL DEFAULT '',
            created_at   TEXT NOT NULL DEFAULT (datetime('now'))
        )
    ");

    $count = (int) $pdo->query('SELECT COUNT(*) FROM games')->fetchColumn();
    if ($count === 0) {
        flux_seed_games($pdo);
        flux_migrate_legacy_categories($pdo);
    }

    $fileCount = (int) $pdo->query('SELECT COUNT(*) FROM game_files')->fetchColumn();
    if ($fileCount === 0) {
        flux_seed_files($pdo);
    }

    return $pdo;
}

/** إضافة أعمدة التحميل إلى قواعد بيانات النسخ القديمة (يتجاهل ما هو موجود). */
function flux_migrate(PDO $pdo)
{
    $names = array();
    foreach ($pdo->query('PRAGMA table_info(games)')->fetchAll() as $c) {
        $names[] = $c['name'];
    }
    $extra = array(
        'package_name'          => "ALTER TABLE games ADD COLUMN package_name TEXT NOT NULL DEFAULT ''",
        'download_version'      => "ALTER TABLE games ADD COLUMN download_version TEXT NOT NULL DEFAULT ''",
        'download_version_code' => 'ALTER TABLE games ADD COLUMN download_version_code INTEGER NOT NULL DEFAULT 0',
        // حقول بنمط سوق أبِل: المطور وتاريخ آخر تحديث للعبة
        'developer'             => "ALTER TABLE games ADD COLUMN developer TEXT NOT NULL DEFAULT ''",
        'last_updated'          => "ALTER TABLE games ADD COLUMN last_updated TEXT NOT NULL DEFAULT ''",
    );
    foreach ($extra as $col => $sql) {
        if (!in_array($col, $names, true)) {
            $pdo->exec($sql);
        }
    }

    // ترقية جدول الملفات: أعمدة مستخرج الرابط المباشر
    // source_url  ← رابط الصفحة الأصلي (ميديافاير/درايف/صفحة تحميل) لإعادة الاستخراج لاحقًا
    // resolved_at ← وقت آخر استخراج ناجح للرابط المباشر
    // (على قاعدة جديدة الجدول غير موجود بعد — يُنشأ كامل الأعمدة بعد الترقية مباشرة)
    $fileNames = array();
    foreach ($pdo->query('PRAGMA table_info(game_files)')->fetchAll() as $c) {
        $fileNames[] = $c['name'];
    }
    if (!empty($fileNames)) {
        $fileExtra = array(
            'source_url' => "ALTER TABLE game_files ADD COLUMN source_url TEXT NOT NULL DEFAULT ''",
            'resolved_at' => "ALTER TABLE game_files ADD COLUMN resolved_at TEXT NOT NULL DEFAULT ''",
        );
        foreach ($fileExtra as $col => $sql) {
            if (!in_array($col, $fileNames, true)) {
                $pdo->exec($sql);
            }
        }
    }
}

/**
 * حساب مسار تثبيت الملف تلقائيًا وفق معايير أندرويد:
 *   apk  ← يثبّت عبر مثبّت النظام (بلا مسار)
 *   obb  ← /storage/emulated/0/Android/obb/<الحزمة>/main.<رقم الإصدار>.<الحزمة>.obb
 *   data ← /storage/emulated/0/Android/data/<الحزمة>/files/<اسم الملف>
 */
function flux_install_path($type, $pkg, $versionCode, $url)
{
    $pkg = trim((string) $pkg);
    $baseName = $url;
    $qpos = strpos($baseName, '?');
    $query = ($qpos !== false) ? substr($baseName, $qpos + 1) : '';
    if ($qpos !== false) {
        $baseName = substr($baseName, 0, $qpos);
    }
    $baseName = basename(str_replace('\\', '/', $baseName));
    if ($baseName === '' || $baseName === '/') {
        $baseName = 'file.bin';
    }
    // إن كان اسم الملف بلا امتداد، جرّب استخراجه من معاملات الرابط (مثل ?f=patch.zip)
    if (strpos($baseName, '.') === false && $query !== '') {
        parse_str($query, $params);
        foreach ($params as $p) {
            if (is_string($p) && $p !== '' && strlen($p) <= 200) {
                $candidate = basename(str_replace('\\', '/', $p));
                if (strpos($candidate, '.') !== false) {
                    $baseName = $candidate;
                    break;
                }
            }
        }
    }

    if ($type === 'obb') {
        if ($pkg === '') {
            $pkg = 'unknown';
        }
        $vc = (int) $versionCode;
        if ($vc < 1) {
            $vc = 1;
        }
        return '/storage/emulated/0/Android/obb/' . $pkg . '/main.' . $vc . '.' . $pkg . '.obb';
    }
    if ($type === 'data') {
        if ($pkg === '') {
            $pkg = 'unknown';
        }
        return '/storage/emulated/0/Android/data/' . $pkg . '/files/' . $baseName;
    }
    return '';
}

/**
 * اشتقاق اسم حزمة أندرويد تلقائيًا من روابط التحميل (لا حاجة لإدخاله يدويًا):
 * يبحث عن نمط com.company.game داخل الروابط ويعيد أول تطابق.
 */
function flux_package_from_url(array $urls)
{
    foreach ($urls as $url) {
        if (!is_string($url) || $url === '') {
            continue;
        }
        if (preg_match('/com\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+/', $url, $m)) {
            return $m[0];
        }
    }
    return '';
}

/** تحويل قيمة ميغابايت (نص) إلى بايتات — صفر عند الفارغة أو غير الصالحة. */
function flux_mb_to_bytes($mb)
{
    return flux_size_to_bytes($mb, 'MB');
}

/** تحويل حجم بقيمة ووحدة (KB/MB/GB) إلى بايتات — من نموذج اللوحة. */
function flux_size_to_bytes($value, $unit)
{
    $v = (float) (($value === '' || $value === null) ? 0 : $value);
    if ($v <= 0) {
        return 0;
    }
    switch (strtoupper((string) $unit)) {
        case 'KB':
            return (int) round($v * 1024);
        case 'GB':
            return (int) round($v * 1024 * 1024 * 1024);
        case 'MB':
        default:
            return (int) round($v * 1024 * 1024);
    }
}

/**
 * جمع ملفات التحميل من نموذج اللعبة مباشرة:
 * APK أساسي + OBB + صفوف Data متعددة (data_url[] / data_size[] + وحدات KB/MB/GB) → مصفوفة جاهزة للإدراج.
 * الحجم يُخزن بالبايتات دائمًا — الوحدة تأتي من حقل اختيار موازٍ لكل صف.
 */
function flux_collect_files_input($post)
{
    $files = array();

    $apkUrl = trim((string) (isset($post['apk_url']) ? $post['apk_url'] : ''));
    if ($apkUrl !== '') {
        $files[] = array(
            'name'         => 'ملف تثبيت اللعبة APK',
            'url'          => $apkUrl,
            'type'         => 'apk',
            'size'         => flux_size_to_bytes(isset($post['apk_size']) ? $post['apk_size'] : '', isset($post['apk_size_unit']) ? $post['apk_size_unit'] : 'MB'),
            'version_code' => 0,
        );
    }

    $obbUrl = trim((string) (isset($post['obb_url']) ? $post['obb_url'] : ''));
    if ($obbUrl !== '') {
        $files[] = array(
            'name'         => 'ملف البيانات الرئيسي OBB',
            'url'          => $obbUrl,
            'type'         => 'obb',
            'size'         => flux_size_to_bytes(isset($post['obb_size']) ? $post['obb_size'] : '', isset($post['obb_size_unit']) ? $post['obb_size_unit'] : 'MB'),
            'version_code' => (int) (isset($post['obb_version_code']) && $post['obb_version_code'] !== '' ? $post['obb_version_code'] : 0),
        );
    }

    $dataUrls  = (isset($post['data_url']) && is_array($post['data_url'])) ? $post['data_url'] : array();
    $dataSizes = (isset($post['data_size']) && is_array($post['data_size'])) ? $post['data_size'] : array();
    $dataUnits = (isset($post['data_size_unit']) && is_array($post['data_size_unit'])) ? $post['data_size_unit'] : array();
    // توافق مع النسخة السابقة (data_size_mb بالميغابايت)
    $dataSizesMb = (isset($post['data_size_mb']) && is_array($post['data_size_mb'])) ? $post['data_size_mb'] : array();
    $n = 0;
    foreach ($dataUrls as $i => $u) {
        $u = trim((string) $u);
        if ($u === '') {
            continue;
        }
        $n++;
        $val = isset($dataSizes[$i]) ? $dataSizes[$i] : (isset($dataSizesMb[$i]) ? $dataSizesMb[$i] : '');
        $unit = isset($dataSizes[$i]) && $dataSizes[$i] !== '' ? (isset($dataUnits[$i]) ? $dataUnits[$i] : 'MB') : 'MB';
        $files[] = array(
            'name'         => 'ملفات إضافية Data ' . $n,
            'url'          => $u,
            'type'         => 'data',
            'size'         => flux_size_to_bytes($val, $unit),
            'version_code' => 0,
        );
    }

    return $files;
}

/** جلب ملفات التحميل لمجموعة ألعاب دفعة واحدة → [game_id ← قائمة الملفات]. */
function flux_files_for_games(PDO $pdo, array $ids)
{
    $ids = array_values(array_filter(array_map('intval', $ids)));
    if (empty($ids)) {
        return array();
    }
    $marks = array();
    foreach ($ids as $i => $v) {
        $marks[] = ':id' . $i;
    }
    $stmt = $pdo->prepare('SELECT * FROM game_files WHERE game_id IN (' . implode(',', $marks) . ') ORDER BY id ASC');
    $params = array();
    foreach ($ids as $i => $v) {
        $params[':id' . $i] = $v;
    }
    $stmt->execute($params);

    $map = array();
    foreach ($stmt->fetchAll() as $row) {
        $gid = (int) $row['game_id'];
        if (!isset($map[$gid])) {
            $map[$gid] = array();
        }
        $map[$gid][] = $row;
    }
    return $map;
}

/** تعبئة ملفات تحميل تجريبية لألعبتين مجانيتين (روابط اختبار OVH تدعم الاستئناف Range) — استبدلها بروابطك من لوحة الإدارة. */
function flux_seed_files(PDO $pdo)
{
    $demo = array(
        array('Dota 2', 'com.valve.dota2', '2.4.1', 120, array(
            array('ملف تثبيت اللعبة APK', 'https://proof.ovh.net/files/100Mb.dat', 'apk', 104857600, 0),
            array('ملف البيانات الرئيسي OBB', 'https://proof.ovh.net/files/100Mb.dat', 'obb', 104857600, 120),
            array('ملفات إضافية Data', 'https://proof.ovh.net/files/10Mb.dat', 'data', 10485760, 0),
        )),
        array('Counter-Strike 2', 'com.valve.cs2', '1.40.6', 1406, array(
            array('ملف تثبيت اللعبة APK', 'https://proof.ovh.net/files/10Mb.dat', 'apk', 10485760, 0),
        )),
    );

    $lookup = $pdo->prepare('SELECT id FROM games WHERE name = :name');
    $insert = $pdo->prepare("
        INSERT INTO game_files (game_id, name, url, type, size, version_code)
        VALUES (:game_id, :name, :url, :type, :size, :version_code)
    ");

    foreach ($demo as $d) {
        $lookup->execute(array(':name' => $d[0]));
        $gid = $lookup->fetchColumn();
        if ($gid === false) {
            continue;
        }
        // تحديث بيانات الحزمة والإصدار للعبة
        $pdo->prepare('UPDATE games SET package_name = :p, download_version = :v, download_version_code = :vc WHERE id = :id')
            ->execute(array(':p' => $d[1], ':v' => $d[2], ':vc' => $d[3], ':id' => (int) $gid));
        foreach ($d[4] as $f) {
            $insert->execute(array(
                ':game_id'      => (int) $gid,
                ':name'         => $f[0],
                ':url'          => $f[1],
                ':type'         => $f[2],
                ':size'         => $f[3],
                ':version_code' => $f[4],
            ));
        }
    }
}

/** تعبئة 14 لعبة مشهورة بصور حقيقية من Steam CDN (تعمل مرة واحدة فقط). */
function flux_seed_games(PDO $pdo)
{
    $steam = function ($id) {
        return 'https://cdn.cloudflare.steamstatic.com/steam/apps/' . $id . '/';
    };

    // (الاسم، الفئة، السعر، سعر الخصم، التقييم، مميزة؟، تاريخ الإصدار، الوصف، معرف Steam، تاريخ الإضافة)
    $games = array(
        array('Cyberpunk 2077', 'rpg', 59.99, 29.99, 4.6, 1, '2020-12-10', 'لعبة أكشن ومغامرات في عالم مستقبلي مفتوح بمدينة نايت سيتي، حيث تلعب دور مرتزق اسمه V بحثًا عن زرعة رقمية هي مفتاح الخلود.', '1091500', '2026-01-01 10:00:00'),
        array('Elden Ring', 'rpg', 59.99, 41.99, 4.8, 1, '2022-02-25', 'ملحمة عالم مفتوح من فروم سوفتوير بمشاركة جورج آر آر مارتن: ممالك متداعية، زعماء مخيفون، ووحشية لا ترحم.', '1245620', '2026-01-02 10:00:00'),
        array('Red Dead Redemption 2', 'action', 59.99, 17.99, 4.9, 1, '2019-11-05', 'قصة آرثر مورغان وعصابة فان دير ليند في نهاية عصر الغرب المتوحش — تفاصيل عالم مذهلة وسرد من أقوى القصص في تاريخ الألعاب.', '1174180', '2026-01-03 10:00:00'),
        array('Grand Theft Auto V', 'action', 29.99, null, 4.5, 0, '2015-04-13', 'ثلاثة مجرمين بأساليب مختلفة في مدينة لوس سانتوس الفاسدة — عالم مفتوح لا نهائي مع وضع Online متجدد باستمرار.', '271590', '2026-01-04 10:00:00'),
        array('The Witcher 3: Wild Hunt', 'rpg', 39.99, 7.99, 4.9, 0, '2015-05-18', 'الصياد جيرالت من ريفيا يبحث عن ابنة بالتبني بينما يزحف الويلد هنتر — RPG ضخم بأخلاقيات معقدة وقصص جانبية لا تُنسى.', '292030', '2026-01-05 10:00:00'),
        array('Dota 2', 'strategy', 0, null, 4.3, 1, '2013-07-09', 'الـ MOBA الأيقوني: فريقان من خمسة لاعبين يتنافسان على تدمير العرش — عمق استراتيجي هائل ومجاني بالكامل.', '570', '2026-01-06 10:00:00'),
        array('Counter-Strike 2', 'shooter', 0, null, 4.1, 0, '2023-09-27', 'جديد عالم كاونتر سترايك بمحرك Source 2: قتال تكتيكي 5 ضد 5 بدقة عالية واقتصاد أسلحة عالمي.', '730', '2026-01-07 10:00:00'),
        array('Forza Horizon 5', 'racing', 59.99, 29.99, 4.7, 0, '2021-11-05', 'قيادة مفتوحة في المكسيك بمئات السيارات وطقس ديناميكي — أجمل لعبة سباقات عالم مفتوح على الإطلاق.', '1551360', '2026-01-08 10:00:00'),
        array('It Takes Two', 'adventure', 39.99, 9.99, 4.8, 0, '2021-03-25', 'مغامرة تعاونية مغايرة لزوجين في خضم الطلاق، بتحديات لكل لاعب تتطلب تنسيقًا كاملًا — لعبة العام 2021.', '1426210', '2026-01-09 10:00:00'),
        array('Hades', 'action', 24.99, null, 4.8, 0, '2020-09-17', 'روغ لايت أسطوري في العالم السفلي الإغريقي: انتحار متكرر ممتع، قصص تتطور مع كل موت، وسرعة قتال أدمانية.', '1145360', '2026-01-10 10:00:00'),
        array('Stardew Valley', 'sandbox', 14.99, 8.99, 4.9, 0, '2016-02-26', 'اترك مدينتك وورث مزرعة جدك: زراعة، صيد، تعدين، وعلاقات اجتماعية في مدينة ساحلية دافئة — طوّره شخص واحد فقط.', '413150', '2026-01-11 10:00:00'),
        array('Hollow Knight', 'adventure', 14.99, null, 4.8, 0, '2017-02-24', 'ميترويدفانيا مرسومة يدويًا في مملكة الحشرات Hallownest: تحديات قاسية، أسرار عميقة، وجمال حزين فريد.', '367520', '2026-01-12 10:00:00'),
        array('EA SPORTS FC 24', 'sports', 69.99, 34.99, 3.9, 0, '2023-09-29', 'أول إصدار بعد رحيل FIFA: أكثر من 19 ألف لاعب و700 نادٍ بتقنيات حركة HyperMotionV وMatch IQ.', '2195250', '2026-01-13 10:00:00'),
        array("Baldur's Gate 3", 'rpg', 59.99, null, 4.9, 1, '2023-08-03', 'RPG تكتيكي من Larian بقواعد Dungeons & Dragons: ردود فعل لكل قرار، حملة من 100+ ساعة، وشخصيات لا تُنسى — لعبة العام 2023.', '1086940', '2026-01-14 10:00:00'),
    );

    $stmt = $pdo->prepare("
        INSERT INTO games
            (name, description, price, discount_price, category, rating,
             image_url, banner_url, release_date, is_featured, created_at)
        VALUES
            (:name, :description, :price, :discount_price, :category, :rating,
             :image_url, :banner_url, :release_date, :is_featured, :created_at)
    ");

    foreach ($games as $g) {
        $stmt->execute(array(
            ':name'           => $g[0],
            ':description'    => $g[7],
            ':price'          => $g[2],
            ':discount_price' => $g[3],
            ':category'       => $g[1],
            ':rating'         => $g[4],
            ':image_url'      => $steam($g[8]) . 'library_600x900.jpg',
            ':banner_url'     => $steam($g[8]) . 'library_hero.jpg',
            ':release_date'   => $g[6],
            ':is_featured'    => $g[5],
            ':created_at'     => $g[9],
        ));
    }
}

/** تحويل صف من قاعدة البيانات إلى صيغة JSON المتوافقة مع تطبيق Flutter حرفيًا (+ ملفات التحميل).
 *  $catSlugs تصنيفات اللعبة المتعددة (slug) — تحسب تلقائيًا من القاعدة عند تركها فارغة. */
function flux_serialize_game(array $g, array $files = array(), array $catSlugs = null)
{
    $price    = (float) $g['price'];
    $discount = ($g['discount_price'] === null) ? null : (float) $g['discount_price'];
    $has      = ($discount !== null && $discount < $price && $price > 0);
    $final    = $has ? $discount : $price;
    $cats     = flux_categories();
    $cat      = $g['category'];
    $catSlugs = ($catSlugs === null || empty($catSlugs)) ? array($cat) : $catSlugs;
    $catNames = array();
    foreach ($catSlugs as $slug) {
        $catNames[] = isset($cats[$slug]) ? $cats[$slug] : $slug;
    }

    // كائن التحميل: الملف الرئيسي هو أول ملف APK، والبقية OBB/Data بمسارات محسوبة تلقائيًا
    $dlFiles = array();
    $mainUrl = '';
    $mainSize = 0;
    foreach ($files as $f) {
        $type = (string) $f['type'];
        $url  = (string) $f['url'];
        if ($type === 'apk' && $mainUrl === '') {
            $mainUrl = $url;
            $mainSize = (int) $f['size'];
        }
        $dlFiles[] = array(
            'id'           => (int) $f['id'],
            'name'         => $f['name'],
            'type'         => $type,
            'url'          => $url,
            'size'         => (int) $f['size'],
            'version_code' => (int) $f['version_code'],
            'install_path' => flux_install_path($type, isset($g['package_name']) ? $g['package_name'] : '', isset($f['version_code']) ? $f['version_code'] : 0, $url),
        );
    }

    $out = array(
        'id'               => (int) $g['id'],
        'name'             => $g['name'],
        'description'      => $g['description'],
        'price'            => $price,
        'discount_price'   => $discount,
        'final_price'      => round($final, 2),
        'has_discount'     => $has,
        'category'         => $catSlugs[0],
        'category_display' => $catNames[0],
        // التصنيفات المتعددة بنمط سوق أبِل: قائمة كاملة بالأسماء والمعرفات
        'categories'       => $catSlugs,
        'categories_display' => $catNames,
        'rating'           => (float) $g['rating'],
        'image'            => $g['image_url'],
        'banner'           => $g['banner_url'],
        'release_date'     => $g['release_date'],
        'developer'        => isset($g['developer']) ? $g['developer'] : '',
        'last_updated'     => isset($g['last_updated']) ? $g['last_updated'] : '',
        'is_featured'      => (bool) $g['is_featured'],
        'created_at'       => $g['created_at'],
        'package_name'     => isset($g['package_name']) ? $g['package_name'] : '',
        'download'         => array(
            'available'    => !empty($dlFiles),
            'url'          => $mainUrl,
            'size'         => $mainSize,
            'version'      => isset($g['download_version']) ? $g['download_version'] : '',
            'version_code' => (int) (isset($g['download_version_code']) ? $g['download_version_code'] : 0),
            'package_name' => isset($g['package_name']) ? $g['package_name'] : '',
            'files'        => $dlFiles,
        ),
    );
    return $out;
}

/** إخراج JSON مع رمز حالة معين ثم إنهاء التنفيذ. */
function flux_json($data, $status = 200)
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

/** تجاه special characters داخل نمط LIKE (% و _ والشرطة المائلة). */
function flux_escape_like($s)
{
    return str_replace(array('\\', '%', '_'), array('\\\\', '\\%', '\\_'), $s);
}

/** بناء رابط مطلق لصفحة معين مع الحفاظ على كل معاملات البحث (للـ next/previous). */
function flux_page_url($page, $total, $newOffset)
{
    if ($total === 0 || $page < 1 || $newOffset < 0 || ($newOffset > 0 && $newOffset >= $total)) {
        return null;
    }
    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host   = isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : 'localhost';
    $uri    = isset($_SERVER['REQUEST_URI']) ? $_SERVER['REQUEST_URI'] : '/';

    $uri = preg_replace('/([?&])page=[^&]*/', '${1}page=' . (int) $page, $uri, 1, $replaced);
    if (!$replaced) {
        $uri .= (strpos($uri, '?') === false ? '?' : '&') . 'page=' . (int) $page;
    }
    return $scheme . '://' . $host . $uri;
}

/**
 * جلب قائمة الألعاب مع كل فلاتر الـ API المدعومة (نفس سلوك نسخة Django):
 * search، category، min_price، max_price، featured، ordering، page، page_size.
 */
function flux_games_list(PDO $pdo)
{
    $q     = $_GET;
    $where = array();
    $bind  = array();

    // 1) البحث بالاسم أو الوصف
    $search = trim((string) (isset($q['search']) ? $q['search'] : ''));
    if ($search !== '') {
        $like = '%' . flux_escape_like($search) . '%';
        $where[]       = '(name LIKE :s1 OR description LIKE :s2)';
        $bind[':s1']   = $like;
        $bind[':s2']   = $like;
    }

    // 2) التصنيف: يقبل أي تصنيف من تصنيفات اللعبة المتعددة (+ التوافق مع العمود القديم)
    $category = trim((string) (isset($q['category']) ? $q['category'] : ''));
    if ($category !== '') {
        $where[] = "(category = :cat OR id IN (SELECT gc.game_id FROM game_categories gc JOIN categories c ON c.id = gc.category_id WHERE c.slug = :cat))";
        $bind[':cat'] = $category;
    }

    // 3) نطاق السعر
    if (isset($q['min_price']) && $q['min_price'] !== '' && is_numeric($q['min_price'])) {
        $where[]        = 'price >= :min_price';
        $bind[':min_price'] = (float) $q['min_price'];
    }
    if (isset($q['max_price']) && $q['max_price'] !== '' && is_numeric($q['max_price'])) {
        $where[]        = 'price <= :max_price';
        $bind[':max_price'] = (float) $q['max_price'];
    }

    // 4) المميزة فقط
    $featured = strtolower(trim((string) (isset($q['featured']) ? $q['featured'] : '')));
    if (in_array($featured, array('true', '1', 'yes'), true)) {
        $where[] = 'is_featured = 1';
    }

    // 5) الترتيب (قائمة بيضاء لمنع أي استعلام غير آمن)
    $orderMap = array(
        'price'         => 'price ASC',
        '-price'        => 'price DESC',
        'rating'        => 'rating ASC',
        '-rating'       => 'rating DESC',
        'name'          => 'name ASC',
        '-name'         => 'name DESC',
        'release_date'  => 'release_date ASC',
        '-release_date' => 'release_date DESC',
    );
    $ordering = trim((string) (isset($q['ordering']) ? $q['ordering'] : ''));
    $orderBy  = isset($orderMap[$ordering]) ? $orderMap[$ordering] : 'is_featured DESC, created_at DESC, id DESC';

    // 6) تقسيم الصفحات
    $page     = max(1, (int) (isset($q['page']) ? $q['page'] : 1));
    $pageSize = (int) (isset($q['page_size']) ? $q['page_size'] : 10);
    if ($pageSize < 1) {
        $pageSize = 10;
    }
    if ($pageSize > 50) {
        $pageSize = 50;
    }
    $offset = ($page - 1) * $pageSize;

    $whereSql = empty($where) ? '' : 'WHERE ' . implode(' AND ', $where);

    $countStmt = $pdo->prepare('SELECT COUNT(*) FROM games ' . $whereSql);
    $countStmt->execute($bind);
    $total = (int) $countStmt->fetchColumn();

    $stmt = $pdo->prepare('SELECT * FROM games ' . $whereSql . ' ORDER BY ' . $orderBy . ' LIMIT ' . (int) $pageSize . ' OFFSET ' . (int) $offset);
    $stmt->execute($bind);
    $rows = $stmt->fetchAll();

    // جلب ملفات التحميل والتصنيفات لكل ألعاب الصفحة دفعة واحدة
    $ids = array();
    foreach ($rows as $r) {
        $ids[] = (int) $r['id'];
    }
    $filesMap = flux_files_for_games($pdo, $ids);
    $catsMap  = flux_game_category_slugs($pdo, $ids);

    $results = array();
    foreach ($rows as $r) {
        $gid = (int) $r['id'];
        $results[] = flux_serialize_game($r, isset($filesMap[$gid]) ? $filesMap[$gid] : array(), isset($catsMap[$gid]) ? $catsMap[$gid] : array());
    }

    return array(
        'count'    => $total,
        'next'     => flux_page_url($page + 1, $total, $offset + $pageSize),
        'previous' => flux_page_url($page - 1, $total, $offset - $pageSize),
        'results'  => $results,
    );
}

/** تحويل مصفوفة حقول إلى معاملات PDO مسماة (name ← :name) لضمان التوافق مع كل المحركات. */
function flux_prefix_params(array $fields)
{
    $out = array();
    foreach ($fields as $k => $v) {
        $out[':' . $k] = $v;
    }
    return $out;
}

/** جمع حقول نموذج الإدارة والتحقق منها (يُستخدم في admin.php). يعيد null عند الخطأ. */
function flux_collect_game_input(array $post)
{
    $name = trim((string) (isset($post['name']) ? $post['name'] : ''));
    if ($name === '') {
        return null;
    }

    $categories = flux_categories();
    $category   = trim((string) (isset($post['category']) ? $post['category'] : ''));
    if (!array_key_exists($category, $categories)) {
        $category = 'action';
    }

    $discountRaw = trim((string) (isset($post['discount_price']) ? $post['discount_price'] : ''));
    $discount    = ($discountRaw === '') ? null : (float) $discountRaw;

    $rating = (float) (isset($post['rating']) && $post['rating'] !== '' ? $post['rating'] : 0);
    if ($rating < 0) {
        $rating = 0;
    }
    if ($rating > 5) {
        $rating = 5;
    }

    $release = trim((string) (isset($post['release_date']) ? $post['release_date'] : ''));
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $release)) {
        $release = '2024-01-01';
    }

    // تاريخ آخر تحديث (نمط سوق أبِل) — افتراضيًا تاريخ الإصدار
    $lastUpdated = trim((string) (isset($post['last_updated']) ? $post['last_updated'] : ''));
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $lastUpdated)) {
        $lastUpdated = $release;
    }

    return array(
        'name'                  => $name,
        'description'           => (string) (isset($post['description']) ? $post['description'] : ''),
        'price'                 => max(0, (float) (isset($post['price']) && $post['price'] !== '' ? $post['price'] : 0)),
        'discount_price'        => $discount,
        'category'              => $category,
        'rating'                => $rating,
        'image_url'             => trim((string) (isset($post['image_url']) ? $post['image_url'] : '')),
        'banner_url'            => trim((string) (isset($post['banner_url']) ? $post['banner_url'] : '')),
        'release_date'          => $release,
        'developer'             => trim((string) (isset($post['developer']) ? $post['developer'] : '')),
        'last_updated'          => $lastUpdated,
        'is_featured'           => !empty($post['is_featured']) ? 1 : 0,
        'package_name'          => trim((string) (isset($post['package_name']) ? $post['package_name'] : '')),
        'download_version'      => trim((string) (isset($post['download_version']) ? $post['download_version'] : '')),
        'download_version_code' => (int) (isset($post['download_version_code']) && $post['download_version_code'] !== '' ? $post['download_version_code'] : 0),
    );
}
