import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/services.dart';

typedef BookingAction = Future<void> Function(String bookingId);

void _snack(ScaffoldMessengerState messenger, String msg,
    {bool isError = false}) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: isError ? AppColors.error : AppColors.primary,
    ),
  );
}

/// تأكيد طلب حجز معلّق (مستخرج من شاشة الحجوزات ليعمل أيضاً من التقويم).
/// يرجع true إذا تم التأكيد فعلاً.
Future<bool> confirmBookingFlow(
  BuildContext context,
  String bookingId, {
  BookingAction? confirm,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await (confirm ?? BookingService.instance.confirmIncomingBooking)(bookingId);
    _snack(messenger, 'تم تأكيد الحجز بنجاح');
    return true;
  } catch (_) {
    _snack(messenger, 'تعذر تأكيد الحجز، يرجى المحاولة لاحقاً', isError: true);
    return false;
  }
}

/// رفض طلب حجز معلّق بعد تأكيد صريح (تجنباً للرفض بضغطة واحدة).
/// يرجع true إذا تم الرفض فعلاً.
Future<bool> rejectBookingFlow(
  BuildContext context,
  String bookingId, {
  BookingAction? reject,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
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
    ),
  );
  if (confirmed != true) return false;

  try {
    await (reject ?? BookingService.instance.rejectIncomingBooking)(bookingId);
    _snack(messenger, 'تم رفض الحجز');
    return true;
  } catch (_) {
    _snack(messenger, 'تعذر رفض الحجز، يرجى المحاولة لاحقاً', isError: true);
    return false;
  }
}
