part of 'owner_calendar_widgets.dart';

/// شريط وضع تحديد الأيام أسفل التقويم.
class RangeActionBar extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;
  final RangeAction? action;
  final BlockPlan? blockPlan;
  final UnblockPlan? unblockPlan;
  final String? hint;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const RangeActionBar({
    super.key,
    required this.start,
    required this.end,
    required this.action,
    required this.blockPlan,
    required this.unblockPlan,
    required this.hint,
    required this.busy,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    String title;
    String? detail;
    String? buttonLabel;
    var enabled = false;

    if (start == null) {
      title = 'اختر أول يوم في النطاق';
    } else if (end == null) {
      title = 'من ${shortDayLabel(start!)} — اختر آخر يوم (شامل)';
    } else if (action == RangeAction.unblock) {
      final plan = unblockPlan!;
      title = 'إلغاء حجب من ${shortDayLabel(_lo)} إلى ${shortDayLabel(_hi)}';
      if (plan.dates.isEmpty) {
        detail = 'لا توجد أيام محجوبة في هذا النطاق.';
      } else {
        buttonLabel = 'إلغاء حجب ${daysLabel(plan.dates.length)}';
        enabled = true;
        if (plan.skippedNotBlocked > 0) {
          detail = 'سيُتخطى ${daysLabel(plan.skippedNotBlocked)} غير محجوب.';
        }
      }
    } else {
      final plan = blockPlan!;
      title = 'حجب من ${shortDayLabel(_lo)} إلى ${shortDayLabel(_hi)}';
      final notes = <String>[];
      if (plan.skippedBooked > 0) {
        notes.add('سيُتخطى ${daysLabel(plan.skippedBooked)} لوجود حجز عليه');
      }
      if (plan.alreadyBlocked > 0) {
        notes.add('${daysLabel(plan.alreadyBlocked)} محجوب أصلاً');
      }
      if (plan.dates.isEmpty) {
        detail = notes.isEmpty
            ? 'لا توجد أيام يمكن حجبها في هذا النطاق.'
            : '${notes.join(' · ')}. لا توجد أيام يمكن حجبها.';
      } else {
        buttonLabel = 'حجب ${daysLabel(plan.dates.length)}';
        enabled = true;
        if (notes.isNotEmpty) detail = '${notes.join(' · ')}.';
      }
    }

    return Container(
      key: const Key('range_bar'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              key: const Key('range_title'),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal)),
          if (detail != null || hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(hint ?? detail!,
                  key: const Key('range_detail'),
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: hint != null
                          ? AppColors.error
                          : AppColors.textSecondary)),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (buttonLabel != null)
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      key: const Key('range_confirm'),
                      onPressed: enabled && !busy ? onConfirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(buttonLabel,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              if (buttonLabel != null) const SizedBox(width: 10),
              TextButton(
                key: const Key('range_cancel'),
                onPressed: busy ? null : onCancel,
                child: const Text('إلغاء',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  DateTime get _lo => end!.isBefore(start!) ? end! : start!;
  DateTime get _hi => end!.isBefore(start!) ? start! : end!;
}
