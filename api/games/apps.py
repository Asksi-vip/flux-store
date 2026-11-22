"""إعدادات تطبيق games."""
from django.apps import AppConfig


class GamesConfig(AppConfig):
    """ضبط تطبيق الألعاب."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "games"
    verbose_name = "الألعاب"
