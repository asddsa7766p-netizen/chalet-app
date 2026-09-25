part of 'services.dart';

// ============================================
// CHALET SERVICE
// ============================================
class ChaletService {
  static ChaletService? _instance;
  static ChaletService get instance => _instance ??= ChaletService._();
  ChaletService._();

  /// Get all chalets with optional filters
  // ✅ إصلاح: has_bbq/has_parking أعمدة حقيقية موجودة أصلاً بجدول chalets
  // (ومقروءة أصلاً في ChaletModel)، لكنها لم تكن مدعومة كفلتر بحث إطلاقاً.
  // إضافتهما هنا استعلام Dart عادي على عمود موجود فعلياً — بلا أي تعديل
  // على الـschema أو الـRLS أو أي RPC.
  Future<List<ChaletModel>> getChalets({
    String? city,
    double? minPrice,
    double? maxPrice,
    bool? hasPool,
    bool? hasWifi,
    bool? hasBbq,
    bool? hasParking,
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
          .eq('is_approved', true)
          .isFilter('deleted_at', null);

      if (city != null && city.isNotEmpty && city != AppStrings.allCities) {
        query = query.eq('city', city);
      }
      if (minPrice != null) query = query.gte('price_per_night', minPrice);
      if (maxPrice != null) query = query.lte('price_per_night', maxPrice);
      if (hasPool == true) query = query.eq('has_pool', true);
      if (hasWifi == true) query = query.eq('has_wifi', true);
      if (hasBbq == true) query = query.eq('has_bbq', true);
      if (hasParking == true) query = query.eq('has_parking', true);
      if (minGuests != null) query = query.gte('max_guests', minGuests);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        // ✅ إصلاح: رموز صيغة فلتر PostgREST (الأقواس/الفاصلة/% ...) داخل
        // نص البحث كانت تكسر الطلب كله (مثلاً البحث عن "شاليه (جديد)" يفشل
        // بخطأ عام). نزيلها من الكلمات قبل بناء شرط or().
        final words = searchQuery
            .replaceAll(RegExp(r'[(),%*\\:"]'), ' ')
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
          .isFilter('deleted_at', null)
          .order('rating', ascending: false)
          .limit(limit);
      return (data as List).map((e) => ChaletModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Check availability.
  ///
  /// ✅ إصلاح: كانت تستعلم bookings مباشرة عن أي تداخل بتواريخ check_in/
  /// check_out بغض النظر عن نوع الإقامة — بعد أن صار الشاليه يقبل حجزاً
  /// صباحياً وآخر مسائياً بنفس اليوم، تداخل تواريخ خام لم يعد يعني عدم توفر
  /// فعلي (حجز صباحي موجود لا يمنع حجزاً مسائياً بنفس اليوم). الآن تستدعي
  /// دالة القاعدة الموحّدة is_chalet_available التي تفحص تعارض الفترات
  /// الفعلية (occupied_slots) حسب p_stay_type، مطابقة تماماً لما يتحقق منه
  /// الإدراج الفعلي بجدول bookings.
  Future<bool> isAvailable({
    required String chaletId,
    required DateTime checkIn,
    required DateTime checkOut,
    String stayType = BookingService.defaultStayType,
  }) async {
    try {
      final result = await supabase.rpc(
        'is_chalet_available',
        params: {
          'p_chalet_id': chaletId,
          'p_check_in': checkIn.toIso8601String().split('T').first,
          'p_check_out': checkOut.toIso8601String().split('T').first,
          'p_stay_type': stayType,
        },
      );

      return result as bool;
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
        } catch (e, st) {
          // ignore secondary cleanup failure to preserve original error
          reportError(e, st, context: 'chalet_save.cleanup_insert');
        }
      }

      rethrow;
    }
  }

  /// سقف أمان لقائمة شاليهات المالك (بالواقع بضعة شاليهات لكل مالك).
  static const ownerChaletsLimit = 200;

  /// Get the raw, owner-scoped chalet list used by the owner chalets screen.
  /// This keeps the same table, filters, selected columns and ordering as the
  /// original screen query, while returning the same Map-shaped rows the UI
  /// expects.
  Future<List<Map<String, dynamic>>> getOwnerChalets(String ownerId) async {
    try {
      final data = await supabase
          .from('chalets')
          .select(
            'id, name, city, location, price_per_night, images, is_available, is_approved, rating, reviews_count, max_guests',
          )
          .eq('owner_id', ownerId)
          // الحذف من المالك "ناعم" (trigger يضبط deleted_at بدل الحذف)، فالشاليه
          // المحذوف يبقى بالجدول ولا يجب أن يظهر بأي قائمة.
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(ownerChaletsLimit);

      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }
}
