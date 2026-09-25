import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/services/services.dart';
import '../../../data/services/location_service.dart';
import '../../../data/models/models.dart';
import '../../../data/models/chalet_model.dart';

import '../../widgets/common/common_widgets.dart';
import '../profile/profile_provider.dart';

class OwnerAddChaletScreen extends ConsumerStatefulWidget {
  final ChaletModel? chalet;

  const OwnerAddChaletScreen({super.key, this.chalet});

  @override
  ConsumerState<OwnerAddChaletScreen> createState() =>
      _OwnerAddChaletScreenState();
}

class _OwnerAddChaletScreenState extends ConsumerState<OwnerAddChaletScreen> {
  static const Color _darkGreen = Color(0xFF3D5228);
  static const Color _gold = Color(0xFFC9A24B);

  final _step1FormKey = GlobalKey<FormState>();
  final _step4FormKey = GlobalKey<FormState>();

  int _currentStep = 0;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _maxGuestsCtrl = TextEditingController(text: '1');
  final _cityCtrl = TextEditingController(text: 'نابلس');
  final _locationCtrl = TextEditingController();
  final _pricePerNightCtrl = TextEditingController(text: '0');
  final _videoUrlCtrl = TextEditingController();

  String _bookingType = 'يومي';

  bool _wifi = false;
  bool _pool = false;
  bool _bbq = false;
  bool _parking = false;
  int _bedrooms = 1;
  int _bathrooms = 1;

  // NEW: إحداثيات موقع الشاليه — تُملأ عبر زر "استخدم موقعي الحالي"
  // (GPS الحقيقي لصاحب الشاليه وقت الإضافة). null يعني لسا ما تحدد.
  double? _latitude;
  double? _longitude;
  bool _fetchingLocation = false;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _newImages = [];
  final List<Uint8List> _newImageBytes = [];
  final List<String> _existingImageUrls = [];

  final List<String> _cities = AppStrings.cities;

  bool _saving = false;
  String? _editingChaletId;

  static const List<_StepInfo> _stepsInfo = [
    _StepInfo('معلومات أساسية', Icons.info_outline_rounded),
    _StepInfo('الصور والفيديو', Icons.photo_camera_outlined),
    _StepInfo('المميزات', Icons.star_outline_rounded),
    _StepInfo('الأسعار والتوافر', Icons.attach_money_rounded),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.chalet != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showSnack(
          'تعديل شاليه موجود غير مدعوم حاليًا، سيتم فتح شاشة فاضية',
          isError: true,
        );
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _maxGuestsCtrl.dispose();
    _cityCtrl.dispose();
    _locationCtrl.dispose();
    _pricePerNightCtrl.dispose();
    _videoUrlCtrl.dispose();
    super.dispose();
  }

  // ====================== UI helpers ======================

  Future<bool> _confirmLeaveIfDirty() async {
    final hasData = _nameCtrl.text.trim().isNotEmpty ||
        _descCtrl.text.trim().isNotEmpty ||
        _newImages.isNotEmpty;
    if (!hasData) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('مغادرة الصفحة؟',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: const Text(
          'لديك بيانات لم تُحفظ بعد. هل تريد المغادرة بدون حفظ؟',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مغادرة',
                style: TextStyle(fontFamily: 'Cairo', color: AppColors.error)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand),
      ),
      child: child,
    );
  }

  Widget _amenityChip(String label, IconData icon, bool selected,
      ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _darkGreen.withValues(alpha: 0.08)
              : const Color(0xFFF6F2E7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _darkGreen : AppColors.sand,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18, color: selected ? _darkGreen : AppColors.textHint),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: selected ? _darkGreen : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================== Location ======================

  // NEW: يطلب صلاحية الموقع ويجلب موقع صاحب الشاليه الحالي (GPS)،
  // ويخزّنه ليُرسل مع بيانات الشاليه عند الحفظ. لا يعطّل الحفظ لو
  // فشل — الموقع اختياري، مش شرط لإنشاء الشاليه.
  Future<void> _useCurrentLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (!mounted) return;
      if (pos == null) {
        _showSnack(
          'تعذر الوصول لموقعك، تأكد من تفعيل GPS ومنح صلاحية الموقع',
          isError: true,
        );
        return;
      }
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
      _showSnack('تم تحديد موقع الشاليه بنجاح ✅');
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  // ====================== Images ======================

  Future<void> _pickImages() async {
    final total = _existingImageUrls.length + _newImages.length;
    if (total >= 8) {
      _showSnack('الحد الأقصى 8 صور', isError: true);
      return;
    }

    List<XFile> picked;
    try {
      picked = await _picker.pickMultiImage(imageQuality: 85);
    } catch (_) {
      _showSnack('تعذر فتح معرض الصور، يرجى المحاولة لاحقاً', isError: true);
      return;
    }
    if (picked.isEmpty) return;

    final remaining = 8 - total;
    final toAdd = picked.take(remaining).toList();
    if (toAdd.isEmpty) return;

    final validFiles = <XFile>[];
    final bytesList = <Uint8List>[];
    for (final x in toAdd) {
      try {
        final bytes = await x.readAsBytes();
        if (bytes.isEmpty) continue;
        validFiles.add(x);
        bytesList.add(bytes);
      } catch (_) {
        continue;
      }
    }

    if (validFiles.isEmpty) {
      _showSnack('تعذرت قراءة الصور المحددة', isError: true);
      return;
    }

    setState(() {
      _newImages.addAll(validFiles);
      _newImageBytes.addAll(bytesList);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
      _newImageBytes.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  // ====================== Validation helpers ======================

  bool _isValidYoutubeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.isAbsolute) return false;
    final host = uri.host.toLowerCase();
    return host == 'youtube.com' ||
        host == 'www.youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'youtu.be' ||
        host == 'www.youtu.be';
  }

  // ====================== Save ======================

  Map<String, dynamic> _buildChaletPayload() {
    final ownerId = AuthService.instance.currentUser?.id;
    if (ownerId == null) {
      throw Exception('لا يوجد مستخدم مسجل دخول حاليًا');
    }
    return {
      'owner_id': ownerId,
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'price_per_night': parseLocalizedDouble(_pricePerNightCtrl.text) ?? 0,
      'location': (() {
        final loc = _locationCtrl.text.trim();
        if (loc.isNotEmpty) return loc;
        final city = _cityCtrl.text.trim();
        if (city.isNotEmpty) return city;
        return 'غير محدد';
      })(),
      'city': _cityCtrl.text.trim(),
      // NEW: إحداثيات الموقع الفعلي (اختياري) — تُرسل فقط لو المالك
      // ضغط "استخدم موقعي الحالي" ونجح جلب GPS.
      'latitude': _latitude,
      'longitude': _longitude,
      'max_guests': parseLocalizedInt(_maxGuestsCtrl.text) ?? 1,
      'bedrooms': _bedrooms,
      'bathrooms': _bathrooms,
      'has_pool': _pool,
      'has_wifi': _wifi,
      'has_bbq': _bbq,
      'has_parking': _parking,
      'booking_type': _bookingType,
      'video_url':
          _videoUrlCtrl.text.trim().isEmpty ? null : _videoUrlCtrl.text.trim(),
      'is_available': true,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _saveAll() async {
    final step1Valid = _step1FormKey.currentState?.validate() ?? true;
    final step4Valid = _step4FormKey.currentState?.validate() ?? false;
    if (!step1Valid || !step4Valid) {
      if (!step1Valid) {
        _showSnack('يرجى مراجعة بيانات الخطوة 1', isError: true);
        setState(() => _currentStep = 0);
      } else {
        _showSnack('يرجى مراجعة بيانات الخطوة 4', isError: true);
      }
      return;
    }

    if (!_isValidYoutubeUrl(_videoUrlCtrl.text)) {
      _showSnack('رابط اليوتيوب غير صالح', isError: true);
      setState(() => _currentStep = 0);
      return;
    }

    if (_existingImageUrls.isEmpty && _newImages.isEmpty) {
      _showSnack('أضف صورة واحدة على الأقل', isError: true);
      setState(() => _currentStep = 1);
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);

    try {
      final ownerId = AuthService.instance.currentUser?.id;
      if (ownerId == null) {
        throw Exception('لا يوجد مستخدم مسجل دخول حاليًا');
      }

      final payload = _buildChaletPayload();
      await ChaletService.instance.createOrUpdateChaletWithImages(
        isEditing: _editingChaletId != null,
        editingChaletId: _editingChaletId,
        ownerId: ownerId,
        chaletData: payload,
        newImages: _newImages,
        newImageBytes: _newImageBytes,
        existingImageUrls: _existingImageUrls,
      );

      // ✅ إصلاح: القيمة المرجعة كانت تُهمَل بالكامل. شرط become_owner()
      // ببكند (شاليه واحد على الأقل is_approved=true) لا يتحقق عادةً
      // لأن أي شاليه جديد يُدرَج دائمًا بـ is_approved=false (بانتظار
      // مراجعة الإدارة) — فكانت الواجهة تعرض "نجاح" وتنتقل لـ
      // /owner-dashboard رغم أن الدور لم يتغيّر فعليًا، فيُعاد طرد
      // المستخدم فورًا من حارس الراوتر (isHost=false) وكأن كل شيء اختفى.
      final becameOwner = await AuthService.instance.becomeOwner();

      if (!mounted) return;

      if (becameOwner) {
        // ✅ يزامن حالة الحساب في Riverpod مع Supabase فورًا (بدل بقاء
        // profileProvider يعرض role=customer القديم لحد إعادة بناء
        // لاحقة من مكان آخر).
        ref.invalidate(profileProvider);
        _showSnack('تم حفظ الشاليه بنجاح ✅');
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        context.go('/owner-dashboard');
      } else {
        // الشاليه انحفظ فعليًا بنجاح بقاعدة البيانات — هذا ليس فشلًا
        // بالحفظ، فقط وضع المالك لسا غير مفعّل لحد ما الإدارة توافق.
        _showSnack(
          'تم حفظ الشاليه بنجاح، وبانتظار موافقة الإدارة لتفعيل حساب المالك.',
        );
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        context.go('/home');
      }
    } catch (_) {
      if (mounted) {
        _showSnack('حدث خطأ أثناء الحفظ، يرجى المحاولة لاحقاً', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _saveDraft() {
    // ⚠️ حفظ كمسودة فعلي غير مفعّل بعد — بس رسالة تنبيه مؤقتة. إذا بدك
    // سلوك حقيقي (حفظ جزئي بدون تحقق كامل)، خبرني وبنبنيها.
    _showSnack('سيتم دعم "حفظ كمسودة" قريبًا');
  }

  // ====================== Step content ======================

  Widget _buildStep1() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('المعلومات الأساسية',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('أدخل المعلومات الأساسية للشاليه',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _nameCtrl,
            label: 'اسم الشاليه',
            hint: 'مثال: شاليه الندى',
            prefixIcon: Icons.home_work_rounded,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'هاد الحقل مطلوب' : null,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _numberField(
                    label: 'غرف النوم',
                    value: _bedrooms,
                    onChanged: (v) => setState(() => _bedrooms = v),
                    min: 1,
                    max: 50),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numberField(
                    label: 'الحمامات',
                    value: _bathrooms,
                    onChanged: (v) => setState(() => _bathrooms = v),
                    min: 1,
                    max: 50),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _maxGuestsCtrl,
            label: 'عدد الأشخاص المسموح بهم',
            hint: 'مثال: 10',
            prefixIcon: Icons.group_outlined,
            keyboardType: TextInputType.number,
            validator: (v) {
              final val = parseLocalizedInt(v);
              if (val == null || val <= 0) return 'أدخل رقم صحيح';
              if (val > 200) return 'رقم غير منطقي';
              return null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _cities.contains(_cityCtrl.text.trim())
                ? _cityCtrl.text.trim()
                : _cities.first,
            decoration: InputDecoration(
              labelText: 'المدينة',
              prefixIcon:
                  const Icon(Icons.location_city_rounded, color: _darkGreen),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _cities
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c,
                          style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 14)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _cityCtrl.text = v);
            },
            validator: (v) => v == null || v.isEmpty ? 'هاد الحقل مطلوب' : null,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _locationCtrl,
            label: 'المنطقة/الحي',
            hint: 'مثال: قرب مدخل بيتا',
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 10),
          // NEW: زر تحديد الموقع الفعلي عبر GPS + رسالة تأكيد بعد النجاح.
          _buildLocationPicker(),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _descCtrl,
            label: 'وصف مختصر',
            hint: 'اكتب وصفًا جذابًا ومختصرًا عن الشاليه...',
            prefixIcon: Icons.description_outlined,
            maxLines: 4,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'هاد الحقل مطلوب' : null,
          ),
        ],
      ),
    );
  }

  // NEW: بطاقة صغيرة فيها زر "استخدم موقعي الحالي" وحالة النتيجة
  // (لسا ما تحدد / جاري التحديد / تم بنجاح مع عرض الإحداثيات).
  Widget _buildLocationPicker() {
    final hasLocation = _latitude != null && _longitude != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasLocation
            ? _darkGreen.withValues(alpha: 0.06)
            : const Color(0xFFF6F2E7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              hasLocation ? _darkGreen.withValues(alpha: 0.4) : AppColors.sand,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasLocation
                ? Icons.check_circle_rounded
                : Icons.my_location_rounded,
            color: hasLocation ? _darkGreen : AppColors.textHint,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLocation
                      ? 'تم تحديد موقع الشاليه ✅'
                      : 'موقع الشاليه على الخريطة (اختياري)',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: hasLocation ? _darkGreen : AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasLocation
                      ? 'يساعد الضيوف اللي بالقرب منك على إيجاد شاليهك'
                      : 'كن واقفًا عند الشاليه واضغط الزر لتحديد موقعه بدقة',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: OutlinedButton(
              onPressed: _fetchingLocation ? null : _useCurrentLocation,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: hasLocation ? _darkGreen : AppColors.sand),
                foregroundColor: _darkGreen,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                // ✅ إصلاح: outlinedButtonTheme العام يفرض
                // minimumSize: Size(double.infinity, 52)، وهذا الزر طفل
                // غير مرن (بدون Expanded) داخل Row — التركيبة تسبب
                // "BoxConstraints forces an infinite width". تجاوز
                // minimumSize محليًا لـSize.zero يجعل الزر يأخذ عرضًا
                // مناسبًا لمحتواه الفعلي (النص المتغيّر أو مؤشر التحميل)
                // بدل عرض لانهائي، دون تغيير توزيع بقية الـRow.
                minimumSize: Size.zero,
              ),
              child: _fetchingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      hasLocation ? 'تحديث' : 'استخدم موقعي الحالي',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final allCount = _existingImageUrls.length + _newImages.length;
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الصور والفيديو',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _CoverImageBox(
            hasImages: allCount > 0,
            onTap: _saving ? null : _pickImages,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 14, color: Colors.red),
              const SizedBox(width: 4),
              Text('إضافة صورة واحدة على الأقل إجباري',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 12),
          if (allCount > 0)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, i) {
                if (i < _existingImageUrls.length) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _existingImageUrls[i],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.sand,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _deleteButton(() => _removeExistingImage(i)),
                      ),
                    ],
                  );
                } else {
                  final newIndex = i - _existingImageUrls.length;
                  final bytes = newIndex < _newImageBytes.length
                      ? _newImageBytes[newIndex]
                      : null;
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: bytes != null && bytes.isNotEmpty
                            ? Image.memory(bytes,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity)
                            : Container(
                                color: AppColors.sand,
                                child: const Icon(Icons.image)),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _deleteButton(() => _removeNewImage(newIndex)),
                      ),
                    ],
                  );
                }
              },
            ),
          if (allCount > 0) const SizedBox(height: 14),
          Text('$allCount / 8 صور',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.textHint)),
          const SizedBox(height: 18),
          CustomTextField(
            controller: _videoUrlCtrl,
            label: 'رابط فيديو يوتيوب (اختياري)',
            hint: 'https://youtube.com/watch?v=...',
            prefixIcon: Icons.smart_display_outlined,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              if (!_isValidYoutubeUrl(v)) return 'يرجى إدخال رابط يوتيوب صحيح';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('المميزات',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _amenityChip('واي فاي', Icons.wifi_rounded, _wifi,
                  (v) => setState(() => _wifi = v)),
              _amenityChip('مسبح', Icons.pool_rounded, _pool,
                  (v) => setState(() => _pool = v)),
              _amenityChip('باربيكيو', Icons.outdoor_grill_rounded, _bbq,
                  (v) => setState(() => _bbq = v)),
              _amenityChip('باركينج', Icons.local_parking_rounded, _parking,
                  (v) => setState(() => _parking = v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الأسعار والتوافر',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _pricePerNightCtrl,
            label: 'السعر الأساسي (يبدأ من)',
            hint: 'مثال: 350',
            prefixIcon: Icons.attach_money_rounded,
            keyboardType: TextInputType.number,
            validator: (v) {
              final val = parseLocalizedDouble(v);
              if (val == null || val <= 0) return 'أدخل رقم أكبر من صفر';
              return null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _bookingType,
            decoration: InputDecoration(
              labelText: 'نوع الحجز',
              prefixIcon:
                  const Icon(Icons.calendar_today_rounded, color: _darkGreen),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'يومي',
                  child: Text('يومي', style: TextStyle(fontFamily: 'Cairo'))),
              DropdownMenuItem(
                  value: 'خارجي',
                  child: Text('خارجي', style: TextStyle(fontFamily: 'Cairo'))),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _bookingType = v);
            },
            validator: (v) => v == null || v.isEmpty ? 'اختر نوع الحجز' : null,
          ),
        ],
      ),
    );
  }

  Widget _numberField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required int min,
    required int max,
  }) {
    return _NumberFieldInput(
        label: label, value: value, min: min, max: max, onChanged: onChanged);
  }

  Widget _deleteButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration:
            const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
        child: const Icon(Icons.close, size: 14, color: Colors.white),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: isError ? AppColors.error : _darkGreen,
      ),
    );
  }

  Future<void> _handleScreenBack() async {
    if (_saving) {
      _showSnack('يرجى الانتظار حتى انتهاء عملية الحفظ');
      return;
    }

    final confirmed = await _confirmLeaveIfDirty();
    if (!confirmed || !mounted) return;

    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go('/owner-dashboard');
  }

  Future<void> _handleStepContinue() async {
    if (_currentStep == 0) {
      final ok = _step1FormKey.currentState?.validate() ?? false;
      if (!ok) return;
      setState(() => _currentStep = 1);
      return;
    }
    if (_currentStep == 1) {
      if (_existingImageUrls.isEmpty && _newImages.isEmpty) {
        _showSnack('أضف صورة واحدة على الأقل', isError: true);
        return;
      }
      setState(() => _currentStep = 2);
      return;
    }
    if (_currentStep == 2) {
      setState(() => _currentStep = 3);
      return;
    }
    if (_currentStep == 3) {
      await _saveAll();
    }
  }

  void _handleStepCancel() {
    if (_currentStep == 0 || _saving) return;
    setState(() => _currentStep = _currentStep - 1);
  }

  /// الرجوع (زر النظام أو سهم الأعلى): خطوة للخلف داخل المعالج، ومن
  /// الخطوة الأولى خروج من الشاشة (بتأكيد إن وُجدت تعديلات).
  Future<void> _handleBack() async {
    if (_currentStep > 0 && !_saving) {
      _handleStepCancel();
      return;
    }
    await _handleScreenBack();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4EC),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildStepHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: _currentStep == 0
                      ? Form(key: _step1FormKey, child: _buildStep1())
                      : _currentStep == 1
                          ? _buildStep2()
                          : _currentStep == 2
                              ? _buildStep3()
                              : Form(key: _step4FormKey, child: _buildStep4()),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _saving ? null : _handleBack,
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child:
                  Icon(Icons.arrow_back, size: 18, color: AppColors.charcoal),
            ),
          ),
          const Expanded(
            child: Text(
              'إعدادات تسجيل الشاليه',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildStepHeader() {
    return SizedBox(
      height: 86,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: List.generate(_stepsInfo.length, (i) {
            final info = _stepsInfo[i];
            final active = i == _currentStep;
            final done = i < _currentStep;
            return Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: active || done ? _darkGreen : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active || done ? _darkGreen : AppColors.sand,
                        ),
                      ),
                      child: Icon(
                        done ? Icons.check : info.icon,
                        size: 18,
                        color:
                            active || done ? Colors.white : AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 78,
                      child: Text(
                        info.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 9.5,
                          height: 1.1,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w600,
                          color: active ? _darkGreen : AppColors.textHint,
                        ),
                      ),
                    ),
                  ],
                ),
                if (i != _stepsInfo.length - 1)
                  Container(
                    width: 30,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: done ? _darkGreen : AppColors.sand,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4EC),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            SizedBox(
              height: 52,
              child: OutlinedButton(
                key: const Key('add_chalet_prev_step'),
                onPressed: _saving ? null : _handleStepCancel,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.sand),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('السابق',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _handleStepContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep == 3 ? 'حفظ الشاليه' : 'التالي',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                              _currentStep == 3
                                  ? Icons.save_rounded
                                  : Icons.arrow_back,
                              size: 16),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ✅ الإصلاح: أضفنا width: 140 هون. بدونها كان هاد الزر يكسر
          // كل الشاشة (BoxConstraints forces an infinite width) لأنه
          // كان جنب Expanded ضمن نفس الـ Row بدون عرض محدد له.
          SizedBox(
            width: 140,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _saveDraft,
              icon: const Icon(Icons.save_outlined,
                  size: 16, color: AppColors.charcoal),
              label: const Text('حفظ كمسودة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.sand),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepInfo {
  final String label;
  final IconData icon;
  const _StepInfo(this.label, this.icon);
}

class _CoverImageBox extends StatelessWidget {
  final bool hasImages;
  final VoidCallback? onTap;

  const _CoverImageBox({required this.hasImages, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DottedBorderBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_upload_outlined,
                  size: 34, color: Color(0xFFC9A24B)),
              const SizedBox(height: 10),
              const Text('صورة الغلاف الرئيسية',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal)),
              const SizedBox(height: 4),
              const Text('يفضل صورة جديدة تظهر المسبح أو الحديقة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEE6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(hasImages ? 'إضافة المزيد' : 'اختر صورة',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// إطار منقط بسيط (Flutter ما عندها CustomPainter جاهز للحدود المنقطة،
/// فبنينا وحدة بسيطة بـ CustomPaint).
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(),
      child: child,
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9A24B)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, dashArray: [6, 4]);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source, {required List<double> dashArray}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = dashArray[draw ? 0 : 1];
        if (draw) {
          dest.addPath(
              metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NumberFieldInput extends StatefulWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberFieldInput({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_NumberFieldInput> createState() => _NumberFieldInputState();
}

class _NumberFieldInputState extends State<_NumberFieldInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _ctrl,
          textAlign: TextAlign.start,
          keyboardType: TextInputType.number,
          onChanged: (s) {
            final val = parseLocalizedInt(s) ?? widget.min;
            final clamped = val.clamp(widget.min, widget.max);
            widget.onChanged(clamped);
          },
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
