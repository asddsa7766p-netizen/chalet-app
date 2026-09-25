part of 'owner_calendar_widgets.dart';

/// اسم الضيف كما يُعرض (انظر [ManualBookingX.displayGuestName]).
String? bookingGuestName(BookingModel b) => b.displayGuestName;

String? bookingGuestPhone(BookingModel b) => b.displayGuestPhone;

/// ورقة اليوم (محتوى واحد يُعرض داخل ورقة سفلية بالهاتف وفي لوحة جانبية
/// بالشاشات العريضة). لا تنفّذ أي كتابة بنفسها: كلها callbacks للشاشة.
class OwnerDayPanel extends StatelessWidget {
  final CalendarChalet chalet;
  final CalendarDay day;
  final DateTime today;

  /// سعر هذا اليوم (من دالة تسعير الشهر). null عند الفشل.
  final Future<DayPriceInfo?> priceFuture;
  final bool busy;

  final VoidCallback onManualBooking;
  final VoidCallback onBlockDay;
  final VoidCallback onUnblockDay;
  final VoidCallback onSelectRangeToBlock;
  final VoidCallback onSelectRangeToUnblock;
  final VoidCallback onOpenPricing;
  final ValueChanged<BookingModel> onConfirm;
  final ValueChanged<BookingModel> onReject;
  final ValueChanged<BookingModel> onCancelManual;

  const OwnerDayPanel({
    super.key,
    required this.chalet,
    required this.day,
    required this.today,
    required this.priceFuture,
    required this.busy,
    required this.onManualBooking,
    required this.onBlockDay,
    required this.onUnblockDay,
    required this.onSelectRangeToBlock,
    required this.onSelectRangeToUnblock,
    required this.onOpenPricing,
    required this.onConfirm,
    required this.onReject,
    required this.onCancelManual,
  });

  @override
  Widget build(BuildContext context) {
    final booking = day.booking;
    return Column(
      key: const Key('day_panel'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const SizedBox(height: 12),
        if (day.isPast) ..._pastBody(booking) else if (booking != null)
          ..._bookedBody(booking)
        else if (day.blocked)
          ..._blockedBody()
        else
          ..._emptyBody(),
      ],
    );
  }

  // ─── الرأس ────────────────────────────────────────────────

  Widget _header() {
    final kind = day.kind;
    final icon = kindIcon(kind);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fullDayLabel(day.date),
                  key: const Key('day_panel_title'),
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.charcoal)),
              const SizedBox(height: 2),
              Text(chalet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      color: AppColors.textSecondary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: kind == CalendarDayKind.available
                ? AppColors.primaryPale
                : _fillOf(kind),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: _inkOf(kind)),
                const SizedBox(width: 4),
              ],
              Text(
                day.isPast && !day.isBooked
                    ? 'منتهٍ'
                    : kindLabel(kind),
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _inkOf(kind)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── الحالات ──────────────────────────────────────────────

  List<Widget> _pastBody(BookingModel? booking) {
    return [
      if (booking != null) ...[
        for (final b in day.bookings)
          KeyedSubtree(
            key: ValueKey('day_booking_${b.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _bookingCard(b),
                if (canCancelManualBooking(b, now: today)) ...[
                  const SizedBox(height: 12),
                  _cancelManualButton(b),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        if (day.departing != null && day.departing!.id != booking.id)
          _departingNote(day.departing!),
      ] else
        _note('يوم منتهٍ، للاطّلاع فقط.'),
    ];
  }

  /// بطاقة حجز مع إجراءاته (تأكيد/رفض أو إلغاء اليدوي).
  Widget _bookingWithActions(BookingModel booking) {
    return KeyedSubtree(
      key: ValueKey('day_booking_${booking.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bookingCard(booking),
          const SizedBox(height: 10),
          if (booking.status == BookingStatus.pending && !booking.isManual)
            Row(
              children: [
                Expanded(
                  child: _primaryButton(
                    key: const Key('day_action_confirm'),
                    label: 'تأكيد الحجز',
                    icon: Icons.check_rounded,
                    onTap: busy ? null : () => onConfirm(booking),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _outlineButton(
                    key: const Key('day_action_reject'),
                    label: 'رفض',
                    icon: Icons.close_rounded,
                    color: AppColors.error,
                    onTap: busy ? null : () => onReject(booking),
                  ),
                ),
              ],
            ),
          if (canCancelManualBooking(booking, now: today))
            _cancelManualButton(booking),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  List<Widget> _bookedBody(BookingModel booking) {
    return [
      for (final b in day.bookings) _bookingWithActions(b),
      if (day.partialLabel != null) _note(day.partialLabel!),
      if (day.departing != null && day.departing!.id != booking.id)
        _departingNote(day.departing!),
      if (day.hasBlockAndBooking) ...[
        const SizedBox(height: 10),
        _note('هذا اليوم محجوب أيضاً. يمكنك إلغاء الحجب دون المساس بالحجز.'),
      ],
      // فترة أخرى من اليوم ما زالت حرة: يمكن إدخال حجز يدوي لها.
      if (day.isPartiallyBooked && !day.blocked) ...[
        const SizedBox(height: 10),
        _outlineButton(
          key: const Key('day_action_manual'),
          label: 'حجز يدوي للفترة المتاحة',
          icon: Icons.edit_calendar_rounded,
          onTap: busy ? null : onManualBooking,
        ),
      ],
      if (day.hasBlockAndBooking) ...[
        const SizedBox(height: 10),
        _outlineButton(
          key: const Key('day_action_unblock'),
          label: 'إلغاء حجب هذا اليوم',
          icon: Icons.lock_open_rounded,
          onTap: busy ? null : onUnblockDay,
        ),
      ],
      _pricingLink(),
    ];
  }

  List<Widget> _blockedBody() {
    return [
      _priceRow(muted: true),
      const SizedBox(height: 12),
      _outlineButton(
        key: const Key('day_action_unblock'),
        label: 'إلغاء الحجب',
        icon: Icons.lock_open_rounded,
        onTap: busy ? null : onUnblockDay,
      ),
      const SizedBox(height: 8),
      // الحجز اليدوي على يوم محجوب سيرفضه الـ trigger، فيُعطَّل بسبب مكتوب.
      _outlineButton(
        key: const Key('day_action_manual'),
        label: 'حجز يدوي',
        icon: Icons.edit_calendar_rounded,
        onTap: null,
      ),
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('أزل الحجب أولاً لتتمكن من الحجز على هذا اليوم.',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                color: AppColors.textSecondary)),
      ),
      TextButton.icon(
        key: const Key('day_action_range_unblock'),
        onPressed: busy ? null : onSelectRangeToUnblock,
        icon: const Icon(Icons.checklist_rounded, size: 18),
        label: const Text('إلغاء حجب عدة أيام',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
      ),
      _pricingLink(),
    ];
  }

  List<Widget> _emptyBody() {
    return [
      _priceRow(),
      if (day.partialLabel != null) _note(day.partialLabel!),
      if (day.departing != null) _departingNote(day.departing!),
      const SizedBox(height: 14),
      _primaryButton(
        key: const Key('day_action_manual'),
        label: 'حجز يدوي',
        icon: Icons.edit_calendar_rounded,
        onTap: busy ? null : onManualBooking,
      ),
      const SizedBox(height: 8),
      _outlineButton(
        key: const Key('day_action_block'),
        label: 'حجب هذا اليوم',
        icon: Icons.block_rounded,
        onTap: busy ? null : onBlockDay,
      ),
      TextButton.icon(
        key: const Key('day_action_range_block'),
        onPressed: busy ? null : onSelectRangeToBlock,
        icon: const Icon(Icons.checklist_rounded, size: 18),
        label: const Text('حجب عدة أيام',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
      ),
      _pricingLink(),
    ];
  }

  // ─── مكوّنات ──────────────────────────────────────────────

  Widget _priceRow({bool muted = false}) {
    return FutureBuilder<DayPriceInfo?>(
      future: priceFuture,
      builder: (context, snap) {
        String text;
        String? sub;
        if (snap.connectionState != ConnectionState.done) {
          text = 'جارٍ جلب السعر…';
        } else if (snap.data == null) {
          text = 'تعذر جلب سعر هذا اليوم';
        } else {
          final info = snap.data!;
          text = 'سعر اليوم: ${AppCurrency.formatPrice(info.finalPrice)}';
          if ((info.finalPrice - info.originalPrice).abs() > 0.001) {
            sub = 'سعر خاص لهذا التاريخ';
          }
        }
        return Container(
          key: const Key('day_price'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.sand),
          ),
          child: Row(
            children: [
              Icon(Icons.sell_outlined,
                  size: 18,
                  color: muted ? AppColors.textHint : AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: muted
                                ? AppColors.textSecondary
                                : AppColors.charcoal)),
                    if (sub != null)
                      Text(sub,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pricingLink() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        key: const Key('day_action_pricing'),
        onPressed: busy ? null : onOpenPricing,
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: const Text('أسعار الشاليه',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
      ),
    );
  }

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textSecondary)),
      );

  Widget _departingNote(BookingModel b) {
    final name = bookingGuestName(b) ?? 'ضيف';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const Icon(Icons.wb_twilight_rounded,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                'حجز $name (يوم كامل - مسائي) يمتد حتى صباح هذا اليوم',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _cancelManualButton(BookingModel b) => _outlineButton(
        key: const Key('day_action_cancel_manual'),
        label: 'إلغاء الحجز اليدوي',
        icon: Icons.event_busy_rounded,
        color: AppColors.error,
        onTap: busy ? null : () => onCancelManual(b),
      );

  Widget _bookingCard(BookingModel b) {
    final name = bookingGuestName(b) ?? 'ضيف';
    final phone = bookingGuestPhone(b);
    final nights = b.nightsCount;
    final night = day.nightNumber;
    final notes = b.notes?.trim();

    Widget row(IconData icon, String text, {Key? key}) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            key: key,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.charcoal)),
              ),
            ],
          ),
        );

    return Container(
      key: const Key('day_booking_card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal)),
          if (phone != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(phone,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: AppColors.charcoal)),
                  ),
                  const SizedBox(width: 4),
                  Builder(
                    builder: (context) => IconButton(
                      key: const Key('day_action_call'),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'اتصال',
                      icon: const Icon(Icons.call_rounded,
                          size: 20, color: AppColors.primary),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        bool opened;
                        try {
                          opened =
                              await launchUrl(Uri(scheme: 'tel', path: phone));
                        } catch (_) {
                          opened = false; // لا تطبيق اتصال (مثلاً جهاز لوحي).
                        }
                        if (!opened) {
                          messenger.showSnackBar(SnackBar(
                            content: Text(
                                'تعذر فتح تطبيق الاتصال. الرقم: $phone',
                                style: const TextStyle(fontFamily: 'Cairo')),
                          ));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          row(Icons.event_rounded, b.dateLabel,
              key: const Key('day_booking_date')),
          row(Icons.schedule_rounded, b.periodWithTime,
              key: const Key('day_booking_period')),
          // حجز قديم ممتد لعدة أيام: موقع هذا اليوم داخله.
          if (night != null && nights > 1)
            row(Icons.today_rounded, 'اليوم $night من $nights'),
          row(Icons.group_outlined, '${b.guestsCount} ضيوف'),
          row(Icons.payments_outlined,
              'الإجمالي ${AppCurrency.formatPrice(b.totalPrice)}'),
          if (notes != null && notes.isNotEmpty)
            row(Icons.notes_rounded, notes),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) =>
      SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          key: key,
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _outlineButton({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    Color color = AppColors.primary,
  }) =>
      SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          key: key,
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            minimumSize: const Size(0, 48),
            side: BorderSide(
                color: onTap == null ? AppColors.border : color.withValues(alpha: 0.6)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}
