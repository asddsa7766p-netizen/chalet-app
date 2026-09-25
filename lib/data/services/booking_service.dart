part of 'services.dart';

// ============================================
// BOOKING SERVICE
// ============================================
class BookingService {
  static BookingService? _instance;
  static BookingService get instance => _instance ??= BookingService._();
  BookingService._();

  final _auth = AuthService.instance;

  /// نوع الإقامة الافتراضي (السلوك القديم قبل دعم أنواع الإقامة).
  static const String defaultStayType = 'default';

  /// Calculate booking price using per-day pricing (weekday prices +
  /// date-specific overrides + fallback price_per_night) **لنوع إقامة
  /// معيّن**. يستدعي دالة SQL موحّدة على السيرفر (calculate_chalet_stay_price)
  /// بدل الضرب اليدوي بسعر ثابت، عشان يحترم أسعار الأيام المختلفة ونوع
  /// الإقامة المختار (صباحية/مسائية/يوم كامل...) اللي حددها صاحب الشاليه.
  ///
  /// ✅ جديد: باراميتر stayType — لو تُرك بقيمته الافتراضية 'default' فالسلوك
  /// يطابق تمامًا النظام القديم (سعر يوم بالأسبوع بدون تصنيف نوع إقامة).
  Future<double> calculateBookingPrice({
    required String chaletId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guestsCount,
    String stayType = defaultStayType,
  }) async {
    final nights = nightsBetween(checkIn, checkOut);
    if (nights <= 0) throw Exception('تواريخ غير صحيحة');

    final checkInStr = checkIn.toIso8601String().split('T').first;
    final checkOutStr = checkOut.toIso8601String().split('T').first;

    try {
      final result = await supabase.rpc(
        'calculate_chalet_stay_price',
        params: {
          'p_chalet_id': chaletId,
          'p_check_in': checkInStr,
          'p_check_out': checkOutStr,
          'p_stay_type': stayType,
        },
      );

      return (result as num).toDouble();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Create booking
  Future<BookingModel> createBooking({
    required String chaletId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guestsCount,
    required double totalPrice,
    String paymentMethod = 'cash',
    String? notes,
    String stayType = defaultStayType,
  }) async {
    final userId = _auth.currentUser!.id;
    try {
      final data = await supabase
          .from('bookings')
          .insert({
            'chalet_id': chaletId,
            'user_id': userId,
            'check_in': checkIn.toIso8601String().split('T').first,
            'check_out': checkOut.toIso8601String().split('T').first,
            'guests_count': guestsCount,
            'total_price': totalPrice,
            'status': 'pending',
            'payment_method': paymentMethod,
            'notes': notes,
            'stay_type': stayType,
          })
          .select()
          .single();
      return BookingModel.fromJson(data);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// توفر الفترات (صباحية/مسائية) لكل يوم لشاليه، من [from] (افتراضياً
  /// اليوم) لمدى تقويم الضيف. تمرّ عبر دالة القاعدة لأن الضيف لا يقرأ حجوزات
  /// غيره، وهي المصدر الوحيد الذي يميّز حجز الفترتين معاً (تقويم الضيف
  /// وورقة الحجز اليدوي).
  Future<Map<DateTime, ChaletDaySlot>> getDaySlots(
    String chaletId, {
    DateTime? from,
    @visibleForTesting RpcCaller? rpc,
  }) async {
    try {
      return await ChaletSlotAvailability.load(
        chaletId,
        from: from ?? DateTime.now(),
        rpc: rpc,
      );
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Get incoming bookings for owner.
  ///
  /// ✅ يعرض كل حالات الحجز (قيد الانتظار/مؤكد/مرفوض/ملغي/مكتمل) المرتبطة
  /// بشاليهات المالك، مع بيانات الضيف (full_name / phone / avatar_url) من
  /// جدول profiles عبر JOIN — RLS يسمح بقراءتها للحجوزات المرتبطة فعليًا
  /// بشاليهات المالك، بغض النظر عن حالة الحجز.
  ///
  /// مرقّمة بصفحات [bookingsPageSize] (الأحدث إنشاءً أولاً).
  Future<List<BookingModel>> getIncomingBookings({int page = 0}) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final data = await _incomingQuery(userId)
          .order('created_at', ascending: false)
          .range(_pageStart(page), _pageEnd(page));
      return _toBookings(data);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// أقرب حجوزات المالك القادمة (قيد الانتظار أو مؤكدة، وصول اليوم أو بعده).
  Future<List<BookingModel>> getUpcomingIncomingBookings({int limit = 3}) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final data = await _incomingQuery(userId)
          .inFilter('status', ['pending', 'confirmed'])
          .gte('check_in', _isoDate(DateTime.now()))
          .order('check_in', ascending: true)
          .limit(limit);
      return _toBookings(data);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// عدد طلبات الحجز بانتظار قرار المالك (عدّ على السيرفر، بلا جلب الصفوف).
  Future<int> countPendingIncomingBookings() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final res = await supabase
          .from('bookings')
          .select('id, chalets!inner(owner_id)')
          .eq('chalets.owner_id', userId)
          .eq('status', 'pending')
          .count(CountOption.exact);
      return res.count;
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// الحجوزات اليدوية (source = 'external') لشاليهات المالك، مقسومة على آخر
  /// يوم محجوز (check_out هو اليوم التالي له): القادمة بالأقرب أولاً،
  /// والمنتهية بالأحدث أولاً. كل قسم مرقّم بصفحات [bookingsPageSize].
  Future<List<BookingModel>> getManualBookings({
    required bool upcoming,
    int page = 0,
  }) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return [];

    final today = _isoDate(DateTime.now());
    try {
      final base = _incomingQuery(userId).eq('source', 'external');
      final data = await (upcoming
              ? base.gt('check_out', today).order('check_in', ascending: true)
              : base.lte('check_out', today).order('check_in', ascending: false))
          .range(_pageStart(page), _pageEnd(page));
      return _toBookings(data);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  static const bookingsPageSize = 30;
  static int _pageStart(int page) => page * bookingsPageSize;
  static int _pageEnd(int page) => _pageStart(page) + bookingsPageSize - 1;
  static String _isoDate(DateTime d) => d.toIso8601String().split('T').first;
  static List<BookingModel> _toBookings(dynamic data) => (data as List)
      .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
      .toList();

  PostgrestFilterBuilder<PostgrestList> _incomingQuery(String ownerId) =>
      supabase
          .from('bookings')
          .select(
            '*, chalets!inner(name, city, owner_id, images, '
            '$bookingPeriodColumns), '
            'profiles(full_name, phone, avatar_url)',
          )
          .eq('chalets.owner_id', ownerId);

  /// Confirm booking (owner action)
  Future<void> confirmIncomingBooking(String bookingId) =>
      _setIncomingBookingStatus(bookingId, 'confirmed');

  /// Reject booking (owner action)
  Future<void> rejectIncomingBooking(String bookingId) =>
      _setIncomingBookingStatus(bookingId, 'rejected');

  /// رفض RLS لا يرمي خطأً: UPDATE يمرّ بصمت ويعدّل صفر صفوف، فكانت تظهر
  /// للمالك رسالة "نجاح" كاذبة. .select() يرجع الصفوف المعدَّلة فعلاً.
  Future<void> _setIncomingBookingStatus(String bookingId, String status) async {
    final List<dynamic> rows;
    try {
      rows = await supabase
          .from('bookings')
          .update({'status': status})
          .eq('id', bookingId)
          .select('id');
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
    if (rows.isEmpty) throw Exception(bookingNotUpdatedMessage);
  }

  /// حجوزات الزبون بالحالات [statuses]، مرقّمة بصفحات [bookingsPageSize]
  /// (الأحدث إنشاءً أولاً).
  Future<List<BookingModel>> getMyBookings({
    required List<String> statuses,
    int page = 0,
  }) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final data = await supabase
          .from('bookings')
          .select('*, chalets(name, city, images, $bookingPeriodColumns)')
          .eq('user_id', userId)
          .inFilter('status', statuses)
          .order('created_at', ascending: false)
          .range(_pageStart(page), _pageEnd(page));
      return _toBookings(data);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// عدد حجوزات الزبون بحالة معيّنة (عدّ على السيرفر).
  Future<int> countMyBookings(String status) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final res = await supabase
          .from('bookings')
          .select('id')
          .eq('user_id', userId)
          .eq('status', status)
          .count(CountOption.exact);
      return res.count;
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Cancel booking
  Future<void> cancelBooking(String bookingId) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;

    final List<dynamic> rows;
    try {
      rows = await supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', bookingId)
          .eq('user_id', userId)
          .select('id');
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
    if (rows.isEmpty) throw Exception(bookingNotUpdatedMessage);
  }

  /// Cancel a manual (owner-entered) booking through cancel_external_booking.
  ///
  /// الدالة ترفض (برسائل عربية) إن لم يكن المستدعي مالك الشاليه، أو لم يكن
  /// الحجز يدوياً، أو كان ملغى مسبقاً. الإلغاء يحرّر التواريخ.
  Future<void> cancelExternalBooking(String bookingId) async {
    try {
      await supabase.rpc(
        'cancel_external_booking',
        params: {'p_booking_id': bookingId},
      );
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Create a manual (owner-entered) booking through create_external_booking.
  ///
  /// [totalPrice] هو السعر المتفق عليه مع الضيف ويُستخدم كما هو (السيرفر
  /// يرفض ≤ 0، ولو أُرسل null يرجع لسعر التقويم). لا عمولة على الحجز اليدوي.
  /// نوع الإقامة الافتراضي 'default' لأن bookings_stay_type_check يرفض 'خارجي'.
  Future<void> createExternalBooking({
    required String chaletId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guestsCount,
    required double totalPrice,
    required String guestName,
    required String guestPhone,
    String? notes,
    String stayType = defaultStayType,
  }) async {
    try {
      await supabase.rpc(
        'create_external_booking',
        params: {
          'p_chalet_id': chaletId,
          'p_check_in': checkIn.toIso8601String().split('T').first,
          'p_check_out': checkOut.toIso8601String().split('T').first,
          'p_guests_count': guestsCount,
          'p_total_price': totalPrice,
          'p_guest_name': guestName,
          'p_guest_phone': guestPhone,
          'p_notes': notes,
          'p_stay_type': stayType,
        },
      );
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }
}
