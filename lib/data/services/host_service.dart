import 'package:supabase_flutter/supabase_flutter.dart';

final _supabaseHost = Supabase.instance.client;

class HostService {
  static HostService? _instance;
  static HostService get instance => _instance ??= HostService._();
  HostService._();

  /// Returns true if current user role is owner (profiles.role = 'owner').
  /// This allows users to enter host flow before creating any chalets.
  Future<bool> isHost() async {
    final userId = _supabaseHost.auth.currentUser?.id;
    if (userId == null) return false;

    final data = await _supabaseHost
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

    final role = (data?['role'] as String?)?.toLowerCase();
    return role == 'owner';
  }
}
