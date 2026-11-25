/// ملف تحميل تابع للعبة (APK / OBB / Data) — مسار التثبيت محسوب تلقائيًا من الخادم
/// وفق معايير أندرويد (Android/obb/<الحزمة>/ أو Android/data/<الحزمة>/files/).
class DownloadFile {
  final int id;
  final String name;
  final String type; // apk | obb | data
  final String url;
  final int size; // بالبايت (0 = غير معروف)
  final int versionCode;
  final String installPath; // فارغ لملفات APK لأنها تُثبّت عبر مثبّت النظام

  const DownloadFile({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    required this.size,
    required this.versionCode,
    required this.installPath,
  });

  bool get isApk => type == 'apk';
  bool get isObb => type == 'obb';
  bool get isData => type == 'data';

  factory DownloadFile.fromJson(Map<String, dynamic> json) => DownloadFile(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
        type: json['type']?.toString() ?? 'apk',
        url: json['url']?.toString() ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
        installPath: json['install_path']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'url': url,
        'size': size,
        'version_code': versionCode,
        'install_path': installPath,
      };
}

/// معلومات التحميل الكاملة للعبة: الملف الرئيسي (أول APK) + قائمة الملفات الإضافية.
class DownloadInfo {
  final String url; // الملف الرئيسي (أول ملف APK)
  final int size; // حجم الملف الرئيسي بالبايت
  final String version;
  final int versionCode;
  final String packageName;
  final List<DownloadFile> files;

  const DownloadInfo({
    required this.url,
    required this.size,
    required this.version,
    required this.versionCode,
    required this.packageName,
    required this.files,
  });

  /// هل تتوفر ملفات تحميل لهذه اللعبة؟
  bool get available => files.isNotEmpty;

  factory DownloadInfo.fromJson(Map<String, dynamic> json) => DownloadInfo(
        url: json['url']?.toString() ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        version: json['version']?.toString() ?? '',
        versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
        packageName: json['package_name']?.toString() ?? '',
        files: ((json['files'] as List?) ?? const [])
            .map((dynamic e) =>
                DownloadFile.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'size': size,
        'version': version,
        'version_code': versionCode,
        'package_name': packageName,
        'files': files.map((f) => f.toJson()).toList(),
      };
}

/// نموذج اللعبة القادم من الـ API.
class Game {
  final int id;
  final String name;
  final String description;
  final double price;
  final double? discountPrice;
  final String category;
  final String categoryDisplay;
  final List<String> categories; // التصنيفات المتعددة (معرفات)
  final List<String> categoriesDisplay; // التصنيفات المتعددة (أسماء للعرض)
  final double rating;
  final String image;
  final String banner;
  final String releaseDate;
  final String developer; // اسم المطوّر (نمط سوق أبِل)
  final String lastUpdated; // تاريخ آخر تحديث
  final bool isFeatured;
  final String packageName;
  final DownloadInfo? download;

  const Game({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.discountPrice,
    required this.category,
    required this.categoryDisplay,
    this.categories = const [],
    this.categoriesDisplay = const [],
    required this.rating,
    required this.image,
    required this.banner,
    required this.releaseDate,
    this.developer = '',
    this.lastUpdated = '',
    required this.isFeatured,
    this.packageName = '',
    this.download,
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
      isFree ? 'Free' : '\$${_fmt(finalPrice)}';

  /// نص السعر الأصلي قبل الخصم.
  String get priceLabel => '\$${_fmt(price)}';

  /// نسبة الخصم المحفوظة (%) — صفر إن لم يوجد خصم.
  int get discountPercent {
    if (!hasDiscount) return 0;
    return (((price - finalPrice) / price) * 100).round();
  }

  /// هل يمكن تحميل هذه اللعبة داخل التطبيق؟ (ألعاب مجانية بملفات متوفرة)
  bool get isDownloadable => isFree && (download?.available ?? false);

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
        categories: ((json['categories'] as List?) ?? const [])
            .map((dynamic e) => e.toString())
            .toList(),
        categoriesDisplay: ((json['categories_display'] as List?) ?? const [])
            .map((dynamic e) => e.toString())
            .toList(),
        rating: _toDouble(json['rating']),
        image: json['image']?.toString() ?? '',
        banner: json['banner']?.toString() ?? '',
        releaseDate: json['release_date']?.toString() ?? '',
        developer: json['developer']?.toString() ?? '',
        lastUpdated: json['last_updated']?.toString() ?? '',
        isFeatured: json['is_featured'] == true,
        packageName: json['package_name']?.toString() ?? '',
        download: json['download'] is Map
            ? DownloadInfo.fromJson(
                Map<String, dynamic>.from(json['download'] as Map))
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'discount_price': discountPrice,
        'category': category,
        'category_display': categoryDisplay,
        'categories': categories,
        'categories_display': categoriesDisplay,
        'rating': rating,
        'image': image,
        'banner': banner,
        'release_date': releaseDate,
        'developer': developer,
        'last_updated': lastUpdated,
        'is_featured': isFeatured,
        'package_name': packageName,
        'download': download?.toJson(),
      };

  /// تحويل قيمة السعر (رقم أو نص من الخادم) إلى double بأمان.
  static double _toDouble(dynamic v) =>
      v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

  /// تنسيق الرقم: إزالة الأصفار الزائدة (30.0 → 30 / 29.99 → 29.99).
  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
