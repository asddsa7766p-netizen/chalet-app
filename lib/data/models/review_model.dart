part of 'models.dart';

// ============================================
// REVIEW MODEL
// ============================================
class ReviewModel {
  final String id;
  final String chaletId;
  final String userId;

  /// الحجز المكتمل الذي قُيِّم. سياسة الإدراج تشترطه، فوجوده = "إقامة مؤكدة"
  /// (تقييمات قديمة من قبل السياسة قد تكون بلا حجز).
  final String? bookingId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? userName;
  final String? userAvatar;

  /// فترة الحجز المقيَّم (stay_type من bookings عبر
  /// get_chalet_reviews_with_author). null لتقييم بلا حجز.
  final String? stayType;

  const ReviewModel({
    required this.id,
    required this.chaletId,
    required this.userId,
    this.bookingId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.userName,
    this.userAvatar,
    this.stayType,
  });

  bool get isVerifiedStay => bookingId != null;

  /// فترة تستحق شارة: الحجوزات القديمة (قبل الفترات) قيمتها 'default'
  /// ولا تعني فترة فعلية، فلا شارة لها ولا لـ null.
  String? get periodBadgeType =>
      stayType == null || stayType == 'default' ? null : stayType;

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      chaletId: json['chalet_id'] as String,
      userId: json['user_id'] as String,
      bookingId: json['booking_id'] as String?,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      // created_at nullable بالجدول (افتراضه now())؛ لا يُسقط القائمة كلها.
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      userName: json['profiles']?['full_name'] as String?,
      userAvatar: json['profiles']?['avatar_url'] as String?,
      stayType: json['stay_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'chalet_id': chaletId,
        'user_id': userId,
        'booking_id': bookingId,
        'rating': rating,
        'comment': comment,
      };
}

/// ترتيب قائمة التقييمات (على السيرفر).
enum ReviewSort {
  newest('الأحدث'),
  highest('الأعلى تقييماً'),
  lowest('الأدنى تقييماً');

  const ReviewSort(this.label);
  final String label;
}

/// ملخص تقييمات شاليه: العدد والمتوسط وتوزيع النجوم، من كل التقييمات (لا من
/// الصفحة المعروضة فقط).
class ReviewSummary {
  final int count;
  final double average;

  /// عدد التقييمات لكل نجمة 1..5.
  final Map<int, int> distribution;

  const ReviewSummary._(this.count, this.average, this.distribution);

  static const empty =
      ReviewSummary._(0, 0, {5: 0, 4: 0, 3: 0, 2: 0, 1: 0});

  factory ReviewSummary.fromRatings(Iterable<int> ratings) {
    final dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    var sum = 0;
    var n = 0;
    for (final r in ratings) {
      final star = r.clamp(1, 5);
      dist[star] = dist[star]! + 1;
      sum += star;
      n++;
    }
    return n == 0 ? empty : ReviewSummary._(n, sum / n, dist);
  }

  bool get isEmpty => count == 0;

  /// نسبة نجمة [star] من كل التقييمات (0..1).
  double share(int star) => count == 0 ? 0 : (distribution[star] ?? 0) / count;
}
