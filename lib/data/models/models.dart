import '../../core/utils/date_utils.dart';

// ============================================
// HELPERS
// ============================================

/// يستخرج أول صورة من chalet_images (JOIN) مرتبة بـ is_cover ثم sort_order
String? _extractChaletImage(Map<String, dynamic>? chaletJson) {
  if (chaletJson == null) return null;

  final images = (chaletJson['images'] as List?)?.cast<dynamic>();

  if (images == null || images.isEmpty) {
    return null;
  }

  return images.first.toString();
}

// ============================================
// BOOKING MODEL
// ============================================
enum BookingStatus { pending, confirmed, cancelled, rejected, completed }

extension BookingStatusX on BookingStatus {
  String get arabicLabel {
    switch (this) {
      case BookingStatus.pending:
        return 'قيد الانتظار';
      case BookingStatus.confirmed:
        return 'مؤكد';
      case BookingStatus.cancelled:
        return 'ملغي';
      case BookingStatus.rejected:
        return 'مرفوض';
      case BookingStatus.completed:
        return 'مكتمل';
    }
  }
}

class BookingModel {
  final String id;
  final String chaletId;
  /// null لحجز حساب حُذف (delete_my_account تفك الربط وتُبقي الحجز للمالك).
  final String? userId;
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

  /// ✅ بيانات الضيف (full_name / phone / avatar_url) — تُجلب من جدول
  /// profiles عبر JOIN في استعلامات المالك (RLS يسمح بذلك للحجوزات
  /// المرتبطة بشاليهات المالك). كانت غائبة تمامًا، والآن تُعرض مباشرة
  /// على بطاقة الحجز في شاشة إدارة الحجوزات.
  final String? guestName;
  final String? guestPhone;
  final String? guestAvatar;

  /// ✅ جديد: نوع الإقامة الفعلي لهذا الحجز — 'default' (السلوك القديم قبل
  /// دعم أنواع الإقامة) أو أحد القيم: morning / evening / full_day_morning
  /// / full_day_evening. يُستخدم لعرض تفاصيل الحجز ولإعادة حساب الأسعار
  /// بنفس نوع الإقامة الذي اختاره الضيف وقت الحجز.
  final String stayType;

  /// مصدر الحجز: 'app' (من الزبون عبر التطبيق) أو 'external' (حجز يدوي أدخله
  /// المالك). العمود محمي بـ trigger بقاعدة البيانات ولا يُرسل من التطبيق أبداً.
  final String source;

  /// اسم وهاتف ضيف الحجز اليدوي (أعمدة bookings.guest_name / guest_phone).
  /// منفصلان عن [guestName]/[guestPhone] أعلاه (بيانات ملف صاحب الحساب).
  final String? externalGuestName;
  final String? externalGuestPhone;

  /// وقت بداية/نهاية فترة الحجز كما ضبطها المالك ("HH:MM:SS")، من
  /// chalets.chalet_stay_types المضمَّنة بالاستعلام. null إن لم تُجلب أو
  /// كانت الفترة 'default' (يوم كامل بلا أوقات).
  final String? periodStart;
  final String? periodEnd;

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
    this.guestName,
    this.guestPhone,
    this.guestAvatar,
    this.stayType = 'default',
    this.source = 'app',
    this.externalGuestName,
    this.externalGuestPhone,
    this.periodStart,
    this.periodEnd,
  });

  /// عدد الأيام المحجوزة (1 لكل حجز جديد؛ أكثر للحجوزات القديمة الممتدة).
  int get nightsCount => nightsBetween(checkIn, checkOut);

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final stayType = json['stay_type'] as String? ?? 'default';
    // إعداد الفترة المطابقة لنوع إقامة هذا الحجز (إن ضُمِّنت أنواع الشاليه).
    final types = json['chalets']?['chalet_stay_types'];
    Map? period;
    if (types is List) {
      for (final t in types) {
        if (t is Map && t['stay_type'] == stayType) period = t;
      }
    }
    return BookingModel(
      id: json['id'] as String,
      chaletId: json['chalet_id'] as String,
      userId: json['user_id'] as String?,
      checkIn: DateTime.parse(json['check_in'] as String),
      checkOut: DateTime.parse(json['check_out'] as String),
      guestsCount: json['guests_count'] as int? ?? 1,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      status: BookingStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'pending'),
        orElse: () => BookingStatus.pending,
      ),
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      chaletName: json['chalets']?['name'] as String?,
      chaletImage: _extractChaletImage(json['chalets']),
      chaletCity: json['chalets']?['city'] as String?,
      guestName: json['profiles']?['full_name'] as String?,
      guestPhone: json['profiles']?['phone'] as String?,
      guestAvatar: json['profiles']?['avatar_url'] as String?,
      stayType: stayType,
      source: json['source'] as String? ?? 'app',
      externalGuestName: json['guest_name'] as String?,
      externalGuestPhone: json['guest_phone'] as String?,
      periodStart: period?['checkin_time'] as String?,
      periodEnd: period?['checkout_time'] as String?,
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
        'stay_type': stayType,
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
  final String? role; // ✅ جديد
  final bool isOwner; // ✅ جديد
  final bool isAdmin; // ← أضف هذا

  const UserProfile({
    required this.id,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.email,
    this.createdAt,
    this.role, // ✅ جديد
    this.isOwner = false, // ✅ جديد
    this.isAdmin = false, // ← أضف هذا
  });

  /// المصدر الوحيد لقاعدة "مالك" بالتطبيق (الراوتر وحسابي). become_owner/
  /// become_customer تضبطان role و is_owner معاً، فأيّهما يكفي.
  bool get isHost => isOwner || role == 'owner';

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
      role: json['role'] as String?, // ✅ جديد
      isOwner: json['is_owner'] as bool? ?? false,
      isAdmin: json['is_admin'] as bool? ?? false, // ✅ جديد
    );
  }
  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'phone': phone,
        'avatar_url': avatarUrl,
      };
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

