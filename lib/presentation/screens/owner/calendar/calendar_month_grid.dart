part of 'owner_calendar_screen.dart';

extension _CalendarMonthGrid on _OwnerCalendarScreenState {
  Widget _calendarColumn(bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_monthError != null)
          Container(
            key: const Key('month_error'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 18, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_monthError!,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          color: AppColors.error)),
                ),
                TextButton(
                  onPressed: () => _loadWindow(_focusedDay, reset: true),
                  child: const Text('إعادة المحاولة',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5)),
                ),
              ],
            ),
          ),
        _monthHeader(),
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sand),
          ),
          child: Stack(
            children: [
              _monthGrid(wide),
              if (_inflight > 0)
                const PositionedDirectional(
                  top: 6,
                  end: 8,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const CalendarLegend(),
      ],
    );
  }

  Widget _monthHeader() {
    final month = DateTime(_focusedDay.year, _focusedDay.month);
    final atFirst = _monthKey(month) <= _monthKey(_firstDay);
    final atLast = _monthKey(month) >= _monthKey(_lastDay);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          IconButton(
            key: const Key('month_prev'),
            tooltip: 'الشهر السابق',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: atFirst
                ? null
                : () => _shiftMonth(-1),
          ),
          Expanded(
            child: Text('${monthName(month.month)} ${month.year}',
                key: const Key('month_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.charcoal)),
          ),
          IconButton(
            key: const Key('month_next'),
            tooltip: 'الشهر التالي',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: atLast
                ? null
                : () => _shiftMonth(1),
          ),
        ],
      ),
    );
  }

  // ─── شبكة الشهر ───────────────────────────────────────────

  static const _weekdayShort = [
    'أحد',
    'اثنين',
    'ثلاثاء',
    'أربعاء',
    'خميس',
    'جمعة',
    'سبت',
  ];

  /// شبكة شهرية خاصة (بدل TableCalendar الذي يستبعد وصف Semantics لكل خلية
  /// ويمنع قراءة حالة اليوم بقارئ الشاشة). الأسبوع يبدأ بالأحد، وترتيب الصف
  /// يتبع RTL: الأحد على اليمين.
  Widget _monthGrid(bool wide) {
    final month = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final offset = month.weekday % 7; // الأحد = 0
    final rows = ((offset + daysInMonth) / 7).ceil();
    final rowHeight = wide ? 68.0 : 58.0;

    return GestureDetector(
      key: const Key('month_grid'),
      behavior: HitTestBehavior.opaque,
      // السحب لليسار (RTL) = الشهر التالي.
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -250) _shiftMonth(1);
        if (v > 250) _shiftMonth(-1);
      },
      child: KeyedSubtree(
        key: ValueKey('month_${month.year}_${month.month}'),
        child: Column(
          children: [
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  for (final name in _weekdayShort)
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(name,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (var r = 0; r < rows; r++)
              SizedBox(
                height: rowHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(child: _gridSlot(month, r * 7 + c - offset + 1, daysInMonth, wide)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _gridSlot(DateTime month, int dayNumber, int daysInMonth, bool wide) {
    if (dayNumber < 1 || dayNumber > daysInMonth) return const SizedBox.shrink();
    final day = DateTime(month.year, month.month, dayNumber);
    final outOfRange = day.isBefore(_firstDay) || day.isAfter(_lastDay);
    final cell = _cell(day, wide: wide);
    if (outOfRange) return cell;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onDayTapped(day),
      onLongPress: () => _onDayLongPressed(day),
      child: cell,
    );
  }

  void _onDayLongPressed(DateTime selected) {
    final d = dateOnly(selected);
    final info = _data.dayInfo(d, today: _today);
    if (info.isPast || info.isBooked) return;
    _setState(() {
      _rangeMode = true;
      _selectedDay = null;
    });
    _onRangeTap(d);
  }

  // ─── الخلية ───────────────────────────────────────────────

  bool _sameBand(CalendarDay a, CalendarDay? b) {
    if (b == null) return false;
    if (a.booking != null) return b.booking?.id == a.booking!.id;
    return a.kind == CalendarDayKind.blocked &&
        b.booking == null &&
        b.blocked;
  }

  Widget _cell(DateTime day, {required bool wide}) {
    final d = dateOnly(day);
    final info = _data.dayInfo(d, today: _today);
    final isBand = info.kind != CalendarDayKind.available;

    // الأسبوع يبدأ بالأحد (weekday % 7 == 0) وينتهي بالسبت. الأطراف المتصلة
    // فقط داخل نفس الصف ونفس الشهر.
    final firstOfMonth = d.day == 1;
    final lastOfMonth = d.day == DateTime(d.year, d.month + 1, 0).day;
    final weekStart = d.weekday % 7 == 0;
    final weekEnd = d.weekday % 7 == 6;
    final prev = isBand && !weekStart && !firstOfMonth
        ? _data.dayInfo(addDays(d, -1), today: _today)
        : null;
    final next = isBand && !weekEnd && !lastOfMonth
        ? _data.dayInfo(addDays(d, 1), today: _today)
        : null;
    final prevConnected = _sameBand(info, prev);
    final nextConnected = _sameBand(info, next);

    final inRange = _rangeMode && _isInRange(d);
    final selected = inRange ||
        (!_rangeMode && _selectedDay != null && _selectedDay == d);

    String? label;
    if (wide && info.booking != null && !prevConnected) {
      label = bookingGuestName(info.booking!);
    }

    final tappable = _rangeMode ? !info.isPast : !(info.isPast && !info.isBooked);
    final semantics = StringBuffer(fullDayLabel(d))
      ..write('، ')
      ..write(kindLabel(info.kind));
    if (info.hasBlockAndBooking) semantics.write('، ومحجوب أيضاً');
    if (info.partialLabel != null) semantics.write('، ${info.partialLabel}');
    if (info.isToday) semantics.write('، اليوم');
    if (info.isPast) semantics.write('، منتهٍ');

    return KeyedSubtree(
      key: ValueKey('cal_cell_${_iso(d)}'),
      child: Semantics(
        label: semantics.toString(),
        button: tappable,
        selected: selected,
        container: true,
        excludeSemantics: true,
        onTap: tappable ? () => _onDayTapped(d) : null,
        onLongPress: tappable ? () => _onDayLongPressed(d) : null,
        child: CalendarDayCell(
          dayNumber: d.day,
          kind: info.kind,
          prevConnected: prevConnected,
          nextConnected: nextConnected,
          isToday: info.isToday,
          isPast: info.isPast,
          selected: selected,
          hasBlockBadge: info.hasBlockAndBooking,
          partialSlot: info.isPartiallyBooked ? info.slot : null,
          label: label,
          roomy: wide,
        ),
      ),
    );
  }

  bool _isInRange(DateTime d) {
    final s = _rangeStart;
    if (s == null) return false;
    final e = _rangeEnd ?? s;
    final lo = s.isBefore(e) ? s : e;
    final hi = s.isBefore(e) ? e : s;
    return !d.isBefore(lo) && !d.isAfter(hi);
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
