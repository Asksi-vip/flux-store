<?php
/**
 * مستخرج روابط التحميل المباشر — FLUX API
 *
 * الفكرة: تلصق رابط صفحة التحميل (ميديافاير، جوجل درايف، أو أي صفحة فيها
 * زر تحميل) والنظام يسحب منها رابط الملف المباشر + الاسم + الحجم —
 * حتى يبدأ تحميل المستخدم داخل التطبيق مباشرة من أول ضغطة على التحميل.
 *
 * الاستخدامان:
 *   1) كمكتبة من admin.php:  require_once resolve.php ثم flux_resolve_link($url)
 *   2) نقطة AJAX مستقلة:     POST resolve.php  (url=...) — تتطلب جلسة إدارة مسجلة
 *
 * المنطق:
 *   - الرابط المباشر أصلاً (ينتهي بامتداد ملف أو يجيب Content-Disposition) ← يمر كما هو.
 *   - ميديافاير ← زر التحميل download1234.mediafire.com من الصفحة.
 *   - جوجل درايف ← تحويل file/d/{id} إلى رابط usercontent مع توكن التأكيد.
 *   - صفحات عامة ← أول <a> فيه امتداد ملف أو خاصية download أو فئة تحميل،
 *     ثم meta refresh و location.href كقفزات إعادة توجيه (حتى 4 قفزات).
 *   - كل مرشح يُفحص برأس HTTP (HEAD ثم GET بمقطع 0-0) للتأكد أنه ملف فعلي
 *     ولقراءة الحجم واسم الملف من Content-Disposition.
 */

// إعدادات المتجر (تجلب FLUX_RESOLVE_ALLOW_LOCAL أيضًا)
require_once __DIR__ . '/config.php';

if (!defined('FLUX_RESOLVE_ALLOW_LOCAL')) {
    define('FLUX_RESOLVE_ALLOW_LOCAL', false); // للاختبار المحلي فقط — لا تفعّلها على الاستضافة
}

define('FLUX_RESOLVE_MAX_HOPS', 4);
define('FLUX_RESOLVE_TIMEOUT', 20);
define('FLUX_RESOLVE_PAGE_LIMIT', 3145728); // 3MB كحد أقصى لجلب نص الصفحة
define('FLUX_RESOLVE_UA', 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36');

/** امتدادات الملفات المقبولة كرابط مباشر. */
function flux_file_extensions()
{
    return 'apk|obb|xapk|apks|apkm|zip|rar|7z|ipa|exe|msi|dmg|tar|gz|bin|iso|cab|deb|data';
}

/** فحص أمان الرابط: http/https فقط وحجب العناوين الداخلية (حماية من SSRF). */
function flux_url_allowed($url)
{
    $p = parse_url((string) $url);
    if (!isset($p['scheme'], $p['host'])) {
        return false;
    }
    $scheme = strtolower($p['scheme']);
    if ($scheme !== 'http' && $scheme !== 'https') {
        return false;
    }
    if (FLUX_RESOLVE_ALLOW_LOCAL) {
        return true; // وضع الاختبار المحلي
    }
    $host = strtolower($p['host']);
    if ($host === 'localhost' || $host === '0.0.0.0' || $host === '::1' || substr($host, -5) === '.local' || substr($host, -9) === '.internal') {
        return false;
    }
    if (preg_match('/^(127|10|192\.168|169\.254|172\.(1[6-9]|2\d|3[01]))\./', $host)) {
        return false;
    }
    return true;
}

/** تنفيذ طلب HTTP وإرجاع الحالة + الترويسات + جزء من الجسم (أو null عند الفشل).
 *  $jarPath ملف كوكيز مشترك بين طلبات نفس العملية (ميديافاير/modsfire والصفحات المسجلة).
 *  $postFields إرسال POST متعدد الأجزاء عند تمرير مصفوفة.
 *  $referer ترويسة المُحيل (تحتاجها مواقع مثل modsfire لنقطة التنزيل النهائية).
 *  عند حجب كلاودفلير (403 Just a moment) نحاول عبر curl النظامي — بصمة مختلفة تعبر أحيانًا. */
function flux_http_fetch($url, $headersOnly = false, $withBody = true, $jarPath = null, $postFields = null, $extraHeaders = array(), $referer = '')
{
    if (!flux_url_allowed($url)) {
        return null;
    }
    $r = flux_http_fetch_curl($url, $headersOnly, $withBody, $jarPath, $postFields, $extraHeaders, $referer);
    $challenged = false;
    if ($r === null) {
        $challenged = true;
    } else {
        $st = (int) $r['status'];
        $body = (string) $r['body'];
        if ($st === 403 || $st === 503) {
            if (stripos($body, 'just a moment') !== false || stripos($body, 'challenge-platform') !== false || stripos($body, 'cf-browser-verification') !== false || stripos($body, 'cloudflare') !== false) {
                $challenged = true;
            }
        }
    }
    if ($challenged) {
        $r2 = flux_http_fetch_shell($url, $headersOnly, $jarPath, $postFields, $referer);
        if ($r2 !== null) {
            return $r2;
        }
    }
    return $r;
}

/** الجلب عبر cURL الداخلي (مع بديل التدفق عند غياب الإضافة). */
function flux_http_fetch_curl($url, $headersOnly = false, $withBody = true, $jarPath = null, $postFields = null, $extraHeaders = array(), $referer = '')
{
    $status = 0;
    $headers = array();
    $body = '';
    $finalUrl = $url;

    if (function_exists('curl_init')) {
        $ch = curl_init((string) $url);
        $bodyLen = 0;
        $opts = array(
            CURLOPT_RETURNTRANSFER   => true,
            CURLOPT_FOLLOWLOCATION   => true,
            CURLOPT_MAXREDIRS        => 5,
            CURLOPT_CONNECTTIMEOUT   => FLUX_RESOLVE_TIMEOUT,
            CURLOPT_TIMEOUT          => FLUX_RESOLVE_TIMEOUT,
            CURLOPT_SSL_VERIFYPEER   => true,
            CURLOPT_HEADERFUNCTION   => function ($ch, $line) use (&$headers) {
                $pos = strpos($line, ':');
                if ($pos !== false) {
                    $key = strtolower(trim(substr($line, 0, $pos)));
                    $val = trim(substr($line, $pos + 1));
                    if ($key !== '') {
                        $headers[$key] = $val;
                    }
                }
                return strlen($line);
            },
            // حد صارم على القراءة: نوقف النقل بعد حد الصفحة — لا ننزّل ملف 200MB للذاكرة
            CURLOPT_WRITEFUNCTION    => function ($ch, $data) use (&$body, &$bodyLen) {
                $body .= $data;
                $bodyLen += strlen($data);
                if ($bodyLen > FLUX_RESOLVE_PAGE_LIMIT) {
                    return -1; // إيقاف النقل — الترويسات والحالة تُقرأ بعد الإيقاف
                }
                return strlen($data);
            },
            CURLOPT_USERAGENT        => FLUX_RESOLVE_UA,
            CURLOPT_HTTPHEADER       => array_merge(array(
                'Accept: text/html,application/xhtml+xml,application/octet-stream,*/*',
                'Accept-Language: en-US,en;q=0.9,ar;q=0.8',
            ), $extraHeaders),
            CURLOPT_ENCODING         => '',
        );
        if ($referer !== '') {
            $opts[CURLOPT_REFERER] = $referer;
        }
        if ($jarPath !== null) {
            $opts[CURLOPT_COOKIEJAR] = $jarPath;
            $opts[CURLOPT_COOKIEFILE] = $jarPath;
        }
        if ($postFields !== null) {
            $opts[CURLOPT_POST] = true;
            $opts[CURLOPT_POSTFIELDS] = $postFields;
        }
        if ($headersOnly) {
            $opts[CURLOPT_NOBODY] = true;
        }
        curl_setopt_array($ch, $opts);
        curl_exec($ch);
        $status  = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
        $finalUrl = (string) curl_getinfo($ch, CURLINFO_EFFECTIVE_URL);
        curl_close($ch);
        if ($status === 0) {
            return null;
        }
        if (strlen($body) > FLUX_RESOLVE_PAGE_LIMIT) {
            $body = substr($body, 0, FLUX_RESOLVE_PAGE_LIMIT);
        }
        return array('status' => $status, 'headers' => $headers, 'body' => $body, 'final_url' => $finalUrl);
    }

    // بديل بلا cURL: file_get_contents مع سياق تدفق (تتبع إعادة التوجيه حتى 5)
    $ctxOpts = array(
        'http' => array(
            'method'        => $headersOnly ? 'HEAD' : 'GET',
            'follow_location' => 1,
            'max_redirects' => 5,
            'timeout'       => FLUX_RESOLVE_TIMEOUT,
            'user_agent'    => FLUX_RESOLVE_UA,
            'ignore_errors' => true,
        ),
        'ssl' => array('verify_peer' => true),
    );
    if ($referer !== '') {
        $ctxOpts['http']['header'] = 'Referer: ' . $referer . "\r\n";
    }
    if ($postFields !== null && is_array($postFields)) {
        $ctxOpts['http']['method'] = 'POST';
        $ctxOpts['http']['header'] .= "Content-Type: multipart/form-data\r\n";
        $ctxOpts['http']['content'] = http_build_query($postFields);
    }
    $ctx = stream_context_create($ctxOpts);
    $fh = @fopen((string) $url, 'rb', false, $ctx);
    if ($fh === false) {
        return null;
    }
    $meta  = stream_get_meta_data($fh);
    $finalUrl = '';
    foreach ((array) (isset($meta['wrapper_data']) ? $meta['wrapper_data'] : array()) as $h) {
        if (stripos($h, 'HTTP/') === 0) {
            $parts = explode(' ', $h);
            $status = (int) (isset($parts[1]) ? $parts[1] : 0);
            continue;
        }
        $pos = strpos($h, ':');
        if ($pos !== false) {
            $headers[strtolower(trim(substr($h, 0, $pos)))] = trim(substr($h, $pos + 1));
        }
        if (stripos($h, 'location:') === 0) {
            $finalUrl = trim(substr($h, 9));
        }
    }
    if ($withBody && !$headersOnly) {
        $body = (string) stream_get_contents($fh, FLUX_RESOLVE_PAGE_LIMIT);
    }
    fclose($fh);
    if ($status === 0) {
        return null;
    }
    return array('status' => $status, 'headers' => $headers, 'body' => $body, 'final_url' => $finalUrl !== '' ? $finalUrl : $url);
}

/** الجلب عبر curl النظامي (exec) — بصمة TLS مختلفة تعبر حجب كلاودفلير أحيانًا.
 *  يعيد بنفس بنية flux_http_fetch_curl أو null عند الفشل/عدم توفر exec. */
function flux_http_fetch_shell($url, $headersOnly = false, $jarPath = null, $postFields = null, $referer = '')
{
    $disabled = array_map('trim', explode(',', (string) ini_get('disable_functions')));
    if (in_array('exec', $disabled, true)) {
        return null;
    }
    $jar = ($jarPath !== null && $jarPath !== '') ? $jarPath : tempnam(sys_get_temp_dir(), 'fluxshell_');
    $bodyFile = tempnam(sys_get_temp_dir(), 'fluxbody_');
    $hdrFile = tempnam(sys_get_temp_dir(), 'fluxhdr_');
    $cmd = 'curl -s -L --compressed -m ' . (int) FLUX_RESOLVE_TIMEOUT
        . ' -A ' . escapeshellarg(FLUX_RESOLVE_UA)
        . ' -H ' . escapeshellarg('Accept: text/html,application/xhtml+xml,application/octet-stream,*/*')
        . ' -H ' . escapeshellarg('Accept-Language: en-US,en;q=0.9,ar;q=0.8')
        . ' -b ' . escapeshellarg($jar) . ' -c ' . escapeshellarg($jar)
        . ($referer !== '' ? ' -e ' . escapeshellarg($referer) : '')
        . ' -D ' . escapeshellarg($hdrFile)
        . ' --max-filesize ' . (int) FLUX_RESOLVE_PAGE_LIMIT
        . ($headersOnly ? ' -I' : '')
        . ' --output ' . escapeshellarg($bodyFile);
    if ($postFields !== null && is_array($postFields)) {
        foreach ($postFields as $k => $v) {
            $cmd .= ' -F ' . escapeshellarg($k . '=' . (string) $v);
        }
    }
    $cmd .= ' ' . escapeshellarg((string) $url) . ' 2>/dev/null';
    exec($cmd, $out, $code);
    $body = ($headersOnly || $code !== 0) ? '' : (string) @file_get_contents($bodyFile);
    @unlink($bodyFile);
    $rawHeaders = (string) @file_get_contents($hdrFile);
    @unlink($hdrFile);
    // أكواد الإيقاف المتوقعة مقبولة: 63 = تجاوز حد الحجم، 23 = إيقاف كتابة، 18 = نقل جزئي
    $acceptable = array(0, 18, 23, 63);
    if ($rawHeaders === '' || (!in_array($code, $acceptable, true) && $body === '')) {
        return null;
    }
    // آخر كتلة ترويسات = استجابة الوجهة النهائية بعد إعادة التوجيه
    $blocks = preg_split('~\r?\n\r?\n~', trim($rawHeaders));
    $last = (string) end($blocks);
    $status = 0;
    $headers = array();
    foreach (preg_split('~\r?\n~', $last) as $line) {
        if (preg_match('~^HTTP/\S+\s+(\d+)~i', $line, $m)) {
            $status = (int) $m[1];
            $headers = array();
            continue;
        }
        $pos = strpos($line, ':');
        if ($pos !== false) {
            $headers[strtolower(trim(substr($line, 0, $pos)))] = trim(substr($line, $pos + 1));
        }
    }
    // الرابط النهائي من آخر location إن وجد
    $finalUrl = $url;
    if (preg_match_all('~^location:\s*(\S+)~mi', $rawHeaders, $lm)) {
        $lastLoc = (string) end($lm[1]);
        if ($lastLoc !== '') {
            $abs = flux_absolute_url($url, $lastLoc);
            if ($abs !== '') {
                $finalUrl = $abs;
            }
        }
    }
    if ($status === 0) {
        return null;
    }
    return array('status' => $status, 'headers' => $headers, 'body' => $body, 'final_url' => $finalUrl);
}

/** قراءة الحجم الكلي من ترويسة Content-Range (استجابة مقطع 0-0). */
function flux_size_from_content_range($value)
{
    if (preg_match('~bytes\s+\d+-\d+/(\d+)~i', (string) $value, $m)) {
        return (int) $m[1];
    }
    return 0;
}

/** هل نوع المحتوى يشير إلى ملف حقيقي (لا صفحة HTML)؟ */
function flux_ctype_is_file($ctype, $disposition)
{
    $ctype = strtolower(trim((string) $ctype));
    $disposition = strtolower((string) $disposition);
    if (strpos($disposition, 'attachment') !== false) {
        return true;
    }
    if ($ctype === '') {
        return false;
    }
    $pageTypes = 'text/html|application/xhtml|application/json|application/javascript|text/javascript|text/plain|application/xml|text/xml|image/svg';
    foreach (explode('|', $pageTypes) as $bad) {
        if (strpos($ctype, $bad) === 0) {
            return false;
        }
    }
    return true;
}

/** فحص رابط: هل هو ملف مباشر فعلي؟ يعيد معلومات الحجم والاسم والنوع.
 *  $jarPath/$referer تمرر جلسة الموقع والمُحيل (modsfire وغيرها ترفض بدونها). */
function flux_probe_url($url, $jarPath = null, $referer = '')
{
    $r = flux_http_fetch($url, true, false, $jarPath, null, array(), $referer);
    $size = 0;
    $ctype = '';
    $disposition = '';
    $final = $url;
    if ($r !== null) {
        $size = (int) (isset($r['headers']['content-length']) ? $r['headers']['content-length'] : 0);
        if ($size === 0 && isset($r['headers']['content-range'])) {
            $size = flux_size_from_content_range($r['headers']['content-range']);
        }
        $ctype = isset($r['headers']['content-type']) ? $r['headers']['content-type'] : '';
        $disposition = isset($r['headers']['content-disposition']) ? $r['headers']['content-disposition'] : '';
        $final = $r['final_url'];
    }
    if ($size === 0 || !flux_ctype_is_file($ctype, $disposition)) {
        // بعض الخوادم ترفض HEAD أو ترسل ترويسات ناقصة — GET بمقطع 0-0 يعطي الحجم الكلي
        $r2 = flux_http_fetch($url, false, true, $jarPath, null, array('Range: bytes=0-0'), $referer);
        if ($r2 !== null) {
            $b2 = is_array($r2['headers']) ? $r2['headers'] : array();
            $s2 = (int) (isset($b2['content-length']) ? $b2['content-length'] : 0);
            if ($s2 === 0 && isset($b2['content-range'])) {
                $s2 = flux_size_from_content_range($b2['content-range']);
            }
            $ct2 = isset($b2['content-type']) ? $b2['content-type'] : '';
            $cd2 = isset($b2['content-disposition']) ? $b2['content-disposition'] : '';
            if ($s2 > $size || ($ctype !== '' && $ct2 !== '' && flux_ctype_is_file($ct2, $cd2) && !flux_ctype_is_file($ctype, $disposition))) {
                $size = $s2 > 0 ? $s2 : $size;
                $ctype = $ct2 !== '' ? $ct2 : $ctype;
                $disposition = $cd2 !== '' ? $cd2 : $disposition;
                $final = $r2['final_url'];
            }
            if ($r === null) {
                $r = $r2;
            }
        }
    }
    $isFile = $r !== null && flux_ctype_is_file($ctype, $disposition);
    // امتداد معروف + ليس صفحة HTML = ملف حتى لو الترويسة غريبة
    if (!$isFile && $r !== null && preg_match('~\.(' . flux_file_extensions() . ')(?:[?#]|$)~i', parse_url((string) $final, PHP_URL_PATH) ?: '')) {
        $isFile = true;
    }
    if (!$isFile) {
        return null;
    }
    return array(
        'url'         => $final,
        'status'      => $r['status'],
        'size'        => $size,
        'content_type' => $ctype,
        'disposition' => $disposition,
    );
}

/** تحويل رابط نسبي إلى مطلق وفق رابط الصفحة ووسم base إن وجد. */
function flux_absolute_url($baseUrl, $rel)
{
    $rel = trim(html_entity_decode((string) $rel, ENT_QUOTES, 'UTF-8'));
    if ($rel === '' || preg_match('~^\s*(javascript|data|mailto|tel):~i', $rel)) {
        return '';
    }
    if (preg_match('~^https?://~i', $rel)) {
        return $rel;
    }
    if ($rel === '#') {
        return '';
    }
    $baseParts = parse_url((string) $baseUrl);
    if (!isset($baseParts['scheme'], $baseParts['host'])) {
        return '';
    }
    $port = isset($baseParts['port']) ? ':' . $baseParts['port'] : '';
    $scheme = $baseParts['scheme'] . '://' . $baseParts['host'] . $port;
    if (substr($rel, 0, 2) === '//') {
        return $baseParts['scheme'] . ':' . $rel;
    }
    if (substr($rel, 0, 1) === '/') {
        return $scheme . $rel;
    }
    // مسار نسبي: نبني من مجلد الصفحة
    $path = isset($baseParts['path']) ? $baseParts['path'] : '/';
    $dir  = substr($path, 0, strrpos($path, '/') + 1);
    if ($dir === '') {
        $dir = '/';
    }
    return $scheme . $dir . $rel;
}

/** هل ينتهي مسار الرابط بامتداد ملف معروف؟ */
function flux_is_file_url($url)
{
    $path = (string) (parse_url((string) $url, PHP_URL_PATH) ?: '');
    return (bool) preg_match('~\.(' . flux_file_extensions() . ')$~i', $path);
}

/** استخراج اسم الملف من ترويسة Content-Disposition (يدعم filename*=UTF-8). */
function flux_name_from_disposition($disposition)
{
    $disposition = (string) $disposition;
    if (preg_match('~filename\*=(?:UTF-8|utf-8)\'\'([^;]+)~', $disposition, $m)) {
        $name = rawurldecode(trim($m[1], " \t\"'"));
        if ($name !== '') {
            return $name;
        }
    }
    if (preg_match('~filename="?([^";]+)"?~i', $disposition, $m)) {
        $name = trim(html_entity_decode($m[1], ENT_QUOTES, 'UTF-8'), " \t\"'");
        if ($name !== '') {
            return $name;
        }
    }
    return '';
}

/** استخراج اسم الملف من رابط (آخر جزء من المسار بعد فك الترميز). */
function flux_name_from_url($url)
{
    $path = (string) (parse_url((string) $url, PHP_URL_PATH) ?: '');
    $name = basename(str_replace('\\', '/', $path));
    $name = rawurldecode($name);
    if ($name === '' || $name === '/' || strpos($name, '.') === false) {
        return '';
    }
    return $name;
}

/** حجم مقترح من نص صفحة ميديافاير مثل Download (25.65MB). */
function flux_size_from_button_text($html)
{
    if (preg_match('~Download\s*\(\s*([\d.]+)\s*(KB|MB|GB)\s*\)~i', (string) $html, $m)) {
        $v = (float) $m[1];
        $unit = strtoupper($m[2]);
        if ($unit === 'KB') {
            return (int) round($v * 1024);
        }
        if ($unit === 'GB') {
            return (int) round($v * 1024 * 1024 * 1024);
        }
        return (int) round($v * 1024 * 1024);
    }
    return 0;
}

/** تنسيق الحجم للعرض. */
function flux_size_text($bytes)
{
    $bytes = (int) $bytes;
    if ($bytes <= 0) {
        return '';
    }
    $units = array('B', 'KB', 'MB', 'GB');
    $v = (float) $bytes;
    $i = 0;
    while ($v >= 1024 && $i < count($units) - 1) {
        $v /= 1024;
        $i++;
    }
    return ($i === 0 || $v >= 100 ? round($v) : round($v, 1)) . ' ' . $units[$i];
}

/** مرشّحات جوجل درايف: تحويل روابط الصفحات إلى رابط تحميل مباشر مع توكن التأكيد. */
function flux_drive_candidates($url)
{
    $url = (string) $url;
    $id = '';
    if (preg_match('~drive\.google\.com/(?:file/d/|uc\?(?:[^#]*&)?id=|open\?(?:[^#]*&)?id=)([A-Za-z0-9_-]{10,})~i', $url, $m)) {
        $id = $m[1];
    }
    if ($id === '') {
        return array();
    }
    // محاولة مباشرة أولًا: ملفات صغيرة تجيب attachment فورًا
    $cands = array('https://drive.google.com/uc?export=download&id=' . $id);
    // صفحة التأكيد للملفات الكبيرة: نستخرج حقول الفورم من رابط uc
    $r = flux_http_fetch($cands[0], false, true);
    if ($r !== null && strpos(strtolower((string) $r['headers']['content-type']), 'text/html') !== false) {
        $html = $r['body'];
        if (preg_match('~action="?(https://drive\.usercontent\.google\.com/download[^"\']*)"?~i', $html, $fm)) {
            $action = html_entity_decode($fm[1], ENT_QUOTES, 'UTF-8');
            $params = array();
            if (preg_match_all('~<input[^>]+name="(id|export|confirm|uuid)"[^>]+value="([^"]*)"~i', $html, $im, PREG_SET_ORDER)) {
                foreach ($im as $inp) {
                    $params[$inp[1]] = html_entity_decode($inp[2], ENT_QUOTES, 'UTF-8');
                }
            }
            $params += array('id' => $id, 'export' => 'download', 'confirm' => 't');
            $action = preg_replace('~\?.*$~', '', $action);
            $cands = array($action . '?' . http_build_query($params));
        }
    }
    return $cands;
}

/** تحويلات مواقع معروفة رابطها المباشر ثابت الصيغة (بلا HTML).
 *  تعيد قائمة مرشحات تُفحص قبل فتح الصفحة، أو مصفوفة فارغة. */
function flux_host_candidates($url)
{
    $url = (string) $url;
    $host = strtolower((string) (parse_url($url, PHP_URL_HOST) ?: ''));
    $out = array();

    // pixeldrain: صفحة /u/<id> ← واجهة API المباشرة
    if (strpos($host, 'pixeldrain.com') !== false && preg_match('~/u/([A-Za-z0-9]+)~', $url, $m)) {
        $out[] = 'https://pixeldrain.com/api/file/' . $m[1] . '?download';
        return $out;
    }
    // دروببوكس: أي رابط ← رابط تنزيل مباشر
    if (strpos($host, 'dropbox.com') !== false) {
        $u = preg_replace('~([?&])dl=0~', '$1dl=1', $url);
        if (strpos($u, 'dl=1') === false) {
            $u .= (strpos($u, '?') === false ? '?' : '&') . 'dl=1';
        }
        $out[] = $u;
        return $out;
    }
    // OneDrive / واجهات مايكروسوفت
    if (strpos($host, '1drv.ms') !== false || strpos($host, 'onedrive.live.com') !== false || strpos($host, 'sharepoint.com') !== false) {
        $out[] = $url . (strpos($url, '?') === false ? '?' : '&') . 'download=1';
        return $out;
    }
    return $out;
}

/** هل الرابط المباشر موقّع/مؤقت الصلاحية؟ (modsfire R2 وغيرها) —
 *  يقرر نظام التحديث التلقائي مدى قِدم الرابط المقبولة قبل إعادة الاستخراج. */
function flux_url_is_signed($url)
{
    return (bool) preg_match('~X-Amz-(Signature|Expires)|Signature=|Expires=|token=|sig=~i', (string) parse_url((string) $url, PHP_URL_QUERY) ?: '');
}

/** استخراج كل مرشحات التحميل المباشر من نص صفحة HTML بترتيب الأولوية. */
function flux_extract_candidates($html, $baseUrl)
{
    $html = (string) $html;
    $cands = array();
    $seen = array();
    $push = function ($u) use (&$cands, &$seen) {
        $u = trim((string) $u);
        if ($u === '' || isset($seen[$u])) {
            return;
        }
        $seen[$u] = true;
        $cands[] = $u;
    };

    // 1) ميديافاير: رابط الزر المباشر download1234.mediafire.com
    if (preg_match_all('~https?://download\d+\.mediafire\.com/[^\s"\'<>]+~i', $html, $mm)) {
        foreach ($mm[0] as $u) {
            $push(rtrim($u, " \t\r\n\"'"));
        }
    }
    // زر التحميل بالمعرف (قد يكون نطاقًا آخر)
    if (preg_match_all('~<a[^>]+id=["\']downloadButton["\'][^>]+href=["\']([^"\']+)["\']~i', $html, $bm)) {
        foreach ($bm[1] as $u) {
            $u2 = flux_absolute_url($baseUrl, $u);
            if ($u2 !== '') {
                $push($u2);
            }
        }
    }

    // 2) كل الارتساء: أولوية الامتداد ثم خاصية download ثم الفئات
    if (preg_match_all('~<a\b([^>]*)>~is', $html, $am)) {
        $withExt = array();
        $withDl  = array();
        $withCls = array();
        foreach ($am[1] as $attrs) {
            if (!preg_match('~href=["\']([^"\']+)["\']~i', $attrs, $hm)) {
                continue;
            }
            $href = html_entity_decode($hm[1], ENT_QUOTES, 'UTF-8');
            if (preg_match('~^\s*(javascript|data|mailto|tel|#)~i', $href)) {
                continue;
            }
            $abs = flux_absolute_url($baseUrl, $href);
            if ($abs === '') {
                continue;
            }
            if (preg_match('~\.(' . flux_file_extensions() . ')(?:[?#]|$)~i', (string) (parse_url($abs, PHP_URL_PATH) ?: ''))) {
                $withExt[] = $abs;
            } elseif (preg_match('~\bdownload\b~i', $attrs)) {
                $withDl[] = $abs;
            } elseif (preg_match('~(?:class|id|rel|title)=["\'][^"\']*(?:download|dl)[^"\']*["\']~i', $attrs)) {
                $withCls[] = $abs;
            }
        }
        foreach ($withExt as $u) {
            $push($u);
        }
        foreach ($withDl as $u) {
            $push($u);
        }
        foreach ($withCls as $u) {
            $push($u);
        }
    }

    // 3) روابط ملفات مقتبسة داخل السكربتات/JSON (downloadUrl أو غيرها)
    if (preg_match_all('~["\']https?://[^"\']+\.(?:' . flux_file_extensions() . ')(?:\?[^"\']*)?["\']~i', $html, $qm)) {
        foreach ($qm[0] as $u) {
            $push(trim($u, "\"'"));
        }
    }

    // 4) إعادة التوجيه: meta refresh ثم JS location
    $redirects = array();
    if (preg_match('~<meta[^>]+http-equiv=["\']?refresh["\']?[^>]+content=["\']?[^"\'<>]*url=([^"\'>]+)~i', $html, $rm)) {
        $redirects[] = flux_absolute_url($baseUrl, html_entity_decode($rm[1], ENT_QUOTES, 'UTF-8'));
    }
    foreach (array(
        '~location\.replace\(\s*["\']([^"\']+)["\']~i',
        '~(?:window\.)?location(?:\.href)?\s*=\s*["\']([^"\']+)["\']~i',
    ) as $pat) {
        if (preg_match($pat, $html, $jm)) {
            $redirects[] = flux_absolute_url($baseUrl, $jm[1]);
            break;
        }
    }
    foreach ($redirects as $u) {
        if ($u !== '') {
            $push($u);
        }
    }

    return $cands;
}

/**
 * المحرك الرئيسي: حل أي رابط (صفحة أو مباشر) إلى رابط ملف مباشر مع الاسم والحجم.
 * يعيد مصفوفة: ok, direct_url, file_name, size, size_text, content_type, source, note, trail.
 */
function flux_resolve_link($url, $depth = 0, &$trail = array(), $jarPath = null, $referer = '')
{
    $url = trim((string) $url);
    $trail[] = $url;
    if ($url === '') {
        return array('ok' => false, 'note' => 'أدخل رابطًا أولًا', 'trail' => $trail);
    }
    if (!flux_url_allowed($url)) {
        return array('ok' => false, 'note' => 'الرابط غير صالح — يُقبل http/https فقط (بدون عناوين داخلية)', 'trail' => $trail);
    }
    if ($depth > FLUX_RESOLVE_MAX_HOPS) {
        return array('ok' => false, 'note' => 'تعذّر الوصول للملف — سلسلة إعادة توجيه طويلة جدًا', 'trail' => $trail);
    }
    // ملف كوكيز مشترك لكل طلبات نفس الرابط (جلسة ميديافاير/modsfire مثلاً)
    if ($jarPath === null) {
        $jarPath = tempnam(sys_get_temp_dir(), 'fluxjar');
    }

    $isDrive = stripos($url, 'drive.google.com') !== false;
    $host = strtolower((string) (parse_url($url, PHP_URL_HOST) ?: ''));
    $isMediafire = strpos($host, 'mediafire.com') !== false;

    // 0) مواقع برابط مباشر ثابت الصيغة (pixeldrain / dropbox / onedrive)
    foreach (flux_host_candidates($url) as $cand) {
        $probe = flux_probe_url($cand, $jarPath, $url);
        if ($probe !== null) {
            return flux_resolve_result($probe, 'رابط مباشر (تحويل)', $trail, $url);
        }
    }

    // 1) جوجل درايف له معالجة خاصة
    if ($isDrive) {
        foreach (flux_drive_candidates($url) as $cand) {
            $probe = flux_probe_url($cand, $jarPath, $url);
            if ($probe !== null) {
                return flux_resolve_result($probe, 'جوجل درايف', $trail, $url);
            }
        }
        return array('ok' => false, 'note' => 'تعذّر استخراج الملف من درايف — تأكد أن الرابط ملف عام (المشاركة: أي شخص لديه الرابط)', 'trail' => $trail);
    }

    // 2) الرابط نفسه مباشر؟ (امتداد ملف)
    if (flux_is_file_url($url)) {
        $probe = flux_probe_url($url, $jarPath, $referer);
        if ($probe !== null) {
            return flux_resolve_result($probe, 'رابط مباشر', $trail, $url);
        }
    }

    // 3) جلب الصفحة واستخراج المرشحات (مع المُحيل والكوكيز)
    $page = flux_http_fetch($url, false, true, $jarPath, null, array(), $referer);
    if ($page === null) {
        return array('ok' => false, 'note' => 'تعذّر فتح الصفحة — تحقق من الرابط أو من توفر الإنترنت للخادم', 'trail' => $trail);
    }
    $ctype = strtolower((string) (isset($page['headers']['content-type']) ? $page['headers']['content-type'] : ''));
    $finalUrl = $page['final_url'];
    $pageStatus = (int) $page['status'];

    // الصفحة نفسها طلعت ملفًا مباشرًا بعد إعادة التوجيه
    if (flux_ctype_is_file($ctype, isset($page['headers']['content-disposition']) ? $page['headers']['content-disposition'] : '')) {
        $probe = array(
            'url'          => $finalUrl,
            'status'       => $pageStatus,
            'size'         => (int) (isset($page['headers']['content-length']) ? $page['headers']['content-length'] : 0),
            'content_type' => $ctype,
            'disposition'  => isset($page['headers']['content-disposition']) ? $page['headers']['content-disposition'] : '',
        );
        if ($probe['size'] === 0 && isset($page['headers']['content-range'])) {
            $probe['size'] = flux_size_from_content_range($page['headers']['content-range']);
        }
        return flux_resolve_result($probe, 'رابط مباشر', $trail, $url);
    }

    $html = $page['body'];

    // محجوب بكلاودفلير حتى بعد الاحتياطي؟ رسالة واضحة
    if ($pageStatus === 403 || $pageStatus === 503) {
        return array('ok' => false, 'note' => 'الموقع محمي بحماية كلاودفلير ورفض الوصول من الخادم — جرّب رابط آخر أو ارفع الملف على استضافة مباشرة', 'trail' => $trail);
    }

    // ميديافاير معمّم؟ (تحذير أمني من ميديافاير نفسها — لا رابط مباشر فيها)
    if ($isMediafire && (stripos($html, 'malware_advisory') !== false || stripos($html, 'download_repair.php') !== false) && stripos($html, 'downloadButton') === false) {
        return array('ok' => false, 'note' => 'ميديافاير عمّمت هذا الملف (تحذير أمني) — لا يوجد رابط مباشر لها. ارفع نسخة نظيفة من الملف على ميديافاير أو استضافة مباشرة', 'trail' => $trail);
    }

    // 4) تدفق التحميل المؤجل الحديث (ميديافاير الجديدة وأي صفحة بنفس النمط):
    //    زر يحمل JWT → POST على نقطة download_link.php داخل الصفحة → JSON بالرابط
    $res = flux_deferred_download($html, $finalUrl, $jarPath, $trail);
    if ($res !== null) {
        return $res;
    }

    $candidates = flux_extract_candidates($html, $finalUrl);
    if ($isMediafire) {
        // ميديافاير أولًا ثم البقية
        usort($candidates, function ($a, $b) {
            $am = stripos($a, 'mediafire.com') !== false ? 0 : 1;
            $bm = stripos($b, 'mediafire.com') !== false ? 0 : 1;
            return $am - $bm;
        });
    }

    foreach ($candidates as $cand) {
        // مرشح صفحة إعادة توجيه؟ (بدون امتداد ملف) → قفزة أخرى بمُحيل الصفحة الحالية
        if (!flux_is_file_url($cand) && $depth < FLUX_RESOLVE_MAX_HOPS) {
            $isRedirectish = stripos($cand, 'mediafire.com') === false && stripos($cand, 'drive.google.com') === false;
            if ($isRedirectish) {
                $sub = flux_resolve_link($cand, $depth + 1, $trail, $jarPath, $finalUrl);
                if (!empty($sub['ok'])) {
                    $sub['source'] = $sub['source'] === 'رابط مباشر' ? 'صفحة (إعادة توجيه)' : $sub['source'];
                    $sub['source_url'] = $url;
                    return $sub;
                }
                continue;
            }
        }
        $probe = flux_probe_url($cand, $jarPath, $finalUrl);
        if ($probe !== null) {
            $res = flux_resolve_result($probe, $isMediafire ? 'ميديافاير' : 'صفحة (عام)', $trail, $url);
            if ($isMediafire && $res['size'] === 0) {
                $res['size'] = flux_size_from_button_text($html);
                $res['size_text'] = flux_size_text($res['size']);
            }
            return $res;
        }
    }

    return array(
        'ok'   => false,
        'note' => 'لم نجد رابط تحميل مباشر في الصفحة — جرّب رابط الصفحة نفسه (مثل رابط ميديافاير /file/ أو رابط modsfire) أو ارفع الملف على استضافة مباشرة',
        'trail' => $trail,
    );
}

/**
 * تدفق التحميل المؤجل (ميديافاير الجديدة): JWT من زر الصفحة
 * → POST على نقطة download_link.php المستخرجة من سكربت الصفحة → JSON.
 * يعيد نتيجة نهائية عند النجاح، أو null لنكمل بطرق الاستخراج الأخرى.
 * يعالج استجابة delay بإعادة المحاولة (حتى 3 مرات حسب retry_after).
 */
function flux_deferred_download($html, $pageUrl, $jarPath, &$trail)
{
    // 1) التوكن JWT الكامل من زر التحميل المؤجل (ثلاثة أجزاء بنقاط وطول معقول)
    $token = '';
    if (preg_match_all('~data-security-token=["\']([^"\']+)["\']~i', (string) $html, $tm)) {
        foreach ($tm[1] as $t) {
            if (substr_count($t, '.') >= 2 && strlen($t) > 80) {
                $token = $t;
                break;
            }
        }
    }
    if ($token === '') {
        return null;
    }

    // 2) نقطة الاستقبال: من سكربت الصفحة (download_link.php) أو مسار ميديافاير المعروف
    $endpoint = '';
    if (preg_match('~["\']((?:https?://[^"\']+)?/?download_link\.php)["\']~i', (string) $html, $em)) {
        $endpoint = flux_absolute_url($pageUrl, $em[1]);
    }
    if ($endpoint === '') {
        $p = parse_url((string) $pageUrl);
        if (isset($p['scheme'], $p['host'])) {
            $port = isset($p['port']) ? ':' . $p['port'] : '';
            $endpoint = $p['scheme'] . '://' . $p['host'] . $port . '/download_link.php';
        }
    }
    if ($endpoint === '' || !flux_url_allowed($endpoint)) {
        return null;
    }

    // 3) POST مع كوكيز الجلسة + معالجة delay بإعادة المحاولة
    for ($attempt = 0; $attempt < 3; $attempt++) {
        $r = flux_http_fetch(
            $endpoint,
            false,
            true,
            $jarPath,
            array('security_token' => $token),
            array('X-Requested-With: XMLHttpRequest', 'Referer: ' . $pageUrl)
        );
        if ($r === null) {
            return null;
        }
        $data = json_decode($r['body'], true);
        if (!is_array($data)) {
            return null;
        }
        $result = isset($data['result']) ? $data['result'] : '';
        $status = isset($data['status']) ? $data['status'] : '';
        if ($result === 'success' && $status === 'success' && !empty($data['download_url'])) {
            $dl = (string) $data['download_url'];
            $trail[] = $dl;
            $probe = flux_probe_url($dl, $jarPath, $pageUrl);
            if ($probe === null) {
                // رابط الـ API يعتبر صالحًا حتى لو فشل الفحص (بعض الخوادم ترفض HEAD)
                $isMf = stripos($pageUrl, 'mediafire.com') !== false;
                return array(
                    'ok'          => true,
                    'direct_url'  => $dl,
                    'file_name'   => flux_name_from_url($dl),
                    'size'        => 0,
                    'size_text'   => '',
                    'content_type' => '',
                    'source'      => $isMf ? 'ميديافاير' : 'صفحة (تحميل مؤجل)',
                    'source_url'  => $pageUrl,
                    'note'        => '',
                    'trail'       => $trail,
                );
            }
            return flux_resolve_result($probe, stripos($pageUrl, 'mediafire.com') !== false ? 'ميديافاير' : 'صفحة (تحميل مؤجل)', $trail, $pageUrl);
        }
        if ($result === 'success' && $status === 'delay') {
            $wait = (int) (isset($data['retry_after']) ? $data['retry_after'] : 2);
            sleep(max(1, min($wait, 5)));
            continue;
        }
        return null; // خطأ — نكمل بطرق أخرى
    }
    return null;
}

/** بناء نتيجة نهائية من فحص ناجح. */
function flux_resolve_result(array $probe, $source, $trail, $sourceUrl)
{
    $name = flux_name_from_disposition($probe['disposition']);
    if ($name === '') {
        $name = flux_name_from_url($probe['url']);
    }
    return array(
        'ok'          => true,
        'direct_url'  => $probe['url'],
        'file_name'   => $name,
        'size'        => (int) $probe['size'],
        'size_text'   => flux_size_text($probe['size']),
        'content_type' => $probe['content_type'],
        'source'      => $source,
        'source_url'  => $sourceUrl,
        'note'        => '',
        'trail'       => $trail,
    );
}

// ============================================================================
// نقطة AJAX المستقلة — تعمل فقط عندما يُفتح هذا الملف مباشرة من المتصفح
// (عند تضمينه من admin.php يبقى كوصيفة دوال فقط)
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

    $url = '';
    if (isset($_POST['url'])) {
        $url = (string) $_POST['url'];
    } elseif (isset($_GET['url'])) {
        $url = (string) $_GET['url'];
    }

    $trail = array();
    $result = flux_resolve_link($url, 0, $trail);
    echo json_encode($result, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
