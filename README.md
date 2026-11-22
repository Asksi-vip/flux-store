# 🎮 Flux — متجر الألعاب بأسلوب Epic Games

متجر ألعاب كامل باسم **Flux** بتصميم مستوحى من **Epic Games Store** (الخلفية الداكنة، الأزرق الرسمي، شارات الخصومات، البانرات السينمائية)، مكوّن من جزأين متصلين:

| الجزء | التقنية | المسار |
|---|---|---|
| 📱 تطبيق Android | **Flutter (Dart) أصلي** — الكود كامل في `/app/lib` | `/app` |
| ⚙️ Backend API | **PHP 7.4+ / 8 + SQLite** (بلا قواعد بيانات خارجية) | `/php-api` |

> ملاحظة: التطبيق **ليس HTML** — كود Flutter/Dart أصلي (24 ملفًا في `app/lib/`) يبنيه GitHub Actions إلى APK عبر SDK الرسمي في السحابة.

[![Build Flux APK](https://github.com/Asksi-vip/flux-store/actions/workflows/build-apk.yml/badge.svg)](https://github.com/Asksi-vip/flux-store/actions/workflows/build-apk.yml)

## 📲 تحميل APK جاهز (بدون تثبيت Flutter)

يوجد سير عمل GitHub Actions (`.github/workflows/build-apk.yml`) يبني نسخة الإطلاق تلقائيًا عند كل تحديث، وينشر الملف في صفحة Releases:

- **أحدث APK:** https://github.com/Asksi-vip/flux-store/releases/latest/download/flux-store.apk
- **صفحة Releases:** https://github.com/Asksi-vip/flux-store/releases
- يمكن أيضًا تحميله من تبويب **Actions ← Build Flux APK ← Artifacts**

التثبيت على أندرويد 7+: نزّل `flux-store.apk` وثبّته مباشرة (اسمح بخيار "مصادر غير معروفة" إن طُلب). لا تحتاج Flutter SDK على جهازك إطلاقًا — السحابة تبنيه لك، ويمكنك تشغيل البناء يدويًا من زر **Run workflow** في تبويب Actions.

## 🎨 هوية التصميم (Epic Games)

| اللون | القيمة | الاستخدام |
|---|---|---|
| خلفية Epic الداكنة | `#101014` | خلفية التطبيق |
| سطح داكن | `#18181C` | البطاقات والأشرطة |
| سطح مرفوع | `#202024` | الحقول والعناصر التفاعلية |
| حدود رمادية | `#2A2A2A` | الحدود والفواصل الرقيقة |
| أزرق Epic الرسمي | `#0074E4` | الأزرار الأساسية وشارات الخصم `-X%` |
| سماوي Epic | `#26BBFF` | الروابط والألعاب المجانية والتقييم |
| رمادي النص الثانوي | `#B8B8C1` | الأوصاف والنصوص الجانبية |

الزاوية الموحدة للبطاقات: 4px حادة (نفس أسلوب Epic)، بلا توهجات أو تدرجات نيون.

## 📱 ميزات التطبيق (بمؤثرات Epic)

- **شاشة Splash**: شعار FLUX متوهج (توهج أزرق مزدوج) مع دخول Scale + Fade وشريط تحميل منزلق
- **البانر السينمائي** (HeroCarousel): شرائح تتبدل تلقائيًا كل 5 ثوانٍ بانتقال easeInOutCubic + صف صور مصغرة بتحكم يدوي وإطار أزرق للشريحة المختارة
- **عروض وخصومات**: شارات `-X%` الزرقاء المربعة + السعر الأصلي مشطوب + "وفّر X$" — بأسلوب Epic بالضبط
- **بطاقات الألعاب**: غلاف حاد 3:4 مع مؤثر ضغط (تصغير 0.97 عند اللمس) ودخول متدرج (Stagger)
- **Skeleton/Shimmer**: هياكل تحميل نابضة تحاكي شكل المحتوى قبل وصول البيانات
- **انتقال صفحات**: Fade + انزلاق خفيف بين كل الشاشات (PageRouteBuilder مخصص)
- **التفاصيل**: بانر عريض متدرج، وصف قابل للتوسيع (AnimatedCrossFade)، زر إضافة يتحول بحركة AnimatedSwitcher مع SnackBar زر تراجع، ومقترحات من نفس الفئة
- **المكتبة**: صفوف Epic مع سحب للحذف + SnackBar "تراجع" + إجمالي قيمة المكتبة
- **البحث**: مؤجل (Debounce) + فلاتر فئات وسعر بشرائح متحولة اللون
- **الحساب**: إحصائيات حقيقية من المكتبة + نقطة حالة الخادم النابضة المتحولة اللون
- **تنقل سفلي مخصص**: مؤشر أزرق متحرك + تكبير الأيقونة المختارة
- **سحب لتحديث** + حالات فارغة + رسائل أخطاء شبكة عربية واضحة

## 🐘 الـ API بلغة PHP (للاستضافة العادية مثل serv00)

الـ API مبني بـ PHP خالص + SQLite — لا يحتاج MySQL ولا Python ولا أي إعداد معقد.

### الرفع على الاستضافة (serv00)

1. ارفع **محتويات** مجلد `php-api/` إلى: `domains/<اسمك>.serv00.net/public_html/flux/api/`
   (عبر FTP أو SFTP أو مدير الملفات في لوحة serv00)
2. تأكد أن إصدار PHP من لوحة serv00 هو **7.4 أو أحدث** (الافتراضي مناسب)
3. افتح رابط الـ API في المتصفح — قاعدة البيانات تُنشأ وتُملأ **تلقائيًا** بأول طلب:
   - الـ API: `http://camillecyrm.serv00.net/flux/api/games/`
   - لوحة الإدارة: `http://camillecyrm.serv00.net/flux/api/admin.php`
4. ⚠️ غيّر كلمة مرور لوحة الإدارة من `php-api/config.php` (`FLUX_ADMIN_PASSWORD`)

إن ظهرت رسالة عن قاعدة البيانات: فعّل `pdo_sqlite` من إعدادات PHP في لوحة الاستضافة، أو أعط مجلد `data/` صلاحية كتابة (755/775).

### التشغيل المحلي (للتجربة)

```bash
cd php-api
php -S localhost:8000
# ثم: http://localhost:8000/games/  و  http://localhost:8000/admin.php
```

على محاكي Android استخدم `http://10.0.2.2:8000` في `app/lib/config.dart`.

## 🔌 نقاط النهاية (Endpoints)

الأساس: `http://camillecyrm.serv00.net/flux/api`

| المسار | الوصف |
|---|---|
| `GET /games/` | قائمة الألعاب (تقسيم صفحات: `{count, next, previous, results}`) |
| `GET /games/{id}/` | تفاصيل لعبة |
| `GET /games/?search=cyber` | بحث بالاسم أو الوصف |
| `GET /games/?category=rpg` | فلترة حسب التصنيف |
| `GET /games/?min_price=10&max_price=50` | فلترة حسب السعر |
| `GET /games/?featured=true` | الألعاب المميزة فقط |
| `GET /games/?ordering=-rating` | ترتيب (price / rating / name / release_date، مع `-` للعكس) |
| `GET /games/?page=2&page_size=5` | تقسيم صفحات مخصص (حتى 50) |
| `GET /games/featured/` | الألعاب المميزة (يستخدمها البانر السينمائي) |

مثال لعبة من الاستجابة:

```json
{
  "id": 1,
  "name": "Cyberpunk 2077",
  "description": "...",
  "price": 59.99,
  "discount_price": 29.99,
  "final_price": 29.99,
  "has_discount": true,
  "category": "rpg",
  "category_display": "لعب أدوار (RPG)",
  "rating": 4.6,
  "image": "https://cdn.cloudflare.steamstatic.com/steam/apps/1091500/library_600x900.jpg",
  "banner": "https://cdn.cloudflare.steamstatic.com/steam/apps/1091500/library_hero.jpg",
  "release_date": "2020-12-10",
  "is_featured": true
}
```

## 📱 تشغيل تطبيق Flutter

المتطلبات: Flutter SDK 3.10+ (Dart 3)

```bash
cd app

# 1) توليد مجلدات الأندرويد (أول مرة فقط)
flutter create . --platforms android --org com.fluxstore

# 2) الاعتماديات
flutter pub get

# 3) التشغيل على محاكي أو جهاز
flutter run
```

### 🔗 ربط التطبيق بالـ API

العنوان مضبوط في ملف واحد: `app/lib/config.dart`

- **الإنتاج (الافتراضي):** `http://camillecyrm.serv00.net/flux/api` — يعمل على أي جهاز فورًا
- **خادم محلي على المحاكي:** `http://10.0.2.2:8000` (مع `php -S localhost:8000` داخل php-api)
- **جهاز حقيقي مع خادم محلي:** ضع IP الكمبيوتر مثل `http://192.168.1.10:8000`
  (اعرفه بـ `ipconfig` على ويندوز أو `ifconfig`/`ip a` على لينكس)

### 🔨 أوامر بناء APK

```bash
cd app

# نسخة الإصدار (مضغوطة ومهيأة للنشر)
flutter build apk --release

# الناتج هنا:
# build/app/outputs/flutter-apk/app-release.apk

# للتثبيت المباشر على جهاز متصل:
flutter install

# نسخة تجريبية أسرع بناءً (للاختبار فقط):
flutter build apk --debug
```

## 🛠 لوحة إدارة PHP (admin.php)

- العنوان: `http://camillecyrm.serv00.net/flux/api/admin.php` — محمية بكلمة مرور من `config.php`
- إدارة كاملة: **إضافة/تعديل/حذف** الألعاب، تحديد السعر وسعر الخصم والتصنيف والتقييم والتمييز
- الصور برابط مباشر (مثال: روابط Steam CDN) مع معاينة مصغرة في الجدول وشارات الخصم والمجاني
- التنسيق بنفس هوية Epic الداكنة ومتوافق مع الجوال

## 🗂 البيانات التجريبية

تلقائية بالكامل: أول طلب على الـ API ينشئ قاعدة SQLite ويملأها بـ **14 لعبة مشهورة بصور حقيقية** من Steam CDN: Cyberpunk 2077، Elden Ring، RDR2، GTA V، The Witcher 3، Dota 2، Counter-Strike 2، Forza Horizon 5، It Takes Two، Hades، Stardew Valley، Hollow Knight، EA FC 24، Baldur's Gate 3 — بأسعار وخصومات تجريبية.

لإعادة التعبئة من الصفر: احذف ملف `php-api/data/flux_store.db` وأعد تحميل أي صفحة.

## 🧱 بنية المشروع

```
flux-store/
├── php-api/                    # الـ API بلغة PHP (ارفع محتوياته إلى flux/api على الاستضافة)
│   ├── index.php               # الراوتر: /games/ و /games/{id}/ و /games/featured/ + الفلاتر
│   ├── db.php                  # SQLite + إنشاء الجدول + تعبئة تلقائية + دوال مساعدة
│   ├── config.php              # كلمة مرور الإدارة ومسار قاعدة البيانات
│   ├── admin.php               # لوحة إدارة الألعاب (إضافة/تعديل/حذف)
│   ├── data/.htaccess          # حماية ملف قاعدة البيانات من التحميل المباشر
│   └── .htaccess               # توجيه المسارات النظيفة إلى index.php
└── app/                        # Flutter (Dart أصلي)
    ├── lib/
    │   ├── main.dart           # نقطة البداية (RTL عربي + ثيم Epic)
    │   ├── config.dart         # عنوان الخادم (افتراضيًا: serv00)
    │   ├── theme/app_theme.dart# ألوان Epic (#101014 / #0074E4) وثيم كامل
    │   ├── models/game.dart
    │   ├── services/           # dio API + SharedPreferences
    │   ├── controllers/        # مدير المكتبة (ChangeNotifier)
    │   ├── widgets/            # زر Epic، بطاقة، بانر سينمائي، شارات خصم، سكلتون، انتقالات
    │   └── screens/            # splash، رئيسية، تفاصيل، بحث، مكتبة، حساب، shell
    └── pubspec.yaml
```

## ⚠️ ملاحظات للإنتاج

- غيّر `FLUX_ADMIN_PASSWORD` في `php-api/config.php` فورًا بعد الرفع
- ملف قاعدة البيانات `data/flux_store.db` محمي عبر `.htaccess` — لا تحذفه إن أردت حفظ بياناتك
- إن أردت HTTPS فعّل الشهادة المجانية من لوحة serv00 ثم بدّل العنوان في `config.dart` إلى `https://`
- للانتقال لقاعدة بيانات MySQL لاحقًا: بدّل اتصال PDO في `db.php` فقط — كل ما عدا ذلك لا يتغير
