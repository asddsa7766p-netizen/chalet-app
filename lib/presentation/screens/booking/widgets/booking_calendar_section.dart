part of '../booking_screen.dart';

extension _BookingCalendarSection on _BookingScreenState {
  // ===================== DATE (يوم واحد) =====================
  Widget _buildDatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('تاريخ الحجز',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 12),
        GestureDetector(
          key: const Key('booking_date_box'),
          onTap: () => _setState(() => _showCalendar = !_showCalendar),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.sand),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EEE6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today_outlined,
                      size: 18, color: _BookingScreenState._darkGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _date == null ? 'اختر يوم الحجز' : arabicDayLabel(_date!),
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _date == null
                            ? AppColors.textSecondary
                            : AppColors.charcoal),
                  ),
                ),
                Icon(
                    _showCalendar
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        if (_showCalendar) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.sand),
            ),
            child: TableCalendar(
              // ✅ إصلاح: بدون هذا كان اسم الشهر وأيام الأسبوع يظهران
              // بالإنجليزية دائماً (مؤكَّد بتشغيل التطبيق فعلياً) رغم أن
              // التقويم داخل شاشة عربية بالكامل.
              locale: 'ar',
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _date ?? DateTime.now(),
              // يوم واحد فقط: مفعّل إن كانت فيه فترة واحدة متاحة على الأقل.
              enabledDayPredicate: _isDayEnabled,
              selectedDayPredicate: (day) => isSameDay(_date, day),
              calendarFormat: CalendarFormat.month,
              rowHeight: 58,
              // ✅ إصلاح: هذه البيانات (سعر كل يوم) كانت تُجلب فعلياً
              // بـ_loadMonthPricing وتُرمى بدون استخدام. الآن تُعرض تحت كل
              // يوم — بيانات حقيقية من نفس المصدر المعتمد بحساب السعر
              // النهائي، وليست قيمة مُخترعة.
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) =>
                    _dayCell(day, false),
                todayBuilder: (context, day, focusedDay) =>
                    _dayCell(day, false, isToday: true),
                // اليوم غير المتاح يظهر مشطوباً بهدوء بلا ذكر السبب (محجوز
                // أم محجوب)، والمعطَّل لسبب آخر (ماضٍ) رمادي فقط.
                disabledBuilder: (context, day, focusedDay) =>
                    _disabledCell(day),
              ),
              onPageChanged: (focusedDay) {
                final newMonth = DateTime(focusedDay.year, focusedDay.month);
                if (newMonth.year != _visibleMonth.year ||
                    newMonth.month != _visibleMonth.month) {
                  _loadMonthPricing(newMonth);
                }
              },
              onDaySelected: (selected, focused) => _onDaySelected(selected),
              calendarStyle: const CalendarStyle(
                selectedDecoration:
                    BoxDecoration(color: _BookingScreenState._darkGreen, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(
                    color: AppColors.accent, shape: BoxShape.circle),
                defaultTextStyle: TextStyle(fontFamily: 'Cairo'),
              ),
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle:
                    TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // نص قصير يوضّح أي فترة حرة ليوم "جزئي" (فترة واحدة محجوزة والثانية حرة).
  // مستقل عن نوع الإقامة المختار حالياً — يعتمد فقط على حالة الفترتين الخام.
  String? _partialSlotNote(DateTime day) {
    final slot = _daySlots[DateTime(day.year, day.month, day.day)];
    if (slot == null || !slot.isPartiallyBooked) return null;
    return slot.morningBooked ? 'مسائي فقط' : 'صباحي فقط';
  }

  Widget _disabledCell(DateTime day) {
    final slot = _daySlots[DateTime(day.year, day.month, day.day)];
    final unavailable = slot?.isFullyUnavailable ?? false;
    final note = _partialSlotNote(day);
    return Container(
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textHint.withValues(alpha: 0.7),
              decoration: unavailable ? TextDecoration.lineThrough : null,
            ),
          ),
          // يوم جزئي معطّل لنوع الإقامة المختار حالياً (مثلاً "صباحية" وهذا
          // اليوم صباحه محجوز): نوضّح أي فترة تبقى متاحة فعلاً.
          if (note != null)
            Text(
              note,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: AppColors.textHint.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ إضافة: خلية يوم بالتقويم تعرض السعر الفعلي (من _monthPricing —
  // نفس البيانات الحقيقية المستخدمة أصلاً بحساب السعر، وليست قيمة
  // مُخترعة) تحت رقم اليوم، بدل يوم بلا أي معلومة سعر قبل اختياره.
  //
  // ✅ يوم "جزئي" (فترة واحدة فقط محجوزة) يظهر بلون مميّز مع نص قصير
  // يوضّح أي فترة ما زالت متاحة، بدل السعر، حتى قبل اختيار نوع الإقامة.
  Widget _dayCell(DateTime day, bool _, {bool isToday = false}) {
    final key = DateTime(day.year, day.month, day.day);
    final info = _monthPricing[key];
    final note = _partialSlotNote(day);

    return Container(
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: isToday
                ? const BoxDecoration(
                    color: AppColors.accent, shape: BoxShape.circle)
                : note != null
                    ? BoxDecoration(
                        color: const Color(0xFFE0A63C).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: const Color(0xFFE0A63C)),
                      )
                    : null,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday ? Colors.white : AppColors.charcoal,
              ),
            ),
          ),
          if (note != null)
            Text(
              note,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE0A63C),
              ),
            )
          else if (info != null)
            Text(
              info.finalPrice.toStringAsFixed(0),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color:
                    info.isSpecialOffer ? AppColors.error : AppColors.textHint,
              ),
            ),
        ],
      ),
    );
  }

  // ===================== STAY TYPE =====================
  Widget _buildStayTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('الفترة',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 4),
        Text(
          _date == null
              ? 'اختر يوم الحجز أولاً لمعرفة الفترات المتاحة'
              : 'الفترات المتاحة ليوم ${arabicDayLabel(_date!, withYear: false)}',
          style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        // بطاقتان بكل صف: أسماء الفترات ("يوم كامل - صباحي") وأوقاتها لا
        // تتسع لأربع بطاقات بعرض هاتف.
        LayoutBuilder(builder: (context, constraints) {
          final width = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in _periods)
                SizedBox(
                  width: _periods.length == 1 ? constraints.maxWidth : width,
                  child: _stayTypeCard(p),
                ),
            ],
          );
        }),
      ],
    );
  }

  Widget _stayTypeCard(BookingPeriod period) {
    final selected = _selectedStayType == period.stayType;
    final available = _isPeriodAvailable(period.stayType);

    return Opacity(
      opacity: available ? 1 : 0.45,
      child: GestureDetector(
      key: Key('period_${period.stayType}'),
      onTap: available ? () => _onStayTypeSelected(period.stayType) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? _BookingScreenState._darkGreen : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _BookingScreenState._darkGreen : AppColors.sand,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ✅ إصلاح: بطاقة نوع الإقامة كانت تفيض أفقياً فعلياً على
            // شاشة موبايل حقيقية (390px) — "OVERFLOWED BY 28 PIXELS" —
            // لأن تسمية النوع (مثل "يوم كامل - صباحي") ونطاق الوقت لم
            // يكونا مقيَّدين بعرض البطاقة الثلاثية الأعمدة. تأكدت من هذا
            // بتشغيل التطبيق فعلياً على عرض هاتف حقيقي، وليس افتراضاً.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(period.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? Colors.white
                                  : AppColors.charcoal)),
                    ),
                    const SizedBox(width: 4),
                    Icon(period.icon,
                        size: 15,
                        color:
                            selected ? Colors.white : const Color(0xFFE0A63C)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  available
                      ? (period.timeLabel ?? 'طوال اليوم')
                      : 'محجوزة بهذا اليوم',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.textSecondary),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: -8,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 12, color: _BookingScreenState._darkGreen),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
