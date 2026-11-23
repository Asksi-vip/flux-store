<?php
/**
 * التعبئة التلقائية بالذكاء الاصطناعي — FLUX API
 *
 * يكتب وصفًا كاملًا للعبة ويملأ كل ما هو ناقص (المطور، الباكج نيم، التقييم،
 * تواريخ الإصدار/التحديث، التصنيفات المقترحة، الإصدار) عبر وكيل الذكاء
 * الاصطناعي المتوافق مع OpenAI (lara-php-api المنشور مثلًا على /flux/ai/).
 *
 * الاستخدام:
 *   1) كمكتبة من admin.php:  flux_ai_fill_game($name, $hints, &$error)
 *   2) نقطة AJAX مستقلة:     POST ai.php (name=...، hints=...) — جلسة إدارة مسجلة
 */

require_once __DIR__ . '/config.php';

/** رابط نقطة المحادثة للوكيل (يُضبط في config.php). */
if (!defined('FLUX_AI_URL')) {
    define('FLUX_AI_URL', 'http://camillecyrm.serv00.net/flux/ai/v1/chat/completions');
}
if (!defined('FLUX_AI_MODEL')) {
    define('FLUX_AI_MODEL', 'gpt-4o'); // اسم مستعار يوجهه الوكيل لأفضل نموذج مجاني
}
if (!defined('FLUX_AI_TIMEOUT')) {
    define('FLUX_AI_TIMEOUT', 90);
}

/** استدعاء نموذج المحادثة عبر الوكيل (غير مُبثّ) — يعيد نص الرد أو null. */
function flux_ai_chat($system, $user)
{
    if (!flux_ai_url_allowed()) {
        return null;
    }
    $payload = json_encode(array(
        'model'    => FLUX_AI_MODEL,
        'stream'   => false,
        'messages' => array(
            array('role' => 'system', 'content' => $system),
            array('role' => 'user', 'content' => $user),
        ),
    ), JSON_UNESCAPED_UNICODE);

    $ch = curl_init((string) FLUX_AI_URL);
    curl_setopt_array($ch, array(
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => $payload,
        CURLOPT_CONNECTTIMEOUT => 15,
        CURLOPT_TIMEOUT        => FLUX_AI_TIMEOUT,
        CURLOPT_HTTPHEADER     => array(
            'Content-Type: application/json',
            'Content-Length: ' . strlen($payload),
        ),
    ));
    $body = curl_exec($ch);
    $code = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    curl_close($ch);
    if ($code === 0 || $code >= 400 || !is_string($body) || $body === '') {
        return null;
    }
    $data = json_decode($body, true);
    $text = '';
    if (is_array($data) && isset($data['choices'][0]['message']['content'])) {
        $text = (string) $data['choices'][0]['message']['content'];
    }
    return $text !== '' ? $text : null;
}

/** حماية بسيطة: الرابط يجب أن يكون http/https ولا يشير لعناوين داخلية. */
function flux_ai_url_allowed()
{
    $p = parse_url((string) FLUX_AI_URL);
    if (!isset($p['scheme'], $p['host'])) {
        return false;
    }
    $scheme = strtolower($p['scheme']);
    if ($scheme !== 'http' && $scheme !== 'https') {
        return false;
    }
    $host = strtolower($p['host']);
    if ($host === 'localhost' || preg_match('/^(127|10|192\.168|169\.254|172\.(1[6-9]|2\d|3[01]))\./', $host)) {
        return false;
    }
    return true;
}

/** استخراج كائن JSON من نص الرد (يتسامح مع ```json أو نص زائد حوله). */
function flux_ai_extract_json($text)
{
    $text = trim((string) $text);
    // أزل أسوار كتلة الكود إن وجدت
    if (preg_match('~```(?:json)?\s*(.+?)```~s', $text, $m)) {
        $text = trim($m[1]);
    }
    $data = json_decode($text, true);
    if (is_array($data)) {
        return $data;
    }
    // جرّب أول { ... } متوازن في النص
    $start = strpos($text, '{');
    if ($start !== false) {
        $depth = 0;
        for ($i = $start, $n = strlen($text); $i < $n; $i++) {
            if ($text[$i] === '{') {
                $depth++;
            } elseif ($text[$i] === '}') {
                $depth--;
                if ($depth === 0) {
                    $data = json_decode(substr($text, $start, $i - $start + 1), true);
                    if (is_array($data)) {
                        return $data;
                    }
                    break;
                }
            }
        }
    }
    return null;
}

/**
 * التعبئة الذكية لبيانات لعبة:
 * يبني مطالبة بالحقول الناقصة فقط، ويعيد مصفوفة قيم جاهزة للنموذج.
 * $existing ما هو موجود بالفعل (يخبر النموذج ألا يغيّره إلا خطأً واضحًا).
 */
function flux_ai_fill_game($name, $existing = array(), &$error = null)
{
    $name = trim((string) $name);
    if ($name === '') {
        $error = 'اكتب اسم اللعبة أولًا ثم اضغط التعبئة الذكية';
        return null;
    }
    if (!flux_ai_url_allowed()) {
        $error = 'رابط FLUX_AI_URL في config.php غير صالح — يجب أن يكون http/https عام (مثل نقطة lara-php-api على استضافتك)';
        return null;
    }

    $have = array();
    $skip = array();
    foreach (array(
        'description'    => 'الوصف',
        'developer'      => 'المطور',
        'package_name'   => 'الباكج نيم',
        'rating'         => 'التقييم',
        'release_date'   => 'تاريخ الإصدار',
        'last_updated'   => 'تاريخ آخر تحديث',
        'download_version' => 'رقم الإصدار',
        'categories'     => 'التصنيفات',
    ) as $key => $label) {
        $val = isset($existing[$key]) ? $existing[$key] : '';
        if (is_array($val)) {
            $val = array_filter(array_map('trim', $val));
        }
        if (!empty($val)) {
            $have[] = $label . ': ' . (is_array($val) ? implode('، ', $val) : $val);
            $skip[] = $key;
        }
    }

    $system = 'أنت مساعد متخصص في ألعاب الفيديو داخل لوحة إدارة متجر ألعاب أندرويد اسمه FLUX GAMES. '
        . 'مهمتك: إكمال بيانات لعبة بصيغة JSON فقط بدون أي نص حولها. '
        . 'اكتب الوصف بالعربية الفصحى الواضحة بأسلوب متاجر الألعاب الرسمية (3-5 جمل غنية بالتفاصيل: القصة، أسلوب اللعب، أبرز الميزات). '
        . 'الباكج نيم بصيغة com.company.game المعروفة للعبة الأصلية (إن لم تكن معروفة استنتج الأقرب المنطقي). '
        . 'التقييم رقم من 0 إلى 5 بخانة عشرية واحدة. التواريخ بصيغة YYYY-MM-DD حقيقية قدر الإمكان. '
        . 'التصنيفات اختر من هذه القائمة حصرًا: action، adventure، rpg، racing، shooter، sports، strategy، sandbox — من 1 إلى 3 تصنيفات. '
        . 'أعد JSON بهذا الشكل حرفيًا: {"description":"...","developer":"...","package_name":"...","rating":4.5,"release_date":"YYYY-MM-DD","last_updated":"YYYY-MM-DD","download_version":"x.y.z","categories":["action"]}';
    if (!empty($have)) {
        $system .= ' هذه بيانات موجودة مسبقًا فلا تغيّرها إلا إذا كانت خاطئة بشكل واضح: ' . implode(' | ', $have);
    }

    $user = 'أكمل بيانات اللعبة: ' . $name . (!empty($existing['notes']) ? "\nملاحظات من المدير: " . (string) $existing['notes'] : '');

    $text = flux_ai_chat($system, $user);
    if ($text === null) {
        $error = 'الذكاء الاصطناعي غير متاح حاليًا — تأكد من رفع مجلد lara-php-api على /flux/ai/ ومن ضبط FLUX_AI_URL في config.php، أو عوّد المحاولة لاحقًا (المصدر المجاني قد يكون مشغولًا)';
        return null;
    }
    $data = flux_ai_extract_json($text);
    if ($data === null || !isset($data['description'])) {
        $error = 'رد الذكاء الاصطناعي غير مفهوم — جرّب مرة أخرى';
        return null;
    }

    // تنظيف وتطبيع القيم قبل إعادتها للنموذج
    $out = array();
    $out['description'] = trim((string) $data['description']);
    $out['developer'] = trim((string) (isset($data['developer']) ? $data['developer'] : ''));
    $pkg = trim((string) (isset($data['package_name']) ? $data['package_name'] : ''));
    if (!preg_match('~^[a-z][a-z0-9_]+(\.[a-z0-9_]+){1,}$~i', $pkg)) {
        $pkg = '';
    }
    $out['package_name'] = $pkg;
    $rating = (float) (isset($data['rating']) ? $data['rating'] : 0);
    $out['rating'] = ($rating > 0 && $rating <= 5) ? round($rating, 1) : null;
    foreach (array('release_date', 'last_updated') as $k) {
        $d = trim((string) (isset($data[$k]) ? $data[$k] : ''));
        $out[$k] = preg_match('~^\d{4}-\d{2}-\d{2}$~', $d) ? $d : null;
    }
    $ver = trim((string) (isset($data['download_version']) ? $data['download_version'] : ''));
    $out['download_version'] = preg_match('~^\d+(\.\d+){0,3}$~', $ver) ? $ver : null;
    $cats = array();
    if (isset($data['categories']) && is_array($data['categories'])) {
        foreach ($data['categories'] as $c) {
            $c = strtolower(trim((string) $c));
            if (array_key_exists($c, flux_categories())) {
                $cats[] = $c;
            }
        }
    }
    $out['categories'] = array_values(array_unique(array_slice($cats, 0, 3)));

    return $out;
}

// ============================================================================
// نقطة AJAX المستقلة — تعمل فقط عند فتح هذا الملف مباشرة
// ============================================================================
if (isset($_SERVER['SCRIPT_FILENAME']) && realpath($_SERVER['SCRIPT_FILENAME']) === realpath(__FILE__)) {
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');

    if (session_status() !== PHP_SESSION_ACTIVE) {
        session_start();
    }
    if (empty($_SESSION['flux_admin_ok'])) {
        http_response_code(401);
        echo json_encode(array('ok' => false, 'note' => 'غير مسجل — افتح admin.php وسجل الدخول أولًا'), JSON_UNESCAPED_UNICODE);
        exit;
    }

    $name = '';
    if (isset($_POST['name'])) {
        $name = (string) $_POST['name'];
    } elseif (isset($_GET['name'])) {
        $name = (string) $_GET['name'];
    }
    $existing = array();
    foreach (array('description', 'developer', 'package_name', 'download_version') as $k) {
        if (isset($_POST[$k])) {
            $existing[$k] = (string) $_POST[$k];
        }
    }
    if (isset($_POST['notes'])) {
        $existing['notes'] = (string) $_POST['notes'];
    }

    $error = null;
    $data = flux_ai_fill_game($name, $existing, $error);
    if ($data === null) {
        echo json_encode(array('ok' => false, 'note' => $error), JSON_UNESCAPED_UNICODE);
        exit;
    }
    echo json_encode(array('ok' => true, 'data' => $data), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
