"""
واجهات الـ API (Views) لتطبيق games.
"""
from decimal import Decimal, InvalidOperation

from django.db.models import Q
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Game
from .serializers import GameSerializer

# خيارات الترتيب المسموحة (لمنع أي استعلام غير آمن)
ALLOWED_ORDERING = {
    "price",
    "-price",
    "rating",
    "-rating",
    "name",
    "-name",
    "release_date",
    "-release_date",
}


def _parse_decimal(value):
    """تحويل نص إلى رقم عشري بأمان، ويعيد None عند الفشل."""
    try:
        return Decimal(value)
    except (InvalidOperation, TypeError, ValueError):
        return None


class GameViewSet(viewsets.ReadOnlyModelViewSet):
    """
    واجهة الألعاب (للقراءة فقط — الإضافة والتعديل من لوحة التحكم).

    الاستعلامات المدعومة:
      /api/games/                          القائمة (مع تقسيم صفحات)
      /api/games/{id}/                     تفاصيل لعبة
      /api/games/?search=كلمة              بحث بالاسم أو الوصف (icontains)
      /api/games/?category=action          فلترة حسب التصنيف
      /api/games/?min_price=10&max_price=50  فلترة حسب السعر
      /api/games/?featured=true            الألعاب المميزة فقط
      /api/games/?ordering=price           ترتيب النتائج
      /api/games/featured/                 الألعاب المميزة (نقطة نهاية إضافية)
    """

    queryset = Game.objects.all()
    serializer_class = GameSerializer

    def get_queryset(self):
        """بناء الاستعلام حسب معاملات البحث والفلترة الواردة في الرابط."""
        qs = Game.objects.all()
        params = self.request.query_params

        # 1) البحث بالاسم أو الوصف (غير حساس لحالة الأحرف)
        search = (params.get("search") or "").strip()
        if search:
            qs = qs.filter(Q(name__icontains=search) | Q(description__icontains=search))

        # 2) الفلترة حسب التصنيف
        category = (params.get("category") or "").strip()
        if category and category in Game.Category.values:
            qs = qs.filter(category=category)

        # 3) الفلترة حسب السعر (أدنى/أعلى)
        min_price = _parse_decimal(params.get("min_price"))
        max_price = _parse_decimal(params.get("max_price"))
        if min_price is not None:
            qs = qs.filter(price__gte=min_price)
        if max_price is not None:
            qs = qs.filter(price__lte=max_price)

        # 4) الألعاب المميزة فقط
        featured = (params.get("featured") or "").strip().lower()
        if featured in ("true", "1", "yes"):
            qs = qs.filter(is_featured=True)

        # 5) الترتيب
        ordering = (params.get("ordering") or "").strip()
        if ordering in ALLOWED_ORDERING:
            qs = qs.order_by(ordering)

        return qs

    @action(detail=False, methods=["get"])
    def featured(self, request):
        """نقطة نهاية إضافية: /api/games/featured/ للألعاب المميزة فقط."""
        games = Game.objects.filter(is_featured=True)
        page = self.paginate_queryset(games)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(games, many=True)
        return Response(serializer.data)
