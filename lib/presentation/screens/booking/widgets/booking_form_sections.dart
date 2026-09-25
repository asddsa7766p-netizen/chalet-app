part of '../booking_screen.dart';

extension _BookingFormSections on _BookingScreenState {
  Widget _payOption(String value, IconData icon, String title, String sub,
      {bool enabled = true}) {
    final selected = enabled && _paymentMethod == value;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? () => _setState(() => _paymentMethod = value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? _BookingScreenState._darkGreen.withValues(alpha: 0.06) : AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _BookingScreenState._darkGreen : AppColors.sand,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? _BookingScreenState._darkGreen : const Color(0xFFF1EEE6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: selected ? Colors.white : AppColors.textHint,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? _BookingScreenState._darkGreen
                                    : AppColors.charcoal)),
                        if (!enabled) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.sand,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('قريباً',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary)),
                          ),
                        ],
                      ],
                    ),
                    Text(enabled ? sub : 'غير متاح حالياً',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Radio<String>(
                value: value,
                enabled: enabled,
                activeColor: _BookingScreenState._darkGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== GUESTS =====================
  Widget _buildGuestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('عدد الضيوف',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sand),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _guestCounter(
                    label: 'الرضّع',
                    icon: Icons.child_friendly_outlined,
                    value: _infants,
                    // الرضّع لا يُحتسبون ضمن _guests المرسل للسيرفر، فتركت
                    // حدّهم الأقصى مرتبط بسعة الشاليه فقط كحماية معقولة.
                    maxOverride: _chaletModel?.maxGuests ?? 1,
                    onChanged: (v) => _setState(() => _infants = v),
                  ),
                  _guestCounter(
                    label: 'الأطفال',
                    icon: Icons.emoji_people_outlined,
                    value: _children,
                    // ✅ إصلاح: كان بالإمكان زيادة الأطفال والبالغين لحد
                    // maxGuests كل واحد لحاله، فيصير المجموع الفعلي (اللي
                    // بيروح للسيرفر) أكبر من سعة الشاليه المسموحة. هلأ
                    // الحد الأقصى لكل فئة = سعة الشاليه ناقص الفئة التانية.
                    maxOverride: (_chaletModel?.maxGuests ?? 1) - _adults,
                    onChanged: (v) {
                      _setState(() => _children = v);
                      _onGuestsChanged();
                    },
                  ),
                  _guestCounter(
                    label: 'البالغين',
                    icon: Icons.person_outline,
                    value: _adults,
                    min: 1,
                    maxOverride: (_chaletModel?.maxGuests ?? 1) - _children,
                    onChanged: (v) {
                      _setState(() => _adults = v);
                      _onGuestsChanged();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline,
                      size: 13, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    'الحد الأقصى ${_chaletModel?.maxGuests ?? 1} ضيوف (بالغين وأطفال)',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AppColors.textHint),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _guestCounter({
    required String label,
    required IconData icon,
    required int value,
    required ValueChanged<int> onChanged,
    int min = 0,
    int maxOverride = 1,
  }) {
    // الحد الأقصى ما ينزل تحت الحالي، حتى ما يظهر الزر مقفول بشكل مربك
    // إذا صارت إعادة حساب مؤقتة (مثلاً وقت تحميل بيانات الشاليه).
    final max = maxOverride < value ? value : maxOverride;
    return Column(
      children: [
        Row(children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal)),
          const SizedBox(width: 4),
          Icon(icon, size: 14, color: const Color(0xFFE0A63C)),
        ]),
        const SizedBox(height: 10),
        Row(
          children: [
            _counterBtn(
              icon: Icons.remove,
              semanticLabel: 'تقليل $label',
              onTap: () {
                if (value > min) onChanged(value - 1);
              },
            ),
            SizedBox(
              width: 26,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ),
            _counterBtn(
              icon: Icons.add,
              semanticLabel: 'زيادة $label',
              onTap: () {
                if (value < max) {
                  onChanged(value + 1);
                } else {
                  _showSnack(
                      'وصلت للحد الأقصى المسموح لعدد الضيوف بهذا الشاليه');
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _counterBtn({
    required IconData icon,
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    // ✅ إصلاح: كانت منطقة اللمس 26x26 فقط (أصغر من الحد الأدنى الموصى
    // به 44x44 لإمكانية الوصول)، وبدون أي ripple feedback. رفعتها لـ 36
    // وأضفت InkWell وSemantics.
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: const Color(0xFFF1EEE6),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 14, color: AppColors.charcoal),
          ),
        ),
      ),
    );
  }

  // ===================== PAYMENT =====================
  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('طريقة الدفع',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: _paymentMethod,
          onChanged: (v) {
            if (v != null) _setState(() => _paymentMethod = v);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _payOption('cash', Icons.money_rounded, AppStrings.cashOnArrival,
                  'ادفع نقداً في الشاليه يوم الحجز'),
              const SizedBox(height: 8),
              _payOption('online', Icons.credit_card_rounded,
                  AppStrings.onlinePayment, 'ادفع إلكترونياً بأمان عبر التطبيق',
                  enabled: _BookingScreenState._onlinePaymentEnabled),
            ],
          ),
        ),
      ],
    );
  }

  // ===================== NOTES =====================
  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('ملاحظات إضافية (اختياري)',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _notesCtrl,
          label: '',
          hint: 'أي طلبات أو ملاحظات خاصة...',
          maxLines: 3,
        ),
      ],
    );
  }
}
