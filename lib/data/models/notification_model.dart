/// إشعار من جدول notifications (id, user_id, title, body, type, is_read,
/// created_at). النموذج الوحيد للإشعارات بالتطبيق (الزبون والمالك).
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String? body;

  /// booking / booking_confirmed / payment / system / offer / reminder...
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
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      type: json['type'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        userId: userId,
        title: title,
        body: body,
        type: type,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}
