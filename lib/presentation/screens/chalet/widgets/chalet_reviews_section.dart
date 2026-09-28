part of '../chalet_detail_screen.dart';

extension _ChaletReviewsSection on _ChaletDetailScreenState {
  /// الملخص (أو الحالة الفارغة) وأحدث تقييمين، و"عرض الكل" لشاشة التقييمات.
  Widget _buildReviews() {
    final summary = _reviewSummary;
    final Widget body;
    if (_reviewsFailed) {
      body = _reviewsError();
    } else if (summary == null) {
      body = const ReviewCardSkeleton();
    } else if (summary.isEmpty) {
      body = const ReviewsEmptyState();
    } else {
      body = Column(
        children: [
          ReviewSummaryView(summary: summary),
          for (final r in _reviews) ...[
            const SizedBox(height: 12),
            ReviewCard(review: r),
          ],
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(AppStrings.reviews,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal)),
              ),
              if (summary != null && !summary.isEmpty)
                TextButton(
                  onPressed: _openAllReviews,
                  child: Text('عرض الكل (${summary.count})',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(
              key: ValueKey(_reviewsFailed
                  ? 'failed'
                  : summary == null
                      ? 'loading'
                      : 'loaded'),
              child: body,
            ),
          ),
        ],
      ),
    );
  }

  void _openAllReviews() {
    if (!requireAuth(
        context,
        PendingAuthAction('open_reviews',
            {'chaletId': widget.chaletId, 'chaletName': _chalet?.name ?? ''}))) {
      return;
    }
    context.push('/home/reviews/${widget.chaletId}', extra: _chalet?.name);
  }

  Widget _reviewsError() {
    return Column(
      children: [
        const Text('تعذر تحميل التقييمات',
            style: TextStyle(
                fontFamily: 'Cairo', color: AppColors.textSecondary)),
        TextButton.icon(
          onPressed: _loadReviews,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة',
              style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}
