import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';

class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  List<BookingModel> _bookings = [];

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
    try {
      final incoming = await BookingService.instance.getIncomingBookings();
      if (!mounted) return;
      setState(() {
        _bookings = incoming;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bookings = [];
        _loading = false;
        _error = 'تعذر تحميل الحجوزات، حاول مرة أخرى';
      });
    }
  }

  Future<void> _onConfirm(String bookingId) async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await BookingService.instance.confirmIncomingBooking(bookingId);
      await _load();
      if (!mounted) return;
      _showSnack('تم تأكيد الحجز بنجاح');
    } catch (_) {
      if (!mounted) return;
      _showSnack('تعذر تأكيد الحجز، يرجى المحاولة لاحقاً', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _onReject(String bookingId) async {
    if (_actionLoading) return;

    // إضافة تأكيد قبل الرفض، تجنبًا لرفض حجز بالخطأ بضغطة واحدة (لم يكن
    // موجودًا في النسخة السابقة).
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('رفض الحجز',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: const Text(
          'هل أنت متأكد من رفض هذا الحجز؟ لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('رفض الحجز',
                style: TextStyle(fontFamily: 'Cairo', color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      await BookingService.instance.rejectIncomingBooking(bookingId);
      await _load();
      if (!mounted) return;
      _showSnack('تم رفض الحجز');
    } catch (_) {
      if (!mounted) return;
      _showSnack('تعذر رفض الحجز، يرجى المحاولة لاحقاً', isError: true);
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
      case BookingStatus.completed:
        return 'مكتمل';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إدارة الحجوزات',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
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
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _bookings.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 1.55,
                          ),
                          itemBuilder: (context, i) =>
                              _bookingCard(_bookings[i]),
                        ),
            ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      // ListView (بدل Center مباشرة) لكي يبقى RefreshIndicator قابلاً
      // للسحب لإعادة المحاولة حتى في حالة الخطأ.
      children: [
        const SizedBox(height: 120),
        Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
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
            'لا توجد حجوزات قيد الانتظار حاليًا',
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 6),
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
                  ? AppColors.accent.withOpacity(0.12)
                  : statusColor.withOpacity(0.35),
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
                              Text(
                                '${b.checkIn.day} - ${b.checkOut.day} ${_monthName(b.checkIn.month)}',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary,
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
                        color: AppColors.primary.withOpacity(0.06),
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
                              color: AppColors.border.withOpacity(0.9),
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

  String _monthName(int month) {
    switch (month) {
      case 1:
        return 'يناير';
      case 2:
        return 'فبراير';
      case 3:
        return 'مارس';
      case 4:
        return 'أبريل';
      case 5:
        return 'مايو';
      case 6:
        return 'يونيو';
      case 7:
        return 'يوليو';
      case 8:
        return 'أغسطس';
      case 9:
        return 'سبتمبر';
      case 10:
        return 'أكتوبر';
      case 11:
        return 'نوفمبر';
      case 12:
        return 'ديسمبر';
      default:
        return '';
    }
  }
}
