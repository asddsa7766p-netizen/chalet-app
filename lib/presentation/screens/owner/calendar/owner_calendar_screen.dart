import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/models.dart';
import '../../../../data/services/chalet_slot_availability.dart';
import '../../../../data/services/pricing_service.dart';
import '../pricing/chalet_pricing_screen.dart';
import '../bookings/manual_booking_actions.dart';
import '../bookings/manual_booking_sheet.dart';
import '../bookings/owner_booking_actions.dart';
import '../owner_bottom_nav.dart';
import 'owner_calendar_data_source.dart';
import 'owner_calendar_logic.dart';
import 'owner_calendar_widgets.dart';
import '../../../../core/utils/error_reporter.dart';

part 'calendar_chalet_selector.dart';
part 'calendar_month_grid.dart';

typedef ManualBookingOpener = Future<bool> Function(
  BuildContext context, {
  String? chaletId,
  DateTime? checkIn,
});

typedef PricingOpener = Future<void> Function(
  BuildContext context,
  CalendarChalet chalet,
);

/// عرض التقويم الشهري لتقويم المالك (تبويب "التقويم"): شاليه واحد بالمرة،
/// نقرة على يوم تفتح ورقته (سعر، حجز يدوي، حجب، تفاصيل الحجز)، ووضع "تحديد
/// أيام" لحجب/إلغاء حجب نطاق بنقرتين.
///
/// التحميل كسول بالشهر (الشهر الظاهر مع السابق والتالي) بطلبين لكل نافذة:
/// حجوزات الشاليه المحدد ضمن النافذة، وليالي الحجب. الأسعار لا تُجلب للشبكة
/// بل عند فتح ورقة يوم.
class OwnerCalendarScreen extends StatefulWidget {
  final OwnerCalendarDataSource dataSource;
  final String? initialChaletId;

  /// لتثبيت "اليوم" في الاختبارات فقط.
  final DateTime? today;

  /// بدائل للاختبار: فتح ورقة الحجز اليدوي وشاشة الأسعار.
  @visibleForTesting
  final ManualBookingOpener? manualBookingOpener;
  @visibleForTesting
  final PricingOpener? pricingOpener;

  const OwnerCalendarScreen({
    super.key,
    this.dataSource = const SupabaseOwnerCalendarDataSource(),
    this.initialChaletId,
    this.today,
    this.manualBookingOpener,
    this.pricingOpener,
  });

  @override
  State<OwnerCalendarScreen> createState() => _OwnerCalendarScreenState();
}

class _OwnerCalendarScreenState extends State<OwnerCalendarScreen> {
  // لأجزاء الشاشة (extensions بملفات part) التي لا تستطيع استدعاء
  // setState المحمي مباشرة.
  void _setState(VoidCallback fn) => setState(fn);

  static const double _wideBreakpoint = 720;

  late final DateTime _today;
  late final DateTime _firstDay;
  late final DateTime _lastDay;

  OwnerCalendarDataSource get _ds => widget.dataSource;

  bool _loadingChalets = true;
  String? _chaletsError;
  List<CalendarChalet> _chalets = [];
  Map<String, int> _pending = {};
  CalendarChalet? _chalet;
  int _unread = 0;

  DateTime _focusedDay = DateTime.now();
  CalendarData _data = CalendarData();
  Set<int> _loadedMonths = {};
  int _gen = 0;
  int _inflight = 0;
  String? _monthError;

  DateTime? _selectedDay;
  bool _sheetOpen = false;
  bool _busy = false;

  // وضع تحديد الأيام.
  bool _rangeMode = false;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  RangeAction? _rangeAction;
  String? _rangeHint;

  // أسعار الأشهر (تُجلب عند فتح ورقة يوم فقط).
  final Map<String, Future<Map<DateTime, DayPriceInfo>?>> _pricing = {};
  final Map<String, Future<DayPriceInfo?>> _priceFutures = {};

  void _clearPricing() {
    _pricing.clear();
    _priceFutures.clear();
  }

  /// Future ثابت لكل (شاليه، يوم) حتى لا يومض السعر عند إعادة بناء الورقة.
  Future<DayPriceInfo?> _priceFutureFor(DateTime day) => _priceFutures
      .putIfAbsent('${_chalet?.id}-${_iso(day)}', () => _priceFor(day));

  @override
  void initState() {
    super.initState();
    final now = widget.today ?? DateTime.now();
    _today = dateOnly(now);
    _firstDay = DateTime(_today.year, _today.month - 3, 1);
    _lastDay = DateTime(_today.year, _today.month + 13, 0);
    _focusedDay = _today;
    _init();
  }

  int _monthKey(DateTime d) => d.year * 12 + d.month;

  // ─── التحميل ──────────────────────────────────────────────

  Future<void> _init() async {
    setState(() {
      _loadingChalets = true;
      _chaletsError = null;
    });
    try {
      final chalets = await _ds.loadChalets();
      final pending = chalets.isEmpty
          ? <String, int>{}
          : await _ds.loadPendingCounts([for (final c in chalets) c.id])
              .catchError((_) => <String, int>{});
      final unread = await _ds.loadUnreadCount().catchError((_) => 0);
      if (!mounted) return;
      setState(() {
        _chalets = chalets;
        _pending = pending;
        _unread = unread;
        _chalet = chalets.isEmpty ? null : _pickInitialChalet(chalets, pending);
        _loadingChalets = false;
      });
      if (_chalet != null) _loadWindow(_focusedDay, reset: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingChalets = false;
        _chaletsError = 'تعذر تحميل شاليهاتك، حاول مرة أخرى';
      });
    }
  }

  /// الشاليه المطلوب صراحةً، وإلا صاحب أكبر عدد طلبات معلّقة، وإلا الأول.
  CalendarChalet _pickInitialChalet(
      List<CalendarChalet> chalets, Map<String, int> pending) {
    final wanted = widget.initialChaletId;
    if (wanted != null) {
      final match = chalets.where((c) => c.id == wanted);
      if (match.isNotEmpty) return match.first;
    }
    var best = chalets.first;
    var bestCount = pending[best.id] ?? 0;
    for (final c in chalets.skip(1)) {
      final n = pending[c.id] ?? 0;
      if (n > bestCount) {
        best = c;
        bestCount = n;
      }
    }
    return best;
  }

  /// الأشهر التي حول [center] (السابق والحالي والتالي) ضمن مدى التقويم.
  List<DateTime> _windowMonths(DateTime center) {
    final out = <DateTime>[];
    for (var i = -1; i <= 1; i++) {
      final m = DateTime(center.year, center.month + i, 1);
      final endOfMonth = DateTime(m.year, m.month + 1, 0);
      if (endOfMonth.isBefore(_firstDay) || m.isAfter(_lastDay)) continue;
      out.add(m);
    }
    return out;
  }

  /// يحمّل نافذة أشهر حول [center]. [reset] يبدّل البيانات كلها ببيانات النافذة
  /// (بعد أي كتابة أو تبديل شاليه) دون وميض: البيانات القديمة تبقى معروضة حتى
  /// وصول الجديدة.
  Future<void> _loadWindow(DateTime center, {bool reset = false}) async {
    final chalet = _chalet;
    if (chalet == null) return;
    final gen = reset ? ++_gen : _gen;
    var months = _windowMonths(center);
    if (!reset) {
      months = months.where((m) => !_loadedMonths.contains(_monthKey(m))).toList();
    }
    if (months.isEmpty) return;

    final from = months.first;
    final last = months.last;
    final toExclusive = DateTime(last.year, last.month + 1, 1);
    final toInclusive = addDays(toExclusive, -1);

    setState(() {
      _inflight++;
      _monthError = null;
    });
    try {
      final results = await Future.wait<Object>([
        _ds.loadBookings(chalet.id, from, toExclusive),
        _ds.loadBlocked(chalet.id, from, toInclusive),
        // ثانوي: فشله يخفي علامة "محجوز جزئياً" فقط، لا التقويم كله.
        _ds
            .loadDaySlots(chalet.id, from, toInclusive)
            .catchError((_) => <DateTime, ChaletDaySlot>{}),
      ]);
      if (!mounted || gen != _gen || chalet.id != _chalet?.id) return;
      final bookings = results[0] as List<BookingModel>;
      final blocked = results[1] as Set<DateTime>;
      final slots = results[2] as Map<DateTime, ChaletDaySlot>;
      setState(() {
        if (reset) {
          _data = CalendarData();
          _loadedMonths = {};
        }
        _data.addBookings(bookings);
        _data.replaceBlocked(from, toInclusive, blocked);
        _data.replaceSlots(from, toInclusive, slots);
        for (final m in months) {
          _loadedMonths.add(_monthKey(m));
        }
      });
    } catch (_) {
      if (!mounted || gen != _gen) return;
      setState(() => _monthError = 'تعذر تحميل بيانات التقويم، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _inflight--);
    }
  }

  Future<void> _refresh() async {
    await _loadWindow(_focusedDay, reset: true);
    try {
      final ids = [for (final c in _chalets) c.id];
      final pending = await _ds.loadPendingCounts(ids);
      if (mounted) setState(() => _pending = pending);
    } catch (e, st) {
      // شارات "قيد الانتظار" ثانوية: تبقى قيمها السابقة.
      reportError(e, st, context: 'owner_calendar.pending_counts');
    }
  }

  void _selectChalet(CalendarChalet chalet) {
    if (chalet.id == _chalet?.id) return;
    _gen++;
    setState(() {
      _chalet = chalet;
      _data = CalendarData();
      _loadedMonths = {};
      _selectedDay = null;
      _monthError = null;
      _exitRangeMode();
      _clearPricing();
    });
    _loadWindow(_focusedDay, reset: true);
  }

  // ─── الأسعار ──────────────────────────────────────────────

  Future<DayPriceInfo?> _priceFor(DateTime day) async {
    final chalet = _chalet;
    if (chalet == null) return null;
    final key = '${chalet.id}-${day.year}-${day.month}';
    final month = _pricing.putIfAbsent(key, () async {
      try {
        return await _ds.loadMonthPricing(chalet, day.year, day.month);
      } catch (_) {
        return null;
      }
    });
    final map = await month;
    if (map == null) {
      _pricing.remove(key);
      return null;
    }
    return map[dateOnly(day)];
  }

  // ─── النقر على الأيام ─────────────────────────────────────

  bool get _wide => MediaQuery.sizeOf(context).width >= _wideBreakpoint;

  void _onDayTapped(DateTime day) {
    final d = dateOnly(day);
    if (_rangeMode) {
      _onRangeTap(d);
      return;
    }
    final info = _data.dayInfo(d, today: _today);
    // اليوم الماضي الفارغ لا يفتح شيئاً.
    if (info.isPast && !info.isBooked) return;
    setState(() => _selectedDay = d);
    if (!_wide) _openSheet(d);
  }

  void _openSheet(DateTime day) {
    if (_sheetOpen) return;
    _sheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                16, 10, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                _dayPanel(),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      _sheetOpen = false;
      if (mounted && !_wide) setState(() => _selectedDay = null);
    });
  }

  void _closeSheet() {
    if (_sheetOpen && mounted) Navigator.of(context).pop();
  }

  Widget _dayPanel() {
    final chalet = _chalet!;
    final selected = _selectedDay ?? _today;
    final info = _data.dayInfo(selected, today: _today);
    return OwnerDayPanel(
      chalet: chalet,
      day: info,
      today: _today,
      priceFuture: _priceFutureFor(selected),
      busy: _busy,
      onManualBooking: () => _manualBooking(selected),
      onBlockDay: () => _blockDays([selected], label: fullDayLabel(selected)),
      onUnblockDay: () =>
          _unblockDays([selected], label: fullDayLabel(selected)),
      onSelectRangeToBlock: () => _startRangeFrom(selected),
      onSelectRangeToUnblock: () => _startRangeFrom(selected),
      onOpenPricing: _openPricing,
      onConfirm: _confirmBooking,
      onReject: _rejectBooking,
      onCancelManual: _cancelManual,
    );
  }

  // ─── إجراءات اليوم ────────────────────────────────────────

  Future<void> _manualBooking(DateTime day) async {
    final chalet = _chalet!;
    _closeSheet();
    final opener = widget.manualBookingOpener ?? openManualBookingSheet;
    final saved = await opener(context, chaletId: chalet.id, checkIn: day);
    if (!mounted || !saved) return;
    _snack('تم حجز الفترة');
    await _refresh();
  }

  Future<void> _openPricing() async {
    final chalet = _chalet!;
    _closeSheet();
    final opener = widget.pricingOpener ?? _defaultPricingOpener;
    await opener(context, chalet);
    if (!mounted) return;
    // قد تغيّرت الأسعار: يُعاد جلبها عند فتح أي ورقة.
    setState(_clearPricing);
  }

  Future<void> _defaultPricingOpener(
      BuildContext context, CalendarChalet chalet) {
    return Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChaletPricingScreen(
        chaletId: chalet.id,
        chaletName: chalet.name,
        defaultPricePerNight: chalet.pricePerNight,
      ),
    ));
  }

  Future<void> _confirmBooking(BookingModel b) => _decideBooking(
      (onStart) => confirmBookingFlow(context, b.id,
          confirm: _ds.confirmBooking, onStart: onStart));

  Future<void> _rejectBooking(BookingModel b) => _decideBooking(
      (onStart) => rejectBookingFlow(context, b.id,
          reject: _ds.rejectBooking, onStart: onStart));

  /// "مشغول" يُضبط بعد موافقة المالك بالحوار وقبل الطلب (لا بعده).
  Future<void> _decideBooking(
      Future<bool> Function(VoidCallback onStart) flow) async {
    if (_busy) return;
    var ok = false;
    try {
      ok = await flow(() => setState(() => _busy = true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!ok || !mounted) return;
    _closeSheet();
    await _refresh();
  }

  Future<void> _cancelManual(BookingModel b) async {
    final ok = await confirmAndCancelManualBooking(context, b,
        cancel: _ds.cancelManualBooking);
    if (!ok || !mounted) return;
    _closeSheet();
    await _refresh();
  }

  // ─── الحجب وإلغاء الحجب ───────────────────────────────────

  Future<void> _blockDays(
    List<DateTime> dates, {
    required String label,
    int skippedBooked = 0,
  }) async {
    if (_busy || dates.isEmpty) return;
    final chalet = _chalet!;
    _closeSheet();
    setState(() => _busy = true);
    var ok = false;
    try {
      await _ds.blockDates(chalet.id, dates);
      ok = true;
    } catch (_) {
      _snack('تعذر حجب الأيام، حاول مرة أخرى', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
    if (!ok || !mounted) return;
    final extra = skippedBooked > 0
        ? '، وتم تخطي ${daysLabel(skippedBooked)} لوجود حجز'
        : '';
    _snack(
      dates.length == 1
          ? 'تم حجب $label'
          : 'تم حجب ${daysLabel(dates.length)}$extra',
      undoLabel: 'تراجع',
      onUndo: () => _writeAndRefresh(() => _ds.unblockDates(chalet.id, dates)),
    );
  }

  Future<void> _unblockDays(
    List<DateTime> dates, {
    required String label,
  }) async {
    if (_busy || dates.isEmpty) return;
    final chalet = _chalet!;
    _closeSheet();
    setState(() => _busy = true);
    var ok = false;
    try {
      await _ds.unblockDates(chalet.id, dates);
      ok = true;
    } catch (_) {
      _snack('تعذر إلغاء الحجب، حاول مرة أخرى', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
    if (!ok || !mounted) return;
    _snack(
      dates.length == 1
          ? 'تم إلغاء حجب $label'
          : 'تم إلغاء حجب ${daysLabel(dates.length)}',
      undoLabel: 'تراجع',
      onUndo: () => _writeAndRefresh(() => _ds.blockDates(chalet.id, dates)),
    );
  }

  Future<void> _writeAndRefresh(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {
      _snack('تعذر التراجع، حاول مرة أخرى', isError: true);
    }
    if (mounted) await _refresh();
  }

  // ─── وضع تحديد الأيام ─────────────────────────────────────

  void _startRangeFrom(DateTime day) {
    _closeSheet();
    setState(() {
      _rangeMode = true;
      _selectedDay = null;
      _rangeHint = null;
    });
    _onRangeTap(dateOnly(day));
  }

  void _toggleRangeMode() {
    setState(() {
      if (_rangeMode) {
        _exitRangeMode();
      } else {
        _rangeMode = true;
        _selectedDay = null;
      }
    });
  }

  void _exitRangeMode() {
    _rangeMode = false;
    _rangeStart = null;
    _rangeEnd = null;
    _rangeAction = null;
    _rangeHint = null;
  }

  void _onRangeTap(DateTime d) {
    final info = _data.dayInfo(d, today: _today);
    if (info.isPast) {
      setState(() => _rangeHint = 'لا يمكن اختيار يوم منتهٍ');
      return;
    }
    // نقرة ثالثة (أو الأولى) تبدأ نطاقاً جديداً. البداية لا تكون على يوم عليه
    // حجز لأن الحجب لا يُطبَّق عليه.
    final starting = _rangeStart == null || _rangeEnd != null;
    if (starting) {
      if (info.isBooked) {
        setState(() => _rangeHint = 'هذا اليوم عليه حجز، لا يمكن حجبه');
        return;
      }
      setState(() {
        _rangeStart = d;
        _rangeEnd = null;
        _rangeAction = info.blocked ? RangeAction.unblock : RangeAction.block;
        _rangeHint = null;
      });
    } else {
      setState(() {
        _rangeEnd = d;
        _rangeHint = null;
      });
    }
  }

  BlockPlan? get _blockPlan {
    if (_rangeStart == null || _rangeEnd == null) return null;
    return planBlock(_rangeStart!, _rangeEnd!, _data, today: _today);
  }

  UnblockPlan? get _unblockPlan {
    if (_rangeStart == null || _rangeEnd == null) return null;
    return planUnblock(_rangeStart!, _rangeEnd!, _data, today: _today);
  }

  Future<void> _confirmRange() async {
    if (_rangeStart == null || _rangeEnd == null) return;
    if (_rangeAction == RangeAction.unblock) {
      final plan = _unblockPlan!;
      setState(_exitRangeMode);
      await _unblockDays(plan.dates, label: '');
    } else {
      final plan = _blockPlan!;
      setState(_exitRangeMode);
      await _blockDays(plan.dates,
          label: '', skippedBooked: plan.skippedBooked);
    }
  }

  // ─── مساعدات ──────────────────────────────────────────────

  void _snack(String msg,
      {bool isError = false, String? undoLabel, VoidCallback? onUndo}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: isError ? AppColors.error : AppColors.primary,
      action: undoLabel == null
          ? null
          : SnackBarAction(
              label: undoLabel,
              textColor: Colors.white,
              onPressed: onUndo ?? () {},
            ),
    ));
  }

  Future<void> _handleBack() async {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/owner-dashboard');
  }

  int get _totalPending => _pending.values.fold(0, (a, b) => a + b);

  // ─── الواجهة ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.primary,
          elevation: 0,
          leading: IconButton(
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            tooltip: 'رجوع',
          ),
          title: const Text('التقويم',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              key: const Key('action_today'),
              tooltip: 'اليوم',
              icon: const Icon(Icons.today_rounded),
              onPressed: _chalet == null ? null : _goToToday,
            ),
            IconButton(
              key: const Key('action_range_mode'),
              tooltip: 'تحديد أيام',
              isSelected: _rangeMode,
              icon: const Icon(Icons.checklist_rounded),
              selectedIcon: const Icon(Icons.checklist_rtl_rounded),
              onPressed: _chalet == null ? null : _toggleRangeMode,
            ),
            IconButton(
              key: const Key('action_bookings_list'),
              tooltip: 'قائمة الحجوزات',
              icon: Badge(
                isLabelVisible: _totalPending > 0,
                label: Text('$_totalPending'),
                child: const Icon(Icons.view_list_rounded),
              ),
              onPressed: () => context.push('/owner-bookings'),
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: OwnerBottomNav(
          currentRoute: '/owner-calendar',
          unreadCount: _unread,
        ),
      ),
    );
  }

  void _goToToday() => _setMonth(_today);

  /// ينتقل لشهر [target] (ضمن مدى التقويم) ويحمّل نافذته إن لزم.
  void _setMonth(DateTime target) {
    var m = DateTime(target.year, target.month, 1);
    final first = DateTime(_firstDay.year, _firstDay.month, 1);
    final last = DateTime(_lastDay.year, _lastDay.month, 1);
    if (m.isBefore(first)) m = first;
    if (m.isAfter(last)) m = last;
    if (m.year == _focusedDay.year && m.month == _focusedDay.month) return;
    setState(() => _focusedDay = m);
    _loadWindow(m);
  }

  void _shiftMonth(int delta) =>
      _setMonth(DateTime(_focusedDay.year, _focusedDay.month + delta, 1));

  Widget _buildBody() {
    if (_loadingChalets) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_chaletsError != null) {
      return _centered(
        icon: Icons.error_outline_rounded,
        text: _chaletsError!,
        actionLabel: 'إعادة المحاولة',
        onAction: _init,
      );
    }
    if (_chalet == null) {
      return _centered(
        icon: Icons.home_work_outlined,
        text: 'أضف شاليهاً أولاً لتظهر حجوزاته على التقويم',
        actionLabel: 'إضافة شاليه',
        onAction: () => context.go('/owner-add-chalet'),
      );
    }

    final wide = _wide;
    final calendar = _calendarColumn(wide);
    return Column(
      children: [
        _chaletSelector(),
        Expanded(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: calendar,
                      ),
                    ),
                    Container(
                      key: const Key('side_panel'),
                      width: 340,
                      margin: const EdgeInsetsDirectional.fromSTEB(0, 4, 16, 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.sand),
                      ),
                      child: SingleChildScrollView(
                        child: _selectedDay == null
                            ? _sidePlaceholder()
                            : _dayPanel(),
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: calendar,
                ),
        ),
        if (_rangeMode)
          RangeActionBar(
            start: _rangeStart,
            end: _rangeEnd,
            action: _rangeAction,
            blockPlan: _blockPlan,
            unblockPlan: _unblockPlan,
            hint: _rangeHint,
            busy: _busy,
            onCancel: () => setState(_exitRangeMode),
            onConfirm: _confirmRange,
          ),
      ],
    );
  }

  Widget _sidePlaceholder() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.touch_app_outlined, size: 40, color: AppColors.textMuted),
          SizedBox(height: 10),
          Text('اختر يوماً لعرض تفاصيله وإجراءاته',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13.5,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _centered({
    required IconData icon,
    required String text,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel,
                  style: const TextStyle(
                      fontFamily: 'Cairo', color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

}
