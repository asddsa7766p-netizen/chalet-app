class ChaletModel {
  final String id;
  final String name;
  final String description;
  final String location;
  final String city;
  final double pricePerNight;
  final int maxGuests;
  final int bedrooms;
  final int bathrooms;
  final bool hasPool;
  final bool hasWifi;
  final bool hasBbq;
  final bool hasParking;
  final List<String> images;
  final String? ownerId;
  final double rating;
  final int reviewsCount;
  final bool isAvailable;
  final DateTime createdAt;
  final double? latitude; // ✅ جديد
  final double? longitude; // ✅ جديد

  const ChaletModel({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.city,
    required this.pricePerNight,
    this.maxGuests = 10,
    this.bedrooms = 3,
    this.bathrooms = 2,
    this.hasPool = false,
    this.hasWifi = true,
    this.hasBbq = false,
    this.hasParking = true,
    this.images = const [],
    this.ownerId,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.isAvailable = true,
    required this.createdAt,
    this.latitude, // ✅ جديد
    this.longitude, // ✅ جديد
  });

  factory ChaletModel.fromJson(Map<String, dynamic> json) {
    return ChaletModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      location: json['location'] as String,
      city: json['city'] as String,
      pricePerNight: (json['price_per_night'] as num).toDouble(),
      maxGuests: json['max_guests'] as int? ?? 10,
      bedrooms: json['bedrooms'] as int? ?? 3,
      bathrooms: json['bathrooms'] as int? ?? 2,
      hasPool: json['has_pool'] as bool? ?? false,
      hasWifi: json['has_wifi'] as bool? ?? true,
      hasBbq: json['has_bbq'] as bool? ?? false,
      hasParking: json['has_parking'] as bool? ?? true,
      images: List<String>.from(json['images'] as List? ?? []),
      ownerId: json['owner_id'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: json['reviews_count'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(), // ✅ جديد
      longitude: (json['longitude'] as num?)?.toDouble(), // ✅ جديد
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'location': location,
        'city': city,
        'price_per_night': pricePerNight,
        'max_guests': maxGuests,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'has_pool': hasPool,
        'has_wifi': hasWifi,
        'has_bbq': hasBbq,
        'has_parking': hasParking,
        'images': images,
        'owner_id': ownerId,
        'rating': rating,
        'reviews_count': reviewsCount,
        'is_available': isAvailable,
        'created_at': createdAt.toIso8601String(),
        'latitude': latitude, // ✅ جديد
        'longitude': longitude, // ✅ جديد
      };

  String get mainImage => images.isNotEmpty
      ? images.first
      : 'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800';

  ChaletModel copyWith({
    String? id,
    String? name,
    String? description,
    String? location,
    String? city,
    double? pricePerNight,
    int? maxGuests,
    int? bedrooms,
    int? bathrooms,
    bool? hasPool,
    bool? hasWifi,
    bool? hasBbq,
    bool? hasParking,
    List<String>? images,
    String? ownerId,
    double? rating,
    int? reviewsCount,
    bool? isAvailable,
    DateTime? createdAt,
    double? latitude, // ✅ جديد
    double? longitude, // ✅ جديد
  }) {
    return ChaletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      city: city ?? this.city,
      pricePerNight: pricePerNight ?? this.pricePerNight,
      maxGuests: maxGuests ?? this.maxGuests,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      hasPool: hasPool ?? this.hasPool,
      hasWifi: hasWifi ?? this.hasWifi,
      hasBbq: hasBbq ?? this.hasBbq,
      hasParking: hasParking ?? this.hasParking,
      images: images ?? this.images,
      ownerId: ownerId ?? this.ownerId,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      latitude: latitude ?? this.latitude, // ✅ جديد
      longitude: longitude ?? this.longitude, // ✅ جديد
    );
  }
}
