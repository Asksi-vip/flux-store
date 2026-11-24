<?php
/**
 * إعدادات API متجر Flux — PHP
 *
 * ارفع محتويات هذا المجلد إلى مجلد flux/api داخل public_html على استضافتك
 * (مثال serv00: /home/<user>/domains/<user>.serv00.net/public_html/flux/api/)
 *
 * لا يحتاج MySQL — يستخدم SQLite يُنشأ تلقائيًا مع أول طلب.
 */

// ⚠️ كلمة مرور لوحة الإدارة admin.php — غيّرها فورًا بعد الرفع!
define('FLUX_ADMIN_PASSWORD', 'flux-admin-2026');

// مسار ملف قاعدة البيانات SQLite (يُنشأ تلقائيًا داخل مجلد data/)
define('FLUX_DB_PATH', __DIR__ . '/data/flux_store.db');

// مستخرج الرابط المباشر (resolve.php): اتركه false على الاستضافة —
// يمنع الخادم من فتح عناوين داخلية/محلية. فعّله true فقط للاختبار المحلي.
define('FLUX_RESOLVE_ALLOW_LOCAL', false);

// الذكاء الاصطناعي للتعبئة التلقائية (ai.php):
// ارفع مجلد lara-php-api إلى public_html/flux/ai/ على الاستضافة نفسها
// ثم يكفي هذا الرابط كما هو — نقطة محادثة متوافقة مع OpenAI بدون مفتاح.
define('FLUX_AI_URL', 'http://camillecyrm.serv00.net/flux/ai/v1/chat/completions');
define('FLUX_AI_MODEL', 'gpt-4o'); // اسم مستعار يوجهه الوكيل لأفضل نموذج مجاني

// ================= نظام المصادقة الذاتي (بديل Firebase) — auth.php =================
// بوابة إرسال رموز التحقق OTP. القيم الممكنة:
//   debug   ← بلا إرسال فعلي: الرمز يظهر داخل التطبيق مباشرة (مجاني — للتجربة)
//   generic ← أي بوابة SMS بعنوان قالب (أغلب المزودين العراقيين والعالميين)
//   twilio  ← Twilio (بطاقة مطلوبة)
//   semysms ← تطبيق Semysms: يرسل من هاتف أندرويد خاص بك (شبه مجاني)
define('FLUX_SMS_DRIVER', 'debug');

// إعدادات generic: عنوان فيه {phone} و {message} + ترويسات اختيارية (مفتاح API)
// مثال مزود عراقي: 'https://api.provider.iq/api/SendSMS?api_key=XXX&number={phone}&msg={message}'
define('FLUX_SMS_URL', 'https://example.com/api/sms?key=KEY&to={phone}&text={message}');
define('FLUX_SMS_HEADERS', '[]'); // مثل: '{"Authorization": "Bearer XXX"}'

// إعدادات twilio
define('FLUX_TWILIO_SID', '');
define('FLUX_TWILIO_AUTH_TOKEN', '');
define('FLUX_TWILIO_FROM', '');

// إعدادات semysms (ثبت تطبيق Semysms على هاتفك بشراء رصيد جهاز)
define('FLUX_SEMYSMS_DEVICE_ID', '');
define('FLUX_SEMYSMS_API_TOKEN', '');
