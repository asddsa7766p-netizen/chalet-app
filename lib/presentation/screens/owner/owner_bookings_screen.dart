import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/pricing_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/booking_period.dart';
import '../../../data/models/manual_booking.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import '../../../data/services/notification_service.dart';
import '../../widgets/common/paged_list.dart';
import 'manual_booking_actions.dart';
import 'manual_booking_sheet.dart';
import 'owner_booking_actions.dart';
import 'owner_bottom_nav.dart';

class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  final _pager = PagedList<BookingModel>(
      (page) => BookingService.instance.getIncomingBookings(page: page),
      pageSize: BookingService.bookingsPageSize);
  List<BookingModel> get _bookings => _pager.items;
  // ✅ إصلاح: نفس نمط تحميل unreadCount المستخدم في owner_dashboard_screen.dart
  // (Problem #2)، حتى تعرض شارة الإشعارات في OwnerBottomNav هنا العدد
  // الحقيقي بدل الاعتماد على القيمة الافتراضية صفر.
  int _unreadCount = 0;

  Future<void> _cancelManualBooking(BookingModel b) async {
    final cancelled = await confirmAndCancelManualBooking(context, b);
    if (mounted && cancelled) _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _addManualBooking() async {
    final saved = await openManualBookingSheet(context);
    if (!mounted || !saved) return;
    _showSnack('تم حجز الفترة');
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // الحجوزات هي الطلب الأساسي؛ عدّاد الإشعارات ثانوي ولا يُسقط القائمة
      // إن فشل (نفس نمط _init() بـ owner_calendar_screen.dart).
      final fresh = await _pager.reset();
      final unread = await NotificationService.instance
          .getUnreadCount()
          .catchError((_) => _unreadCount);
      if (!mounted || !fresh) return;
      setState(() {
        _unreadCount = unread;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pager.items = [];
        _pager.hasMore = false;
        _loading = false;
        _error = 'تعذر تحميل الحجوزات، حاول مرة أخرى';
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() {});
    try {
      await _pager.loadMore();
    } catch (_) {
      _showSnack('تعذر تحميل المزيد، حاول مرة أخرى', isError: true);
    }
    if (mounted) setState(() {});
  }

  Future<void> _onConfirm(String bookingId) => _decide(
      (onStart) => confirmBookingFlow(context, bookingId, onStart: onStart));

  Future<void> _onReject(String bookingId) => _decide(
      (onStart) => rejectBookingFlow(context, bookingId, onStart: onStart));

  /// القبول والرفض متناظران: حوار تأكيد أولاً، ثم "مشغول" قبل الطلب نفسه
  /// (كان الرفض يضبطه بعد الطلب، فيبقى الزر مفعّلاً أثناءه).
  Future<void> _decide(Future<bool> Function(VoidCallback onStart) flow) async {
    if (_actionLoading) return;
    try {
      final ok = await flow(() => setState(() => _actionLoading = true));
      if (ok && mounted) await _load();
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
      ),
    );
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
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

  String _statusLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'قيد الانتظار';
      case BookingStatus.confirmed:
        return 'مؤكد';
      case BookingStatus.cancelled:
        return 'ملغى';
      case BookingStatus.rejected:
        return 'مرفوض';
      case BookingStatus.completed:
        return 'مكتمل';
    }
  }

  Future<void> _handleBack() async {
    if (context.canPop()) {
      if (mounted) context.pop();
      return;
    }
    if (mounted) context.go('/owner-dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: _handleBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'رجوع',
        ),
        title: const Text('إدارة الحجوزات',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => context.push('/owner-external'),
            icon: const Icon(Icons.edit_calendar_rounded),
            tooltip: 'الحجوزات اليدوية',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManualBooking,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('حجز يدوي',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: _error != null
                  ? _buildErrorState()
                  : _bookings.isEmpty
                      ? _buildEmptyState()
                      // ListView (لا شبكة بنسبة ثابتة): ارتفاع البطاقة يتبع
                      // محتواها، فلا يفيض سطر الفترة أو النص المكبّر.
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _bookings.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, i) => i == _bookings.length
                              ? LoadMoreFooter(
                                  pager: _pager, onLoadMore: _loadMore)
                              : _bookingCard(_bookings[i]),
                        ),
            ),
      // ✅ إصلاح: إضافة نفس الشريط السفلي المستخدم بلوحة التحكم و
      // "شاليهاتي"، بدل إجبار المالك على العودة للوحة التحكم أولًا
      // للانتقال منها إلى قسم آخر.
      bottomNavigationBar: OwnerBottomNav(
        currentRoute: '/owner-bookings',
        unreadCount: _unreadCount,
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      // ListView (بدل Center مباشرة) لكي يبقى RefreshIndicator قابلاً
      // للسحب لإعادة المحاولة حتى في حالة الخطأ.
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
        const SizedBox(height: 14),
        Center(
          child: Text(
            _error ?? 'حدث خطأ',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _load,
            child: const Text('إعادة المحاولة',
                style:
                    TextStyle(fontFamily: 'Cairo', color: AppColors.primary)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Icon(Icons.event_busy_rounded, size: 56, color: AppColors.textMuted),
        SizedBox(height: 14),
        Center(
          child: Text(
            'لا توجد حجوزات حاليًا',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _bookingCard(BookingModel b) {
    final isPending = b.status == BookingStatus.pending;
    final statusColor = _statusColor(b.status);
    final isManual = b.isManual;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isPending
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : statusColor.withValues(alpha: 0.35),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.border,
                      ),
                      child: const Icon(
                        Icons.home_work_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.chaletName ?? 'شاليه',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded,
                                  size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  b.dateLabel,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  b.periodWithTime,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '₪${b.totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ✅ بيانات الضيف (الاسم / الهاتف / الصورة) — مطلوبة على كل
                // بطاقة حجز ليتمكن المالك من رؤية كامل بيانات الضيف فورًا.
                _buildGuestSection(b, isManual: isManual),

                const SizedBox(height: 12),

                // ✅ عرض فقط (DISPLAY-ONLY): تفاصيل عمولة المنصة للمالك —
                // لا تُخصم فعليًا من أي مبلغ ولا تغير bookings.total_price.
                // مخفية للحجز اليدوي: نسبة العمولة لا تنطبق على حجز خارج المنصة.
                if (!isManual) ...[
                  _buildOwnerPriceBreakdown(b),
                  const SizedBox(height: 12),
                ],
                if (isPending)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _actionLoading ? null : () => _onConfirm(b.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'قبول',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _actionLoading ? null : () => _onReject(b.id),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: BorderSide(
                              color: AppColors.border.withValues(alpha: 0.9),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'رفض',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _statusLabel(b.status),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      if (canCancelManualBooking(b))
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: () => _cancelManualBooking(b),
                            icon: const Icon(Icons.event_busy_rounded,
                                size: 16, color: AppColors.error),
                            label: const Text('إلغاء الحجز',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    color: AppColors.error)),
                          ),
                        ),
                      // زر "التواصل مع الضيف" غير مُفعّل بعد (لا توجد آلية
                      // تواصل/رسائل داخل التطبيق حاليًا)، فتمت إزالته من
                      // الواجهة بدل تركه ظاهرًا ومعطّلاً بشكل مضلل للمالك.
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestSection(BookingModel b, {required bool isManual}) {
    // الحجز اليدوي: صاحب الحساب هو المالك نفسه، فبيانات الضيف الحقيقية
    // تُستخرج من الملاحظات (انظر manual_booking.dart).
    final manualGuest = isManual ? b.manualGuest : null;
    final guestName = isManual ? manualGuest!.name : b.guestName;
    final guestPhone = isManual ? manualGuest!.phone : b.guestPhone;
    final guestAvatar = isManual ? null : b.guestAvatar;
    final hasName = (guestName ?? '').isNotEmpty;
    final hasPhone = (guestPhone ?? '').isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          // صورة الضيف
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
              image: guestAvatar != null && guestAvatar.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(guestAvatar),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: guestAvatar == null || guestAvatar.isEmpty
                ? const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 22)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasName ? guestName! : 'ضيف',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.charcoal,
                  ),
                ),
                if (hasPhone) ...[
                  const SizedBox(height: 2),
                  Text(
                    guestPhone!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // شارة "حجز يدوي" للحجز الذي أدخله المالك بنفسه، وإلا أيقونة توضيحية
          if (isManual)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('حجز يدوي',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal)),
            )
          else
            const Icon(Icons.person_outline_rounded,
                size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildOwnerPriceBreakdown(BookingModel b) {
    final commission = b.totalPrice * kPlatformCommissionPercentage;
    final netDue = b.totalPrice - commission;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryPale.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تفاصيل العمولة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          _breakdownRow(
            'قيمة الحجز',
            AppCurrency.formatPrice(b.totalPrice),
          ),
          const SizedBox(height: 2),
          _breakdownRow(
            'عمولة المنصة (${(kPlatformCommissionPercentage * 100).toStringAsFixed(0)}%)',
            '-${AppCurrency.formatPrice(commission)}',
            valueColor: AppColors.error,
          ),
          const Divider(height: 12),
          _breakdownRow(
            'المبلغ المستحق',
            AppCurrency.formatPrice(netDue),
            bold: true,
            valueColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: bold ? 12 : 11,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            color: bold ? AppColors.charcoal : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: bold ? 13 : 11,
            fontWeight: FontWeight.w900,
            color: valueColor ?? AppColors.charcoal,
          ),
        ),
      ],
    );
  }
}
