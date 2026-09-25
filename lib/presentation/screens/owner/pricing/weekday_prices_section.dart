part of 'chalet_pricing_screen.dart';

extension _WeekdayPricesSection on _ChaletPricingScreenState {
  // ---------------- التسعير الأسبوعي (تبويبات) ----------------

  Widget _buildWeekdaySection() {
    final key = _selectedEditingType;
    final isDefault = key == _ChaletPricingScreenState._defaultKey;
    final type = isDefault ? null : ChaletStayType.fromDb(key);
    final draftSnap = _snapshot(draft: true);

    return Container(
      key: _weekdaySectionKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'التسعير الأسبوعي',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'اختر النوع اللي بدك تعدّل أسعار أيامه. تعديلاتك بكل نوع بتنحفظ '
            'كمسودة لحد ما تضغط "حفظ".',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _typeTab(label: 'كل الأنواع (عام)', value: _ChaletPricingScreenState._defaultKey),
              for (final t in _enabledTypes)
                _typeTab(label: t.shortLabel, value: t.dbValue),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isDefault
                ? 'أنت تعدّل: أسعار «عام»'
                : 'أنت تعدّل: أسعار "${type!.label}"',
            key: const ValueKey('editingTitle'),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isDefault
                ? 'تسري على كل نوع ما له سعر خاص بيومه. اتركه فاضي = يرجع '
                    'للسعر الاحتياطي للنوع (إن وُجد) ثم الافتراضي.'
                : 'تتفوق على أسعار «عام» لهذا النوع. اتركه فاضي = يرجع لسعر '
                    '«عام»، ثم السعر الاحتياطي، ثم الافتراضي.',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          for (var weekday = 0; weekday < 7; weekday++) ...[
            _buildWeekdayRow(key, type, weekday, draftSnap),
            if (weekday != 6) const Divider(height: 22),
          ],
        ],
      ),
    );
  }

  Widget _typeTab({required String label, required String value}) {
    final selected = _selectedEditingType == value;
    final hasDraft = _dirtyWeekdays(value) > 0;
    // تبويب مخصّص بدل ChoiceChip: ارتفاع الشريحة ثابت فيقصّ النص عندما تكبر
    // مقاييس سطر الخط (لوحظ بخط التطبيق الفعلي على الويب). هنا الارتفاع يتبع
    // النص مع حشوة.
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : AppColors.cream,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppColors.primary : AppColors.sand),
        ),
        child: InkWell(
          key: ValueKey('editTab_$value'),
          customBorder: const StadiumBorder(),
          onTap: () => _selectEditingType(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasDraft) ...[
                  Container(
                    key: ValueKey('tabDot_$value'),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.charcoal,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _weekdayHint(ChaletStayType? type, int day, PricingSnapshot draftSnap) {
    final fb = effectiveWeekdayPrice(
        draftSnap.withoutWeekday(type, day), type, day);
    final from = switch (fb.source) {
      PriceSource.defaultWeekday => 'من «عام»',
      PriceSource.typeBase => 'احتياطي',
      PriceSource.chaletDefault => 'افتراضي',
      PriceSource.typeWeekday => '',
    };
    return 'فارغ ← ${formatPriceNumber(fb.price)} $from'.trim();
  }

  Widget _buildWeekdayRow(
    String key,
    ChaletStayType? type,
    int weekday,
    PricingSnapshot draftSnap,
  ) {
    final field = _weekdayFields[key]![weekday]!;
    final isSaving = _savingWeekday.contains('$key:$weekday');
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            ChaletPricingService.weekdayLabels[weekday],
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            key: ValueKey('weekdayField_${key}_$weekday'),
            controller: field.ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              isDense: true,
              hintText: _weekdayHint(type, weekday, draftSnap),
              hintMaxLines: 1,
              hintStyle: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textHint),
              errorText: field.invalid ? 'سعر غير صحيح' : null,
              suffixText: field.dirty ? 'لم يُحفظ' : null,
              suffixStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentDark),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: _fieldBorder(dirty: field.dirty),
              enabledBorder: _fieldBorder(dirty: field.dirty),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 66,
          child: Center(
            child: _saveButton(
              key: ValueKey('weekdaySave_${key}_$weekday'),
              dirty: field.dirty,
              saving: isSaving && !_savingAll,
              onTap: () => _persistWeekday(key, weekday, quiet: false),
            ),
          ),
        ),
      ],
    );
  }
}
