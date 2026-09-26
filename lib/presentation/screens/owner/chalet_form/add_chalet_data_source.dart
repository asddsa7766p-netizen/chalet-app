import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../../data/services/services.dart'
    show AuthService, ChaletService;

/// واجهة رفيعة بين معالج إضافة الشاليه والباك إند (لتمكين اختباره بلا
/// Supabase)، بنفس فكرة [ChaletEditDataSource] لشاشة التعديل. التنفيذ
/// الافتراضي [SupabaseAddChaletDataSource] يستدعي نفس الخدمات كما كانت.
abstract class AddChaletDataSource {
  /// معرّف المستخدم الحالي، أو null إن لم يكن مسجلاً.
  String? get currentUserId;

  /// يفتح معرض الصور ويرجع المختار (قد يكون فارغاً).
  Future<List<XFile>> pickImages();

  /// يحفظ الشاليه ويرفع صوره، ويرجع معرّفه
  /// ([ChaletService.createOrUpdateChaletWithImages]).
  Future<String> saveChalet({
    required bool isEditing,
    String? editingChaletId,
    required String ownerId,
    required Map<String, dynamic> chaletData,
    required List<XFile> newImages,
    required List<Uint8List> newImageBytes,
    required List<String> existingImageUrls,
  });

  /// [AuthService.becomeOwner]: true إن تفعّل حساب المالك فعلاً.
  Future<bool> becomeOwner();
}

class SupabaseAddChaletDataSource implements AddChaletDataSource {
  SupabaseAddChaletDataSource();

  final ImagePicker _picker = ImagePicker();

  @override
  String? get currentUserId => AuthService.instance.currentUser?.id;

  @override
  Future<List<XFile>> pickImages() => _picker.pickMultiImage(imageQuality: 85);

  @override
  Future<String> saveChalet({
    required bool isEditing,
    String? editingChaletId,
    required String ownerId,
    required Map<String, dynamic> chaletData,
    required List<XFile> newImages,
    required List<Uint8List> newImageBytes,
    required List<String> existingImageUrls,
  }) =>
      ChaletService.instance.createOrUpdateChaletWithImages(
        isEditing: isEditing,
        editingChaletId: editingChaletId,
        ownerId: ownerId,
        chaletData: chaletData,
        newImages: newImages,
        newImageBytes: newImageBytes,
        existingImageUrls: existingImageUrls,
      );

  @override
  Future<bool> becomeOwner() => AuthService.instance.becomeOwner();
}
