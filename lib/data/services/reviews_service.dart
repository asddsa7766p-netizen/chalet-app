part of 'services.dart';

// ============================================
// REVIEWS SERVICE
// ============================================
class ReviewsService {
  static ReviewsService? _instance;
  static ReviewsService get instance => _instance ??= ReviewsService._();
  ReviewsService._();

  Future<List<ReviewModel>> getChaletReviews(String chaletId) async {
    try {
      final data =
          await supabase.rpc('get_chalet_reviews_with_author', params: {
        'p_chalet_id': chaletId,
      });
      return (data as List).map((e) {
        final row = Map<String, dynamic>.from(e as Map<String, dynamic>);
        row['profiles'] = {
          'full_name': row['author_full_name'],
          'avatar_url': row['author_avatar_url'],
        };
        return ReviewModel.fromJson(row);
      }).toList();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  Future<void> addReview({
    required String chaletId,
    required int rating,
    String? comment,
    String? bookingId,
  }) async {
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) return;
    final hasCompletedBooking = bookingId != null
        ? await supabase
            .from('bookings')
            .select('id')
            .eq('id', bookingId)
            .eq('user_id', userId)
            .eq('status', 'completed')
            .maybeSingle()
            .then((row) => row != null)
        : await supabase
            .from('bookings')
            .select('id')
            .eq('user_id', userId)
            .eq('chalet_id', chaletId)
            .eq('status', 'completed')
            .limit(1)
            .then((data) => (data as List).isNotEmpty);

    if (!hasCompletedBooking) {
      throw Exception('not_eligible_review');
    }

    // ✅ إصلاح: سياسة RLS على reviews (reviews_insert_completed_booking_own)
    // تشترط أن يطابق booking_id حجزاً مكتملاً للمستخدم نفسه، وقيد
    // unique_review_per_booking يمنع أكثر من تقييم لنفس الحجز. التطبيق كان
    // يرسل booking_id = null دائماً ⇒ كل محاولة تقييم تُرفض من السيرفر (رسالة
    // "حدث خطأ" للمستخدم). نختار الآن أول حجز مكتمل لهذا الشاليه لم يُقيَّم بعد.
    var effectiveBookingId = bookingId;
    if (effectiveBookingId == null) {
      try {
        final completed = await supabase
            .from('bookings')
            .select('id')
            .eq('user_id', userId)
            .eq('chalet_id', chaletId)
            .eq('status', 'completed')
            .order('check_out', ascending: false);
        final ids = (completed as List).map((r) => r['id'] as String).toList();
        final reviewed = ids.isEmpty
            ? <String>{}
            : ((await supabase
                    .from('reviews')
                    .select('booking_id')
                    .eq('user_id', userId)
                    .inFilter('booking_id', ids)) as List)
                .map((r) => r['booking_id'] as String)
                .toSet();
        final free = ids.where((id) => !reviewed.contains(id));
        if (free.isEmpty) throw Exception('already_reviewed');
        effectiveBookingId = free.first;
      } catch (e) {
        if (e.toString().contains('already_reviewed')) rethrow;
        throw Exception(_translateSupabaseError(e));
      }
    }

    try {
      await supabase.from('reviews').insert({
        'chalet_id': chaletId,
        'user_id': userId,
        'booking_id': effectiveBookingId,
        'rating': rating,
        'comment': comment,
      });
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }
}
