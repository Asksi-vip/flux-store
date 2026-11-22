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

    $count = (int) $pdo->query('SELECT COUNT(*) FROM games')->fetchColumn();
    if ($count === 0) {
        flux_seed_games($pdo);
    }

    return $pdo;
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

/** تحويل صف من قاعدة البيانات إلى صيغة JSON المتوافقة مع تطبيق Flutter حرفيًا. */
function flux_serialize_game(array $g)
{
    $price    = (float) $g['price'];
    $discount = ($g['discount_price'] === null) ? null : (float) $g['discount_price'];
    $has      = ($discount !== null && $discount < $price && $price > 0);
    $final    = $has ? $discount : $price;
    $cats     = flux_categories();
    $cat      = $g['category'];

    return array(
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
    );
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

    return array(
        'count'    => $total,
        'next'     => flux_page_url($page + 1, $total, $offset + $pageSize),
        'previous' => flux_page_url($page - 1, $total, $offset - $pageSize),
        'results'  => array_map('flux_serialize_game', $rows),
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
        'name'           => $name,
        'description'    => (string) (isset($post['description']) ? $post['description'] : ''),
        'price'          => max(0, (float) (isset($post['price']) && $post['price'] !== '' ? $post['price'] : 0)),
        'discount_price' => $discount,
        'category'       => $category,
        'rating'         => $rating,
        'image_url'      => trim((string) (isset($post['image_url']) ? $post['image_url'] : '')),
        'banner_url'     => trim((string) (isset($post['banner_url']) ? $post['banner_url'] : '')),
        'release_date'   => $release,
        'is_featured'    => !empty($post['is_featured']) ? 1 : 0,
    );
}
