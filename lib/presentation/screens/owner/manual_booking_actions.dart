import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/manual_booking.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';

/// هل يظهر زر "إلغاء الحجز" لهذا الحجز؟ فقط الحجز اليدوي الفعّال الذي لم
/// تنتهِ مغادرته بعد (cancel_external_booking ترفض غير اليدوي أو الملغى).
bool canCancelManualBooking(BookingModel b, {DateTime? now}) {
  if (!b.isManual) return false;
  if (b.status != BookingStatus.confirmed &&
      b.status != BookingStatus.pending) {
    return false;
  }
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  return !b.checkOut.isBefore(today);
}

/// يسأل المالك أولاً ثم يلغي الحجز اليدوي عبر cancel_external_booking.
/// يرجع true إذا تم الإلغاء فعلاً.
Future<bool> confirmAndCancelManualBooking(
  BuildContext context,
  BookingModel booking, {
  Future<void> Function(String bookingId)? cancel,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final guest = booking.manualGuest.name ?? 'الضيف';
  String d(DateTime x) => '${x.day}/${x.month}/${x.year}';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إلغاء الحجز اليدوي؟',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Text(
          'سيُلغى حجز $guest من ${d(booking.checkIn)} إلى ${d(booking.checkOut)} '
          'وتصبح هذه التواريخ متاحة للحجز من جديد.',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع', style: TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إلغاء الحجز',
                style: TextStyle(fontFamily: 'Cairo', color: AppColors.error)),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true) return false;

  try {
    await (cancel ?? BookingService.instance.cancelExternalBooking)(booking.id);
    messenger.showSnackBar(const SnackBar(
      content: Text('تم إلغاء الحجز', style: TextStyle(fontFamily: 'Cairo')),
      backgroundColor: AppColors.primary,
    ));
    return true;
  } catch (e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    messenger.showSnackBar(SnackBar(
      content: Text(msg.isEmpty ? 'تعذر إلغاء الحجز، حاول مرة أخرى' : msg,
          style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: AppColors.error,
    ));
    return false;
  }
}
