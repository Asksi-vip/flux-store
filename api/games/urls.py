"""
مسارات الـ API لتطبيق games.
"""
from rest_framework.routers import DefaultRouter

from .views import GameViewSet

# مسار تلقائي: /api/games/ و /api/games/{id}/ و /api/games/featured/
router = DefaultRouter()
router.register("games", GameViewSet, basename="game")

urlpatterns = router.urls
