import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reel_model.dart';

final _supabase = Supabase.instance.client;

class ReelsService {
  static ReelsService? _instance;
  static ReelsService get instance => _instance ??= ReelsService._();
  ReelsService._();

  /// أحدث الفيديوهات أولاً. الشاشة لا تحمّل إلا 3 مشغّلات بنفس الوقت، لكن
  /// القائمة نفسها محدودة أيضاً حتى لا تُجلب كل صفوف الجدول دفعة واحدة.
  static const reelsPageSize = 50;

  Future<List<ReelModel>> fetchReels() async {
    final data = await _supabase
        .from('reels')
        .select('*, chalets(*)')
        .order('created_at', ascending: false)
        .limit(reelsPageSize);

    // video_url و chalet_id أعمدة nullable بالقاعدة: صف بلا فيديو أو بلا
    // شاليه لا يمكن عرضه ولا فتح تفاصيله، فيُستبعد بدل إسقاط القائمة كلها.
    return (data as List)
        .map((e) => ReelModel.fromJson(e as Map<String, dynamic>))
        .where((r) => r.videoUrl.isNotEmpty && r.chaletId.isNotEmpty)
        .toList();
  }
}
