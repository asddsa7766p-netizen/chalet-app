import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_model.dart';
import 'services.dart' show translateSupabaseError;

/// خدمة الإشعارات الوحيدة بالتطبيق (للزبون والمالك). كل الأخطاء تصل
/// للمستدعي برسالة عربية مترجمة.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// أحدث الإشعارات أولاً (حد أقصى [limit]).
  static const int limit = 100;

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } catch (e) {
      throw Exception(translateSupabaseError(e));
    }
  }

  Future<List<NotificationModel>> getNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    return _guard(() async {
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (data as List)
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// عدد غير المقروءة (العدّ على السيرفر بدل جلب الصفوف).
  Future<int> getUnreadCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    return _guard(() async {
      final res = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return res.count;
    });
  }

  Future<void> markAsRead(String id) => _guard(() async {
        await _supabase
            .from('notifications')
            .update({'is_read': true}).eq('id', id);
      });

  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _guard(() async {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    });
  }
}
