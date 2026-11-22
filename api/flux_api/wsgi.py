"""
WSGI — نقطة دخول الخادم لمشروع flux_api.
"""
import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "flux_api.settings")

application = get_wsgi_application()
