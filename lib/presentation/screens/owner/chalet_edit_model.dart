// القيم القابلة للتعديل لشاليه، وحساب فروقاتها لبناء حمولة التحديث.
//
// الحقول المحمية (is_approved, is_featured, owner_id, rating, reviews_count)
// ليست هنا ولا تُرسل أبداً. `booking_type` و`min_nights` و`deposit_amount`
// و`updated_at` كذلك خارج هذه الشاشة بقرار المنتج.

/// أسماء الأعمدة التي يجوز أن تظهر بحمولة التحديث. أي عمود غيرها ممنوع.
const Set<String> chaletEditableColumns = {
  'name',
  'description',
  'location',
  'city',
  'address',
  'price_per_night',
  'max_guests',
  'bedrooms',
  'bathrooms',
  'has_pool',
  'has_wifi',
  'has_bbq',
  'has_parking',
  'is_available',
  'latitude',
  'longitude',
  'images',
  'video_url',
};

class ChaletEditValues {
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
  final bool isAvailable;
  final double? latitude;
  final double? longitude;
  final List<String> images;
  final String? videoUrl;

  const ChaletEditValues({
    required this.name,
    required this.description,
    required this.location,
    required this.city,
    required this.address,
    required this.pricePerNight,
    required this.maxGuests,
    required this.bedrooms,
    required this.bathrooms,
    required this.hasPool,
    required this.hasWifi,
    required this.hasBbq,
    required this.hasParking,
    required this.isAvailable,
    required this.latitude,
    required this.longitude,
    required this.images,
    required this.videoUrl,
  });

  /// من صف جدول chalets (Map من Supabase). آمن ضد null للحقول الاختيارية.
  factory ChaletEditValues.fromRow(Map<String, dynamic> row) {
    String? nz(dynamic v) {
      final s = v as String?;
      return (s == null || s.trim().isEmpty) ? null : s;
    }

    return ChaletEditValues(
      name: (row['name'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      location: (row['location'] as String?) ?? '',
      city: (row['city'] as String?) ?? '',
      address: nz(row['address']),
      pricePerNight: _num(row['price_per_night'])?.toDouble() ?? 0,
      maxGuests: _num(row['max_guests'])?.toInt() ?? 1,
      bedrooms: _num(row['bedrooms'])?.toInt() ?? 1,
      bathrooms: _num(row['bathrooms'])?.toInt() ?? 1,
      hasPool: row['has_pool'] as bool? ?? false,
      hasWifi: row['has_wifi'] as bool? ?? false,
      hasBbq: row['has_bbq'] as bool? ?? false,
      hasParking: row['has_parking'] as bool? ?? false,
      isAvailable: row['is_available'] as bool? ?? true,
      latitude: _num(row['latitude'])?.toDouble(),
      longitude: _num(row['longitude'])?.toDouble(),
      images: [
        for (final e in (row['images'] as List? ?? const [])) e.toString(),
      ],
      videoUrl: nz(row['video_url']),
    );
  }

  /// فروقات [next] عن هذه القيم بأسماء أعمدة القاعدة. فارغة إن لم يتغير شيء.
  /// النصوص تُقارَن بعد trim، و`address`/`video_url` الفارغان يساويان null.
  Map<String, dynamic> diffTo(ChaletEditValues next) {
    String? nz(String? s) {
      final t = s?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final out = <String, dynamic>{};
    void put(String key, Object? a, Object? b) {
      if (a != b) out[key] = b;
    }

    put('name', name.trim(), next.name.trim());
    put('description', description.trim(), next.description.trim());
    put('location', location.trim(), next.location.trim());
    put('city', city.trim(), next.city.trim());
    put('address', nz(address), nz(next.address));
    put('price_per_night', pricePerNight, next.pricePerNight);
    put('max_guests', maxGuests, next.maxGuests);
    put('bedrooms', bedrooms, next.bedrooms);
    put('bathrooms', bathrooms, next.bathrooms);
    put('has_pool', hasPool, next.hasPool);
    put('has_wifi', hasWifi, next.hasWifi);
    put('has_bbq', hasBbq, next.hasBbq);
    put('has_parking', hasParking, next.hasParking);
    put('is_available', isAvailable, next.isAvailable);
    put('latitude', latitude, next.latitude);
    put('longitude', longitude, next.longitude);
    put('video_url', nz(videoUrl), nz(next.videoUrl));

    final sameImages = images.length == next.images.length &&
        [for (var i = 0; i < images.length; i++) images[i] == next.images[i]]
            .every((e) => e);
    if (!sameImages) out['images'] = List<String>.of(next.images);
    return out;
  }
}

/// مسار الملف داخل bucket `chalet-images` لرابط عام، بشرط أن يقع تحت
/// `chalets/{chaletId}/` لهذا الشاليه بالذات. غير ذلك (رابط خارجي، شاليه
/// آخر، مسار ملتوٍ) يرجع null فلا يُحذف. سياسة التخزين تسمح للمالك بحذف
/// ملفات شاليهاته فقط، وهذا الفحص يمنع المحاولة أصلاً.
String? chaletImageStoragePath(String url, String chaletId) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final seg = uri.pathSegments;
  final i = seg.indexOf('chalet-images');
  if (i < 0 || i == seg.length - 1) return null;
  final rest = seg.sublist(i + 1);
  if (rest.any((s) => s.isEmpty || s == '.' || s == '..')) return null;
  final rel = rest.join('/');
  return rel.startsWith('chalets/$chaletId/') ? rel : null;
}

/// رقم من قيمة JSON: يقبل number أو نصاً رقمياً (numeric قد يصل نصاً).
num? _num(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  return null;
}
