/// نموذج اللعبة القادم من الـ API.
class Game {
  final int id;
  final String name;
  final String description;
  final double price;
  final double? discountPrice;
  final String category;
  final String categoryDisplay;
  final double rating;
  final String image;
  final String banner;
  final String releaseDate;
  final bool isFeatured;

  const Game({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.discountPrice,
    required this.category,
    required this.categoryDisplay,
    required this.rating,
    required this.image,
    required this.banner,
    required this.releaseDate,
    required this.isFeatured,
  });

  /// هل يوجد خصم فعلي؟
  bool get hasDiscount =>
      discountPrice != null && discountPrice! < price && price > 0;

  /// السعر النهائي بعد الخصم.
  double get finalPrice => hasDiscount ? discountPrice! : price;

  /// هل اللعبة مجانية؟
  bool get isFree => finalPrice <= 0;

  /// نص السعر النهائي الجاهز للعرض (مجاني / 29.99$).
  String get finalPriceLabel =>
      isFree ? 'مجاني' : '\$${_fmt(finalPrice)}';

  /// نص السعر الأصلي قبل الخصم.
  String get priceLabel => '\$${_fmt(price)}';

  /// نسبة الخصم المحفوظة (%) — صفر إن لم يوجد خصم.
  int get discountPercent {
    if (!hasDiscount) return 0;
    return (((price - finalPrice) / price) * 100).round();
  }

  @override
  bool operator ==(Object other) => other is Game && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory Game.fromJson(Map<String, dynamic> json) => Game(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        price: _toDouble(json['price']),
        discountPrice: json['discount_price'] == null
            ? null
            : _toDouble(json['discount_price']),
        category: json['category']?.toString() ?? '',
        categoryDisplay: json['category_display']?.toString() ?? '',
        rating: _toDouble(json['rating']),
        image: json['image']?.toString() ?? '',
        banner: json['banner']?.toString() ?? '',
        releaseDate: json['release_date']?.toString() ?? '',
        isFeatured: json['is_featured'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'discount_price': discountPrice,
        'category': category,
        'category_display': categoryDisplay,
        'rating': rating,
        'image': image,
        'banner': banner,
        'release_date': releaseDate,
        'is_featured': isFeatured,
      };

  /// تحويل قيمة السعر (رقم أو نص من الخادم) إلى double بأمان.
  static double _toDouble(dynamic v) =>
      v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

  /// تنسيق الرقم: إزالة الأصفار الزائدة (30.0 → 30 / 29.99 → 29.99).
  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
