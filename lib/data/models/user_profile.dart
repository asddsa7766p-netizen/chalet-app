part of 'models.dart';

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
