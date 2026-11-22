"""
إعدادات تقسيم الصفحات (Pagination) للـ API.
"""
from rest_framework.pagination import PageNumberPagination


class GamePagination(PageNumberPagination):
    """تقسيم قائمة الألعاب: 10 عناصر لكل صفحة افتراضيًا مع دعم ?page_size="""

    page_size = 10
    page_size_query_param = "page_size"
    max_page_size = 50
