"""
نماذج تطبيق games — مخطط بيانات الألعاب لمتجر Flux.
"""
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils.html import format_html


class Game(models.Model):
    """لعبة معروضة في المتجر مع بياناتها وتسعيرها وصورها."""

    class Category(models.TextChoices):
        """تصنيفات الألعاب المدعومة في المتجر."""

        ACTION = "action", "أكشن"
        ADVENTURE = "adventure", "مغامرات"
        RPG = "rpg", "لعب أدوار (RPG)"
        RACING = "racing", "سباقات"
        SHOOTER = "shooter", "تصويب"
        SPORTS = "sports", "رياضة"
        STRATEGY = "strategy", "استراتيجية"
        SANDBOX = "sandbox", "عالم مفتوح"

    # --- معلومات أساسية ---
    name = models.CharField("اسم اللعبة", max_length=200)
    description = models.TextField("الوصف")

    # --- التسعير ---
    price = models.DecimalField(
        "السعر",
        max_digits=8,
        decimal_places=2,
        validators=[MinValueValidator(0)],
    )
    discount_price = models.DecimalField(
        "سعر الخصم",
        max_digits=8,
        decimal_places=2,
        null=True,
        blank=True,
        validators=[MinValueValidator(0)],
    )

    # --- التصنيف والتقييم ---
    category = models.CharField(
        "التصنيف",
        max_length=20,
        choices=Category.choices,
        default=Category.ACTION,
        db_index=True,
    )
    rating = models.FloatField(
        "التقييم",
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(5)],
    )

    # --- الصور: روابط خارجية (لتطبيق Flutter) أو ملفات مرفوعة من لوحة التحكم ---
    image_url = models.URLField("رابط صورة الغلاف", max_length=500, blank=True)
    banner_url = models.URLField("رابط صورة البانر", max_length=500, blank=True)
    image_file = models.ImageField(
        "صورة الغلاف (رفع)", upload_to="games/images/", blank=True, null=True
    )
    banner_file = models.ImageField(
        "صورة البانر (رفع)", upload_to="games/banners/", blank=True, null=True
    )

    # --- بيانات إضافية ---
    release_date = models.DateField("تاريخ الإصدار")
    is_featured = models.BooleanField("لعبة مميزة", default=False, db_index=True)
    created_at = models.DateTimeField("تاريخ الإضافة", auto_now_add=True)

    class Meta:
        verbose_name = "لعبة"
        verbose_name_plural = "الألعاب"
        ordering = ["-is_featured", "-created_at"]

    def __str__(self):
        return self.name

    # ---------- خصائص محسوبة تُستخدم في الواجهات والـ API ----------

    @property
    def has_discount(self):
        """هل يوجد خصم فعلي على السعر؟"""
        return self.discount_price is not None and self.discount_price < self.price

    @property
    def final_price(self):
        """السعر النهائي بعد الخصم (إن وُجد)."""
        return self.discount_price if self.has_discount else self.price

    @property
    def display_image(self):
        """رابط صورة الغلاف: الملف المرفوع أولًا وإلا الرابط الخارجي."""
        if self.image_file:
            return self.image_file.url
        return self.image_url or ""

    @property
    def display_banner(self):
        """رابط صورة البانر: الملف المرفوع أولًا وإلا الرابط الخارجي."""
        if self.banner_file:
            return self.banner_file.url
        return self.banner_url or ""
