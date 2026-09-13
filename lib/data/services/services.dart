import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chalet_model.dart';
import '../models/models.dart';

// ============================================
// SUPABASE CLIENT
// ============================================
final supabase = Supabase.instance.client;

/// ترجمة رسائل أخطاء قاعدة البيانات (PostgreSQL/Supabase) لرسائل واضحة ومفهومة للمستخدم
String _translateSupabaseError(dynamic error) {
  final msg = error.toString();
  final normalized = msg.toLowerCase();

  if (normalized.contains('booking conflict: overlapping dates') ||
      normalized.contains('overlapping dates') ||
      normalized.contains('booking conflict')) {
    return 'هذا التاريخ محجوز، جرب تواريخ تانية';
  }

  if (normalized.contains('غير مسموح تعديل هذه الحقول من طرفك') ||
      normalized.contains('not allowed to update these fields')) {
    return 'حدث خطأ، حاول مرة أخرى';
  }

  if (normalized.contains('صلاحيات أدمن مطلوبة') ||
      normalized.contains('admin permissions required') ||
      normalized.contains('permission denied')) {
    return 'حدث خطأ، غير مصرح بهذا الإجراء';
  }

  if (normalized.contains('لا يمكن إنشاء دفعة لحجز لا يخصك') ||
      normalized
          .contains('cannot create payment for booking not owned by you')) {
    return 'حدث خطأ في معالجة الدفع';
  }

  if (error is PostgrestException) {
    return error.message;
  }
  if (error is Exception) {
    return error.toString().replaceFirst('Exception: ', '');
  }
  return msg;
}

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
    try {
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
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Update password
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      return await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Get current profile
  Future<UserProfile?> getCurrentProfile() async {
    if (currentUser == null) return null;
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();
      return UserProfile.fromJson(data);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Update profile
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    if (currentUser == null) return;
    try {
      await supabase.from('profiles').update({
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }).eq('id', currentUser!.id);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  Future<bool> becomeOwner() async {
    if (currentUser == null) return false;

    try {
      final result = await supabase.rpc('become_owner');
      return result as bool;
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  Future<bool> becomeCustomer() async {
    if (currentUser == null) return false;

    try {
      final result = await supabase.rpc('become_customer');
      return result as bool;
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
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

/// Holds a pending action requested by a guest that needs authentication.
class PendingAuthAction {
  final String type;
  final Map<String, dynamic> data;
  const PendingAuthAction(this.type, [this.data = const {}]);
}

/// Simple in-memory storage for a pending auth action. Not persisted.
class AuthRedirectService {
  static PendingAuthAction? _pending;

  static void setPendingAction(PendingAuthAction action) {
    _pending = action;
  }

  static PendingAuthAction? consumePendingAction() {
    final a = _pending;
    _pending = null;
    return a;
  }

  static PendingAuthAction? peek() => _pending;
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
    try {
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
        final words = searchQuery
            .trim()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toList();

        final orConditions = <String>[];
        for (final word in words) {
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
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  Future<ChaletModel?> getChaletById(String id) async {
    try {
      final data =
          await supabase.from('chalets').select('*').eq('id', id).single();

      return ChaletModel.fromJson(data);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Get featured chalets
  Future<List<ChaletModel>> getFeaturedChalets({int limit = 6}) async {
    try {
      final data = await supabase
          .from('chalets')
          .select('*')
          .eq('is_available', true)
          .eq('is_approved', true)
          .order('rating', ascending: false)
          .limit(limit);
      return (data as List).map((e) => ChaletModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Check availability
  Future<bool> isAvailable({
    required String chaletId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    try {
      final data = await supabase
          .from('bookings')
          .select()
          .eq('chalet_id', chaletId)
          .inFilter('status', ['pending', 'confirmed'])
          .lt('check_in', checkOut.toIso8601String().split('T').first)
          .gt('check_out', checkIn.toIso8601String().split('T').first);

      return (data as List).isEmpty;
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  Future<List<String>> uploadChaletImages({
    required String chaletId,
    required List<XFile> images,
    required List<Uint8List> imageBytes,
  }) async {
    final uploadedUrls = <String>[];

    for (int i = 0; i < images.length; i++) {
      final xFile = images[i];

      String ext = 'jpg';
      final path = xFile.path.toLowerCase();
      if (!path.startsWith('blob:') && path.contains('.')) {
        final candidate =
            path.split('.').last.replaceAll(RegExp(r'[^a-z]'), '');
        if (['jpg', 'jpeg', 'png', 'webp'].contains(candidate)) {
          ext = candidate == 'jpeg' ? 'jpg' : candidate;
        }
      }

      final contentType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';

      final fileName =
          'chalets/$chaletId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

      try {
        final bytes = i < imageBytes.length && imageBytes[i].isNotEmpty
            ? imageBytes[i]
            : await xFile.readAsBytes();

        if (bytes.isEmpty) continue;

        await supabase.storage.from('chalet-images').uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(
                contentType: contentType,
                cacheControl: '3600',
                upsert: false,
              ),
            );

        final url =
            supabase.storage.from('chalet-images').getPublicUrl(fileName);
        uploadedUrls.add(url);
      } catch (_) {
        continue;
      }
    }

    return uploadedUrls;
  }

  Future<void> _deleteUploadedImageFiles(List<String> publicUrls) async {
    final paths = <String>[];
    for (final url in publicUrls) {
      final uri = Uri.tryParse(url);
      if (uri == null) continue;
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf('chalet-images');
      if (bucketIndex == -1 || bucketIndex == segments.length - 1) continue;
      final relativePath = segments.sublist(bucketIndex + 1).join('/');
      if (relativePath.isNotEmpty) {
        paths.add(relativePath);
      }
    }

    if (paths.isEmpty) return;
    await supabase.storage.from('chalet-images').remove(paths);
  }

  Future<String> createOrUpdateChaletWithImages({
    required bool isEditing,
    String? editingChaletId,
    required String ownerId,
    required Map<String, dynamic> chaletData,
    required List<XFile> newImages,
    required List<Uint8List> newImageBytes,
    required List<String> existingImageUrls,
  }) async {
    String chaletId = isEditing ? (editingChaletId ?? '') : '';
    final uploadedUrls = <String>[];

    try {
      if (!isEditing) {
        final inserted = await supabase
            .from('chalets')
            .insert({
              'owner_id': ownerId,
              'name': chaletData['name'],
              'is_available': false,
              'is_approved': false,
            })
            .select('id')
            .single();

        chaletId = inserted['id'] as String;
      }

      if (chaletId.isEmpty) {
        throw Exception('Invalid chalet id');
      }

      final newUrls = await uploadChaletImages(
        chaletId: chaletId,
        images: newImages,
        imageBytes: newImageBytes,
      );
      uploadedUrls.addAll(newUrls);

      final finalPayload = Map<String, dynamic>.from(chaletData);
      finalPayload['images'] = [...existingImageUrls, ...uploadedUrls];

      await supabase.from('chalets').update(finalPayload).eq('id', chaletId);
      return chaletId;
    } catch (e) {
      if (uploadedUrls.isNotEmpty) {
        await _deleteUploadedImageFiles(uploadedUrls);
      }

      if (!isEditing && chaletId.isNotEmpty) {
        try {
          await supabase.from('chalets').delete().eq('id', chaletId);
        } catch (_) {
          // ignore secondary cleanup failure to preserve original error
        }
      }

      rethrow;
    }
  }

  /// Get the raw, owner-scoped chalet list used by the owner chalets screen.
  /// This keeps the same table, filters, selected columns and ordering as the
  /// original screen query, while returning the same Map-shaped rows the UI
  /// expects.
  Future<List<Map<String, dynamic>>> getOwnerChalets(String ownerId) async {
    try {
      final data = await supabase
          .from('chalets')
          .select(
            'id, name, city, location, price_per_night, images, is_available, is_approved, rating, reviews_count',
          )
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false);

      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Get external-type chalets owned by the current owner.
  Future<List<Map<String, dynamic>>> getOwnerExternalChalets(
      String ownerId) async {
    try {
      final data = await supabase
          .from('chalets')
          .select('id, name')
          .eq('owner_id', ownerId)
          .eq('booking_type', 'خارجي');

      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
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

  /// Get booked dates for a chalet (for calendar display)
  Future<List<DateTime>> getBookedDates(String chaletId) async {
    try {
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
  Future<List<BookingModel>> getIncomingBookings() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final data = await supabase
          .from('bookings')
          .select(
            '*, chalets!inner(name, city, owner_id, images), '
            'profiles(full_name, phone, avatar_url)',
          )
          .eq('chalets.owner_id', userId)
          .order('created_at', ascending: false);

      return (data as List).map((e) => BookingModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Confirm booking (owner action)
  Future<void> confirmIncomingBooking(String bookingId) async {
    try {
      await supabase
          .from('bookings')
          .update({'status': 'confirmed'}).eq('id', bookingId);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Reject booking (owner action)
  Future<void> rejectIncomingBooking(String bookingId) async {
    try {
      await supabase
          .from('bookings')
          .update({'status': 'rejected'}).eq('id', bookingId);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Get my bookings (for customer)
  Future<List<BookingModel>> getMyBookings() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final data = await supabase
          .from('bookings')
          .select('*, chalets(name, city, images)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (data as List).map((e) => BookingModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Cancel booking
  Future<void> cancelBooking(String bookingId) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', bookingId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Get external bookings for a list of chalet IDs owned by this user.
  Future<List<Map<String, dynamic>>> getOwnerExternalBookings(
      List<String> chaletIds) async {
    if (chaletIds.isEmpty) return const [];

    try {
      final data = await supabase
          .from('bookings')
          .select(
            'id, chalet_id, check_in, check_out, total_price, status, notes, '
            'chalets!inner(name)',
          )
          .inFilter('chalet_id', chaletIds)
          .order('check_in', ascending: false)
          .limit(100);

      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Delete an external booking record by id.
  Future<void> deleteBookingRecord(String bookingId) async {
    try {
      await supabase.from('bookings').delete().eq('id', bookingId);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Create an external booking using the same RPC and parameters currently used
  /// in the owner external booking flow.
  Future<void> createExternalBooking({
    required String chaletId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guestsCount,
    required double totalPrice,
    required String guestName,
    required String guestPhone,
    String? notes,
    String stayType = 'خارجي',
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

    try {
      final data = await supabase
          .from('favorites')
          .select('chalets(*)')
          .eq('user_id', userId);

      return (data as List)
          .map(
              (e) => ChaletModel.fromJson(e['chalets'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  Future<Set<String>> getFavoriteIds() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return {};

    try {
      final data = await supabase
          .from('favorites')
          .select('chalet_id')
          .eq('user_id', userId);

      return (data as List).map((e) => e['chalet_id'] as String).toSet();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// ✅ مُصلَّح (كان فيه Race Condition): قبل هيك كانت الدالة تعمل عمليتين
  /// منفصلتين (SELECT للتحقق ثم INSERT أو DELETE)، وهاد كان يسبب نتيجة
  /// غير متوقعة لو ضُغط زر الإعجاب مرتين بسرعة (لأنه بين السؤال والتنفيذ
  /// في فسحة زمنية ممكن يتغير فيها الوضع من طلب متزامن آخر).
  ///
  /// الحل: صرنا نستدعي دالة SQL واحدة اسمها toggle_favorite تعمل كل شي
  /// بخطوة ذرية محمية داخل قاعدة البيانات نفسها (قفل على مستوى الصف)،
  /// وترجع لنا الحالة الحقيقية النهائية: true = تمت الإضافة فعليًا،
  /// false = تمت الإزالة فعليًا. هيك الواجهة دايمًا تعرض الحالة الصحيحة
  /// المطابقة لقاعدة البيانات، بغض النظر عن سرعة الضغط.
  Future<bool> toggleFavorite(String chaletId) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) {
      throw Exception('يجب تسجيل الدخول أولاً');
    }

    try {
      final result = await supabase.rpc('toggle_favorite', params: {
        'p_chalet_id': chaletId,
      });

      return result as bool;
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
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

    try {
      await supabase.from('reviews').insert({
        'chalet_id': chaletId,
        'user_id': userId,
        'booking_id': bookingId,
        'rating': rating,
        'comment': comment,
      });
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
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

    try {
      final data = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (data as List).map((e) => NotificationModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  Future<void> markAllAsRead() async {
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }
}
