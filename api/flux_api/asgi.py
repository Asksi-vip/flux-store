"""
ASGI — نقطة دخول الخادم غير المتزامن لمشروع flux_api.
"""
import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "flux_api.settings")

application = get_asgi_application()
