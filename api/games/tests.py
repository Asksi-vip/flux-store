"""
اختبارات وحدة الـ API لتطبيق games.
"""
from decimal import Decimal

from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from .models import Game


class GameApiTests(APITestCase):
    """اختبارات نقاط نهاية الألعاب: القائمة، التفاصيل، البحث، الفلترة."""

    def setUp(self):
        """إنشاء بيانات تجريبية صغيرة قبل كل اختبار."""
        self.racing_game = Game.objects.create(
            name="Neon Drift",
            description="لعبة سباقات نيون سريعة في شوارع Vice City",
            price=Decimal("29.99"),
            discount_price=Decimal("19.99"),
            category=Game.Category.RACING,
            rating=4.5,
            release_date=timezone.now().date(),
            is_featured=True,
        )
        Game.objects.create(
            name="Shadow Quest",
            description="مغامرة في عالم مظلم مليء بالأسرار",
            price=Decimal("49.99"),
            category=Game.Category.ADVENTURE,
            rating=4.0,
            release_date=timezone.now().date(),
        )

    def test_games_list_paginated(self):
        """القائمة تعيد كل الألعاب مع بنية تقسيم الصفحات."""
        res = self.client.get("/api/games/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("results", res.data)
        self.assertIn("count", res.data)
        self.assertEqual(res.data["count"], 2)

    def test_game_detail(self):
        """تفاصيل لعبة موجودة تعيد بياناتها الصحيحة."""
        res = self.client.get(f"/api/games/{self.racing_game.id}/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["name"], "Neon Drift")
        self.assertTrue(res.data["has_discount"])
        self.assertEqual(res.data["final_price"], Decimal("19.99"))

    def test_search_by_name(self):
        """البحث بالاسم يعمل بشكل غير حساس لحالة الأحرف (icontains)."""
        res = self.client.get("/api/games/", {"search": "neon"})
        self.assertEqual(res.data["count"], 1)
        self.assertEqual(res.data["results"][0]["name"], "Neon Drift")

    def test_category_filter(self):
        """الفلترة حسب التصنيف تعيد الألعاب المطابقة فقط."""
        res = self.client.get("/api/games/", {"category": "adventure"})
        self.assertEqual(res.data["count"], 1)
        self.assertEqual(res.data["results"][0]["category"], "adventure")

    def test_price_filter(self):
        """الفلترة حسب السعر تعيد الألعاب ضمن النطاق فقط."""
        res = self.client.get("/api/games/", {"max_price": "30"})
        self.assertEqual(res.data["count"], 1)
        self.assertEqual(res.data["results"][0]["name"], "Neon Drift")

    def test_featured_endpoint(self):
        """نقطة النهاية المميزة تعيد الألعاب المميزة فقط."""
        res = self.client.get("/api/games/featured/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["count"], 1)

    def test_detail_404(self):
        """الطلب بمعرف غير موجود يعيد 404."""
        res = self.client.get("/api/games/9999/")
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)
