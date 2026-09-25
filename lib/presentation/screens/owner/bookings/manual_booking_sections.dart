part of 'manual_booking_sheet.dart';

extension _ManualBookingSections on _ManualBookingSheetState {
  Widget _buildChaletPicker() {
    if (widget.chalets.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            const Icon(Icons.home_work_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_chalet.name,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal)),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in widget.chalets)
            ChoiceChip(
              label: Text(c.name,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: c.id == _chalet.id
                        ? Colors.white
                        : AppColors.charcoal,
                  )),
              selected: c.id == _chalet.id,
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              onSelected: (_) => _onChaletChanged(c),
            ),
        ],
      ),
    );
  }

  /// فترات الشاليه بأوقاتها؛ غير المتاحة باليوم المختار معطّلة.
  Widget _buildStayTypePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الفترة',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in _periods) _periodChip(p),
          ],
        ),
      ],
    );
  }

  Widget _periodChip(BookingPeriod p) {
    final selected = p.stayType == _stayType;
    final available = _isPeriodAvailable(p.stayType);
    final fg = selected ? Colors.white : AppColors.charcoal;
    return ChoiceChip(
      key: Key('manual_stay_${p.stayType}'),
      avatar: Icon(p.icon,
          size: 16, color: selected ? Colors.white : AppColors.primary),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: fg)),
          Text(
              available
                  ? (p.timeLabel ?? 'طوال اليوم')
                  : 'محجوزة بهذا اليوم',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: fg)),
        ],
      ),
      selected: selected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      showCheckmark: false,
      onSelected: available ? (_) => _onStayTypeChanged(p.stayType) : null,
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand),
      ),
      child: Stack(
        children: [
          TableCalendar(
            locale: 'ar',
            firstDay: _today,
            lastDay: _today.add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            rowHeight: 44,
            // يوم واحد فقط. النقر يصل عبر onDaySelected حتى لليوم المعطّل
            // (قاعدة التعطيل مخصّصة بـ _isBlocked) فتظهر رسالة السبب.
            selectedDayPredicate: (day) => isSameDay(_date, day),
            onDaySelected: (selected, focused) {
              _focusedDay = focused;
              _onDayTapped(selected);
            },
            onPageChanged: (focused) => _focusedDay = focused,
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focused) =>
                  _dayCell(day, isToday: false),
              todayBuilder: (context, day, focused) =>
                  _dayCell(day, isToday: true),
            ),
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              defaultTextStyle: TextStyle(fontFamily: 'Cairo'),
            ),
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              titleTextStyle: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w800),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12),
              weekendStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12),
            ),
          ),
          if (_loadingBooked)
            const Positioned(
              top: 12,
              left: 12,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime day, {required bool isToday}) {
    final blocked = _isBlocked(day);
    final partial = _partialSlot(day);
    final number = Text(
      '${day.day}',
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: blocked ? AppColors.textHint : AppColors.charcoal,
        decoration: blocked ? TextDecoration.lineThrough : null,
      ),
    );
    return Semantics(
      label: partial == null
          ? null
          : partial.morningBooked
              ? 'الفترة الصباحية محجوزة'
              : 'الفترة المسائية محجوزة',
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.all(3),
        decoration: isToday && !blocked
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 1.5),
              )
            : null,
        // يوم محجوز جزئياً: شمس (الصباحية محجوزة) أو قمر (المسائية) تحت الرقم.
        child: partial == null
            ? number
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  number,
                  Icon(
                    partial.morningBooked
                        ? Icons.wb_sunny_rounded
                        : Icons.nightlight_round,
                    size: 9,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSelectionSummary() {
    String text;
    Color color = AppColors.textSecondary;
    if (_bookedLoadError != null) {
      text = _bookedLoadError!;
      color = AppColors.error;
    } else if (_dateHint != null) {
      text = _dateHint!;
      color = AppColors.error;
    } else if (_date == null) {
      text = 'اختر يوم الحجز';
    } else if (_selectedPeriod == null) {
      text = '${arabicDayLabel(_date!, withYear: false)} — اختر الفترة';
    } else {
      final p = _selectedPeriod!;
      text = '${arabicDayLabel(_date!, withYear: false)} · ${p.label}'
          '${p.timeLabel == null ? '' : ' (${p.timeLabel})'}';
      color = AppColors.primary;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }

  Widget _buildPriceField() {
    final quote = _quote;
    final differs = quote != null &&
        parseManualPrice(_priceCtrl.text) != quote.roundToDouble();

    String? helper;
    if (_priceLoading) {
      helper = 'جارٍ جلب سعر التقويم…';
    } else if (_quoteError != null) {
      helper = _quoteError;
    } else if (quote != null) {
      helper = 'سعر التقويم: ₪${quote.toStringAsFixed(0)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.start,
          validator: validateManualPrice,
          onChanged: (_) => _setState(() => _priceEdited = true),
          decoration: _inputDecoration('السعر المتفق عليه',
                  icon: Icons.payments_outlined)
              .copyWith(
            prefixText: '₪ ',
            suffixIcon: _priceLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (helper != null || differs)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                if (helper != null)
                  Expanded(
                    child: Text(helper,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  )
                else
                  const Spacer(),
                if (differs)
                  TextButton(
                    onPressed: () => _setState(_applyQuoteToField),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('استعادة سعر التقويم',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGuestsStepper() {
    final max = _chalet.maxGuests;
    final canAdd = max == null || _guests < max;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_outlined,
              size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('عدد الضيوف',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
          ),
          IconButton(
            tooltip: 'إنقاص',
            onPressed:
                _guests > 1 ? () => _setState(() => _guests--) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          Text('$_guests',
              key: const Key('manual_guests_count'),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          IconButton(
            tooltip: 'زيادة',
            onPressed: canAdd ? () => _setState(() => _guests++) : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}
