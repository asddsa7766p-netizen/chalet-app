part of 'owner_edit_chalet_screen.dart';

extension _EditChaletSections on _OwnerEditChaletScreenState {
  // ---------------- مساعدات عرض ----------------

  Widget _section({
    required String id,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final dirty = _d.any(_OwnerEditChaletScreenState._sections[id]!.contains);
    return Container(
      key: ValueKey('section_$id'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              if (dirty)
                Container(
                  key: ValueKey('sectionDot_$id'),
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  OutlineInputBorder _border(bool dirty, {bool error = false}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: error
              ? AppColors.error
              : dirty
                  ? AppColors.accent
                  : AppColors.sand,
          width: dirty || error ? 1.6 : 1,
        ),
      );

  Widget _field({
    required String fieldKey,
    required TextEditingController ctrl,
    required String label,
    String? hint,
    String? helper,
    int maxLines = 1,
    TextInputType? type,
    TextDirection? direction,
    int? counterMax,
  }) {
    final dirty = _d.contains(fieldKey);
    final error = _e[fieldKey];
    final multiline = maxLines > 1;
    return KeyedSubtree(
      key: _fieldKeys[fieldKey],
      child: TextField(
        key: ValueKey('field_$fieldKey'),
        controller: ctrl,
        keyboardType: type,
        textDirection: direction,
        maxLines: maxLines,
        minLines: multiline ? 3 : 1,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 3,
          errorText: error,
          errorMaxLines: 3,
          suffixText: dirty && !multiline ? 'لم يُحفظ' : null,
          suffixStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.accentDark),
          counterText: counterMax == null
              ? null
              : '${dirty ? 'لم يُحفظ — ' : ''}${ctrl.text.length}/$counterMax',
          counterStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: dirty ? AppColors.accentDark : AppColors.textHint),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: _border(dirty),
          enabledBorder: _border(dirty),
          errorBorder: _border(dirty, error: true),
          focusedErrorBorder: _border(dirty, error: true),
        ),
      ),
    );
  }

  // ---------------- الحالة ----------------

  Widget _buildStatusCard() {
    final rejected = _rejectionReason != null;
    final color = _approved
        ? AppColors.success
        : (rejected ? AppColors.error : AppColors.warning);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _approved
                ? Icons.verified_outlined
                : (rejected
                    ? Icons.block_rounded
                    : Icons.hourglass_top_rounded),
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _approved ? 'معتمد' : (rejected ? 'مرفوض' : 'قيد المراجعة'),
                  key: const ValueKey('approvalBadge'),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: rejected ? AppColors.error : AppColors.charcoal,
                  ),
                ),
                if (rejected) ...[
                  Text(
                    'سبب الرفض: ${_rejectionReason!.isEmpty ? '—' : _rejectionReason}',
                    key: const ValueKey('rejectionReason'),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const Text(
                    'عدّل ما طلبته الإدارة واحفظ، ثم ارجع إلى "شاليهاتي" واضغط "إعادة الإرسال للمراجعة".',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ] else
                  const Text(
                    'حالة الاعتماد تحددها الإدارة ولا يمكن تغييرها من هنا.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- الأقسام ----------------

  Widget _buildBasic() {
    return _section(
      id: 'basic',
      title: 'المعلومات الأساسية',
      icon: Icons.info_outline_rounded,
      children: [
        _field(
          fieldKey: 'name',
          ctrl: _name,
          label: 'اسم الشاليه',
        ),
        const SizedBox(height: 14),
        _field(
          fieldKey: 'description',
          ctrl: _desc,
          label: 'وصف الشاليه',
          maxLines: 6,
          counterMax: ChaletEditValidation.descriptionMax,
        ),
      ],
    );
  }

  Widget _stepper({
    required String id,
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final dirty = _d.contains(id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dirty ? AppColors.accent : AppColors.sand,
          width: dirty ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  height: 1.3,
                  color: dirty
                      ? AppColors.accentDark
                      : AppColors.textSecondary)),
          Row(
            children: [
              IconButton(
                key: ValueKey('${id}Minus'),
                visualDensity: VisualDensity.compact,
                onPressed: value > ChaletEditValidation.roomsMin
                    ? () => onChanged(value - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
                tooltip: 'إنقاص',
              ),
              Expanded(
                child: Text('$value',
                    key: ValueKey('${id}Value'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
              IconButton(
                key: ValueKey('${id}Plus'),
                visualDensity: VisualDensity.compact,
                onPressed: value < ChaletEditValidation.roomsMax
                    ? () => onChanged(value + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
                tooltip: 'زيادة',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapacity() {
    return _section(
      id: 'capacity',
      title: 'السعة',
      icon: Icons.group_outlined,
      children: [
        LayoutBuilder(builder: (context, c) {
          final stack = c.maxWidth < 260 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final beds = _stepper(
            id: 'bedrooms',
            label: 'غرف النوم',
            value: _bedrooms,
            onChanged: (v) => _setState(() => _bedrooms = v),
          );
          final baths = _stepper(
            id: 'bathrooms',
            label: 'الحمامات',
            value: _bathrooms,
            onChanged: (v) => _setState(() => _bathrooms = v),
          );
          if (stack) {
            return Column(children: [beds, const SizedBox(height: 10), baths]);
          }
          return Row(children: [
            Expanded(child: beds),
            const SizedBox(width: 10),
            Expanded(child: baths),
          ]);
        }),
        const SizedBox(height: 14),
        _field(
          fieldKey: 'max_guests',
          ctrl: _guests,
          label: 'عدد الأشخاص المسموح بهم',
          type: TextInputType.number,
        ),
      ],
    );
  }

  Widget _amenity(String id, String label, IconData icon, bool value,
      ValueChanged<bool> onChanged) {
    final dirty = _d.contains(id);
    return Semantics(
      toggled: value,
      label: label,
      child: Material(
        color: value ? AppColors.primary : AppColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: dirty
                ? AppColors.accent
                : value
                    ? AppColors.primary
                    : AppColors.sand,
            width: dirty ? 1.8 : 1,
          ),
        ),
        child: InkWell(
          key: ValueKey('amenity_$id'),
          customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: value ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: value ? Colors.white : AppColors.charcoal)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmenities() {
    return _section(
      id: 'amenities',
      title: 'المرافق',
      icon: Icons.star_outline_rounded,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _amenity('has_wifi', 'واي فاي', Icons.wifi_rounded, _wifi,
                  (v) => _setState(() => _wifi = v)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _amenity('has_pool', 'مسبح', Icons.pool_rounded, _pool,
                  (v) => _setState(() => _pool = v)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _amenity('has_bbq', 'باربيكيو',
                  Icons.outdoor_grill_rounded, _bbq,
                  (v) => _setState(() => _bbq = v)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _amenity('has_parking', 'باركينج',
                  Icons.local_parking_rounded, _parking,
                  (v) => _setState(() => _parking = v)),
            ),
          ],
        ),
      ],
    );
  }
}
