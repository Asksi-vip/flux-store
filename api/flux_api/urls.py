"""
مسارات المشروع الرئيسية: لوحة التحكم + الـ API + ملفات الوسائط.
"""
from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include("games.urls")),
]

# خدمة الصور المرفوعة في وضع التطوير
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
