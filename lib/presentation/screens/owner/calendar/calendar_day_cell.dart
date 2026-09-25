part of 'owner_calendar_widgets.dart';

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
      faded ? Color.alphaBlend(c.withValues(alpha: 0.42), Colors.white) : c;

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

  /// يوم محجوز جزئياً: شارة شمس (الصباحية محجوزة) أو قمر (المسائية).
  final ChaletDaySlot? partialSlot;

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
    this.partialSlot,
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
                        Icon(icon, size: 13, color: ink.withValues(alpha: 0.92)),
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
            if (partialSlot != null)
              PositionedDirectional(
                top: 2,
                end: 2,
                child: Container(
                  key: const Key('partial_slot_badge'),
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    partialSlot!.morningBooked
                        ? Icons.wb_sunny_rounded
                        : Icons.nightlight_round,
                    size: 11,
                    color: AppColors.charcoal,
                  ),
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
            'كل حجز يوم واحد بفترة. الشمس/القمر = فترة صباحية/مسائية محجوزة والأخرى متاحة.',
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
