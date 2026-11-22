"""
محوّلات البيانات (Serializers) لتطبيق games.
"""
from rest_framework import serializers

from .models import Game


class GameSerializer(serializers.ModelSerializer):
    """تحويل نموذج Game إلى JSON مع حقول محسوبة جاهزة للتطبيق."""

    category_display = serializers.ReadOnlyField(source="get_category_display")
    final_price = serializers.ReadOnlyField()
    has_discount = serializers.ReadOnlyField()
    image = serializers.SerializerMethodField()
    banner = serializers.SerializerMethodField()

    class Meta:
        model = Game
        fields = [
            "id",
            "name",
            "description",
            "price",
            "discount_price",
            "final_price",
            "has_discount",
            "category",
            "category_display",
            "rating",
            "image",
            "banner",
            "release_date",
            "is_featured",
            "created_at",
        ]

    def _absolute_url(self, url):
        """تحويل المسار النسبي إلى رابط مطلق يستطيع التطبيق تحميله."""
        request = self.context.get("request")
        if url and request is not None:
            return request.build_absolute_uri(url)
        return url

    def get_image(self, obj):
        """رابط صورة الغلاف النهائي للمطوّر (مرفوعة أو خارجية)."""
        return self._absolute_url(obj.display_image)

    def get_banner(self, obj):
        """رابط صورة البانر النهائي للمطوّر (مرفوعة أو خارجية)."""
        return self._absolute_url(obj.display_banner)
