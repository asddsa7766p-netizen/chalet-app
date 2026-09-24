import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/manual_booking.dart';
import '../../../data/models/models.dart';
import '../../../data/services/pricing_service.dart';
import 'manual_booking_actions.dart';
import 'owner_calendar_data_source.dart';
import 'owner_calendar_logic.dart';

/// ألوان التقويم. لكل حالة لون ونمط وأيقونة معاً، فلا يُعتمد على اللون وحده:
/// ممتلئ بعلامة (مؤكد/يدوي)، متقطع (معلّق)، مخطّط (محجوب).
class CalendarPalette {
  CalendarPalette._();

  static const confirmedFill = AppColors.primary;
  // أغمق قليلاً من AppColors.info ليصل التباين مع النص الأبيض لـ 4.5:1.
  static const manualFill = Color(0xFF226699);
  static const pendingFill = Color(0xFFFFE3A3);
  static const pendingDash = AppColors.accentDark;
  static const blockedFill = Color(0xFFE3E0D8);
  static const blockedHatch = Color(0xFFB5B0A2);
  static const blockedInk = Color(0xFF55513F);
  static const todayRing = AppColors.accent;
  static const selectedRing = AppColors.primaryDark;
}

IconData? kindIcon(CalendarDayKind kind) {
  switch (kind) {
    case CalendarDayKind.available:
      return null;
    case CalendarDayKind.appConfirmed:
      return Icons.check_circle_rounded;
    case CalendarDayKind.manual:
      return Icons.edit_note_rounded;
    case CalendarDayKind.pending:
      return Icons.hourglass_top_rounded;
    case CalendarDayKind.blocked:
      return Icons.block_rounded;
  }
}

Color _fillOf(CalendarDayKind kind) {
  switch (kind) {
    case CalendarDayKind.available:
      return Colors.white;
    case CalendarDayKind.appConfirmed:
      return CalendarPalette.confirmedFill;
    case CalendarDayKind.manual:
      return CalendarPalette.manualFill;
    case CalendarDayKind.pending:
      return CalendarPalette.pendingFill;
    case CalendarDayKind.blocked:
      return CalendarPalette.blockedFill;
  }
}

Color _inkOf(CalendarDayKind kind) {
  switch (kind) {
    case CalendarDayKind.available:
    case CalendarDayKind.pending:
      return AppColors.charcoal;
    case CalendarDayKind.appConfirmed:
    case CalendarDayKind.manual:
      return Colors.white;
    case CalendarDayKind.blocked:
      return CalendarPalette.blockedInk;
  }
}

/// يرسم خلفية الخلية: التعبئة، ثم التخطيط (محجوب) أو الحد المتقطع (معلّق) أو
/// الحد الرملي (متاح)، ثم حلقة اليوم/التحديد.
class _CellPainter extends CustomPainter {
  _CellPainter({
    required this.kind,
    required this.radius,
    this.ring,
    this.ringWidth = 0,
    this.faded = false,
  });

  final CalendarDayKind kind;
  final BorderRadius radius;
  final Color? ring;
  final double ringWidth;

  /// الأيام الماضية: ألوان معتّمة تُمزج مع الأبيض (معتمة تماماً، لا شفافية) حتى
  /// لا يظهر خيط داكن عند تداخل أشرطة الأيام المتجاورة.
  final bool faded;

  Color _f(Color c) =>
      faded ? Color.alphaBlend(c.withOpacity(0.42), Colors.white) : c;

  @override
  void paint(Canvas canvas, Size size) {
    // شرائط الحجز/الحجب المتجاورة تتداخل بنصف بكسل عند الجانب المتصل حتى لا
    // تظهر خيوط رفيعة بين الخلايا (تنعيم حواف).
    final isBand = kind != CalendarDayKind.available;
    final leftJoined = isBand && radius.topLeft == Radius.zero;
    final rightJoined = isBand && radius.topRight == Radius.zero;
    final rect = Rect.fromLTRB(
      leftJoined ? -0.6 : 0,
      0,
      size.width + (rightJoined ? 0.6 : 0),
      size.height,
    );
    final rrect = radius.toRRect(rect);
    canvas.drawRRect(rrect, Paint()..color = _f(_fillOf(kind)));

    if (kind == CalendarDayKind.blocked) {
      canvas.save();
      canvas.clipRRect(rrect);
      final p = Paint()
        ..color = _f(CalendarPalette.blockedHatch)
        ..strokeWidth = 1.4;
      for (var x = -size.height; x < size.width; x += 7) {
        canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
      }
      canvas.restore();
    } else if (kind == CalendarDayKind.pending) {
      _dashedRRect(canvas, rrect.deflate(0.75),
          Paint()
            ..color = _f(CalendarPalette.pendingDash)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    } else if (kind == CalendarDayKind.available) {
      canvas.drawRRect(
          rrect.deflate(0.5),
          Paint()
            ..color = _f(AppColors.border)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }

    if (ring != null && ringWidth > 0) {
      canvas.drawRRect(
          rrect.deflate(ringWidth / 2),
          Paint()
            ..color = ring!
            ..style = PaintingStyle.stroke
            ..strokeWidth = ringWidth);
    }
  }

  void _dashedRRect(Canvas canvas, RRect rrect, Paint paint) {
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 4, metric.length)), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_CellPainter old) =>
      old.kind != kind ||
      old.radius != radius ||
      old.ring != ring ||
      old.ringWidth != ringWidth ||
      old.faded != faded;
}

/// خلية يوم بالتقويم. الحجز/الحجب يُرسم شريطاً متصلاً عبر الأيام المتجاورة
/// بنفس الصف، بأطراف مدوّرة عند بدايته ونهايته (اتجاه الأطراف يتبع RTL).
class CalendarDayCell extends StatelessWidget {
  final int dayNumber;
  final CalendarDayKind kind;
  final bool prevConnected;
  final bool nextConnected;
  final bool isToday;
  final bool isPast;
  final bool selected;
  final bool hasBlockBadge;

  /// اسم الضيف المختصر (يظهر بالشاشات العريضة عند بداية الشريط).
  final String? label;
  final bool roomy;

  const CalendarDayCell({
    super.key,
    required this.dayNumber,
    required this.kind,
    this.prevConnected = false,
    this.nextConnected = false,
    this.isToday = false,
    this.isPast = false,
    this.selected = false,
    this.hasBlockBadge = false,
    this.label,
    this.roomy = false,
  });

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(11);
    final radius = BorderRadiusDirectional.horizontal(
      start: prevConnected ? Radius.zero : r,
      end: nextConnected ? Radius.zero : r,
    ).resolve(Directionality.of(context));

    final ring = selected
        ? CalendarPalette.selectedRing
        : isToday
            ? CalendarPalette.todayRing
            : null;
    final ink = _inkOf(kind);
    final icon = kindIcon(kind);
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2);

    Widget fade(Widget w) => isPast ? Opacity(opacity: 0.42, child: w) : w;

    return Container(
      margin: EdgeInsetsDirectional.only(
        start: prevConnected ? 0 : 3,
        end: nextConnected ? 0 : 3,
        top: 3,
        bottom: 3,
      ),
      child: CustomPaint(
        painter: _CellPainter(
          kind: kind,
          radius: radius,
          ring: ring,
          ringWidth: selected ? 2.5 : (isToday ? 2 : 0),
          faded: isPast,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            fade(Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: scaler),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      if (icon != null)
                        Icon(icon, size: 13, color: ink.withOpacity(0.92)),
                      if (roomy && label != null)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 52),
                          child: Text(
                            label!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )),
            if (hasBlockBadge)
              PositionedDirectional(
                top: 2,
                start: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block_rounded,
                      size: 12, color: CalendarPalette.blockedInk),
                ),
              ),
          ],
        ),
      ),
    );

  }
}

/// مفتاح الألوان: كل حالة بلونها ونمطها وأيقونتها واسمها.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    const kinds = [
      CalendarDayKind.available,
      CalendarDayKind.appConfirmed,
      CalendarDayKind.manual,
      CalendarDayKind.pending,
      CalendarDayKind.blocked,
    ];
    return Container(
      key: const Key('calendar_legend'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final k in kinds) _swatch(k),
              _todaySwatch(),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'يوم المغادرة يظهر متاحاً لأن ليلته غير محجوزة.',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _swatch(CalendarDayKind k) {
    final icon = kindIcon(k);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          height: 22,
          child: CustomPaint(
            painter: _CellPainter(
              kind: k,
              radius: BorderRadius.circular(6),
            ),
            child: icon == null
                ? null
                : Center(child: Icon(icon, size: 14, color: _inkOf(k))),
          ),
        ),
        const SizedBox(width: 6),
        Text(kindLabel(k),
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal)),
      ],
    );
  }

  Widget _todaySwatch() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          height: 22,
          child: CustomPaint(
            painter: _CellPainter(
              kind: CalendarDayKind.available,
              radius: BorderRadius.circular(6),
              ring: CalendarPalette.todayRing,
              ringWidth: 2,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Text('اليوم',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal)),
      ],
    );
  }
}

/// اسم الضيف كما يُعرض: اليدوي من guest_name، وحجز التطبيق من ملف صاحبه.
String? bookingGuestName(BookingModel b) {
  final raw = b.isManual ? b.manualGuest.name : b.guestName?.trim();
  return (raw == null || raw.isEmpty) ? null : raw;
}

String? bookingGuestPhone(BookingModel b) {
  final raw = b.isManual ? b.manualGuest.phone : b.guestPhone?.trim();
  return (raw == null || raw.isEmpty) ? null : raw;
}

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
        _bookingCard(booking),
        if (day.departing != null && day.departing!.id != booking.id)
          _departingNote(day.departing!),
        if (canCancelManualBooking(booking, now: today)) ...[
          const SizedBox(height: 12),
          _cancelManualButton(booking),
        ],
      ] else
        _note('يوم منتهٍ، للاطّلاع فقط.'),
    ];
  }

  List<Widget> _bookedBody(BookingModel booking) {
    return [
      _bookingCard(booking),
      if (day.departing != null && day.departing!.id != booking.id)
        _departingNote(day.departing!),
      if (day.hasBlockAndBooking) ...[
        const SizedBox(height: 10),
        _note('هذا اليوم محجوب أيضاً. يمكنك إلغاء الحجب دون المساس بالحجز.'),
      ],
      const SizedBox(height: 14),
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
          text = 'سعر الليلة: ${AppCurrency.formatPrice(info.finalPrice)}';
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
          const Icon(Icons.logout_rounded,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text('مغادرة $name صباح هذا اليوم',
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
                  IconButton(
                    key: const Key('day_action_call'),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'اتصال',
                    icon: const Icon(Icons.call_rounded,
                        size: 20, color: AppColors.primary),
                    onPressed: () async {
                      try {
                        await launchUrl(Uri(scheme: 'tel', path: phone));
                      } catch (_) {}
                    },
                  ),
                ],
              ),
            ),
          row(Icons.date_range_rounded,
              'من ${shortDayLabel(b.checkIn)} إلى ${shortDayLabel(b.checkOut)} · ${nightsLabel(nights)}'),
          if (night != null && nights > 1)
            row(Icons.nightlight_round, 'الليلة $night من $nights'),
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
                color: onTap == null ? AppColors.border : color.withOpacity(0.6)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}

/// شريط وضع تحديد الأيام أسفل التقويم.
class RangeActionBar extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;
  final RangeAction? action;
  final BlockPlan? blockPlan;
  final UnblockPlan? unblockPlan;
  final String? hint;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const RangeActionBar({
    super.key,
    required this.start,
    required this.end,
    required this.action,
    required this.blockPlan,
    required this.unblockPlan,
    required this.hint,
    required this.busy,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    String title;
    String? detail;
    String? buttonLabel;
    var enabled = false;

    if (start == null) {
      title = 'اختر أول يوم في النطاق';
    } else if (end == null) {
      title = 'من ${shortDayLabel(start!)} — اختر آخر يوم (شامل)';
    } else if (action == RangeAction.unblock) {
      final plan = unblockPlan!;
      title = 'إلغاء حجب من ${shortDayLabel(_lo)} إلى ${shortDayLabel(_hi)}';
      if (plan.dates.isEmpty) {
        detail = 'لا توجد أيام محجوبة في هذا النطاق.';
      } else {
        buttonLabel = 'إلغاء حجب ${nightsLabel(plan.dates.length)}';
        enabled = true;
        if (plan.skippedNotBlocked > 0) {
          detail = 'سيُتخطى ${daysLabel(plan.skippedNotBlocked)} غير محجوب.';
        }
      }
    } else {
      final plan = blockPlan!;
      title = 'حجب من ${shortDayLabel(_lo)} إلى ${shortDayLabel(_hi)}';
      final notes = <String>[];
      if (plan.skippedBooked > 0) {
        notes.add('سيُتخطى ${daysLabel(plan.skippedBooked)} لوجود حجز عليه');
      }
      if (plan.alreadyBlocked > 0) {
        notes.add('${daysLabel(plan.alreadyBlocked)} محجوب أصلاً');
      }
      if (plan.dates.isEmpty) {
        detail = notes.isEmpty
            ? 'لا توجد أيام يمكن حجبها في هذا النطاق.'
            : '${notes.join(' · ')}. لا توجد أيام يمكن حجبها.';
      } else {
        buttonLabel = 'حجب ${nightsLabel(plan.dates.length)}';
        enabled = true;
        if (notes.isNotEmpty) detail = '${notes.join(' · ')}.';
      }
    }

    return Container(
      key: const Key('range_bar'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              key: const Key('range_title'),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal)),
          if (detail != null || hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(hint ?? detail!,
                  key: const Key('range_detail'),
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: hint != null
                          ? AppColors.error
                          : AppColors.textSecondary)),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (buttonLabel != null)
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      key: const Key('range_confirm'),
                      onPressed: enabled && !busy ? onConfirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(buttonLabel,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              if (buttonLabel != null) const SizedBox(width: 10),
              TextButton(
                key: const Key('range_cancel'),
                onPressed: busy ? null : onCancel,
                child: const Text('إلغاء',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  DateTime get _lo => end!.isBefore(start!) ? end! : start!;
  DateTime get _hi => end!.isBefore(start!) ? start! : end!;
}
