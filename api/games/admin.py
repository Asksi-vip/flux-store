"""
لوحة التحكم المخصصة لتطبيق games بثيم Flux النيوني.
"""
from django.contrib import admin
from django.utils.html import format_html

from .models import Game


@admin.register(Game)
class GameAdmin(admin.ModelAdmin):
    """إدارة الألعاب: عرض منظم مع بحث وفلترة ومعاينة الصور."""

    list_display = ("admin_thumbnail", "name", "category", "price", "discount_price", "rating", "is_featured")
    list_display_links = ("name",)
    list_editable = ("price", "discount_price", "is_featured")
    list_filter = ("category", "is_featured")
    search_fields = ("name", "description")
    ordering = ("-is_featured", "-created_at")
    readonly_fields = ("created_at",)
    list_per_page = 20

    fieldsets = (
        ("معلومات أساسية", {"fields": ("name", "description", "category", "release_date")}),
        ("التسعير", {"fields": ("price", "discount_price")}),
        ("التقييم والتمييز", {"fields": ("rating", "is_featured")}),
        ("الصور — رفع ملفات من الجهاز", {"fields": ("image_file", "banner_file")}),
        ("الصور — روابط خارجية", {"fields": ("image_url", "banner_url")}),
        ("بيانات النظام", {"fields": ("created_at",), "classes": ("collapse",)}),
    )

    @admin.display(description="الصورة")
    def admin_thumbnail(self, obj):
        """معاينة مصغرة لصورة الغلاف داخل جدول اللوحة."""
        url = obj.display_image
        if not url:
            return "—"
        return format_html(
            '<img src="{}" style="width:56px;height:56px;object-fit:cover;'
            'border-radius:10px;border:1px solid #ff2d78;" />',
            url,
        )
