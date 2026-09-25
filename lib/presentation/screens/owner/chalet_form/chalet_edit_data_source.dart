import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../data/services/services.dart' show ChaletService;
import 'chalet_edit_model.dart';

/// واجهة رفيعة بين شاشة تعديل الشاليه والباك إند (لتمكين اختبارها بلا Supabase).
/// التنفيذ الافتراضي [SupabaseChaletEditDataSource] يستخدم الجداول والأعمدة
/// الحالية فقط، ومسار التخزين الموجود أصلاً بالتطبيق.
abstract class ChaletEditDataSource {
  /// معرّف المستخدم الحالي، أو null إن لم يكن مسجلاً.
  String? get currentUserId;

  /// صف الشاليه كاملاً، أو null إن لم يوجد/لا يُرى (RLS).
  Future<Map<String, dynamic>?> fetchChalet(String chaletId);

  /// يرفع صوراً ويرجع روابط الناجح منها بترتيب الإدخال. (الفاشل يُتجاهل بصمت
  /// بالخدمة الحالية، فالمستدعي يقارن العدد.)
  Future<List<String>> uploadImages(
    String chaletId,
    List<XFile> files,
    List<Uint8List> bytes,
  );

  /// يطبّق [changes] ويرجع الصف المحدَّث. يرجع null إن لم يُحدَّث أي صف:
  /// رفض الـRLS لا يرمي خطأ بل يحدّث صفر صفوف.
  Future<Map<String, dynamic>?> updateChalet(
    String chaletId,
    Map<String, dynamic> changes,
  );

  /// يحذف ملفات صور من التخزين (best effort). الروابط خارج مسار هذا الشاليه
  /// تُتجاهل.
  Future<void> deleteImageUrls(String chaletId, List<String> urls);
}

class SupabaseChaletEditDataSource implements ChaletEditDataSource {
  const SupabaseChaletEditDataSource();

  // الوصول كسول: لا يلمس Supabase إلا عند أول استدعاء فعلي.
  SupabaseClient get _client => Supabase.instance.client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<Map<String, dynamic>?> fetchChalet(String chaletId) async {
    final row = await _client
        .from('chalets')
        .select('*')
        .eq('id', chaletId)
        .maybeSingle();
    return row;
  }

  @override
  Future<List<String>> uploadImages(
    String chaletId,
    List<XFile> files,
    List<Uint8List> bytes,
  ) =>
      ChaletService.instance.uploadChaletImages(
        chaletId: chaletId,
        images: files,
        imageBytes: bytes,
      );

  @override
  Future<Map<String, dynamic>?> updateChalet(
    String chaletId,
    Map<String, dynamic> changes,
  ) async {
    // أي عمود خارج القائمة المسموحة يُرفض هنا قبل الشبكة (حماية إضافية).
    final illegal = changes.keys.where((k) => !chaletEditableColumns.contains(k));
    if (illegal.isNotEmpty) {
      throw ArgumentError('Column not editable from this screen: $illegal');
    }
    final rows = await _client
        .from('chalets')
        .update(changes)
        .eq('id', chaletId)
        .select();
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<void> deleteImageUrls(String chaletId, List<String> urls) async {
    final paths = <String>[
      for (final u in urls)
        if (chaletImageStoragePath(u, chaletId) case final p?) p,
    ];
    if (paths.isEmpty) return;
    await _client.storage.from('chalet-images').remove(paths);
  }
}
