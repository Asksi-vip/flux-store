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
