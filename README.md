# 🎮 Flux — متجر الألعاب النيوني

متجر ألعاب كامل باسم **Flux** بتصميم مستوحى من أجواء **GTA 6 / Vice City**، مكوّن من جزأين متصلين:

| الجزء | التقنية | المسار |
|---|---|---|
| 📱 تطبيق Android | Flutter + dio + SharedPreferences | `/app` |
| ⚙️ Backend API | Python + Django + Django REST Framework | `/api` |

## 🎨 هوية التصميم

| اللون | القيمة | الاستخدام |
|---|---|---|
| خلفية داكنة | `#0D0B1E` | خلفية التطبيق واللوحة |
| وردي نيون | `#FF2D78` | الأزرار الأساسية والأسعار |
| بنفسجي | `#8B2FF7` | التدرجات والحدود |
| سماوي نيون | `#00E5FF` | الألعاب المجانية والتفاصيل |
| برتقالي | `#FF7A18` | النجوم والتوفير |
| أبيض | `#FFFFFF` | النصوص |

التدرج الأساسي للأزرار والعناوين: وردي ← بنفسجي مع توهج نيون (Glow).

## 📱 ميزات التطبيق

- **شاشة Splash** بشعار FLUX متوهج وظهور تدريجي
- **الشاشة الرئيسية**: شريط علوي بالبحث + بانر متحرك تلقائيًا للألعاب المميزة + شبكة ألعاب (صورة، اسم، سعر)
- **تفاصيل اللعبة**: غلاف كبير، وصف، تقييم بالنجوم، سعر مع نسبة التوفير، زر "أضف للمكتبة" وزر "شراء"
- **البحث**: بحث مؤجل (Debounce) + فلترة حسب التصنيف (أكشن، مغامرات، RPG، سباقات...)
- **المكتبة**: الألعاب المحفوظة محليًا بـ SharedPreferences مع السحب للإزالة
- **الملف الشخصي**: إحصائيات + فحص حالة الخادم
- **Bottom Navigation**: الرئيسية / البحث / المكتبة / حسابي
- **سحب لتحديث** (Pull to Refresh) + شاشات تحميل + حالات فارغة + رسائل أخطاء شبكة عربية واضحة

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

## 🛠 لوحة تحكم Django النيونية

- العنوان: `/admin/` — بنفس ألوان المتجر (خلفية `#0D0B1E`، وردي `#FF2D78`، بنفسجي `#8B2FF7`)
- إدارة كاملة للألعاب: إضافة/تعديل/حذف، **رفع صور** الغلاف والبانر من الجهاز، معاينة مصغرة في الجدول، بحث وفلترة حسب التصنيف والتمييز
- الصور المرفوعة تُخزن في `api/media/` وتُخدم من `/media/`، وتأخذ الأولوية تلقائيًا على الروابط الخارجية

## 🗂 البيانات التجريبية

10 ألعاب مشهورة (Cyberpunk 2077، GTA V، The Witcher 3، RDR2، Forza Horizon 5، Elden Ring، God of War Ragnarok، Modern Warfare II، EA FC 24، Minecraft) بأسعار وخصومات وصور placeholder.

المصدر: `api/games/fixtures/games.json` — عدّلها ثم أعد `python manage.py loaddata games`.

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
└── app/                        # Flutter
    ├── lib/
    │   ├── main.dart           # نقطة البداية (RTL عربي)
    │   ├── config.dart         # عنوان الخادم
    │   ├── theme/app_theme.dart# الألوان والتدرجات والتوهج
    │   ├── models/game.dart
    │   ├── services/           # dio API + SharedPreferences
    │   ├── controllers/        # مدير المكتبة (ChangeNotifier)
    │   ├── widgets/            # زر نيون، بطاقة، بانر، نجوم، شاشات حالة
    │   └── screens/            # splash، رئيسية، تفاصيل، بحث، مكتبة، حساب، shell
    └── pubspec.yaml
```

## ⚠️ ملاحظات للإنتاج

- عيّن `FLUX_SECRET_KEY` و `FLUX_DEBUG=false` وحدّد `ALLOWED_HOSTS`
- استبدل `CORS_ALLOW_ALL_ORIGINS` بقائمة نطاقات محددة
- أضف مصادقة للـ API (Token/JWT) بدل `AllowAny`
- انتقل من SQLite إلى PostgreSQL وخدم الملفات من S3 أو ما شابه
