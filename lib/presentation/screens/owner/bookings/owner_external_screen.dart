// lib/presentation/screens/owner/owner_external_screen.dart
//
// الحجوزات اليدوية: حجوزات يدخلها صاحب الشاليه بنفسه (زبون كلّمه بالتلفون
// أو وجاهياً) حتى تنحجز الفترة ولا يحجزها أحد من التطبيق. تعمل لأي شاليه
// يملكه المالك. المسار `/owner-external` بقي كما هو.

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/booking_period.dart';
import '../../../../data/models/manual_booking.dart';
import '../../../../data/models/models.dart';
import '../../../../data/services/services.dart';
import '../../../widgets/common/paged_list.dart';
import 'manual_booking_actions.dart';
import 'manual_booking_sheet.dart';

class OwnerExternalScreen extends StatefulWidget {
  const OwnerExternalScreen({super.key});

  @override
  State<OwnerExternalScreen> createState() => _OwnerExternalScreenState();
}

class _OwnerExternalScreenState extends State<OwnerExternalScreen> {
  bool _loading = true;
  String? _error;
  // القادمة أولاً (الأقرب فالأبعد)، ثم المنتهية (الأحدث فالأقدم)؛ الفرز
  // والتقسيم على السيرفر، وكل قسم مرقّم بصفحاته.
  final _upcoming = PagedList<BookingModel>(
      (page) =>
          BookingService.instance.getManualBookings(upcoming: true, page: page),
      pageSize: BookingService.bookingsPageSize);
  final _past = PagedList<BookingModel>(
      (page) =>
          BookingService.instance.getManualBookings(upcoming: false, page: page),
      pageSize: BookingService.bookingsPageSize);

  /// عناصر القائمة: حجوزات القادمة، زر مزيدها، ثم المنتهية وزر مزيدها.
  List<Widget Function()> get _rows => [
        for (final b in _upcoming.items) () => _bookingTile(b),
        if (_upcoming.hasMore) () => _footer(_upcoming),
        for (final b in _past.items) () => _bookingTile(b),
        if (_past.hasMore) () => _footer(_past),
      ];

  bool get _isEmpty => _upcoming.items.isEmpty && _past.items.isEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ownerId = AuthService.instance.currentUser?.id;
    if (ownerId == null) {
      setState(() {
        _loading = false;
        _error = 'لا يوجد مستخدم مسجل دخول';
      });
      return;
    }
    try {
      final fresh = await Future.wait([_upcoming.reset(), _past.reset()]);
      if (!mounted || fresh.contains(false)) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الحجوزات، يرجى المحاولة لاحقاً';
      });
    }
  }

  Widget _footer(PagedList<BookingModel> pager) => LoadMoreFooter(
        pager: pager,
        onLoadMore: () async {
          setState(() {});
          try {
            await pager.loadMore();
          } catch (_) {
            _showSnack('تعذر تحميل المزيد، حاول مرة أخرى', isError: true);
          }
          if (mounted) setState(() {});
        },
      );

  Future<void> _addManualBooking() async {
    final saved = await openManualBookingSheet(context);
    if (!mounted) return;
    if (saved) {
      _showSnack('تم حجز الفترة');
      _load();
    }
  }

  Future<void> _cancelBooking(BookingModel b) async {
    final cancelled = await confirmAndCancelManualBooking(context, b);
    if (mounted && cancelled) _load();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: isError ? AppColors.error : AppColors.primary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: const Text('الحجوزات اليدوية',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                child: _error != null
                    ? _buildError()
                    : _isEmpty
                        ? _buildEmpty()
                        : Builder(builder: (_) {
                            final rows = _rows;
                            return ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 96),
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => rows[i](),
                            );
                          }),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addManualBooking,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('حجز يدوي',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Widget _buildError() => ListView(children: [
        const SizedBox(height: 100),
        Center(
            child: Text(_error!,
                style: const TextStyle(
                    fontFamily: 'Cairo', color: AppColors.textSecondary))),
        Center(
            child: TextButton(
                onPressed: _load,
                child: const Text('إعادة المحاولة',
                    style: TextStyle(
                        fontFamily: 'Cairo', color: AppColors.primary)))),
      ]);

  Widget _buildEmpty() => ListView(children: const [
        SizedBox(height: 100),
        Icon(Icons.edit_calendar_rounded,
            size: 56, color: AppColors.textMuted),
        SizedBox(height: 14),
        Center(
            child: Text('لا توجد حجوزات يدوية',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary))),
        SizedBox(height: 6),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Center(
              child: Text(
                  'اضغط "حجز يدوي" لتحجز يوماً وفترة لزبون كلّمك بالتلفون أو وجاهياً',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textMuted))),
        ),
      ]);

  Widget _bookingTile(BookingModel b) {
    final guest = b.manualGuest;
    final isActive = b.status == BookingStatus.confirmed ||
        b.status == BookingStatus.pending;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.edit_calendar_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guest.name ?? 'ضيف',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary)),
                if (guest.phone != null) ...[
                  const SizedBox(height: 2),
                  Text(guest.phone!,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 4),
                Text(b.chaletName ?? 'شاليه',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text('${b.dateLabel} · ${b.guestsCount} ضيوف',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(b.periodWithTime,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
                if (guest.note != null) ...[
                  const SizedBox(height: 3),
                  Text(guest.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.textMuted)),
                ],
                if (canCancelManualBooking(b)) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => _cancelBooking(b),
                    icon: const Icon(Icons.event_busy_rounded,
                        size: 16, color: AppColors.error),
                    label: const Text('إلغاء الحجز',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: AppColors.error)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₪${b.totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary)),
              if (!isActive) ...[
                const SizedBox(height: 4),
                Text(b.status.arabicLabel,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
