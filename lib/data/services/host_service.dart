import 'package:supabase_flutter/supabase_flutter.dart';

final _supabaseHost = Supabase.instance.client;

class HostService {
  static HostService? _instance;
  static HostService get instance => _instance ??= HostService._();
  HostService._();

  /// Returns true if current user owns at least one chalet.
  Future<bool> isHost() async {
    final userId = _supabaseHost.auth.currentUser?.id;
    if (userId == null) return false;

    final data = await _supabaseHost
        .from('chalets')
        .select('id')
        .eq('owner_id', userId)
        .limit(1);

    // supabase_flutter returns a List when the query is successful.
    // Be defensive in case of unexpected response shape.
    final list = data;
    return list.isNotEmpty;
  }
}
