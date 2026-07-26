// lib/presentation/controllers/owner_bookings_controller.dart
//
// ARCH-01: فصل منطق الحجوزات عن OwnerBookingsScreen
// الشاشة تستدعي Controller فقط، لا تعرف شيئاً عن Services مباشرة.

import 'package:flutter/foundation.dart';
import 'package:friends_chalets/data/models/models.dart';
import 'package:friends_chalets/data/services/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerBookingsController extends ChangeNotifier {
  List<BookingModel> bookings = [];
  bool loading = false;
  bool actionLoading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      bookings = await BookingService.instance.getIncomingBookings();
    } catch (_) {
      error = 'تعذر تحميل الحجوزات، اسحب للأسفل للمحاولة';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> confirm(String bookingId) async {
    if (actionLoading) return false;
    actionLoading = true;
    notifyListeners();
    try {
      await BookingService.instance.confirmIncomingBooking(bookingId);
      await load();
      return true;
    } catch (_) {
      return false;
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<bool> reject(String bookingId) async {
    if (actionLoading) return false;
    actionLoading = true;
    notifyListeners();
    try {
      await BookingService.instance.rejectIncomingBooking(bookingId);
      await load();
      return true;
    } catch (_) {
      return false;
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/presentation/controllers/owner_chalets_controller.dart

class OwnerChaletsController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> chalets = [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    final ownerId = AuthService.instance.currentUser?.id;
    if (ownerId == null) {
      error = 'لا يوجد مستخدم مسجل دخول';
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _supabase
          .from('chalets')
          .select(
            'id, name, city, location, price_per_night, images, '
            'is_available, is_approved, rating, reviews_count',
          )
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false);
      chalets = (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      error = 'تعذر تحميل الشاليهات، اسحب للأسفل للمحاولة';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
