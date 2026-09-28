part of 'services.dart';

// ============================================
// REVIEWS SERVICE
// ============================================
class ReviewsService {
  static ReviewsService? _instance;
  static ReviewsService get instance => _instance ??= ReviewsService._();
  ReviewsService._();

  static const reviewsPageSize = 20;

  /// get_chalet_reviews_with_author ترجع TABLE، فيطبّق PostgREST عليها
  /// select/order/range على السيرفر (ترتيب الدالة الداخلي يُستبدل).
  PostgrestFilterBuilder<dynamic> _reviewsRpc(String chaletId) =>
      supabase.rpc('get_chalet_reviews_with_author',
          params: {'p_chalet_id': chaletId});

  /// صفحة من تقييمات الشاليه بالترتيب [sort] (id آخر مفتاح ليبقى الترقيم
  /// ثابتاً بين الصفحات عند تساوي التقييم والتاريخ).
  Future<List<ReviewModel>> getChaletReviewsPage(
    String chaletId, {
    ReviewSort sort = ReviewSort.newest,
    int page = 0,
    int pageSize = reviewsPageSize,
  }) async {
    try {
      final q = _reviewsRpc(chaletId);
      final ordered = switch (sort) {
        ReviewSort.newest => q.order('created_at'),
        ReviewSort.highest =>
          q.order('rating').order('created_at'),
        ReviewSort.lowest =>
          q.order('rating', ascending: true).order('created_at'),
      };
      final start = page * pageSize;
      final data =
          await ordered.order('id').range(start, start + pageSize - 1);
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

  /// العدد والمتوسط والتوزيع من كل تقييمات الشاليه (عمود rating فقط).
  Future<ReviewSummary> getChaletReviewSummary(String chaletId) async {
    try {
      final data = await _reviewsRpc(chaletId).select('rating');
      return ReviewSummary.fromRatings(
          (data as List).map((r) => (r['rating'] as num).toInt()));
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// أيّ من [bookingIds] قيّمه المستخدم الحالي.
  Future<Set<String>> reviewedBookingIds(List<String> bookingIds) async {
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null || bookingIds.isEmpty) return {};
    try {
      final data = await supabase
          .from('reviews')
          .select('booking_id')
          .eq('user_id', userId)
          .inFilter('booking_id', bookingIds);
      return (data as List)
          .map((r) => r['booking_id'] as String?)
          .whereType<String>()
          .toSet();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// أحدث إقامة مكتملة للمستخدم لم يقيّمها بعد (اختيارياً بشاليه معيّن)، أو
  /// null. إشعار "كيف كانت إقامتك؟" (type = review من
  /// process_booking_lifecycle) لا يحمل رقم الحجز، فيفتح التقييم لهذه.
  Future<BookingModel?> latestBookingAwaitingReview({String? chaletId}) async {
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) return null;
    try {
      var q = supabase
          .from('bookings')
          .select('*, chalets(name, city, images, $bookingPeriodColumns)')
          .eq('user_id', userId)
          .eq('status', 'completed');
      if (chaletId != null) q = q.eq('chalet_id', chaletId);
      final bookings = BookingService._toBookings(
          await q.order('check_in').limit(reviewsPageSize));
      final reviewed =
          await reviewedBookingIds([for (final b in bookings) b.id]);
      for (final b in bookings) {
        if (!reviewed.contains(b.id)) return b;
      }
      return null;
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
      // unique_review_per_booking (23505): الترجمة العامة كانت ستعرض "هذه
      // الفترة محجوزة".
      if (e is PostgrestException && e.code == '23505') {
        throw Exception('already_reviewed');
      }
      throw Exception(_translateSupabaseError(e));
    }
  }
}
