import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// مكان "احجز الآن" لمالك الشاليه: الخادم يرفض حجزه لشاليهه من التطبيق،
/// فيُوجَّه للحجز اليدوي بدل زر يفشل.
class OwnChaletBookingNote extends StatelessWidget {
  final VoidCallback onManualBooking;
  const OwnChaletBookingNote({super.key, required this.onManualBooking});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('own_chalet_note'),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.primaryPale,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('هذا شاليهك',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
                Text('أضف حجوزاته يدوياً',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          TextButton.icon(
            key: const Key('own_chalet_manual_booking'),
            onPressed: onManualBooking,
            icon: const Icon(Icons.edit_calendar_rounded, size: 18),
            label: const Text('حجز يدوي',
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
