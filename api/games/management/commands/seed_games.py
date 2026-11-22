"""
أمر إدارة: تعبئة المتجر ببيانات تجريبية واقعية — ألعاب معروفة بصور حقيقية
من CDN الخاص بـ Steam (روابط عامة ثابتة).

الاستخدام:
    python manage.py seed_games          # إضافة ما ينقص فقط (آمن للتكرار)
    python manage.py seed_games --reset  # حذف كل الألعاب ثم التعبئة من جديد
"""
from django.core.management.base import BaseCommand

from games.models import Game

# (الاسم، الفئة، السعر، سعر الخصم، التقييم، مميزة؟، تاريخ الإصدار، الوصف، معرف تطبيق Steam)
SEED_GAMES = [
    (
        "Cyberpunk 2077", Game.Category.RPG, 59.99, 29.99, 4.6, True, "2020-12-10",
        "لعبة أكشن ومغامرات في عالم مستقبلي مفتوح بمدينة نايت سيتي، حيث تلعب دور مرتزق اسمه V بحثًا عن زرعة رقمية هي مفتاح الخلود.",
        "1091500",
    ),
    (
        "Elden Ring", Game.Category.RPG, 59.99, 41.99, 4.8, True, "2022-02-25",
        "ملحمة عالم مفتوح من فروم سوفتوير بمشاركة جورج آر آر مارتن: ممالك متداعية، زعماء مخيفون، ووحشية لا ترحم.",
        "1245620",
    ),
    (
        "Red Dead Redemption 2", Game.Category.ACTION, 59.99, 17.99, 4.9, True, "2019-11-05",
        "قصة آرثر مورغان وعصابة فان دير ليند في نهاية عصر الغرب المتوحش — تفاصيل عالم مذهلة وسرد من أقوى القصص في تاريخ الألعاب.",
        "1174180",
    ),
    (
        "Grand Theft Auto V", Game.Category.ACTION, 29.99, None, 4.5, False, "2015-04-13",
        "ثلاثة مجرمين بأساليب مختلفة في مدينة لوس سانتوس الفاسدة — عالم مفتوح لا نهائي مع وضع Online متجدد باستمرار.",
        "271590",
    ),
    (
        "The Witcher 3: Wild Hunt", Game.Category.RPG, 39.99, 7.99, 4.9, False, "2015-05-18",
        "الصياد جيرالت من ريفيا يبحث عن ابنة بالتبني بينما يزحف الويلد هنتر — RPG ضخم بأخلاقيات معقدة وقصص جانبية لا تُنسى.",
        "292030",
    ),
    (
        "Dota 2", Game.Category.STRATEGY, 0, None, 4.3, True, "2013-07-09",
        "الـ MOBA الأيقوني: فريقان من خمسة لاعبين يتنافسان على تدمير العرش — عمق استراتيجي هائل ومجاني بالكامل.",
        "570",
    ),
    (
        "Counter-Strike 2", Game.Category.SHOOTER, 0, None, 4.1, False, "2023-09-27",
        "جديد عالم كاونتر سترايك بمحرك Source 2: قتال تكتيكي 5 ضد 5 بدقة عالية واقتصاد أسلحة عالمي.",
        "730",
    ),
    (
        "Forza Horizon 5", Game.Category.RACING, 59.99, 29.99, 4.7, False, "2021-11-05",
        "قيادة مفتوحة في المكسيك بمئات السيارات وطقس ديناميكي — أجمل لعبة سباقات عالم مفتوح على الإطلاق.",
        "1551360",
    ),
    (
        "It Takes Two", Game.Category.ADVENTURE, 39.99, 9.99, 4.8, False, "2021-03-25",
        "مغامرة تعاونية مغايرة لزوجين في خضم الطلاق، بتحديات لكل لاعب تتطلب تنسيقًا كاملًا — لعبة العام 2021.",
        "1426210",
    ),
    (
        "Hades", Game.Category.ACTION, 24.99, None, 4.8, False, "2020-09-17",
        "روغ لايت أسطوري في العالم السفلي الإغريقي: انتحار متكرر ممتع، قصص تتطور مع كل موت، وسرعة قتال أدمانية.",
        "1145360",
    ),
    (
        "Stardew Valley", Game.Category.SANDBOX, 14.99, 8.99, 4.9, False, "2016-02-26",
        "اترك مدينتك وورث مزرعة جدك: زراعة، صيد، تعدين، وعلاقات اجتماعية في مدينة ساحلية دافئة — طوّره شخص واحد فقط.",
        "413150",
    ),
    (
        "Hollow Knight", Game.Category.ADVENTURE, 14.99, None, 4.8, False, "2017-02-24",
        "ميترويدفانيا مرسومة يدويًا في مملكة الحشرات Hallownest: تحديات قاسية، أسرار عميقة، وجمال حزين فريد.",
        "367520",
    ),
    (
        "EA SPORTS FC 24", Game.Category.SPORTS, 69.99, 34.99, 3.9, False, "2023-09-29",
        "أول إصدار بعد رحيل FIFA: أكثر من 19 ألف لاعب و700 نادٍ بتقنيات حركة HyperMotionV وMatch IQ.",
        "2195250",
    ),
    (
        "Baldur's Gate 3", Game.Category.RPG, 59.99, None, 4.9, True, "2023-08-03",
        "RPG تكتيكي من Larian بقواعد Dungeons & Dragons: ردود فعل لكل قرار، حملة من 100+ ساعة، وشخصيات لا تُنسى — لعبة العام 2023.",
        "1086940",
    ),
]


def _steam_url(app_id: str, asset: str) -> str:
    """بناء رابط صورة حقيقية من CDN Steam (library_600x900.jpg للغلاف وlibrary_hero.jpg للبانر)."""
    return f"https://cdn.cloudflare.steamstatic.com/steam/apps/{app_id}/{asset}"


class Command(BaseCommand):
    """تعبئة قاعدة البيانات بألعاب تجريبية بصور حقيقية."""

    help = "تعبئة المتجر بألعاب تجريبية مع صور حقيقية من Steam CDN (آمن للتكرار)"

    def add_arguments(self, parser):
        parser.add_argument(
            "--reset",
            action="store_true",
            help="حذف كل الألعاب الموجودة قبل التعبئة",
        )

    def handle(self, *args, **options):
        if options["reset"]:
            deleted, _ = Game.objects.all().delete()
            self.stdout.write(self.style.WARNING(f"تم حذف {deleted} سجلًا قديمًا"))

        created = 0
        updated = 0
        for (
            name,
            category,
            price,
            discount_price,
            rating,
            is_featured,
            release_date,
            description,
            app_id,
        ) in SEED_GAMES:
            _, was_created = Game.objects.update_or_create(
                name=name,
                defaults={
                    "description": description,
                    "category": category,
                    "price": price,
                    "discount_price": discount_price,
                    "rating": rating,
                    "is_featured": is_featured,
                    "release_date": release_date,
                    "image_url": _steam_url(app_id, "library_600x900.jpg"),
                    "banner_url": _steam_url(app_id, "library_hero.jpg"),
                },
            )
            if was_created:
                created += 1
            else:
                updated += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"تمت التعبئة: {created} لعبة جديدة، {updated} محدثة — افتح التطبيق واستمتع!"
            )
        )
