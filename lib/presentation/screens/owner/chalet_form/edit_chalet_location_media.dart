part of 'owner_edit_chalet_screen.dart';

extension _EditChaletLocationMedia on _OwnerEditChaletScreenState {
  Widget _buildLocation() {
    final cities = [
      ..._OwnerEditChaletScreenState._baseCities,
      if (_orig != null &&
          _orig!.city.trim().isNotEmpty &&
          !_OwnerEditChaletScreenState._baseCities.contains(_orig!.city))
        _orig!.city,
    ];
    final cityDirty = _d.contains('city');
    final coordsDirty = _d.contains('latitude') || _d.contains('longitude');
    final coords = ChaletEditValidation.coordinates(_lat.text, _lng.text);

    return _section(
      id: 'location',
      title: 'الموقع',
      icon: Icons.location_on_outlined,
      children: [
        KeyedSubtree(
          key: _fieldKeys['city'],
          child: DropdownButtonFormField<String>(
            key: const ValueKey('field_city'),
            initialValue: cities.contains(_city) ? _city : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'المدينة',
              errorText: _e['city'],
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: _border(cityDirty),
              enabledBorder: _border(cityDirty),
              errorBorder: _border(cityDirty, error: true),
            ),
            items: [
              for (final c in cities)
                DropdownMenuItem(
                  value: c,
                  child: Text(c,
                      style: const TextStyle(
                          fontFamily: 'Cairo', fontSize: 14)),
                ),
            ],
            onChanged: (v) => _setState(() => _city = v),
          ),
        ),
        const SizedBox(height: 14),
        _field(
          fieldKey: 'location',
          ctrl: _location,
          label: 'المنطقة/الحي',
          hint: 'مثال: قرب مدخل بيتا',
          helper: 'إن تركته فارغاً سنستخدم اسم المدينة.',
        ),
        const SizedBox(height: 14),
        _field(
          fieldKey: 'address',
          ctrl: _address,
          label: 'العنوان التفصيلي (اختياري)',
          helper: 'يظهر في صفحة الشاليه مع الخريطة.',
        ),
        const SizedBox(height: 14),
        // المفتاحان latitude/longitude يحملهما حقلاهما نفسهما (للتمرير لأول خطأ)،
        // فلا لفافة خارجية بنفس المفتاح.
        LayoutBuilder(builder: (context, c) {
            final stack = c.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3;
            final lat = _field(
              fieldKey: 'latitude',
              ctrl: _lat,
              label: 'خط العرض',
              hint: '32.2211',
              direction: TextDirection.ltr,
              type: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
            );
            final lng = _field(
              fieldKey: 'longitude',
              ctrl: _lng,
              label: 'خط الطول',
              hint: '35.2544',
              direction: TextDirection.ltr,
              type: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
            );
            if (stack) {
              return Column(children: [lat, const SizedBox(height: 10), lng]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: lat),
                const SizedBox(width: 10),
                Expanded(child: lng),
              ],
            );
          }),
        if (coordsDirty && coords.warning != null)
          Container(
            key: const ValueKey('coordsWarning'),
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.55)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(coords.warning!,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.charcoal)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('useMyLocation'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: _locating ? null : _useMyLocation,
            icon: _locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('تحديث بموقعي الحالي',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildMedia() {
    final dirty = _d.contains('images');
    return _section(
      id: 'media',
      title: 'الصور والفيديو',
      icon: Icons.photo_camera_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'الصور (${_images.length}/${ChaletEditValidation.imagesMax})',
                key: const ValueKey('imagesCounter'),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: dirty ? AppColors.accentDark : AppColors.charcoal,
                ),
              ),
            ),
            if (dirty)
              const Text('لم يُحفظ',
                  key: ValueKey('imagesDirty'),
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentDark)),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'الصورة الأولى هي الغلاف. الحد الأقصى 8 صور، وكل صورة حتى 10 ميغابايت '
          '(JPG وPNG وWEBP وHEIC).',
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        KeyedSubtree(
          key: _fieldKeys['images'],
          child: ChaletImagesEditor(
            images: _images,
            maxImages: ChaletEditValidation.imagesMax,
            enabled: !_saving,
            onAdd: _addImages,
            onRemove: _removeImage,
            onMakeCover: _makeCover,
          ),
        ),
        if (_e['images'] != null) ...[
          const SizedBox(height: 8),
          Text(_e['images']!,
              key: const ValueKey('imagesError'),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.error)),
        ],
        if (_imageError != null) ...[
          const SizedBox(height: 8),
          Text(_imageError!,
              key: const ValueKey('imagePickError'),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.error)),
        ],
        const SizedBox(height: 16),
        _field(
          fieldKey: 'video_url',
          ctrl: _video,
          label: 'رابط فيديو يوتيوب (اختياري)',
          hint: 'https://youtube.com/watch?v=...',
          direction: TextDirection.ltr,
          type: TextInputType.url,
        ),
      ],
    );
  }

  String _bookingTypeLabel(String t) {
    switch (t) {
      case 'يومي':
      case 'daily':
        return 'يومي';
      case 'خارجي':
      case 'external':
        return 'خارجي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      default:
        return t;
    }
  }

  Widget _buildPricing() {
    final priceDirty = _d.contains('price_per_night');
    final availDirty = _d.contains('is_available');
    final priceValid = ChaletEditValidation.price(_price.text) == null;

    return _section(
      id: 'pricing',
      title: 'السعر والحجز',
      icon: Icons.attach_money_rounded,
      children: [
        _field(
          fieldKey: 'price_per_night',
          ctrl: _price,
          label: 'السعر الأساسي (يبدأ من)',
          type: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 8),
        const Text(
          'يظهر للضيوف كـ"السعر يبدأ من" في البحث وصفحة الشاليه، ويُطبَّق على أي '
          'يوم ليس له سعر يوم أو سعر خاص بالفترة. لتسعير أيام أو فترات '
          'محددة استخدم أسعار الأيام.',
          key: ValueKey('priceHelp'),
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary),
        ),
        if (priceDirty && priceValid)
          Container(
            key: const ValueKey('priceChangeNotice'),
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.55)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تغيير السعر سيؤثر على الأيام التي بلا سعر مضبوط.',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal),
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('openPricing'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 36),
            ),
            onPressed: _openPricing,
            icon: const Icon(Icons.calendar_view_week_rounded, size: 18),
            label: const Text('أسعار الأيام وأنواع الإقامة',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const Divider(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: availDirty ? AppColors.accent : AppColors.sand,
              width: availDirty ? 1.6 : 1,
            ),
          ),
          child: SwitchListTile(
            key: const ValueKey('availableSwitch'),
            contentPadding: EdgeInsets.zero,
            value: _available,
            onChanged: _saving ? null : (v) => _setState(() => _available = v),
            title: const Text('متاح للحجز',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            subtitle: Text(
              availDirty
                  ? 'لم يُحفظ — عند الإيقاف لا يظهر الشاليه للضيوف.'
                  : 'عند الإيقاف لا يظهر الشاليه للضيوف. والشاليه قيد المراجعة '
                      'لا يظهر أصلاً حتى تعتمده الإدارة.',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 12, height: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('bookingTypeReadOnly'),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.sand),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'نوع الحجز: ${_bookingTypeLabel(_bookingType)}',
                      key: const ValueKey('bookingTypeValue'),
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13.5,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'يحدد كيف تُصنَّف حجوزات هذا الشاليه في إحصائيات لوحتك: «يومي» '
                'حجوزات عادية، و«خارجي» حجوزات خارجية. لا يمكن تغييره من هذه '
                'الصفحة.',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
