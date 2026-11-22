# 🎮 Flux — متجر الألعاب بأسلوب Epic Games

متجر ألعاب كامل باسم **Flux** بتصميم مستوحى من **Epic Games Store** (الخلفية الداكنة، الأزرق الرسمي، شارات الخصومات، البانرات السينمائية)، مكوّن من جزأين متصلين:

| الجزء | التقنية | المسار |
|---|---|---|
| 📱 تطبيق Android | **Flutter (Dart) أصلي** — الكود كامل في `/app/lib` | `/app` |
| ⚙️ Backend API | Python + Django + Django REST Framework | `/api` |

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

## ⚙️ تشغيل الـ API (Django)

المتطلبات: Python 3.10+

```bash
cd api

# 1) بيئة افتراضية
python -m venv .venv
source .venv/bin/activate        # ويندوز: .venv\Scripts\activate

# 2) الاعتماديات
pip install -r requirements.txt

# 3) قاعدة البيانات + البيانات التجريبية (10 ألعاب)
python manage.py migrate
python manage.py loaddata games

# 4) حساب لوحة التحكم
python manage.py createsuperuser

# 5) التشغيل
python manage.py runserver
```

الآن:

- الـ API: `http://127.0.0.1:8000/api/games/`
- لوحة التحكم النيونية: `http://127.0.0.1:8000/admin/`

اختبار الوحدات:

```bash
python manage.py test
```

## 🔌 نقاط النهاية (Endpoints)

| المسار | الوصف |
|---|---|
| `GET /api/games/` | قائمة الألعاب (تقسيم صفحات: `{count, next, previous, results}`) |
| `GET /api/games/{id}/` | تفاصيل لعبة |
| `GET /api/games/?search=cyber` | بحث بالاسم أو الوصف (icontains) |
| `GET /api/games/?category=rpg` | فلترة حسب التصنيف |
| `GET /api/games/?min_price=10&max_price=50` | فلترة حسب السعر |
| `GET /api/games/?featured=true` | الألعاب المميزة فقط |
| `GET /api/games/?ordering=-rating` | ترتيب (price / rating / name / release_date، مع `-` للعكس) |
| `GET /api/games/?page=2&page_size=5` | تقسيم صفحات مخصص (حتى 50) |
| `GET /api/games/featured/` | الألعاب المميزة (نقطة نهاية إضافية) |

مثال لعبة من الاستجابة:

```json
{
  "id": 1,
  "name": "Cyberpunk 2077",
  "description": "...",
  "price": "59.99",
  "discount_price": "29.99",
  "final_price": "29.99",
  "has_discount": true,
  "category": "rpg",
  "category_display": "لعب أدوار (RPG)",
  "rating": 4.6,
  "image": "https://placehold.co/600x800/...",
  "banner": "https://placehold.co/1280x480/...",
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

- **محاكي Android** (الافتراضي): `http://10.0.2.2:8000` — يشير تلقائيًا إلى جهاز الكمبيوتر
- **جهاز حقيقي على نفس الشبكة**: ضع IP الكمبيوتر، مثل `http://192.168.1.10:8000`
  (اعرفه بـ `ipconfig` على ويندوز أو `ifconfig`/`ip a` على لينكس)
- **بديل عبر USB**: شغّل `adb reverse tcp:8000 tcp:8000` ثم استخدم `http://127.0.0.1:8000`

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

## 🛠 لوحة تحكم Django

- العنوان: `/admin/` — إدارة كاملة للألعاب: إضافة/تعديل/حذف، **رفع صور** الغلاف والبانر من الجهاز، معاينة مصغرة في الجدول، بحث وفلترة حسب التصنيف والتمييز
- الصور المرفوعة تُخزن في `api/media/` وتُخدم من `/media/`، وتأخذ الأولوية تلقائيًا على الروابط الخارجية

## 🗂 البيانات التجريبية

**الأفضل: صور حقيقية من Steam CDN** — نفّذ داخل مجلد `api`:

```bash
python manage.py seed_games          # 14 لعبة مشهورة بصور حقيقية (آمن للتكرار)
python manage.py seed_games --reset  # حذف الكل وإعادة التعبئة
```

تشمل: Cyberpunk 2077، Elden Ring، RDR2، GTA V، The Witcher 3، Dota 2، Counter-Strike 2، Forza Horizon 5، It Takes Two، Hades، Stardew Valley، Hollow Knight، EA FC 24، Baldur's Gate 3 — بأسعار وخصومات تجريبية وغلاف 600x900 وبانر library_hero حقيقيان.

بديل قديم: `api/games/fixtures/games.json` (10 ألعاب بصور placeholder) عبر `python manage.py loaddata games`.

## 🧱 بنية المشروع

```
flux-store/
├── api/                        # Django + DRF
│   ├── flux_api/               # إعدادات المشروع
│   ├── games/
│   │   ├── models.py           # موديل Game
│   │   ├── serializers.py      # محول JSON مع حقول محسوبة
│   │   ├── views.py            # ViewSet + بحث + فلترة + ترتيب
│   │   ├── pagination.py       # 10 عناصر/صفحة
│   │   ├── admin.py            # لوحة تحكم متقدمة
│   │   ├── templates/admin/    # الثيم النيوني للوحة
│   │   ├── fixtures/games.json # 10 ألعاب تجريبية
│   │   └── tests.py            # 7 اختبارات وحدة
│   ├── requirements.txt
│   └── manage.py
└── app/                        # Flutter (Dart أصلي)
    ├── lib/
    │   ├── main.dart           # نقطة البداية (RTL عربي + ثيم Epic)
    │   ├── config.dart         # عنوان الخادم
    │   ├── theme/app_theme.dart# ألوان Epic (#101014 / #0074E4) وثيم كامل
    │   ├── models/game.dart
    │   ├── services/           # dio API + SharedPreferences
    │   ├── controllers/        # مدير المكتبة (ChangeNotifier)
    │   ├── widgets/            # زر Epic، بطاقة، بانر سينمائي، شارات خصم، سكلتون، انتقالات
    │   └── screens/            # splash، رئيسية، تفاصيل، بحث، مكتبة، حساب، shell
    └── pubspec.yaml
```

## ⚠️ ملاحظات للإنتاج

- عيّن `FLUX_SECRET_KEY` و `FLUX_DEBUG=false` وحدّد `ALLOWED_HOSTS`
- استبدل `CORS_ALLOW_ALL_ORIGINS` بقائمة نطاقات محددة
- أضف مصادقة للـ API (Token/JWT) بدل `AllowAny`
- انتقل من SQLite إلى PostgreSQL وخدم الملفات من S3 أو ما شابه
