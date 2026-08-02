import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/pricing_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';

class HostBookingsScreen extends StatefulWidget {
  const HostBookingsScreen({super.key});

  @override
  State<HostBookingsScreen> createState() => _HostBookingsScreenState();
}

class _HostBookingsScreenState extends State<HostBookingsScreen> {
  bool _loading = true;
  BookingStatus _tabStatus = BookingStatus.pending;

  List<BookingModel> _bookings = [];
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final allIncoming = await BookingService.instance.getIncomingBookings();
      _bookings = allIncoming.where((b) => b.status == _tabStatus).toList();
    } catch (_) {
      _bookings = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onConfirm(String bookingId) async {
    setState(() => _actionLoading = true);
    try {
      await BookingService.instance.confirmIncomingBooking(bookingId);
      await _load();
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _onReject(String bookingId) async {
    setState(() => _actionLoading = true);
    try {
      await BookingService.instance.rejectIncomingBooking(bookingId);
      await _load();
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }

  Widget _buildGuestInfo(BookingModel b) {
    final hasName = (b.guestName ?? '').isNotEmpty;
    final hasPhone = (b.guestPhone ?? '').isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
              image: b.guestAvatar != null && b.guestAvatar!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(b.guestAvatar!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: b.guestAvatar == null || b.guestAvatar!.isEmpty
                ? const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 18)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasName ? b.guestName! : 'ضيف',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.charcoal,
                  ),
                ),
                if (hasPhone) ...[
                  const SizedBox(height: 2),
                  Text(
                    b.guestPhone!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown(BookingModel b) {
    final commission = b.totalPrice * kPlatformCommissionPercentage;
    final netDue = b.totalPrice - commission;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sand),
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

  Color _bookingStatusColor(BookingStatus status) {
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

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      BookingStatus.pending,
      BookingStatus.confirmed,
      BookingStatus.rejected,
      BookingStatus.cancelled,
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('لوحة المالك'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                for (final t in tabs)
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        setState(() {
                          _tabStatus = t;
                          _loading = true;
                        });
                        await _load();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _tabStatus == t
                              ? AppColors.primary.withOpacity(0.12)
                              : AppColors.white,
                          border: Border.all(
                            color: _tabStatus == t
                                ? AppColors.primary
                                : AppColors.sand,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          t.arabicLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: _tabStatus == t
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _bookings.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'لا توجد حجوزات في هذه الحالة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final b = _bookings[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.sand),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _bookingStatusColor(b.status),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.chaletName ?? 'حجز جديد',
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.charcoal,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'تاريخ الحجز: ${_formatDate(b.checkIn)}',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // ✅ بيانات الضيف (الاسم / الهاتف / الصورة) —
                          // مطلوبة على كل بطاقة حجز ليراها المالك فورًا.
                          _buildGuestInfo(b),
                          const SizedBox(height: 12),

                          // ✅ عرض فقط (DISPLAY-ONLY): تفاصيل عمولة المنصة
                          // للمالك — لا تُخصم فعليًا من أي مبلغ ولا تغير
                          // bookings.total_price.
                          _buildPriceBreakdown(b),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'حالة الدفع: ${b.paymentMethod}',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _bookingStatusColor(b.status)
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _bookingStatusColor(b.status),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  b.status.arabicLabel,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: _bookingStatusColor(b.status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (b.status == BookingStatus.pending) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _actionLoading
                                        ? null
                                        : () => _onConfirm(b.id),
                                    icon: const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'قبول',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(
                                          color: AppColors.error),
                                    ),
                                    onPressed: _actionLoading
                                        ? null
                                        : () => _onReject(b.id),
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'رفض',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
