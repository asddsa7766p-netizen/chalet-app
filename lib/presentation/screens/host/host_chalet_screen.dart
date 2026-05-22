import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/common_widgets.dart';

class HostChaletScreen extends StatefulWidget {
  const HostChaletScreen({super.key});

  @override
  State<HostChaletScreen> createState() => _HostChaletScreenState();
}

class _HostChaletScreenState extends State<HostChaletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _bedroomsCtrl = TextEditingController(text: '1');
  final _bathroomsCtrl = TextEditingController(text: '1');
  final _maxGuestsCtrl = TextEditingController(text: '2');
  final _minNightsCtrl = TextEditingController(text: '1');

  // Amenities
  bool _pool = false;
  bool _wifi = false;
  bool _bbq = false;
  bool _parking = false;

  // Booking type
  String _bookingType = 'instant'; // 'instant' | 'request'

  // City
  String _selectedCity = 'نابلس';
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

  // Images
  final List<File> _newImages = [];
  final List<String> _existingImageUrls = [];
  final List<String> _deletedImageUrls = [];
  final ImagePicker _picker = ImagePicker();

  // State
  bool _loading = false;
  bool _initialLoading = true;
  String? _chaletId;

  @override
  void initState() {
    super.initState();
    _loadExistingChalet();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    _bedroomsCtrl.dispose();
    _bathroomsCtrl.dispose();
    _maxGuestsCtrl.dispose();
    _minNightsCtrl.dispose();
    super.dispose();
  }

  // ─── Load existing chalet ───────────────────────────────────────
  Future<void> _loadExistingChalet() async {
    try {
      final userId = AuthService.instance.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('chalets')
          .select()
          .eq('owner_id', userId)
          .limit(1)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _chaletId = data['id'] as String?;
          _nameCtrl.text = data['name'] ?? '';
          _descCtrl.text = data['description'] ?? '';
          _priceCtrl.text = (data['price_per_night'] ?? '').toString();
          _locationCtrl.text = data['location'] ?? '';
          _bedroomsCtrl.text = (data['bedrooms'] ?? 1).toString();
          _bathroomsCtrl.text = (data['bathrooms'] ?? 1).toString();
          _maxGuestsCtrl.text = (data['max_guests'] ?? 2).toString();
          _minNightsCtrl.text = (data['min_nights'] ?? 1).toString();
          _pool = data['has_pool'] ?? false;
          _wifi = data['has_wifi'] ?? false;
          _bbq = data['has_bbq'] ?? false;
          _parking = data['has_parking'] ?? false;
          _bookingType = data['booking_type'] ?? 'instant';
          _selectedCity = data['city'] ?? 'نابلس';

          // Load existing images
          final images = data['images'];
          if (images is List) {
            _existingImageUrls.addAll(images.cast<String>());
          }
        });
      }
    } catch (e) {
      // No chalet yet — create new
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  // ─── Pick images ────────────────────────────────────────────────
  Future<void> _pickImages() async {
    final total = _existingImageUrls.length + _newImages.length;
    if (total >= 8) {
      _showSnack('الحد الأقصى 8 صور', isError: true);
      return;
    }

    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;

    final remaining = 8 - total;
    final toAdd = picked.take(remaining).map((x) => File(x.path)).toList();
    setState(() => _newImages.addAll(toAdd));
  }

  // ─── Upload images to Supabase Storage ──────────────────────────
  Future<List<String>> _uploadImages(String chaletId) async {
    final uploadedUrls = <String>[];

    for (final file in _newImages) {
      final ext = file.path.split('.').last;
      final fileName =
          'chalets/$chaletId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage.from('chalet-images').upload(fileName, file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false));

      final url =
          _supabase.storage.from('chalet-images').getPublicUrl(fileName);
      uploadedUrls.add(url);
    }

    return uploadedUrls;
  }

  // ─── Delete image ────────────────────────────────────────────────
  void _deleteExistingImage(String url) {
    setState(() {
      _existingImageUrls.remove(url);
      _deletedImageUrls.add(url);
    });
  }

  void _deleteNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  // ─── Save ────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final userId = AuthService.instance.currentUser!.id;
      final isNew = _chaletId == null;

      // If new, insert first to get ID
      String chaletId = _chaletId ?? '';
      if (isNew) {
        final inserted = await _supabase
            .from('chalets')
            .insert({'owner_id': userId, 'name': _nameCtrl.text.trim()})
            .select('id')
            .single();
        chaletId = inserted['id'] as String;
        _chaletId = chaletId;
      }

      // Upload new images
      final newUrls = await _uploadImages(chaletId);

      // Final image list = remaining existing + new
      final allImages = [..._existingImageUrls, ...newUrls];

      // Save chalet data
      await _supabase.from('chalets').upsert({
        'id': chaletId,
        'owner_id': userId,
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price_per_night': double.tryParse(_priceCtrl.text.trim()) ?? 0,
        'location': _locationCtrl.text.trim(),
        'city': _selectedCity,
        'bedrooms': int.tryParse(_bedroomsCtrl.text.trim()) ?? 1,
        'bathrooms': int.tryParse(_bathroomsCtrl.text.trim()) ?? 1,
        'max_guests': int.tryParse(_maxGuestsCtrl.text.trim()) ?? 2,
        'min_nights': int.tryParse(_minNightsCtrl.text.trim()) ?? 1,
        'has_pool': _pool,
        'has_wifi': _wifi,
        'has_bbq': _bbq,
        'has_parking': _parking,
        'booking_type': _bookingType,
        'images': allImages,
        'is_available': true,
        'is_approved': false,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _showSnack(isNew ? 'تم إضافة الشاليه بنجاح ✅' : 'تم حفظ التغييرات ✅');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) _showSnack('حدث خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_chaletId == null ? 'إضافة شاليه' : 'تعديل الشاليه'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── الصور ──
              _sectionCard(
                title: 'صور الشاليه',
                icon: Icons.photo_library_rounded,
                child: _buildImagesSection(),
              ),
              const SizedBox(height: 14),

              // ── البيانات الأساسية ──
              _sectionCard(
                title: 'البيانات الأساسية',
                icon: Icons.info_outline_rounded,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _nameCtrl,
                      label: 'اسم الشاليه',
                      hint: 'مثال: شاليه الندى',
                      prefixIcon: Icons.home_work_rounded,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'هاد الحقل مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _descCtrl,
                      label: 'الوصف',
                      hint: 'اكتب وصفاً مختصراً...',
                      prefixIcon: Icons.description_outlined,
                      maxLines: 4,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'هاد الحقل مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _locationCtrl,
                      label: 'الموقع / العنوان',
                      hint: 'مثال: قرب مدخل بيتا',
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildCityDropdown(),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── التفاصيل ──
              _sectionCard(
                title: 'التفاصيل',
                icon: Icons.tune_rounded,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _priceCtrl,
                            label: 'السعر / ليلة (₪)',
                            hint: '350',
                            prefixIcon: Icons.attach_money_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomTextField(
                            controller: _minNightsCtrl,
                            label: 'أقل عدد ليالي',
                            hint: '1',
                            prefixIcon: Icons.nights_stay_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _bedroomsCtrl,
                            label: 'غرف النوم',
                            hint: '1',
                            prefixIcon: Icons.bed_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomTextField(
                            controller: _bathroomsCtrl,
                            label: 'الحمامات',
                            hint: '1',
                            prefixIcon: Icons.bathroom_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomTextField(
                            controller: _maxGuestsCtrl,
                            label: 'أقصى ضيوف',
                            hint: '10',
                            prefixIcon: Icons.group_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── المميزات ──
              _sectionCard(
                title: 'المميزات',
                icon: Icons.star_outline_rounded,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _amenityChip('مسبح', Icons.pool_rounded, _pool,
                        (v) => setState(() => _pool = v)),
                    _amenityChip('واي فاي', Icons.wifi_rounded, _wifi,
                        (v) => setState(() => _wifi = v)),
                    _amenityChip('شواء', Icons.outdoor_grill_rounded, _bbq,
                        (v) => setState(() => _bbq = v)),
                    _amenityChip('موقف سيارة', Icons.local_parking_rounded,
                        _parking, (v) => setState(() => _parking = v)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── نوع الحجز ──
              _sectionCard(
                title: 'نوع الحجز',
                icon: Icons.calendar_today_outlined,
                child: Column(
                  children: [
                    _bookingTypeOption(
                      value: 'instant',
                      label: 'حجز فوري',
                      subtitle: 'الزبون يحجز مباشرة بدون موافقة',
                      icon: Icons.flash_on_rounded,
                    ),
                    const SizedBox(height: 8),
                    _bookingTypeOption(
                      value: 'request',
                      label: 'طلب موافقة',
                      subtitle: 'أنت توافق أو ترفض كل حجز',
                      icon: Icons.how_to_reg_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── زر الحفظ ──
              AppButton(
                label: _chaletId == null ? 'إضافة الشاليه' : 'حفظ التغييرات',
                onPressed: _save,
                loading: _loading,
                icon: Icons.save_rounded,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  fontWeight: FontWeight.w800,
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

  Widget _buildImagesSection() {
    final allCount = _existingImageUrls.length + _newImages.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid of images
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
                return _existingImageTile(_existingImageUrls[i]);
              } else {
                final newIndex = i - _existingImageUrls.length;
                return _newImageTile(newIndex);
              }
            },
          ),

        if (allCount > 0) const SizedBox(height: 12),

        // Add button
        if (allCount < 8)
          InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryPale.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    style: BorderStyle.solid),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'إضافة صور (${allCount}/8)',
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
      ],
    );
  }

  Widget _existingImageTile(String url) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.sand,
              child: const Icon(Icons.broken_image, color: AppColors.textHint),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: _deleteButton(() => _deleteExistingImage(url)),
        ),
      ],
    );
  }

  Widget _newImageTile(int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            _newImages[index],
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: _deleteButton(() => _deleteNewImage(index)),
        ),
      ],
    );
  }

  Widget _deleteButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 14, color: Colors.white),
      ),
    );
  }

  Widget _buildCityDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCity,
      decoration: InputDecoration(
        labelText: 'المدينة',
        prefixIcon:
            const Icon(Icons.location_city_rounded, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.sand),
        ),
      ),
      items: _cities
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _selectedCity = v);
      },
      style: const TextStyle(
          fontFamily: 'Cairo', fontSize: 14, color: AppColors.charcoal),
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
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingTypeOption({
    required String value,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _bookingType == value;
    return InkWell(
      onTap: () => setState(() => _bookingType = value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryPale.withValues(alpha: 0.2)
              : AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.sand,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        color:
                            selected ? AppColors.primary : AppColors.charcoal,
                      )),
                  Text(subtitle,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      )),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    size: 14, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
