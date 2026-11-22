<?php
/**
 * طبقة البيانات: اتصال SQLite + إنشاء الجدول + تعبئة تجريبية + دوال مشتركة.
 * يستخدمها index.php (الـ API) و admin.php (لوحة الإدارة).
 */

require_once __DIR__ . '/config.php';

/** تصنيفات الألعاب المدعومة (القيمة ← الاسم المعروض كما في التطبيق). */
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

/** اتصال PDO بقاعدة SQLite + إنشاء الجدول + تعبئة البيانات التجريبية عند أول تشغيل. */
function flux_db()
{
    $dir = dirname(FLUX_DB_PATH);
    if (!is_dir($dir)) {
        @mkdir($dir, 0775, true);
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

    // ترقية قواعد بيانات النسخ القديمة: أعمدة التحميل
    flux_migrate($pdo);

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
            created_at   TEXT NOT NULL DEFAULT (datetime('now'))
        )
    ");

    $count = (int) $pdo->query('SELECT COUNT(*) FROM games')->fetchColumn();
    if ($count === 0) {
        flux_seed_games($pdo);
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
    );
    foreach ($extra as $col => $sql) {
        if (!in_array($col, $names, true)) {
            $pdo->exec($sql);
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

/** تحويل صف من قاعدة البيانات إلى صيغة JSON المتوافقة مع تطبيق Flutter حرفيًا (+ ملفات التحميل). */
function flux_serialize_game(array $g, array $files = array())
{
    $price    = (float) $g['price'];
    $discount = ($g['discount_price'] === null) ? null : (float) $g['discount_price'];
    $has      = ($discount !== null && $discount < $price && $price > 0);
    $final    = $has ? $discount : $price;
    $cats     = flux_categories();
    $cat      = $g['category'];

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
        'category'         => $cat,
        'category_display' => isset($cats[$cat]) ? $cats[$cat] : $cat,
        'rating'           => (float) $g['rating'],
        'image'            => $g['image_url'],
        'banner'           => $g['banner_url'],
        'release_date'     => $g['release_date'],
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

    // 2) الفئة (من القائمة البيضاء فقط)
    $category = trim((string) (isset($q['category']) ? $q['category'] : ''));
    if ($category !== '' && array_key_exists($category, flux_categories())) {
        $where[]      = 'category = :cat';
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

    // جلب ملفات التحميل لكل ألعاب الصفحة دفعة واحدة
    $ids = array();
    foreach ($rows as $r) {
        $ids[] = (int) $r['id'];
    }
    $filesMap = flux_files_for_games($pdo, $ids);

    $results = array();
    foreach ($rows as $r) {
        $gid = (int) $r['id'];
        $results[] = flux_serialize_game($r, isset($filesMap[$gid]) ? $filesMap[$gid] : array());
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
        'is_featured'           => !empty($post['is_featured']) ? 1 : 0,
        'package_name'          => trim((string) (isset($post['package_name']) ? $post['package_name'] : '')),
        'download_version'      => trim((string) (isset($post['download_version']) ? $post['download_version'] : '')),
        'download_version_code' => (int) (isset($post['download_version_code']) && $post['download_version_code'] !== '' ? $post['download_version_code'] : 0),
    );
}
