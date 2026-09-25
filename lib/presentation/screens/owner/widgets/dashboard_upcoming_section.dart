part of '../owner_dashboard_screen.dart';

extension _DashboardUpcomingSection on _OwnerDashboardScreenState {
  // ─── الحجوزات القادمة ────────────────────────────────────
  // ✅ إصلاح: كانت بطاقة CTA ثابتة لا تعرض أي حجز فعلي. الآن تعرض حتى 3
  // حجوزات قادمة حقيقية (من نفس getIncomingBookings() المستخدمة أصلًا
  // بشاشة "إدارة الحجوزات")، مع حالة فارغة صادقة إن لم توجد.
  Widget _buildUpcomingBookings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_upcomingBookings.isNotEmpty)
              GestureDetector(
                onTap: () => context.go('/owner-bookings'),
                child: const Row(
                  children: [
                    Text('عرض الكل',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    Icon(Icons.chevron_left,
                        size: 16, color: AppColors.primary),
                  ],
                ),
              )
            else
              const SizedBox.shrink(),
            const Text('الحجوزات القادمة',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal)),
          ],
        ),
        const SizedBox(height: 12),
        if (_upcomingBookings.isEmpty)
          GestureDetector(
            onTap: () => context.go('/owner-bookings'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.sand),
              ),
              child: Column(
                children: [
                  const Icon(Icons.event_note_outlined,
                      size: 32, color: AppColors.textHint),
                  const SizedBox(height: 8),
                  Text(
                      _upcomingFailed
                          ? 'تعذر تحميل الحجوزات القادمة'
                          : 'لا توجد حجوزات قادمة حالياً',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('عرض سجل الحجوزات',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      Icon(Icons.chevron_left,
                          size: 18, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              for (final b in _upcomingBookings) ...[
                _upcomingBookingTile(b),
                const SizedBox(height: 10),
              ],
            ],
          ),
      ],
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

  Widget _upcomingBookingTile(BookingModel b) {
    final statusColor = _statusColor(b.status);
    return GestureDetector(
      onTap: () => context.go('/owner-bookings'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.sand),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primary.withValues(alpha: 0.08),
                image: (b.chaletImage != null && b.chaletImage!.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(b.chaletImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (b.chaletImage == null || b.chaletImage!.isEmpty)
                  ? const Icon(Icons.home_work_rounded,
                      color: AppColors.primary, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.charcoal),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${b.displayGuestName ?? 'ضيف'} · '
                    '${b.isMultiDay ? b.dateLabel : arabicDayLabel(b.checkIn, withYear: false)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AppColors.textSecondary),
                  ),
                  Text(
                    b.periodWithTime,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary),
                  ),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(b.status.arabicLabel,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: statusColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
