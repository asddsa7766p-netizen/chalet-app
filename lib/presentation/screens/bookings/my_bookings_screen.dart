import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import '../../../data/models/booking_period.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../widgets/common/paged_list.dart';
import '../../widgets/reviews/review_widgets.dart' show reviewGold;
import '../../widgets/reviews/write_review_sheet.dart';
import '../../../core/utils/error_reporter.dart';

// ============================================
// FAVORITES SCREEN
// ============================================
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // ✅ إصلاح: كانت التسميات "الحالية"/"القادمة" لا تطابق ما تعرضه فعلياً —
  // "الحالية" كانت تعرض حجوزات confirmed بغض النظر عن التاريخ (حجز مؤكد
  // بعد 3 أشهر كان يظهر كأنه "حالي")، و"القادمة" كانت تعرض pending (حجز
  // لم يوافق عليه المالك بعد، وليس بالضرورة "قادم" — قد يُرفض). التسميات
  // الآن تصف الحالة الفعلية التي يفلتر عليها كل تبويب، بدون أي تغيير على
  // منطق الفلترة نفسه.
  final _tabs = ['مؤكدة', 'قيد الانتظار', 'سابقة', 'ملغاة'];
  final _statuses = [
    ['confirmed'],
    ['pending'],
    ['completed'],
    ['cancelled', 'rejected'],
  ];
  // كل تبويب يُفلتر على السيرفر ويُرقَّم بصفحاته (كانت كل الحجوزات تُجلب
  // دفعة واحدة بلا حد ثم تُوزَّع محلياً).
  late final _pagers = [
    for (final statuses in _statuses)
      PagedList<BookingModel>(
          (page) => BookingService.instance
              .getMyBookings(statuses: statuses, page: page),
          pageSize: BookingService.bookingsPageSize),
  ];
  bool _loading = true;
  // ✅ إصلاح: فشل التحميل كان يُعرض كأنه "لا يوجد حجوزات" بكل التبويبات.
  bool _loadError = false;
  bool _cancelling = false;

  /// تبويب "سابقة" (completed) بـ [_statuses].
  static const _completedTab = 2;

  /// حجوزات مكتملة عُرف أنها قُيِّمت / فُحصت. الزر يظهر فقط لما فُحص ولم
  /// يُقيَّم، فلا يومض زر لحجز مقيَّم أثناء الفحص (ولا يظهر إن فشل الفحص).
  final _reviewed = <String>{};
  final _reviewChecked = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final fresh = await Future.wait([for (final p in _pagers) p.reset()]);
      if (mounted && !fresh.contains(false)) {
        setState(() => _loading = false);
        _checkReviewed();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = true;
        });
      }
    }
  }

  Future<void> _loadMore(PagedList<BookingModel> pager) async {
    setState(() {});
    try {
      await pager.loadMore();
      if (identical(pager, _pagers[_completedTab])) _checkReviewed();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تحميل المزيد، حاول مرة أخرى',
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
        ));
      }
    }
    if (mounted) setState(() {});
  }

  /// أيّ الحجوزات المكتملة المعروضة قيّمها المستخدم (لزر "قيّم إقامتك").
  Future<void> _checkReviewed() async {
    final ids = [
      for (final b in _pagers[_completedTab].items)
        if (!_reviewChecked.contains(b.id)) b.id,
    ];
    if (ids.isEmpty) return;
    try {
      final reviewed = await ReviewsService.instance.reviewedBookingIds(ids);
      if (!mounted) return;
      setState(() {
        _reviewed.addAll(reviewed);
        _reviewChecked.addAll(ids);
      });
    } catch (e, st) {
      reportError(e, st, context: 'my_bookings.reviewed_ids');
    }
  }

  Future<void> _review(BookingModel booking) async {
    final sent = await showWriteReviewSheet(context, booking: booking);
    if (sent && mounted) setState(() => _reviewed.add(booking.id));
  }

  Future<void> _cancel(String bookingId, int tabIdx) async {
    if (_cancelling) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إلغاء الحجز',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        content: const Text('هل أنت متأكد من إلغاء هذا الحجز؟',
            style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لا', style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('نعم، إلغاء',
                  style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
    if (confirm == true) {
      // ✅ إصلاح: فشل الإلغاء كان استثناءً غير معالَج (لا رسالة للمستخدم).
      _cancelling = true;
      try {
        await BookingService.instance.cancelBooking(bookingId);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر إلغاء الحجز، يرجى المحاولة مرة أخرى',
                style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.error,
          ));
        }
      } finally {
        _cancelling = false;
      }
      if (mounted) _load();
    }
  }

  _ReviewState _reviewStateOf(BookingModel b) {
    if (b.status != BookingStatus.completed || !_reviewChecked.contains(b.id)) {
      return _ReviewState.none;
    }
    return _reviewed.contains(b.id) ? _ReviewState.done : _ReviewState.pending;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: AppColors.textPrimary,
        title: const Text(AppStrings.myBookings),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
              fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600),
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _loadError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    const Text('تعذر تحميل حجوزاتك',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('تحقق من اتصالك بالإنترنت وحاول مجدداً',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة',
                          style: TextStyle(fontFamily: 'Cairo')),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: List.generate(_tabs.length, (i) {
                final pager = _pagers[i];
                final bookings = pager.items;
                if (bookings.isEmpty) {
                  // قابلة للسحب للتحديث حتى وهي فارغة (كانت Center ثابتة
                  // بلا أي طريقة لإعادة التحميل).
                  return RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.calendar_month_rounded,
                                    size: 60, color: AppColors.sand),
                                const SizedBox(height: 14),
                                Text(
                                  'لا يوجد ${_tabs[i]}',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: bookings.length + 1,
                    itemBuilder: (_, j) => j == bookings.length
                        ? LoadMoreFooter(
                            pager: pager, onLoadMore: () => _loadMore(pager))
                        : _BookingCard(
                            booking: bookings[j],
                            reviewState: _reviewStateOf(bookings[j]),
                            onReview: () => _review(bookings[j]),
                            onCancel: bookings[j].status ==
                                        BookingStatus.pending ||
                                    bookings[j].status ==
                                        BookingStatus.confirmed
                                ? () => _cancel(bookings[j].id, i)
                                : null,
                          ),
                  ),
                );
              }),
            ),
    );
  }
}

/// حالة التقييم لحجز مكتمل: لا شيء (غير مكتمل أو لم يُفحص)، بانتظار
/// التقييم (زر)، أو قُيِّم.
enum _ReviewState { none, pending, done }

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onCancel;
  final _ReviewState reviewState;
  final VoidCallback? onReview;
  const _BookingCard({
    required this.booking,
    this.onCancel,
    this.reviewState = _ReviewState.none,
    this.onReview,
  });

  Color get _statusColor {
    switch (booking.status) {
      case BookingStatus.pending:
        return AppColors.pending;
      case BookingStatus.confirmed:
        return AppColors.confirmed;
      case BookingStatus.cancelled:
        return AppColors.cancelled;
      case BookingStatus.rejected:
        return AppColors.error;
      case BookingStatus.completed:
        return AppColors.completed;
    }
  }

  // ✅ إصلاح: كان booking.id.substring(0,8) يرمي RangeError لو كان الـid
  // أقصر من 8 أحرف. نفس الحماية المطبّقة أصلاً بـbooking_screen.dart
  // (_bookingCode)، هون فقط لم تكن مطبّقة.
  String get _shortId =>
      booking.id.length >= 8 ? booking.id.substring(0, 8) : booking.id;

  @override
  Widget build(BuildContext context) {
    const bg = AppColors.card;
    // ✅ إصلاح: البطاقة كانت لا تُظهر نوع الإقامة رغم توفره فعلياً
    // بـBookingModel.stayType، ولا يوجد أي طريقة للانتقال منها لصفحة
    // الشاليه (لا تفاعل عند الضغط إطلاقاً).
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(
        '/home/chalet/${booking.chaletId}',
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4)),
        ],
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'حجز #$_shortId',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor.withValues(alpha: 0.9)),
                  ),
                  child: Text(
                    booking.status.arabicLabel,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: booking.chaletImage != null
                      ? CachedNetworkImage(
                          imageUrl: booking.chaletImage!,
                          width: 86,
                          height: 86,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 86,
                            height: 86,
                            color: AppColors.primaryLight.withValues(alpha: 0.35),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 86,
                            height: 86,
                            color: AppColors.primaryLight.withValues(alpha: 0.35),
                            child: const Icon(Icons.home_work_rounded,
                                color: AppColors.textMuted),
                          ),
                        )
                      : Container(
                          width: 86,
                          height: 86,
                          color: AppColors.primaryLight.withValues(alpha: 0.35),
                          child: const Icon(Icons.home_work_rounded,
                              color: AppColors.textMuted),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.chaletName ?? 'شاليه',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.chaletCity ?? '',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        booking.dateLabel,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                const Divider(height: 1),
                const SizedBox(height: 10),
                // الفترة واسمها ووقتها (كل حجز = يوم + فترة).
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPale,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      booking.periodWithTime,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${booking.guestsCount} ضيف',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      AppCurrency.formatPrice(booking.totalPrice),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                if (onCancel != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
                if (reviewState == _ReviewState.pending) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: Key('review_booking_${booking.id}'),
                      onPressed: onReview,
                      icon: const Icon(Icons.star_rounded,
                          size: 18, color: reviewGold),
                      label: const Text(
                        'قيّم إقامتك',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        backgroundColor: reviewGold.withValues(alpha: 0.08),
                        side: BorderSide(
                            color: reviewGold.withValues(alpha: 0.6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
                if (reviewState == _ReviewState.done) ...[
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'قيّمت هذه الإقامة، شكراً لك',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ============================================
// REVIEWS SCREEN
// ============================================
