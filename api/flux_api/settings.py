"""
إعدادات مشروع flux_api — الخلفية البرمجية لمتجر ألعاب Flux.

ملاحظة: الإعدادات الحالية مناسبة للتطوير (DEBUG مفعّل افتراضيًا).
للإنتاج: عيّن FLUX_SECRET_KEY من متغيرات البيئة و FLUX_DEBUG=false.
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# المفتاح السري: يُقرأ من متغير البيئة إن وُجد، وإلا يُستخدم مفتاح تطوير
SECRET_KEY = os.environ.get(
    "FLUX_SECRET_KEY",
    "django-insecure-flux-dev-key-CHANGE-ME-in-production",
)

# وضع التطوير مفعّل افتراضيًا — أوقفه في الإنتاج عبر FLUX_DEBUG=false
DEBUG = os.environ.get("FLUX_DEBUG", "true").lower() == "true"

# للتطوير فقط — حدّد نطاقات فعّالة في الإنتاج
ALLOWED_HOSTS = ["*"]

# تطبيقات المشروع
INSTALLED_APPS = [
    # تطبيق الألعاب قبل django.contrib.admin حتى يستطيع تجاوز قوالب لوحة التحكم
    "games.apps.GamesConfig",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # تطبيقات خارجية
    "rest_framework",
    "corsheaders",
]

MIDDLEWARE = [
    # CORS في المقدمة حتى يعمل الاتصال من تطبيق Flutter
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "flux_api.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "flux_api.wsgi.application"

# قاعدة البيانات: SQLite تكفي للتطوير والتجربة
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
    }
}

# قواعد كلمات المرور لحسابات لوحة التحكم
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# واجهة لوحة التحكم بالعربية
LANGUAGE_CODE = "ar"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"

# ملفات الوسائط (الصور المرفوعة من لوحة التحكم)
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# إعدادات Django REST Framework
REST_FRAMEWORK = {
    "DEFAULT_PAGINATION_CLASS": "games.pagination.GamePagination",
    "PAGE_SIZE": 10,
    # قراءة عامة لتطبيق Flutter — أضف مصادقة (Token/JWT) في الإنتاج
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.AllowAny",
    ],
}

# إعدادات CORS — تسمح لتطبيق Flutter بالاتصال بالـ API
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True
