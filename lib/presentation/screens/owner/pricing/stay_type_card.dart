part of 'chalet_pricing_screen.dart';

extension _StayTypeCardSection on _ChaletPricingScreenState {
  // ---------------- أنواع الإقامة ----------------

  Widget _buildStayTypesSection() {
    return Container(
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
            'أنواع الإقامة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'كل فترة مفعّلة يحجزها الضيف ليوم واحد. حدد وقت بداية ونهاية '
            'الفترة، وسعراً احتياطياً للأيام التي بلا سعر (زي: إقامة صباحية، '
            'إقامة مسائية، يوم كامل...)',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          for (final type in ChaletStayType.values) ...[
            _buildStayTypeCard(type),
            if (type != ChaletStayType.values.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildStayTypeCard(ChaletStayType type) {
    final enabled = _stayTypeEnabled.contains(type);
    final isSaving = _savingStayType.contains(type);
    final base = _baseFields[type]!;
    final cardDirty = _cardDirty(type);

    return Container(
      key: ValueKey('stayCard_${type.dbValue}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.primaryPale.withValues(alpha: 0.15)
            : AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.sand,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(type.icon,
                  size: 20,
                  color: enabled ? AppColors.primary : AppColors.textHint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  type.label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: enabled ? AppColors.charcoal : AppColors.textHint,
                  ),
                ),
              ),
              if (isSaving && !_savingAll)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  key: ValueKey('stayToggle_${type.dbValue}'),
                  value: enabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: _savingAll ? null : (v) => _toggleStayType(type, v),
                ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _timeTile(
                    label: 'بداية الفترة',
                    time: _draftCheckin[type]!,
                    onTap: () => _pickTime(type: type, isCheckin: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _timeTile(
                    label: 'نهاية الفترة',
                    time: _draftCheckout[type]!,
                    onTap: () => _pickTime(type: type, isCheckin: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: ValueKey('baseField_${type.dbValue}'),
              controller: base.ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'سعر احتياطي للأيام التي بلا سعر',
                hintText: 'اختياري',
                helperText:
                    'يُطبَّق فقط على الأيام التي ليس لها سعر يوم (لا لهذا النوع '
                    'ولا «عام»).',
                helperMaxLines: 2,
                errorText: base.invalid ? 'سعر غير صحيح' : null,
                suffixText: base.dirty ? 'لم يُحفظ' : null,
                suffixStyle: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentDark),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: _fieldBorder(dirty: base.dirty),
                enabledBorder: _fieldBorder(dirty: base.dirty),
              ),
            ),
            BasePriceNotice(
              type: type,
              impact: basePriceImpact(_snapshot(draft: true), type),
              onOpenTypePrices: () => _openTypePrices(type.dbValue),
            ),
            const SizedBox(height: 6),
            // Wrap بدل Row+Spacer: يلتف للسطر التالي عند النص الكبير بدل الفيض.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  key: ValueKey('openTypePrices_${type.dbValue}'),
                  onPressed: () => _openTypePrices(type.dbValue),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.calendar_view_week_rounded, size: 16),
                  label: const Text('أسعار الأيام لهذا النوع',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                ),
                _saveButton(
                  key: ValueKey('cardSave_${type.dbValue}'),
                  dirty: cardDirty,
                  saving: isSaving,
                  onTap: () => _persistCard(type, quiet: false),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  OutlineInputBorder _fieldBorder({required bool dirty}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: dirty ? AppColors.accent : AppColors.sand,
          width: dirty ? 1.6 : 1,
        ),
      );

  /// زر "حفظ": بارز عند وجود تعديل، ومعطّل (باهت) بغير ذلك.
  Widget _saveButton({
    required Key key,
    required bool dirty,
    required bool saving,
    required VoidCallback onTap,
  }) {
    if (saving) {
      return const SizedBox(
        width: 64,
        height: 34,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }
    return FilledButton(
      key: key,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        disabledBackgroundColor: AppColors.sand,
        disabledForegroundColor: AppColors.textHint,
        minimumSize: const Size(64, 34),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: dirty && !_savingAll ? onTap : null,
      child: const Text('حفظ',
          style: TextStyle(
              fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }

  Widget _timeTile({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.sand),
        ),
        child: Builder(builder: (context) {
          final labelText = Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: AppColors.textSecondary));
          final timeText = Text(
            time.format(context),
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal),
          );
          // النص الكبير: عمود بدل صف، فلا يفيض (البلاطة نصف عرض البطاقة).
          if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, timeText],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [labelText, timeText],
          );
        }),
      ),
    );
  }
}
