import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  static AdminService? _instance;
  static AdminService get instance => _instance ??= AdminService._();
  AdminService._();

  final _supabase = Supabase.instance.client;

  Future<bool> isCurrentUserAdmin() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final row = await _supabase
        .from('profiles')
        .select('is_admin')
        .eq('id', userId)
        .maybeSingle();
    return (row?['is_admin'] as bool?) ?? false;
  }

  Future<Map<String, dynamic>> getOverviewStats() async {
    // Mirrors the queries and client-side revenue logic in the widget.
    final usersRes = await _supabase.from('profiles').select('id').count();
    final ownersRes = await _supabase
        .from('profiles')
        .select('id')
        .eq('is_owner', true)
        .count();
    final chaletsRes = await _supabase.from('chalets').select('id').count();
    final pendingRes = await _supabase
        .from('chalets')
        .select('id')
        .eq('is_approved', false)
        .count();
    final bookingsRows =
        await _supabase.from('bookings').select('total_price, status');

    double revenue = 0;
    for (final row in (bookingsRows as List)) {
      final map = row as Map<String, dynamic>;
      final status = map['status'] as String? ?? '';
      if (status == 'confirmed' || status == 'completed') {
        revenue += (map['total_price'] as num?)?.toDouble() ?? 0;
      }
    }

    return {
      'totalUsers': usersRes.count,
      'totalOwners': ownersRes.count,
      'totalChalets': chaletsRes.count,
      'pendingChalets': pendingRes.count,
      'totalBookings': (bookingsRows as List).length,
      'totalRevenue': revenue,
    };
  }

  Future<List<Map<String, dynamic>>> getPendingChalets() async {
    final data = await _supabase
        .from('chalets')
        .select('id, name, city, location, price_per_night, images, created_at')
        .eq('is_approved', false)
        .order('created_at', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final data = await _supabase
        .from('profiles')
        .select(
            'id, full_name, email, is_owner, is_admin, is_active, created_at')
        .order('created_at', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
  }
}
