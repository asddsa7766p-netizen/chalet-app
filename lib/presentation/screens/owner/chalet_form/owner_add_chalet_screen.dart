
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../data/services/services.dart';
import '../../../../data/services/location_service.dart';
import '../../../../data/models/chalet_model.dart';

import '../../../widgets/common/common_widgets.dart';
import '../../profile/profile_provider.dart';

part 'add_chalet_steps.dart';
part 'add_chalet_widgets.dart';

class OwnerAddChaletScreen extends ConsumerStatefulWidget {
  final ChaletModel? chalet;

  const OwnerAddChaletScreen({super.key, this.chalet});

  @override
  ConsumerState<OwnerAddChaletScreen> createState() =>
      _OwnerAddChaletScreenState();
}

class _OwnerAddChaletScreenState extends ConsumerState<OwnerAddChaletScreen> {
  static const Color _darkGreen = Color(0xFF3D5228);

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

  // لأجزاء الشاشة (extensions بملفات part) التي لا تستطيع استدعاء
  // setState المحمي مباشرة.
  void _setState(VoidCallback fn) => setState(fn);

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
