part of 'models.dart';

// ============================================
// REVIEW MODEL
// ============================================
class ReviewModel {
  final String id;
  final String chaletId;
  final String userId;
  final String? bookingId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? userName;
  final String? userAvatar;

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
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      chaletId: json['chalet_id'] as String,
      userId: json['user_id'] as String,
      bookingId: json['booking_id'] as String?,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: json['profiles']?['full_name'] as String?,
      userAvatar: json['profiles']?['avatar_url'] as String?,
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
