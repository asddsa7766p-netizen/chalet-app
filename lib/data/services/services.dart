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
    var query = supabase.from('chalets').select().eq('is_available', true);

    if (city != null && city.isNotEmpty && city != 'الكل') {
      query = query.eq('city', city);
    }
    if (minPrice != null) query = query.gte('price_per_night', minPrice);
    if (maxPrice != null) query = query.lte('price_per_night', maxPrice);
    if (hasPool == true) query = query.eq('has_pool', true);
    if (hasWifi == true) query = query.eq('has_wifi', true);
    if (minGuests != null) query = query.gte('max_guests', minGuests);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or(
        'name.ilike.%$searchQuery%,'
        'location.ilike.%$searchQuery%,'
        'city.ilike.%$searchQuery%',
      );
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List).map((e) => ChaletModel.fromJson(e)).toList();
  }

  /// Get single chalet
  Future<ChaletModel?> getChaletById(String id) async {
    final data = await supabase.from('chalets').select().eq('id', id).single();
    return ChaletModel.fromJson(data);
  }

  /// Get featured chalets (top rated)
  Future<List<ChaletModel>> getFeaturedChalets({int limit = 6}) async {
    final data = await supabase
        .from('chalets')
        .select()
        .eq('is_available', true)
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
        // Overlap logic:
        // Bookings conflict if existing.check_in < requested.check_out
        // and existing.check_out > requested.check_in
        .lt('check_in', checkOut.toIso8601String().split('T').first)
        .gt('check_out', checkIn.toIso8601String().split('T').first);

    final list = data;
    return list.isEmpty;
  }
}

// ============================================
// BOOKING SERVICE
// ============================================
class BookingService {
  /// Host view: Get incoming bookings for the current owner.
  /// - Incoming = pending
  /// UI will still allow switching tabs for other statuses (confirmed/cancelled).
  Future<List<IncomingBookingModel>> getIncomingBookings({
    BookingStatus status = BookingStatus.pending,
  }) async {
    final ownerId = AuthService.instance.currentUser?.id;
    if (ownerId == null) return [];

    // bookings.id, bookings.user_id, bookings.check_in, bookings.status, bookings.payment_method
    // join profiles for user full_name
    // join chalets to filter by chalets.owner_id
    final data = await supabase
        .from('bookings')
        .select(
            'id, chalet_id, user_id, check_in, status, payment_method, profiles(full_name)')
        .eq('status', status.name)
        .eq('chalets.owner_id', ownerId);

    return (data as List)
        .map((e) => IncomingBookingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Owner: confirm pending booking.
  Future<void> confirmIncomingBooking(String bookingId) async {
    await supabase
        .from('bookings')
        .update({'status': 'confirmed'}).eq('id', bookingId);
  }

  /// Owner: reject pending booking.
  Future<void> rejectIncomingBooking(String bookingId) async {
    await supabase
        .from('bookings')
        .update({'status': 'cancelled'}).eq('id', bookingId);
  }

  /// Edge Function: calculate booking price + availability
  /// Throws an exception for non-200 responses.
  Future<double> calculateBookingPrice({
    required String chaletId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guestsCount,
  }) async {
    final response = await supabase.functions.invoke(
      'calculate-booking-price',
      body: {
        'chaletId': chaletId,
        'checkIn': checkIn.toIso8601String(),
        'checkOut': checkOut.toIso8601String(),
        'guestsCount': guestsCount,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final totalPrice = data['totalPrice'];
    if (totalPrice == null) {
      throw Exception('Invalid price response');
    }
    return (totalPrice as num).toDouble();
  }

  static BookingService? _instance;
  static BookingService get instance => _instance ??= BookingService._();
  BookingService._();

  final _auth = AuthService.instance;

  /// Create booking
  Future<BookingModel> createBooking({
    required String chaletId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guestsCount,
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    // Security: never accept price from the client.
    // Store only the booking core data here; compute total_price server-side (Edge Function / trigger).
    final userId = _auth.currentUser!.id;
    final data = await supabase
        .from('bookings')
        .insert({
          'chalet_id': chaletId,
          'user_id': userId,
          'check_in': checkIn.toIso8601String().split('T').first,
          'check_out': checkOut.toIso8601String().split('T').first,
          'guests_count': guestsCount,
          'status': 'pending',
          'payment_method': paymentMethod,
          'notes': notes,
        })
        .select()
        .single();
    return BookingModel.fromJson(data);
  }

  /// Get user bookings
  Future<List<BookingModel>> getMyBookings({String? status}) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return [];

    var query = supabase
        .from('bookings')
        .select('*, chalets(name, images, city)')
        .eq('user_id', userId);

    if (status != null) query = query.eq('status', status);

    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  /// Cancel booking
  Future<void> cancelBooking(String bookingId) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;

    // IDOR fix: only cancel if the booking belongs to the current user.
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
        .map((e) => ChaletModel.fromJson(e['chalets']))
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

    // Determine current favorite state to avoid relying on insert exceptions.
    final existing = await supabase
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('chalet_id', chaletId)
        .limit(1);

    final isFav = existing.isNotEmpty;

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
    final data = await supabase
        .from('reviews')
        .select('*, profiles(full_name, avatar_url)')
        .eq('chalet_id', chaletId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => ReviewModel.fromJson(e)).toList();
  }

  Future<void> addReview({
    required String chaletId,
    required int rating,
    String? comment,
    String? bookingId,
  }) async {
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) return;

    // Reviews security: only allow when user has a completed booking.
    // Prefer bookingId if provided; otherwise validate by chaletId.
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
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) return;
    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', userId);
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
