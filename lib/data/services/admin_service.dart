import 'package:supabase_flutter/supabase_flutter.dart';

/// إحصائيات لوحة الأدمن كما تُرجعها admin_get_overview_stats (مجمَّعة على
/// السيرفر بدل جلب كل صفوف المنصة وجمعها بالتطبيق).
///
/// الحجوزات والإيرادات حجوزات التطبيق فقط (source = 'app')، ومفلترة بتاريخ
/// الوصول عند تمرير مدى؛ أعداد المستخدمين والشاليهات إجمالية دائماً.
class AdminOverviewStats {
  final int totalUsers;
  final int totalOwners;
  final int activeUsers;
  final int totalChalets;
  final int approvedChalets;
  final int pendingChalets;
  final int totalBookings;
  final int externalBookings;
  final Map<String, int> bookingsByStatus;
  final double totalRevenue;
  final double platformRevenue;

  const AdminOverviewStats({
    required this.totalUsers,
    required this.totalOwners,
    required this.activeUsers,
    required this.totalChalets,
    required this.approvedChalets,
    required this.pendingChalets,
    required this.totalBookings,
    required this.externalBookings,
    required this.bookingsByStatus,
    required this.totalRevenue,
    required this.platformRevenue,
  });

  factory AdminOverviewStats.fromJson(Map<String, dynamic> json) {
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    double d(String k) => (json[k] as num?)?.toDouble() ?? 0;
    final byStatus = json['bookingsByStatus'];
    return AdminOverviewStats(
      totalUsers: i('totalUsers'),
      totalOwners: i('totalOwners'),
      activeUsers: i('activeUsers'),
      totalChalets: i('totalChalets'),
      approvedChalets: i('approvedChalets'),
      pendingChalets: i('pendingChalets'),
      totalBookings: i('totalBookings'),
      externalBookings: i('externalBookings'),
      bookingsByStatus: byStatus is Map
          ? {
              for (final e in byStatus.entries)
                e.key.toString(): (e.value as num?)?.toInt() ?? 0,
            }
          : const {},
      totalRevenue: d('totalRevenue'),
      platformRevenue: d('platformRevenue'),
    );
  }
}

/// كل عمليات الأدمن تمرّ عبر دوال admin_* على السيرفر (SECURITY DEFINER تتحقق
/// من is_current_user_admin وتسجّل بـ admin_audit_log)، لا تحديث مباشر للجداول.
class AdminService {
  static AdminService? _instance;
  static AdminService get instance => _instance ??= AdminService._();
  AdminService._();

  final _supabase = Supabase.instance.client;

  /// حجم صفحة قوائم لوحة الأدمن.
  static const pageSize = 20;

  /// [from] شامل و[to] غير شامل، على تاريخ وصول الحجز.
  Future<AdminOverviewStats> getOverviewStats({
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _rpc('admin_get_overview_stats', {
      'p_from': from == null ? null : _date(from),
      'p_to': to == null ? null : _date(to),
    });
    return AdminOverviewStats.fromJson(
        Map<String, dynamic>.from(data as Map));
  }

  /// الصفحة [page] (تبدأ من 0) من الشاليهات بانتظار الموافقة، الأحدث أولاً.
  Future<List<Map<String, dynamic>>> getPendingChalets({int page = 0}) async {
    final start = page * pageSize;
    final data = await _supabase
        .from('chalets')
        .select('id, name, city, location, price_per_night, images, created_at')
        .eq('is_approved', false)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .range(start, start + pageSize - 1);

    return (data as List).cast<Map<String, dynamic>>();
  }

  /// الصفحة [page] من المستخدمين، مع بحث اختياري بالاسم أو البريد على السيرفر
  /// (حتى يشمل البحث من لم تُحمَّل صفحتهم بعد).
  Future<List<Map<String, dynamic>>> getUsers({
    int page = 0,
    String search = '',
  }) async {
    final start = page * pageSize;
    var query = _supabase.from('profiles').select(
        'id, full_name, email, is_owner, is_admin, is_active, created_at');
    // حروف لها معنى بصيغة فلتر PostgREST أو بـ ilike تُزال من نص البحث.
    final q = search.trim().replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();
    if (q.isNotEmpty) {
      query = query.or('full_name.ilike.%$q%,email.ilike.%$q%');
    }
    final data = await query
        .order('created_at', ascending: false)
        .range(start, start + pageSize - 1);

    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> approveChalet(String chaletId) =>
      _rpc('admin_approve_chalet', {'p_chalet_id': chaletId});

  /// رفض الشاليه يحذفه نهائياً (admin_reject_chalet).
  Future<void> rejectChalet(String chaletId) =>
      _rpc('admin_reject_chalet', {'p_chalet_id': chaletId});

  /// يبدّل حظر المستخدم ويرجع صف profiles المحدَّث.
  Future<Map<String, dynamic>> toggleUserActive(String userId) async =>
      Map<String, dynamic>.from(
          await _rpc('admin_toggle_user_active', {'p_user_id': userId}) as Map);

  /// يبدّل صلاحية الأدمن ويرجع صف profiles المحدَّث.
  Future<Map<String, dynamic>> toggleUserAdmin(String userId) async =>
      Map<String, dynamic>.from(
          await _rpc('admin_toggle_user_admin', {'p_user_id': userId}) as Map);

  /// رسائل الدوال عربية وموجّهة للأدمن ("لا يمكنك تعطيل حسابك الخاص")،
  /// فتُمرَّر كما هي بدل خطأ PostgREST الخام.
  Future<dynamic> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      return await _supabase.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw AdminActionException(e.message);
    }
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class AdminActionException implements Exception {
  final String message;
  const AdminActionException(this.message);

  @override
  String toString() => message;
}
