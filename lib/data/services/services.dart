import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chalet_model.dart';
import '../models/models.dart';

// ============================================
// SUPABASE CLIENT
// ============================================
final supabase = Supabase.instance.client;

// ============================================
// AUTH SERVICE
// ============================================
class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();

  User? get currentUser => supabase.auth.currentUser;
  Session? get currentSession => supabase.auth.currentSession;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'phone': phone},
    );

    if (response.user != null) {
      await supabase.from('profiles').upsert({
        'id': response.user!.id,
        'full_name': fullName,
        'phone': phone,
        'email': email,
      });
    }

    return response;
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() => supabase.auth.signOut();

  /// Reset password
  Future<void> resetPassword(String email) =>
      supabase.auth.resetPasswordForEmail(email);

  /// Update password
  Future<UserResponse> updatePassword(String newPassword) =>
      supabase.auth.updateUser(UserAttributes(password: newPassword));

  /// Get current profile
  Future<UserProfile?> getCurrentProfile() async {
    if (currentUser == null) return null;
    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', currentUser!.id)
        .single();
    return UserProfile.fromJson(data);
  }

  /// Update profile
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    if (currentUser == null) return;
    await supabase.from('profiles').update({
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    }).eq('id', currentUser!.id);
  }

  Future<bool> becomeOwner() async {
    if (currentUser == null) return false;

    final result = await supabase.rpc('become_owner');
    return result as bool;
  }

  Future<bool> becomeCustomer() async {
    if (currentUser == null) return false;

    final result = await supabase.rpc('become_customer');
    return result as bool;
  }

  /// Cached admin check.
  /// Returns true if the current user's profile has is_admin = true.
  bool? _isAdminCache;
  Future<bool> isAdmin() async {
    if (_isAdminCache != null) return _isAdminCache!;
    final userId = currentUser?.id;
    if (userId == null) return false;
    try {
      final row = await supabase
          .from('profiles')
          .select('is_admin')
          .eq('id', userId)
          .maybeSingle();
      _isAdminCache = (row?['is_admin'] as bool?) ?? false;
      return _isAdminCache!;
    } catch (_) {
      return false;
    }
  }

  void clearAdminCache() {
    _isAdminCache = null;
  }
}

// ============================================
// CHALET SERVICE
// ============================================
class ChaletService {
  static ChaletService? _instance;
  static ChaletService get instance => _instance ??= ChaletService._();
  ChaletService._();

  /// Get all chalets with optional filters
  Future<List<ChaletModel>> getChalets({
    String? city,
    double? minPrice,
    double? maxPrice,
    bool? hasPool,
    bool? hasWifi,
    int? minGuests,
    String? searchQuery,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = supabase
        .from('chalets')
        .select('*')
        .eq('is_available', true)
        .eq('is_approved', true);

    if (city != null && city.isNotEmpty && city != 'الكل') {
      query = query.eq('city', city);
    }
    if (minPrice != null) query = query.gte('price_per_night', minPrice);
    if (maxPrice != null) query = query.lte('price_per_night', maxPrice);
    if (hasPool == true) query = query.eq('has_pool', true);
    if (hasWifi == true) query = query.eq('has_wifi', true);
    if (minGuests != null) query = query.gte('max_guests', minGuests);

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      // نقسّم النص المدخل لكلمات (يدعم "شاليهات جنين" فيبحث عن
      // "شاليهات" أو "جنين" بدل ما يدور عن الجملة كاملة كسلسلة متصلة).
      final words = searchQuery
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      final orConditions = <String>[];
      for (final word in words) {
        // نهرب أي فاصلة داخل الكلمة حتى لا تكسر صيغة .or() في PostgREST
        final safeWord = word.replaceAll(',', '');
        orConditions.add('name.ilike.%$safeWord%');
        orConditions.add('location.ilike.%$safeWord%');
        orConditions.add('city.ilike.%$safeWord%');
      }

      if (orConditions.isNotEmpty) {
        query = query.or(orConditions.join(','));
      }
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List).map((e) => ChaletModel.fromJson(e)).toList();
  }

  Future<ChaletModel?> getChaletById(String id) async {
    final data =
        await supabase.from('chalets').select('*').eq('id', id).single();

    return ChaletModel.fromJson(data);
  }

  /// Get featured chalets
  Future<List<ChaletModel>> getFeaturedChalets({int limit = 6}) async {
    final data = await supabase
        .from('chalets')
        .select('*')
        .eq('is_available', true)
        .eq('is_approved', true)
        .order('rating', ascending: false)
        .limit(limit);
    return (data as List).map((e) => ChaletModel.fromJson(e)).toList();
  }

  /// Check availability
  Future<bool> isAvailable({
    required String chaletId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    final data = await supabase
        .from('bookings')
        .select()
        .eq('chalet_id', chaletId)
        .inFilter('status', ['pending', 'confirmed'])
        .lt('check_in', checkOut.toIso8601String().split('T').first)
        .gt('check_out', checkIn.toIso8601String().split('T').first);

    return (data as List).isEmpty;
  }
}

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
    final nights = checkOut.difference(checkIn).inDays;
    if (nights <= 0) throw Exception('تواريخ غير صحيحة');

    final checkInStr = checkIn.toIso8601String().split('T').first;
    final checkOutStr = checkOut.toIso8601String().split('T').first;

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
  }

  /// Get booked dates for a chalet (for calendar display)
  Future<List<DateTime>> getBookedDates(String chaletId) async {
    final data = await supabase
        .from('bookings')
        .select('check_in, check_out')
        .eq('chalet_id', chaletId)
        .inFilter('status', ['pending', 'confirmed']);

    final List<DateTime> dates = [];
    for (final row in data as List) {
      DateTime current = DateTime.parse(row['check_in'] as String);
      final end = DateTime.parse(row['check_out'] as String);
      while (current.isBefore(end)) {
        dates.add(DateTime(current.year, current.month, current.day));
        current = current.add(const Duration(days: 1));
      }
    }
    return dates;
  }

  /// Get incoming bookings for owner
  Future<List<BookingModel>> getIncomingBookings() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return [];
    final data = await supabase
        .from('bookings')
        .select(
          '*, chalets!inner(name, city, owner_id, images)',
        )
        .eq('status', 'pending')
        .eq('chalets.owner_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  /// Confirm booking (owner action)
  Future<void> confirmIncomingBooking(String bookingId) async {
    await supabase
        .from('bookings')
        .update({'status': 'confirmed'}).eq('id', bookingId);
  }

  /// Reject booking (owner action)
  Future<void> rejectIncomingBooking(String bookingId) async {
    await supabase
        .from('bookings')
        .update({'status': 'rejected'}).eq('id', bookingId);
  }

  /// Get my bookings (for customer)
  Future<List<BookingModel>> getMyBookings() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return [];

    final data = await supabase
        .from('bookings')
        .select('*, chalets(name, city, images)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  /// Cancel booking
  Future<void> cancelBooking(String bookingId) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from('bookings')
        .update({'status': 'cancelled'})
        .eq('id', bookingId)
        .eq('user_id', userId);
  }
}

// ============================================
// FAVORITES SERVICE
// ============================================
class FavoritesService {
  static FavoritesService? _instance;
  static FavoritesService get instance => _instance ??= FavoritesService._();
  FavoritesService._();

  final _auth = AuthService.instance;

  Future<List<ChaletModel>> getFavorites() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return [];

    final data = await supabase
        .from('favorites')
        .select('chalets(*)')
        .eq('user_id', userId);

    return (data as List)
        .map((e) => ChaletModel.fromJson(e['chalets'] as Map<String, dynamic>))
        .toList();
  }

  Future<Set<String>> getFavoriteIds() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return {};

    final data = await supabase
        .from('favorites')
        .select('chalet_id')
        .eq('user_id', userId);

    return (data as List).map((e) => e['chalet_id'] as String).toSet();
  }

  Future<void> toggleFavorite(String chaletId) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;

    final existing = await supabase
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('chalet_id', chaletId)
        .limit(1);

    final isFav = (existing as List).isNotEmpty;

    if (isFav) {
      await supabase
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('chalet_id', chaletId);
    } else {
      await supabase.from('favorites').insert({
        'user_id': userId,
        'chalet_id': chaletId,
      });
    }
  }
}

// ============================================
// REVIEWS SERVICE
// ============================================
class ReviewsService {
  static ReviewsService? _instance;
  static ReviewsService get instance => _instance ??= ReviewsService._();
  ReviewsService._();

  Future<List<ReviewModel>> getChaletReviews(String chaletId) async {
    final data = await supabase.rpc('get_chalet_reviews_with_author', params: {
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

    if (!hasCompletedBooking) return;

    await supabase.from('reviews').insert({
      'chalet_id': chaletId,
      'user_id': userId,
      'booking_id': bookingId,
      'rating': rating,
      'comment': comment,
    });
  }
}

// ============================================
// NOTIFICATIONS SERVICE
// ============================================
class NotificationsService {
  static NotificationsService? _instance;
  static NotificationsService get instance =>
      _instance ??= NotificationsService._();
  NotificationsService._();

  Future<List<NotificationModel>> getNotifications() async {
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) return [];

    final data = await supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => NotificationModel.fromJson(e)).toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await supabase
        .from('notifications')
        .update({'is_read': true}).eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }
}
