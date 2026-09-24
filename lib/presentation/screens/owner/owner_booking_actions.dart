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

Future<bool> _askToProceed(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
  required Color actionColor,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel,
                style: TextStyle(fontFamily: 'Cairo', color: actionColor)),
          ),
        ],
      ),
    ),
  );
  return confirmed == true;
}

/// تأكيد طلب حجز معلّق بعد حوار تأكيد صريح (مستخرج من شاشة الحجوزات ليعمل
/// أيضاً من التقويم). [onStart] يُستدعى بعد موافقة المالك وقبل الطلب، ليعطّل
/// المستدعي أزراره طوال الطلب. يرجع true إذا تم التأكيد فعلاً.
Future<bool> confirmBookingFlow(
  BuildContext context,
  String bookingId, {
  BookingAction? confirm,
  VoidCallback? onStart,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final proceed = await _askToProceed(
    context,
    title: 'قبول الحجز',
    message: 'هل تريد قبول هذا الحجز؟ ستُحجز هذه التواريخ للضيف.',
    actionLabel: 'قبول الحجز',
    actionColor: AppColors.primary,
  );
  if (!proceed) return false;

  onStart?.call();
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
/// [onStart] كما في [confirmBookingFlow]. يرجع true إذا تم الرفض فعلاً.
Future<bool> rejectBookingFlow(
  BuildContext context,
  String bookingId, {
  BookingAction? reject,
  VoidCallback? onStart,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final proceed = await _askToProceed(
    context,
    title: 'رفض الحجز',
    message: 'هل أنت متأكد من رفض هذا الحجز؟ لا يمكن التراجع عن هذا الإجراء.',
    actionLabel: 'رفض الحجز',
    actionColor: AppColors.error,
  );
  if (!proceed) return false;

  onStart?.call();
  try {
    await (reject ?? BookingService.instance.rejectIncomingBooking)(bookingId);
    _snack(messenger, 'تم رفض الحجز');
    return true;
  } catch (_) {
    _snack(messenger, 'تعذر رفض الحجز، يرجى المحاولة لاحقاً', isError: true);
    return false;
  }
}
