/// ChaletModel — يطابق جدول chalets بقاعدة البيانات كاملاً
///
/// التغييرات عن النسخة السابقة:
/// - إضافة: depositAmount, videoUrl, bookingType, isApproved,
///           isFeatured, address, latitude, longitude
/// - min_nights لا يُقرأ ولا يُرسل: الحجز يوم واحد + فترة (العمود باقٍ بالقاعدة)
/// - تحويل coverImage (String واحد) → images (List<String>) ليعكس
///   قاعدة البيانات الفعلية (images text[])
/// - إضافة getter coverImage للتوافق مع الكود القديم (non-breaking)
/// - إصلاح fromJson ليكون آمناً ضد null لكل الحقول الاختيارية
class ChaletModel {
  final String id;
  final String name;
  final String description;
  final String location;
  final String city;
  final String? address;
  final double pricePerNight;
  final int maxGuests;
  final int bedrooms;
  final int bathrooms;
  final bool hasPool;
  final bool hasWifi;
  final bool hasBbq;
  final bool hasParking;
  final String? ownerId;
  final double rating;
  final int reviewsCount;
  final bool isAvailable;
  final bool isApproved;
  final bool isFeatured;
  final double? latitude;
  final double? longitude;
  final String bookingType;
  final double depositAmount;
  final List<String> images;
  final String? videoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChaletModel({
    required this.id,
    required this.name,
    this.description = '',
    this.location = '',
    this.city = '',
    this.address,
    this.pricePerNight = 0,
    this.maxGuests = 10,
    this.bedrooms = 1,
    this.bathrooms = 1,
    this.hasPool = false,
    this.hasWifi = false,
    this.hasBbq = false,
    this.hasParking = false,
    this.ownerId,
    this.rating = 0,
    this.reviewsCount = 0,
    this.isAvailable = true,
    this.isApproved = false,
    this.isFeatured = false,
    this.latitude,
    this.longitude,
    this.bookingType = 'يومي',
    this.depositAmount = 0,
    this.images = const [],
    this.videoUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// الصورة الرئيسية — للتوافق مع الكود القديم الذي يستخدم chalet.coverImage
  String get coverImage => images.isNotEmpty ? images.first : '';

  /// هل الشاليه ظاهر للعامة؟
  bool get isPublic => isAvailable && isApproved;

  /// هل لديه إحداثيات خريطة؟
  bool get hasLocation => latitude != null && longitude != null;

  factory ChaletModel.fromJson(Map<String, dynamic> json) {
    // images مخزنة كـ text[] في Supabase — تأتي كـ List<dynamic>
    List<String> parseImages(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    return ChaletModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      city: json['city'] as String? ?? '',
      address: json['address'] as String?,
      pricePerNight: (json['price_per_night'] as num?)?.toDouble() ?? 0,
      maxGuests: json['max_guests'] as int? ?? 10,
      bedrooms: json['bedrooms'] as int? ?? 1,
      bathrooms: json['bathrooms'] as int? ?? 1,
      hasPool: json['has_pool'] as bool? ?? false,
      hasWifi: json['has_wifi'] as bool? ?? false,
      hasBbq: json['has_bbq'] as bool? ?? false,
      hasParking: json['has_parking'] as bool? ?? false,
      ownerId: json['owner_id'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewsCount: json['reviews_count'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      isApproved: json['is_approved'] as bool? ?? false,
      isFeatured: json['is_featured'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      bookingType: json['booking_type'] as String? ?? 'يومي',
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0,
      images: parseImages(json['images']),
      videoUrl: json['video_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'location': location,
        'city': city,
        'address': address,
        'price_per_night': pricePerNight,
        'max_guests': maxGuests,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'has_pool': hasPool,
        'has_wifi': hasWifi,
        'has_bbq': hasBbq,
        'has_parking': hasParking,
        'owner_id': ownerId,
        'rating': rating,
        'reviews_count': reviewsCount,
        'is_available': isAvailable,
        'is_approved': isApproved,
        'is_featured': isFeatured,
        'latitude': latitude,
        'longitude': longitude,
        'booking_type': bookingType,
        'deposit_amount': depositAmount,
        'images': images,
        'video_url': videoUrl,
      };

  ChaletModel copyWith({
    String? id,
    String? name,
    String? description,
    String? location,
    String? city,
    String? address,
    double? pricePerNight,
    int? maxGuests,
    int? bedrooms,
    int? bathrooms,
    bool? hasPool,
    bool? hasWifi,
    bool? hasBbq,
    bool? hasParking,
    String? ownerId,
    double? rating,
    int? reviewsCount,
    bool? isAvailable,
    bool? isApproved,
    bool? isFeatured,
    double? latitude,
    double? longitude,
    String? bookingType,
    double? depositAmount,
    List<String>? images,
    String? videoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChaletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      city: city ?? this.city,
      address: address ?? this.address,
      pricePerNight: pricePerNight ?? this.pricePerNight,
      maxGuests: maxGuests ?? this.maxGuests,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      hasPool: hasPool ?? this.hasPool,
      hasWifi: hasWifi ?? this.hasWifi,
      hasBbq: hasBbq ?? this.hasBbq,
      hasParking: hasParking ?? this.hasParking,
      ownerId: ownerId ?? this.ownerId,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      isAvailable: isAvailable ?? this.isAvailable,
      isApproved: isApproved ?? this.isApproved,
      isFeatured: isFeatured ?? this.isFeatured,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      bookingType: bookingType ?? this.bookingType,
      depositAmount: depositAmount ?? this.depositAmount,
      images: images ?? this.images,
      videoUrl: videoUrl ?? this.videoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChaletModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
