part of 'owner_add_chalet_screen.dart';

extension _AddChaletSteps on _OwnerAddChaletScreenState {
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
                    onChanged: (v) => _setState(() => _bedrooms = v),
                    min: 1,
                    max: 50),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numberField(
                    label: 'الحمامات',
                    value: _bathrooms,
                    onChanged: (v) => _setState(() => _bathrooms = v),
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
            initialValue: _cities.contains(_cityCtrl.text.trim())
                ? _cityCtrl.text.trim()
                : _cities.first,
            decoration: InputDecoration(
              labelText: 'المدينة',
              prefixIcon:
                  const Icon(Icons.location_city_rounded, color: _OwnerAddChaletScreenState._darkGreen),
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
              _setState(() => _cityCtrl.text = v);
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
            ? _OwnerAddChaletScreenState._darkGreen.withValues(alpha: 0.06)
            : const Color(0xFFF6F2E7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              hasLocation ? _OwnerAddChaletScreenState._darkGreen.withValues(alpha: 0.4) : AppColors.sand,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasLocation
                ? Icons.check_circle_rounded
                : Icons.my_location_rounded,
            color: hasLocation ? _OwnerAddChaletScreenState._darkGreen : AppColors.textHint,
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
                    color: hasLocation ? _OwnerAddChaletScreenState._darkGreen : AppColors.charcoal,
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
                    color: hasLocation ? _OwnerAddChaletScreenState._darkGreen : AppColors.sand),
                foregroundColor: _OwnerAddChaletScreenState._darkGreen,
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
          const Row(
            children: [
              Icon(Icons.star_rounded, size: 14, color: Colors.red),
              SizedBox(width: 4),
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
              style: const TextStyle(
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
                  (v) => _setState(() => _wifi = v)),
              _amenityChip('مسبح', Icons.pool_rounded, _pool,
                  (v) => _setState(() => _pool = v)),
              _amenityChip('باربيكيو', Icons.outdoor_grill_rounded, _bbq,
                  (v) => _setState(() => _bbq = v)),
              _amenityChip('باركينج', Icons.local_parking_rounded, _parking,
                  (v) => _setState(() => _parking = v)),
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
            initialValue: _bookingType,
            decoration: InputDecoration(
              labelText: 'نوع الحجز',
              prefixIcon:
                  const Icon(Icons.calendar_today_rounded, color: _OwnerAddChaletScreenState._darkGreen),
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
              if (v != null) _setState(() => _bookingType = v);
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
}
