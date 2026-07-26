import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/services.dart';
import '../../../data/models/models.dart';
import '../../../data/models/chalet_model.dart';

// NOTE: OwnerAddChaletScreen supports both create & edit (via optional chalet).
//
// تعديل بنيوي مهم عن النسخة السابقة:
// - لم يعد يتم إنشاء سجل بقاعدة البيانات إلا بعد اكتمال كل الخطوات والضغط
//   على "حفظ الشاليه" بالخطوة الأخيرة. سابقًا كان يتم إنشاء سجل فور إنهاء
//   الخطوة الأولى، وهذا كان يترك سجلات "يتيمة" ناقصة البيانات لو خرج
//   المستخدم بمنتصف الطريق.
// - رفع الصور يحدث بعد إنشاء السجل مباشرة وضمن نفس عملية الحفظ؛ في حال
//   فشل الرفع، السجل يبقى موجودًا لكنه قابل لإعادة المحاولة لاحقًا (وضع
//   تعديل)، وهذا أسلم من فقدان كل البيانات.

import '../../widgets/common/common_widgets.dart';

class OwnerAddChaletScreen extends StatefulWidget {
  final ChaletModel? chalet;

  const OwnerAddChaletScreen({super.key, this.chalet});

  @override
  State<OwnerAddChaletScreen> createState() => _OwnerAddChaletScreenState();
}

class _OwnerAddChaletScreenState extends State<OwnerAddChaletScreen> {
  // مفتاح Form منفصل لكل خطوة، بدل مفتاح واحد مشترك لكل الخطوات الأربعة.
  //
  // ⚠️ سبب هذا التعديل: Stepper يبني كل الخطوات الأربعة ضمن شجرة الواجهة
  // دفعة واحدة (حتى غير النشطة منها)، وكانت كل الحقول مرتبطة بـ Form واحد
  // مشترك (_formKey). نتيجة ذلك، استدعاء _formKey.currentState.validate()
  // بالخطوة 1 كان يتحقق أيضًا من حقول الخطوة 4 (مثل السعر، الذي تكون
  // قيمته الافتراضية صفرًا وفاشلة بالتحقق)، فيفشل التحقق بصمت دون أي رسالة
  // ظاهرة للمستخدم (لأن رسالة الخطأ كانت تظهر في خطوة بعيدة غير مرئية)،
  // ويبقى زر "التالي" بلا أي أثر ظاهري.
  final _step1FormKey = GlobalKey<FormState>();
  final _step4FormKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  int _currentStep = 0;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _maxGuestsCtrl = TextEditingController(text: '1');
  final _cityCtrl = TextEditingController(text: 'نابلس');
  final _locationCtrl = TextEditingController();
  final _pricePerNightCtrl = TextEditingController(text: '0');
  final _depositCtrl = TextEditingController(text: '0');
  final _minNightsCtrl = TextEditingController(text: '1');
  final _videoUrlCtrl = TextEditingController();

  String _bookingType = 'يومي';

  bool _wifi = false;
  bool _pool = false;
  bool _bbq = false;
  bool _parking = false;
  int _bedrooms = 1;
  int _bathrooms = 1;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _newImages = [];
  final List<Uint8List> _newImageBytes = [];
  final List<String> _existingImageUrls = [];

  final List<String> _cities = [
    'نابلس',
    'رام الله',
    'الخليل',
    'جنين',
    'طولكرم',
    'قلقيلية',
    'أريحا',
    'بيت لحم',
    'طوباس',
    'سلفيت',
  ];

  bool _saving = false;

  // معرف الشاليه الحالي عند التعديل (وضع تعديل شاليه موجود مسبقًا).
  //
  // ⚠️ ملاحظة مهمة: ChaletModel الحالي لا يحتوي حاليًا على كل الحقول
  // المخزّنة فعليًا بجدول chalets في Supabase (مثل deposit_amount,
  // min_nights, video_url, booking_type, و images كقائمة كاملة — الموديل
  // يحتوي فقط على coverImage كصورة واحدة). لذلك تم تعطيل تحميل بيانات
  // شاليه قائم تلقائيًا من ChaletModel مؤقتًا، تجنبًا لاستخدام بيانات
  // ناقصة أو خاطئة في وضع التعديل. هذه الشاشة حاليًا تدعم فعليًا إنشاء
  // شاليه جديد فقط. دعم التعديل الكامل يتطلب أولًا تحديث ChaletModel
  // لمطابقة كل أعمدة قاعدة البيانات.
  String? _editingChaletId;

  @override
  void initState() {
    super.initState();
    if (widget.chalet != null) {
      // وضع التعديل غير مفعّل بعد لنفس السبب أعلاه. نعرض تنبيهًا بدل
      // محاولة قراءة بيانات قد تكون ناقصة بصمت.
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
    _depositCtrl.dispose();
    _minNightsCtrl.dispose();
    _videoUrlCtrl.dispose();
    super.dispose();
  }

  // ====================== UI helpers ======================

  Widget _buildBackToUserButton() {
    return SizedBox(
      width: 160,
      child: OutlinedButton.icon(
        onPressed: _saving
            ? null
            : () async {
                final confirmed = await _confirmLeaveIfDirty();
                if (!confirmed) return;
                try {
                  await AuthService.instance.becomeCustomer();
                } catch (_) {
                  // تجاهل الخطأ هنا: حتى لو فشل تحديث الحالة على السيرفر،
                  // المستخدم لا يزال بحاجة للخروج من هذه الشاشة.
                }
                if (!mounted) return;
                context.go('/home');
              },
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text(
          'العودة كمستخدم',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.sand),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  /// يسأل المستخدم تأكيد الخروج إذا كان بدأ تعبئة بيانات فعلية، لتجنّب فقدان
  /// العمل بالخطأ بضغطة واحدة.
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

  Widget _stepNavTop(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.charcoal,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildBackToUserButton(),
        ],
      ),
    );
  }

  Widget _sectionCard(
      {required Widget child, required IconData icon, required String title}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
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
              ? AppColors.primaryPale.withValues(alpha: 0.4)
              : AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.sand,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
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
    } catch (e) {
      _showSnack('تعذر فتح معرض الصور: $e', isError: true);
      return;
    }
    if (picked.isEmpty) return;

    final remaining = 8 - total;
    final toAdd = picked.take(remaining).toList();
    if (toAdd.isEmpty) return;

    // دائماً نقرأ الـ bytes — يعمل على الويب والموبايل.
    // أي ملف يفشل قراءته (بايتات فاضية) يتم تجاهله بدل إضافته كصورة فاسدة.
    final validFiles = <XFile>[];
    final bytesList = <Uint8List>[];
    for (final x in toAdd) {
      try {
        final bytes = await x.readAsBytes();
        if (bytes.isEmpty) continue;
        validFiles.add(x);
        bytesList.add(bytes);
      } catch (_) {
        // تجاهل هذا الملف فقط، استمر بالباقي.
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

  Future<List<String>> _uploadNewImages(String chaletId) async {
    final uploadedUrls = <String>[];

    for (int i = 0; i < _newImages.length; i++) {
      final xFile = _newImages[i];

      // نحدد الـ extension بأمان — إذا blob أو path فارغ نستخدم jpg
      String ext = 'jpg';
      final path = xFile.path.toLowerCase();
      if (!path.startsWith('blob:') && path.contains('.')) {
        final candidate =
            path.split('.').last.replaceAll(RegExp(r'[^a-z]'), '');
        if (['jpg', 'jpeg', 'png', 'webp'].contains(candidate)) {
          ext = candidate == 'jpeg' ? 'jpg' : candidate;
        }
      }

      // نحدد الـ content type
      final contentType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';

      final fileName =
          'chalets/$chaletId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

      try {
        // نستخدم uploadBinary دائماً — يعمل على الويب والموبايل
        final bytes = i < _newImageBytes.length && _newImageBytes[i].isNotEmpty
            ? _newImageBytes[i]
            : await xFile.readAsBytes();

        if (bytes.isEmpty) {
          // ملف فاسد أو غير قابل للقراءة؛ نتجاوزه دون إيقاف باقي الرفع.
          continue;
        }

        await _supabase.storage.from('chalet-images').uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(
                contentType: contentType,
                cacheControl: '3600',
                upsert: false,
              ),
            );

        final url =
            _supabase.storage.from('chalet-images').getPublicUrl(fileName);
        uploadedUrls.add(url);
      } catch (e) {
        // فشل رفع صورة واحدة لا يجب أن يوقف رفع الباقي، لكن يجب إعلام
        // المستخدم بأن صورة لم تُرفع.
        _showSnack('فشل رفع إحدى الصور، سيتم تجاهلها: $e', isError: true);
      }
    }

    return uploadedUrls;
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

  /// تحقق أكثر دقة من رابط يوتيوب: يتطلب صيغة domain صحيحة بدل احتواء
  /// النص على كلمة "youtube.com" في أي موضع (كان يقبل سابقًا أي نص عشوائي
  /// يحتوي هذه الكلمة، مثل "هذا ليس youtube.com رابط").
  bool _isValidYoutubeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true; // اختياري
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

  Map<String, dynamic> _buildChaletPayload({required List<String> images}) {
    final ownerId = AuthService.instance.currentUser?.id;
    if (ownerId == null) {
      throw Exception('لا يوجد مستخدم مسجل دخول حاليًا');
    }
    return {
      'owner_id': ownerId,
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'price_per_night': double.tryParse(_pricePerNightCtrl.text.trim()) ?? 0,
      // location must be non-null in payload for supabase
      // (keep a safe default if user didn't provide address)
      'location': (() {
        final loc = _locationCtrl.text.trim();
        if (loc.isNotEmpty) return loc;
        final city = _cityCtrl.text.trim();
        if (city.isNotEmpty) return city;
        return 'غير محدد';
      })(),
      'city': _cityCtrl.text.trim(),
      'max_guests': int.tryParse(_maxGuestsCtrl.text.trim()) ?? 1,
      'bedrooms': _bedrooms,
      'bathrooms': _bathrooms,
      'has_pool': _pool,
      'has_wifi': _wifi,
      'has_bbq': _bbq,
      'has_parking': _parking,
      'deposit_amount': double.tryParse(_depositCtrl.text.trim()) ?? 0,
      'min_nights': int.tryParse(_minNightsCtrl.text.trim()) ?? 1,
      'booking_type': _bookingType,
      'images': images,
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

    // تحقق نهائي إضافي على رابط اليوتيوب وقت الحفظ (وليس فقط أثناء
    // التنقل بين الخطوات) لأن المستخدم قد يعدّل الحقل بعد تجاوز الخطوة.
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

    if (_saving) return; // يحمي من الضغط المتكرر على زر الحفظ
    setState(() => _saving = true);

    try {
      String chaletId;

      if (_editingChaletId != null) {
        // وضع تعديل شاليه موجود: نرفع الصور الجديدة أولًا، ثم نحدّث السجل
        // كاملًا دفعة واحدة.
        chaletId = _editingChaletId!;
        final newUrls = await _uploadNewImages(chaletId);
        final allImages = [..._existingImageUrls, ...newUrls];
        final payload = _buildChaletPayload(images: allImages);
        await _supabase.from('chalets').update(payload).eq('id', chaletId);
      } else {
        // وضع إنشاء جديد: ننشئ السجل الكامل دفعة واحدة بعد رفع الصور.
        // لرفع الصور نحتاج معرف الشاليه أولًا، فننشئه بحالة غير متاحة
        // للعامة (is_available: false) كخطوة وسيطة آمنة، ثم نكمل التحديث
        // الكامل فورًا بعد رفع الصور. لو فشل أي شيء بعد هذه النقطة، يبقى
        // للمستخدم سجل بحالة "غير متاح" بدل ضياع كل العمل، وهو قابل
        // لإعادة المحاولة (تعديل) دون أن يظهر للعامة أبدًا.
        final ownerId = AuthService.instance.currentUser?.id;
        if (ownerId == null) {
          throw Exception('لا يوجد مستخدم مسجل دخول حاليًا');
        }
        final inserted = await _supabase
            .from('chalets')
            .insert({
              'owner_id': ownerId,
              'name': _nameCtrl.text.trim(),
              'is_available': false,
              'is_approved': false,
            })
            .select('id')
            .single();
        chaletId = inserted['id'] as String;

        final newUrls = await _uploadNewImages(chaletId);
        final allImages = [..._existingImageUrls, ...newUrls];
        final payload = _buildChaletPayload(images: allImages);
        await _supabase.from('chalets').update(payload).eq('id', chaletId);
      }

      // التحويل لصفة "مالك" يحدث فقط بعد نجاح حفظ الشاليه بالكامل، حتى لا
      // يصبح المستخدم مالكًا بدون أي شاليه فعلي في حال فشل الحفظ.
      await AuthService.instance.becomeOwner();

      if (!mounted) return;
      _showSnack('تم حفظ الشاليه بنجاح ✅');
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      context.go('/owner-dashboard');
    } catch (e) {
      if (mounted) _showSnack('حدث خطأ أثناء الحفظ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ====================== Step content ======================

  Widget _buildStep1() {
    return _sectionCard(
      icon: Icons.info_outline_rounded,
      title: 'المعلومات الأساسية',
      child: Column(
        children: [
          CustomTextField(
            controller: _nameCtrl,
            label: 'اسم الشاليه',
            hint: 'مثال: شاليه الندى',
            prefixIcon: Icons.home_work_rounded,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'هاد الحقل مطلوب' : null,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _descCtrl,
            label: 'تفاصيل / وصف الشاليه',
            hint: 'اكتب وصفاً مختصراً...',
            prefixIcon: Icons.description_outlined,
            maxLines: 4,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'هاد الحقل مطلوب' : null,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _maxGuestsCtrl,
            label: 'عدد الضيوف',
            hint: 'مثال: 10',
            prefixIcon: Icons.group_outlined,
            keyboardType: TextInputType.number,
            validator: (v) {
              final val = int.tryParse(v?.trim() ?? '');
              if (val == null || val <= 0) return 'أدخل رقم صحيح';
              if (val > 200) return 'رقم غير منطقي';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _cities.contains(_cityCtrl.text.trim())
                ? _cityCtrl.text.trim()
                : _cities.first,
            decoration: InputDecoration(
              labelText: 'المدينة',
              prefixIcon: const Icon(Icons.location_city_rounded,
                  color: AppColors.primary),
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
          const SizedBox(height: 12),
          CustomTextField(
            controller: _locationCtrl,
            label: 'العنوان',
            hint: 'مثال: قرب مدخل بيتا',
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _videoUrlCtrl,
            label: 'رابط فيديو يوتيوب (اختياري)',
            hint: 'https://youtube.com/watch?v=...',
            prefixIcon: Icons.smart_display_outlined,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null; // اختياري
              if (!_isValidYoutubeUrl(v)) {
                return 'يرجى إدخال رابط يوتيوب صحيح';
              }
              return null;
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'إضافة فيديو يزيد من فرص حجز شاليهك بشكل ملحوظ',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final allCount = _existingImageUrls.length + _newImages.length;
    return _sectionCard(
      icon: Icons.photo_library_rounded,
      title: 'صور الشاليه',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 14, color: Colors.red),
              const SizedBox(width: 4),
              Text(
                'إضافة صورة واحدة على الأقل إجباري',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
          if (allCount > 0) const SizedBox(height: 12),
          if (allCount < 8)
            InkWell(
              onTap: _saving ? null : _pickImages,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryPale.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'إضافة صور ($allCount/8)',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'سيتم رفع الصور إلى Supabase Storage عند حفظ الشاليه.',
            style: TextStyle(
                fontFamily: 'Cairo', color: AppColors.textHint, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return _sectionCard(
      icon: Icons.star_outline_rounded,
      title: 'المميزات',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _numberField(
                      label: 'غرف النوم',
                      value: _bedrooms,
                      onChanged: (v) => setState(() => _bedrooms = v),
                      min: 1,
                      max: 50)),
              const SizedBox(width: 12),
              Expanded(
                  child: _numberField(
                      label: 'الحمامات',
                      value: _bathrooms,
                      onChanged: (v) => setState(() => _bathrooms = v),
                      min: 1,
                      max: 50)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return _sectionCard(
      icon: Icons.attach_money_rounded,
      title: 'الأسعار',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _pricePerNightCtrl,
                  label: 'السعر لكل ليلة',
                  hint: 'مثال: 350',
                  prefixIcon: Icons.attach_money_rounded,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final val = double.tryParse(v?.trim() ?? '');
                    if (val == null || val <= 0) {
                      return 'أدخل رقم أكبر من صفر';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: _depositCtrl,
                  label: 'مبلغ الوديعة',
                  hint: 'مثال: 100',
                  prefixIcon: Icons.account_balance_wallet_outlined,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final val = double.tryParse(v?.trim() ?? '');
                    if (val == null || val < 0) return 'أدخل رقم صحيح';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _minNightsCtrl,
                  label: 'الحد الأدنى للليالي',
                  hint: 'مثال: 1',
                  prefixIcon: Icons.nights_stay_outlined,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final val = int.tryParse(v?.trim() ?? '');
                    if (val == null || val <= 0) return 'أدخل رقم صحيح';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _bookingType,
                  decoration: InputDecoration(
                    labelText: 'نوع الحجز',
                    prefixIcon: const Icon(Icons.calendar_today_rounded,
                        color: AppColors.primary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'يومي',
                        child: Text('يومي',
                            style: TextStyle(fontFamily: 'Cairo'))),
                    DropdownMenuItem(
                        value: 'خارجي',
                        child: Text('خارجي',
                            style: TextStyle(fontFamily: 'Cairo'))),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _bookingType = v);
                  },
                  validator: (v) =>
                      v == null || v.isEmpty ? 'اختر نوع الحجز' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'سيتم حفظ هذه القيم مباشرة في جدول chalets في Supabase.',
            style: TextStyle(
                fontFamily: 'Cairo', color: AppColors.textHint, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _numberField(
      {required String label,
      required int value,
      required ValueChanged<int> onChanged,
      required int min,
      required int max}) {
    // نستخدم مفتاح ثابت على قيمة value عبر controller منفصل بدل إعادة بناء
    // controller جديد بكل build (كان يفقد موضع المؤشر/الفوكس قبليًا).
    return _NumberFieldInput(
      label: label,
      value: value,
      min: min,
      max: max,
      onChanged: onChanged,
    );
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
        backgroundColor: isError ? AppColors.error : AppColors.primary,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // يمنع الخروج بالخطأ بدون تأكيد إذا كانت هناك بيانات لم تُحفظ، وأيضًا
      // أثناء عملية الحفظ نفسها (لتجنب إيقاف عملية الرفع في منتصفها).
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_saving) {
          _showSnack('يرجى الانتظار حتى انتهاء عملية الحفظ');
          return;
        }
        final confirmed = await _confirmLeaveIfDirty();
        if (confirmed && mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('إضافة شاليه',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: _saving
                ? null
                : () async {
                    final confirmed = await _confirmLeaveIfDirty();
                    if (confirmed && mounted) context.pop();
                  },
          ),
        ),
        body: SafeArea(
          child: Stepper(
            type: StepperType.horizontal,
            currentStep: _currentStep,
            onStepContinue: _saving ? null : _handleStepContinue,
            onStepCancel: _saving ? null : _handleStepCancel,
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: _currentStep == 3
                            ? (_saving ? 'جارٍ الحفظ...' : 'حفظ الشاليه')
                            : 'التالي',
                        loading: _saving,
                        icon: _currentStep == 3
                            ? Icons.save_rounded
                            : Icons.navigate_next_rounded,
                        onPressed: details.onStepContinue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_currentStep > 0)
                      SizedBox(
                        width: 130,
                        child: AppButton(
                          label: 'رجوع',
                          outline: true,
                          icon: Icons.arrow_back_rounded,
                          onPressed: details.onStepCancel,
                        ),
                      ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('1'),
                content: Column(children: [
                  _stepNavTop('إضافة الشاليه — الخطوة 1'),
                  // كل خطوة فيها validators تُلف بـ Form مستقل خاص بها فقط،
                  // بدل Form واحد مشترك لكل الخطوات الأربعة، تجنبًا لتحقق
                  // النموذج من حقول خطوات أخرى لم يصلها المستخدم بعد.
                  Form(key: _step1FormKey, child: _buildStep1()),
                ]),
                isActive: _currentStep == 0,
              ),
              Step(
                title: const Text('2'),
                content: Column(children: [
                  _stepNavTop('إضافة الشاليه — الخطوة 2'),
                  _buildStep2()
                ]),
                isActive: _currentStep == 1,
              ),
              Step(
                title: const Text('3'),
                content: Column(children: [
                  _stepNavTop('إضافة الشاليه — الخطوة 3'),
                  _buildStep3()
                ]),
                isActive: _currentStep == 2,
              ),
              Step(
                title: const Text('4'),
                content: Column(children: [
                  _stepNavTop('إضافة الشاليه — الخطوة 4'),
                  Form(key: _step4FormKey, child: _buildStep4()),
                ]),
                isActive: _currentStep == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// حقل رقمي صغير مستقل بـ controller داخلي ثابت، لتفادي مشكلة إعادة بناء
/// TextEditingController جديد من الصفر في كل عملية build (وهذا كان يكسر
/// موضع المؤشر والتركيز في النسخة السابقة لأن الودجت لم يكن StatefulWidget
/// مستقلاً).
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
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.charcoal)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _ctrl,
          textAlign: TextAlign.start,
          keyboardType: TextInputType.number,
          onChanged: (s) {
            final val = int.tryParse(s.trim()) ?? widget.min;
            final clamped = val.clamp(widget.min, widget.max);
            widget.onChanged(clamped);
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
