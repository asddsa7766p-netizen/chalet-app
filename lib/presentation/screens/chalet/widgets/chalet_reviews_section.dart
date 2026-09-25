part of '../chalet_detail_screen.dart';

extension _ChaletReviewsSection on _ChaletDetailScreenState {
  // تقييمات الضيوف — إضافة توزيع النجوم (5★...1★) زي الصورة المرجعية
  Widget _buildReviews() {
    // حساب توزيع التقييمات من قائمة المراجعات الفعلية
    final distribution = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _reviews) {
      final rounded = r.rating.round().clamp(1, 5);
      distribution[rounded] = (distribution[rounded] ?? 0) + 1;
    }
    final maxCount = distribution.values.isEmpty
        ? 1
        : distribution.values.reduce((a, b) => a > b ? a : b).clamp(1, 999999);

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(AppStrings.reviews,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal)),
              TextButton(
                onPressed: () {
                  if (!requireAuth(
                      context,
                      PendingAuthAction('open_reviews', {
                        'chaletId': widget.chaletId,
                        'chaletName': _chalet?.name ?? ''
                      }))) {
                    return;
                  }
                  context.push('/home/reviews/${widget.chaletId}',
                      extra: _chalet?.name);
                },
                child: const Text('عرض الكل',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_chalet != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Text(_chalet!.rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: AppColors.charcoal)),
                    Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                            5,
                            (i) => Icon(
                                i < _chalet!.rating.round()
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: AppColors.accent,
                                size: 16))),
                    Text('${_chalet!.reviewsCount} تقييم',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [5, 4, 3, 2, 1]
                        .map((star) =>
                            _ratingBar(star, distribution[star] ?? 0, maxCount))
                        .toList(),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),
          if (_reviews.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا يوجد تقييمات بعد',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: AppColors.textHint)),
            ))
          else
            ...(_reviews.take(2).map((r) => _ReviewItem(review: r))),
        ],
      ),
    );
  }

  Widget _ratingBar(int star, int count, int maxCount) {
    final ratio = maxCount == 0 ? 0.0 : count / maxCount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$star',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: AppColors.textSecondary)),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, size: 12, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: AppColors.sand,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 18,
            child: Text('$count',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
