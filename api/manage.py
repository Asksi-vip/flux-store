"""
أداة إدارة مشروع Django — نقطة الدخول لأوامر manage.py لمتجر Flux.
"""
import os
import sys


def main():
    """تشغيل أوامر الإدارة مع ضبط وحدة الإعدادات لمشروع flux_api."""
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "flux_api.settings")
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "تعذر استيراد Django. هل فعّلت البيئة الافتراضية وثبّت "
            "الاعتماديات؟ (pip install -r requirements.txt)"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()
