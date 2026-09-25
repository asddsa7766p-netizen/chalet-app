part of 'services.dart';

// ============================================
// FAVORITES SERVICE
// ============================================
class FavoritesService {
  static FavoritesService? _instance;
  static FavoritesService get instance => _instance ??= FavoritesService._();
  FavoritesService._();

  final _auth = AuthService.instance;

  /// سقف قائمة المفضلة (الأحدث أولاً).
  static const favoritesLimit = 100;

  Future<List<ChaletModel>> getFavorites() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // inner join: مفضلة لشاليه محذوف أو مخفي (RLS لا يعيده لغير مالكه) كانت
      // تعود بـ chalets = null فيسقط التحويل ويفشل تحميل المفضلة كلها.
      final data = await supabase
          .from('favorites')
          .select('chalets!inner(*)')
          .eq('user_id', userId)
          .isFilter('chalets.deleted_at', null)
          .order('created_at', ascending: false)
          .limit(favoritesLimit);

      return (data as List)
          .map((e) => e['chalets'])
          .whereType<Map<String, dynamic>>()
          .map(ChaletModel.fromJson)
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
