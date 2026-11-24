<?php
/**
 * نظام المصادقة الذاتي — بديل Firebase كليًا (بلا أي خدمة خارجية).
 *
 * يعمل على نفس قاعدة SQLite ويقدم:
 *   - إنشاء حساب برقم الهاتف + رمز تحقق OTP + كلمة مرور
 *   - تسجيل دخول بكلمة المرور أو برمز OTP مباشر (يُنشئ حسابًا تلقائيًا لرقم جديد)
 *   - إعادة تعيين كلمة المرور عبر OTP
 *   - جلساتBearer token لمدة 30 يومًا
 *
 * إرسال الرمز عبر بوابة SMS محددة في config.php (FLUX_SMS_DRIVER):
 *   debug   ← بلا إرسال فعلي: الرمز يعود بالاستجابة (dev_code) للتجربة المجانية
 *   generic ← أي بوابة HTTP بعنوان قالب {phone}/{message} (تناسب أغلب مزودي SMS العراقيين)
 *   twilio  ← Twilio REST API
 *   semysms ← تطبيق Semysms (إرسال من أندرويد خاص بك)
 *
 * نقاط النهاية (POST، الحقول JSON أو form):
 *   ?action=otp_request     {phone, purpose: register|login|reset}
 *   ?action=register        {name, phone, password, session, code}
 *   ?action=login           {phone, password}
 *   ?action=otp_login       {phone, session, code}
 *   ?action=reset_password  {phone, session, code, new_password}
 *   ?action=change_password (Bearer token) {new_password}
 *   ?action=me              (Bearer token)
 */

require_once __DIR__ . '/db.php';

// ---------- الثوابت ----------
define('FLUX_OTP_TTL', 300);          // صلاحية الرمز: 5 دقائق
define('FLUX_OTP_RESEND', 60);        // فترة الانتظار بين إرسال وآخر: دقيقة
define('FLUX_OTP_DAILY_LIMIT', 8);    // أقصى رموز يوميًا لرقم واحد
define('FLUX_OTP_MAX_ATTEMPTS', 5);   // أقصى محاولات خاطئة لكل رمز
define('FLUX_TOKEN_TTL', 2592000);    // صلاحية الجلسة: 30 يومًا

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

/** إنشاء جداول المصادقة عند أول استخدام (آمنة للاستدعاء المتكرر). */
function flux_auth_ensure_tables(PDO $pdo)
{
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS flux_users (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            name          TEXT NOT NULL DEFAULT 'لاعب FLUX',
            phone         TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL DEFAULT '',
            created_at    TEXT NOT NULL DEFAULT (datetime('now'))
        )
    ");
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS flux_otps (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            phone      TEXT NOT NULL,
            purpose    TEXT NOT NULL DEFAULT 'register',
            code_hash  TEXT NOT NULL,
            session    TEXT NOT NULL UNIQUE,
            attempts   INTEGER NOT NULL DEFAULT 0,
            expires_at INTEGER NOT NULL,
            used_at    INTEGER,
            created_at INTEGER NOT NULL
        )
    ");
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS flux_tokens (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id    INTEGER NOT NULL,
            token      TEXT NOT NULL UNIQUE,
            expires_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        )
    ");
    $pdo->exec('CREATE INDEX IF NOT EXISTS idx_otps_phone ON flux_otps (phone, created_at)');
}

/** توحيد رقم الهاتف — مطابق تمامًا لمنطق التطبيق (E.164 مثل +9647701234567). */
function flux_auth_normalize_phone($phone, $cc = '+964')
{
    $clean = preg_replace('/[\s\-\(\)]/', '', trim((string) $phone));
    if ($clean === '' || $clean === null) {
        return '';
    }
    if ($clean[0] === '+') {
        return $clean;
    }
    if (strpos($clean, '00') === 0) {
        return '+' . substr($clean, 2);
    }
    if ($clean[0] === '0') {
        $clean = substr($clean, 1);
    }
    $cc = (strpos($cc, '+') === 0) ? $cc : '+' . $cc;
    return $cc . $clean;
}

/** قراءة جسم الطلب: JSON أو form. */
function flux_auth_body()
{
    $raw = file_get_contents('php://input');
    $j = json_decode((string) $raw, true);
    if (is_array($j)) {
        return $j;
    }
    return $_POST;
}

/** قراءة Bearer token من ترويسة Authorization. */
function flux_auth_bearer()
{
    $h = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if ($h === '' && function_exists('apache_request_headers')) {
        $all = apache_request_headers();
        $h = isset($all['Authorization']) ? $all['Authorization'] : '';
    }
    if (preg_match('/Bearer\s+(\S+)/i', (string) $h, $m)) {
        return $m[1];
    }
    return '';
}

/** إرسال الرمز عبر بوابة SMS المفعلة — يعيد true عند النجاح. */
function flux_sms_send($phone, $message)
{
    $driver = strtolower(trim(FLUX_SMS_DRIVER));
    try {
        if ($driver === 'twilio') {
            $ch = curl_init('https://api.twilio.com/2010-04-01/Accounts/' . FLUX_TWILIO_SID . '/Messages.json');
            curl_setopt_array($ch, array(
                CURLOPT_POST           => true,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_TIMEOUT        => 15,
                CURLOPT_USERPWD        => FLUX_TWILIO_SID . ':' . FLUX_TWILIO_AUTH_TOKEN,
                CURLOPT_POSTFIELDS     => http_build_query(array(
                    'To'   => $phone,
                    'From' => FLUX_TWILIO_FROM,
                    'Body' => $message,
                )),
            ));
            $res = curl_exec($ch);
            $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            return $code >= 200 && $code < 300 && $res !== false;
        }

        if ($driver === 'semysms') {
            $ch = curl_init('https://semysms.net/api/3/sms.php');
            curl_setopt_array($ch, array(
                CURLOPT_POST           => true,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_TIMEOUT        => 15,
                CURLOPT_POSTFIELDS     => http_build_query(array(
                    'device' => FLUX_SEMYSMS_DEVICE_ID,
                    'token'  => FLUX_SEMYSMS_API_TOKEN,
                    'phone'  => $phone,
                    'msg'    => $message,
                )),
            ));
            $res = curl_exec($ch);
            $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            return $code >= 200 && $code < 300 && $res !== false;
        }

        if ($driver === 'generic') {
            // عنوان قالب + (اختياري) ترويسات ومتن قالب — يغطي أغلب البوابات العراقية والعالمية
            $url  = str_replace(array('{phone}', '{message}'), array(rawurlencode($phone), rawurlencode($message)), FLUX_SMS_URL);
            $ch = curl_init($url);
            $opts = array(
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_TIMEOUT        => 15,
            );
            $headers = json_decode(FLUX_SMS_HEADERS, true);
            if (is_array($headers) && !empty($headers)) {
                $opts[CURLOPT_HTTPHEADER] = $headers;
            }
            curl_setopt_array($ch, $opts);
            $res = curl_exec($ch);
            $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            return $code >= 200 && $code < 300 && $res !== false;
        }

        // debug أو أي قيمة غير معروفة: بلا إرسال فعلي (الرمز يعود كـ dev_code)
        return true;
    } catch (\Throwable $e) {
        return false;
    }
}

/** إنشاء رمز OTP لغرض معين مع الحدود اليومية وفترة الإعادة — يعيد صف الاستجابة. */
function flux_auth_request_otp(PDO $pdo, $phone, $purpose, $body)
{
    $cc = trim((string) (isset($body['country_code']) ? $body['country_code'] : '+964'));
    $phone = flux_auth_normalize_phone($phone, $cc !== '' ? $cc : '+964');
    if (!preg_match('/^\+\d{8,15}$/', $phone)) {
        flux_json(array('ok' => false, 'error' => 'رقم الهاتف غير صالح، يرجى كتابة الرقم بالصيغة الصحيحة.'), 400);
    }
    if (!in_array($purpose, array('register', 'login', 'reset'), true)) {
        flux_json(array('ok' => false, 'error' => 'غرض الطلب غير معروف.'), 400);
    }

    $now = time();

    // حد الإرسال اليومي
    $startOfDay = strtotime('today', $now);
    $del = $pdo->prepare('SELECT COUNT(*) FROM flux_otps WHERE phone = :p AND created_at >= :s');
    $del->execute(array(':p' => $phone, ':s' => $startOfDay));
    if ((int) $del->fetchColumn() >= FLUX_OTP_DAILY_LIMIT) {
        flux_json(array('ok' => false, 'error' => 'تم تجاوز عدد الرموز المسموح بها اليوم لهذا الرقم، حاول غدًا أو تواصل مع الدعم.'), 429);
    }

    // فترة الانتظار بين الإرسالين
    $last = $pdo->prepare('SELECT MAX(created_at) FROM flux_otps WHERE phone = :p');
    $last->execute(array(':p' => $phone));
    $lastAt = (int) $last->fetchColumn();
    $wait = FLUX_OTP_RESEND - ($now - $lastAt);
    if ($lastAt > 0 && $wait > 0) {
        flux_json(array(
            'ok'           => false,
            'error'        => 'يرجى الانتظار ' . $wait . ' ثانية قبل طلب رمز جديد.',
            'resend_after' => $wait,
        ), 429);
    }

    $code    = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    $session = bin2hex(random_bytes(16));

    $pdo->prepare("
        INSERT INTO flux_otps (phone, purpose, code_hash, session, attempts, expires_at, created_at)
        VALUES (:p, :pu, :ch, :s, 0, :e, :n)
    ")->execute(array(
        ':p'  => $phone,
        ':pu' => $purpose,
        ':ch' => password_hash($code, PASSWORD_DEFAULT),
        ':s'  => $session,
        ':e'  => $now + FLUX_OTP_TTL,
        ':n'  => $now,
    ));

    $out = array(
        'ok'           => true,
        'session'      => $session,
        'expires_in'   => FLUX_OTP_TTL,
        'resend_after' => FLUX_OTP_RESEND,
    );

    $sent = flux_sms_send($phone, 'رمز التحقق FLUX GAMES: ' . $code . ' — صالح لمدة 5 دقائق، لا تشاركه مع أحد.');
    if (!$sent) {
        flux_json(array('ok' => false, 'error' => 'تعذر إرسال الرمز عبر بوابة الرسائل حاليًا، حاول بعد قليل.'), 502);
    }

    // وضع التجربة (بلا بوابة): الرمز يعود بالاستجابة ليظهر داخل التطبيق مجانًا
    if (strtolower(trim(FLUX_SMS_DRIVER)) === 'debug') {
        $out['dev_code'] = $code;
    }

    return $out;
}

/** التحقق من رمز OTP (الجلسة + الكود) — يعيد الرقم عند النجاح أو يوقف الطلب برسالة.
 *  الغرض (register/login/reset) يُستخدم للحد اليومي فقط — ما يهم أمنيًا هو إثبات ملكية الرقم. */
function flux_auth_verify_otp(PDO $pdo, $phone, $session, $code)
{
    $cc = '+964';
    $phone = flux_auth_normalize_phone($phone, $cc);
    $session = trim((string) $session);
    $code = trim((string) $code);

    if ($session === '' || $code === '') {
        flux_json(array('ok' => false, 'error' => 'بيانات التحقق ناقصة.'), 400);
    }

    $stmt = $pdo->prepare('SELECT * FROM flux_otps WHERE session = :s LIMIT 1');
    $stmt->execute(array(':s' => $session));
    $otp = $stmt->fetch();

    if (!$otp || $otp['phone'] !== $phone) {
        flux_json(array('ok' => false, 'error' => 'جلسة التحقق غير صالحة، يرجى طلب رمز جديد.'), 400);
    }
    if ($otp['used_at'] !== null) {
        flux_json(array('ok' => false, 'error' => 'تم استخدام هذا الرمز سابقًا، يرجى طلب رمز جديد.'), 400);
    }
    if ((int) $otp['expires_at'] < time()) {
        flux_json(array('ok' => false, 'error' => 'انتهت صلاحية رمز التحقق، يرجى طلب رمز جديد.'), 400);
    }
    if ((int) $otp['attempts'] >= FLUX_OTP_MAX_ATTEMPTS) {
        flux_json(array('ok' => false, 'error' => 'محاولات كثيرة خاطئة، يرجى طلب رمز جديد.'), 429);
    }

    if (!password_verify($code, $otp['code_hash'])) {
        $pdo->prepare('UPDATE flux_otps SET attempts = attempts + 1 WHERE id = :i')
            ->execute(array(':i' => (int) $otp['id']));
        $left = FLUX_OTP_MAX_ATTEMPTS - ((int) $otp['attempts'] + 1);
        flux_json(array('ok' => false, 'error' => 'رمز التحقق غير صحيح' . ($left > 0 ? ' (بقيت ' . $left . ' محاولات)' : '، يرجى طلب رمز جديد') . '.'), 400);
    }

    // استهلاك الرمز بعد أول نجاح
    $pdo->prepare('UPDATE flux_otps SET used_at = :n WHERE id = :i')
        ->execute(array(':i' => (int) $otp['id'], ':n' => time()));

    return $phone;
}

/** إنشاء/تجديد جلسة المستخدم (Bearer token). */
function flux_auth_issue_token(PDO $pdo, $userId)
{
    $token = bin2hex(random_bytes(24));
    $pdo->prepare('INSERT INTO flux_tokens (user_id, token, expires_at, created_at) VALUES (:u, :t, :e, :n)')
        ->execute(array(
            ':u' => (int) $userId,
            ':t' => $token,
            ':e' => time() + FLUX_TOKEN_TTL,
            ':n' => time(),
        ));
    return $token;
}

/** جلب المستخدم من Bearer token أو إيقاف الطلب برسالة. */
function flux_auth_user_from_token(PDO $pdo, $token)
{
    $token = trim((string) $token);
    if ($token === '') {
        flux_json(array('ok' => false, 'error' => 'الجلسة غير موجودة، يرجى تسجيل الدخول.'), 401);
    }
    $stmt = $pdo->prepare("
        SELECT u.* FROM flux_tokens t JOIN flux_users u ON u.id = t.user_id
        WHERE t.token = :t AND t.expires_at > :n LIMIT 1
    ");
    $stmt->execute(array(':t' => $token, ':n' => time()));
    $user = $stmt->fetch();
    if (!$user) {
        flux_json(array('ok' => false, 'error' => 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول من جديد.'), 401);
    }
    return $user;
}

/** شكل المستخدم في الاستجابات (بلا أي بيانات حساسة). */
function flux_auth_user_public(array $u)
{
    return array(
        'uid'        => 'flux_' . $u['id'],
        'id'         => (int) $u['id'],
        'name'       => $u['name'],
        'phone'      => $u['phone'],
        'created_at' => $u['created_at'],
    );
}

// ---------- التنفيذ ----------

$pdo = flux_db();
flux_auth_ensure_tables($pdo);
$body   = flux_auth_body();
$action = trim((string) ($_GET['action'] ?? ($body['action'] ?? '')));

switch ($action) {

    // طلب رمز OTP (تسجيل / دخول / استعادة)
    case 'otp_request':
        $out = flux_auth_request_otp($pdo, isset($body['phone']) ? $body['phone'] : '', isset($body['purpose']) ? $body['purpose'] : 'register', $body);
        flux_json($out);

    // إنشاء حساب جديد بعد التحقق من الرمز
    case 'register':
        $phone = flux_auth_verify_otp($pdo, isset($body['phone']) ? $body['phone'] : '', isset($body['session']) ? $body['session'] : '', isset($body['code']) ? $body['code'] : '');
        $name  = trim((string) (isset($body['name']) ? $body['name'] : ''));
        $pwd   = (string) (isset($body['password']) ? $body['password'] : '');
        if ($name === '') {
            flux_json(array('ok' => false, 'error' => 'اسم اللاعب مطلوب.'), 400);
        }
        if (strlen($pwd) < 6) {
            flux_json(array('ok' => false, 'error' => 'يجب أن تتكون كلمة المرور من 6 خانات على الأقل.'), 400);
        }
        $exists = $pdo->prepare('SELECT id FROM flux_users WHERE phone = :p LIMIT 1');
        $exists->execute(array(':p' => $phone));
        if ($exists->fetchColumn() !== false) {
            flux_json(array('ok' => false, 'error' => 'يوجد حساب مسجل بهذا الرقم، استخدم تسجيل الدخول.'), 409);
        }
        $pdo->prepare('INSERT INTO flux_users (name, phone, password_hash) VALUES (:n, :p, :h)')
            ->execute(array(':n' => $name, ':p' => $phone, ':h' => password_hash($pwd, PASSWORD_DEFAULT)));
        $id = (int) $pdo->lastInsertId();
        $user = $pdo->prepare('SELECT * FROM flux_users WHERE id = :i');
        $user->execute(array(':i' => $id));
        $u = $user->fetch();
        flux_json(array('ok' => true, 'user' => flux_auth_user_public($u), 'token' => flux_auth_issue_token($pdo, $id)));

    // تسجيل الدخول برقم الهاتف وكلمة المرور
    case 'login':
        $phone = flux_auth_normalize_phone(isset($body['phone']) ? $body['phone'] : '', '+964');
        $pwd   = (string) (isset($body['password']) ? $body['password'] : '');
        $stmt  = $pdo->prepare('SELECT * FROM flux_users WHERE phone = :p LIMIT 1');
        $stmt->execute(array(':p' => $phone));
        $u = $stmt->fetch();
        if (!$u || $u['password_hash'] === '' || !password_verify($pwd, $u['password_hash'])) {
            flux_json(array('ok' => false, 'error' => 'لا يوجد حساب مسجل بهذا الرقم، أو كلمة المرور غير صحيحة.'), 401);
        }
        flux_json(array('ok' => true, 'user' => flux_auth_user_public($u), 'token' => flux_auth_issue_token($pdo, (int) $u['id'])));

    // تسجيل الدخول السريع برمز OTP — ينشئ حسابًا تلقائيًا لرقم جديد
    case 'otp_login':
        $phone = flux_auth_verify_otp($pdo, isset($body['phone']) ? $body['phone'] : '', isset($body['session']) ? $body['session'] : '', isset($body['code']) ? $body['code'] : '');
        $stmt = $pdo->prepare('SELECT * FROM flux_users WHERE phone = :p LIMIT 1');
        $stmt->execute(array(':p' => $phone));
        $u = $stmt->fetch();
        if (!$u) {
            $pdo->prepare("INSERT INTO flux_users (name, phone, password_hash) VALUES ('لاعب FLUX', :p, '')")
                ->execute(array(':p' => $phone));
            $stmt->execute(array(':p' => $phone));
            $u = $stmt->fetch();
        }
        flux_json(array('ok' => true, 'user' => flux_auth_user_public($u), 'token' => flux_auth_issue_token($pdo, (int) $u['id'])));

    // إعادة تعيين كلمة المرور بعد التحقق من الرمز
    case 'reset_password':
        $phone = flux_auth_verify_otp($pdo, isset($body['phone']) ? $body['phone'] : '', isset($body['session']) ? $body['session'] : '', isset($body['code']) ? $body['code'] : '');
        $pwd   = (string) (isset($body['new_password']) ? $body['new_password'] : '');
        if (strlen($pwd) < 6) {
            flux_json(array('ok' => false, 'error' => 'يجب أن تتكون كلمة المرور الجديدة من 6 خانات على الأقل.'), 400);
        }
        $stmt = $pdo->prepare('SELECT * FROM flux_users WHERE phone = :p LIMIT 1');
        $stmt->execute(array(':p' => $phone));
        $u = $stmt->fetch();
        if (!$u) {
            flux_json(array('ok' => false, 'error' => 'لا يوجد حساب مسجل بهذا الرقم.'), 404);
        }
        $pdo->prepare('UPDATE flux_users SET password_hash = :h WHERE id = :i')
            ->execute(array(':h' => password_hash($pwd, PASSWORD_DEFAULT), ':i' => (int) $u['id']));
        // إبطال كل الجلسات القديمة بعد تغيير كلمة المرور
        $pdo->prepare('DELETE FROM flux_tokens WHERE user_id = :i')->execute(array(':i' => (int) $u['id']));
        flux_json(array('ok' => true, 'user' => flux_auth_user_public($u), 'token' => flux_auth_issue_token($pdo, (int) $u['id'])));

    // تغيير كلمة المرور للمستخدم المسجل (من صفحة الملف الشخصي)
    case 'change_password':
        $u   = flux_auth_user_from_token($pdo, flux_auth_bearer());
        $pwd = (string) (isset($body['new_password']) ? $body['new_password'] : '');
        if (strlen($pwd) < 6) {
            flux_json(array('ok' => false, 'error' => 'يجب أن تتكون كلمة المرور من 6 خانات على الأقل.'), 400);
        }
        $pdo->prepare('UPDATE flux_users SET password_hash = :h WHERE id = :i')
            ->execute(array(':h' => password_hash($pwd, PASSWORD_DEFAULT), ':i' => (int) $u['id']));
        flux_json(array('ok' => true));

    // التحقق من الجلسة عند إعادة فتح التطبيق
    case 'me':
        $u = flux_auth_user_from_token($pdo, flux_auth_bearer());
        flux_json(array('ok' => true, 'user' => flux_auth_user_public($u)));

    default:
        flux_json(array('ok' => false, 'error' => 'نقطة النهاية غير معروفة.'), 404);
}
