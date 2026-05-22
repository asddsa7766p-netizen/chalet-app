// ============================================
// BOOKING MODEL
// ============================================
enum BookingStatus { pending, confirmed, cancelled, completed }

extension BookingStatusX on BookingStatus {
  String get arabicLabel {
    switch (this) {
      case BookingStatus.pending: return 'قيد الانتظار';
      case BookingStatus.confirmed: return 'مؤكد';
      case BookingStatus.cancelled: return 'ملغي';
      case BookingStatus.completed: return 'مكتمل';
    }
  }
}

class BookingModel {
  final String id;
  final String chaletId;
  final String userId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guestsCount;
  final double totalPrice;
  final BookingStatus status;
  final String paymentMethod;
  final String? notes;
  final DateTime createdAt;
  final String? chaletName;
  final String? chaletImage;
  final String? chaletCity;

  const BookingModel({
    required this.id,
    required this.chaletId,
    required this.userId,
    required this.checkIn,
    required this.checkOut,
    required this.guestsCount,
    required this.totalPrice,
    required this.status,
    this.paymentMethod = 'cash',
    this.notes,
    required this.createdAt,
    this.chaletName,
    this.chaletImage,
    this.chaletCity,
  });

  int get nightsCount => checkOut.difference(checkIn).inDays;

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String,
      chaletId: json['chalet_id'] as String,
      userId: json['user_id'] as String,
      checkIn: DateTime.parse(json['check_in'] as String),
      checkOut: DateTime.parse(json['check_out'] as String),
      guestsCount: json['guests_count'] as int? ?? 1,
      totalPrice: (json['total_price'] as num).toDouble(),
      status: BookingStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'pending'),
        orElse: () => BookingStatus.pending,
      ),
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      chaletName: json['chalets']?['name'] as String?,
      chaletImage: (json['chalets']?['images'] as List?)?.firstOrNull as String?,
      chaletCity: json['chalets']?['city'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'chalet_id': chaletId,
    'user_id': userId,
    'check_in': checkIn.toIso8601String().split('T').first,
    'check_out': checkOut.toIso8601String().split('T').first,
    'guests_count': guestsCount,
    'total_price': totalPrice,
    'status': status.name,
    'payment_method': paymentMethod,
    'notes': notes,
  };
}

// ============================================
// USER PROFILE MODEL
// ============================================
class UserProfile {
  final String id;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String? email;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.email,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      email: json['email'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'phone': phone,
    'avatar_url': avatarUrl,
  };

  UserProfile copyWith({
    String? fullName, String? phone, String? avatarUrl, String? email,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      createdAt: createdAt,
    );
  }
}

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

// ============================================
// NOTIFICATION MODEL
// ============================================
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String? body;
  final String? type;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    this.type,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      type: json['type'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get icon {
    switch (type) {
      case 'booking_confirmed': return '✅';
      case 'offer': return '🎁';
      case 'reminder': return '🔔';
      case 'review': return '⭐';
      default: return '📢';
    }
  }
}
