import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/relative_time.dart';
import '../../../data/models/booking_period.dart' show stayTypeLabel;
import '../../../data/models/models.dart';

/// ذهبي التقييمات (أهدأ من accent البرتقالي، ومطابق لنجمة أيقونة التطبيق).
const reviewGold = AppColors.accentMuted;

/// "تقييم واحد"، "تقييمان"، "5 تقييمات"، "32 تقييم".
String reviewsCountLabel(int n) {
  if (n == 1) return 'تقييم واحد';
  if (n == 2) return 'تقييمان';
  if (n >= 3 && n <= 10) return '$n تقييمات';
  return '$n تقييم';
}

/// الكلمة تحت نجوم كتابة التقييم (1..5).
String ratingWord(int rating) => const [
      'سيء',
      'مقبول',
      'جيد',
      'جيد جداً',
      'ممتاز',
    ][rating.clamp(1, 5) - 1];

/// نجوم عرض (لا تفاعل) لتقييم عشري: كاملة/نصف/فارغة.
class RatingStars extends StatelessWidget {
  final double rating;
  final double size;

  const RatingStars({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final IconData icon;
        if (rating >= i + 0.75) {
          icon = Icons.star_rounded;
        } else if (rating >= i + 0.25) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: size, color: reviewGold);
      }),
    );
  }
}

/// ظهور تدريجي خفيف (شفافية + إزاحة 8px) مرة واحدة عند البناء.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  const FadeSlideIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)), child: child),
      ),
    );
  }
}

// ═══════════════════════════ الملخص ═══════════════════════════

/// المتوسط الكبير والنجوم والعدد، وبجانبها أشرطة التوزيع 5..1 بالنسبة.
/// للحالة الفارغة استخدم [ReviewsEmptyState] (لا "0.0" ولا أشرطة فارغة).
class ReviewSummaryView extends StatelessWidget {
  final ReviewSummary summary;
  const ReviewSummaryView({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              summary.average.toStringAsFixed(1),
              key: const Key('review_average'),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 40,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal),
            ),
            const SizedBox(height: 4),
            RatingStars(rating: summary.average, size: 16),
            const SizedBox(height: 4),
            Text(
              reviewsCountLabel(summary.count),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: [
              for (final star in const [5, 4, 3, 2, 1])
                _DistributionBar(star: star, share: summary.share(star)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DistributionBar extends StatelessWidget {
  final int star;
  final double share;
  const _DistributionBar({required this.star, required this.share});

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
        fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 12,
              child: Text('$star', textAlign: TextAlign.center, style: label)),
          const Icon(Icons.star_rounded, size: 12, color: reviewGold),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(99),
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: share),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: v,
                  child: Container(
                    decoration: BoxDecoration(
                      color: reviewGold,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text('${(share * 100).round()}%',
                key: Key('review_share_$star'),
                textAlign: TextAlign.end,
                style: label),
          ),
        ],
      ),
    );
  }
}

/// لا تقييمات بعد: دعوة لطيفة بدل "0.0" وأشرطة فارغة.
class ReviewsEmptyState extends StatelessWidget {
  const ReviewsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: reviewGold.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rate_review_outlined,
                color: reviewGold, size: 28),
          ),
          const SizedBox(height: 12),
          const Text('لا توجد تقييمات بعد',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal)),
          const SizedBox(height: 4),
          const Text('كن أول من يقيّم بعد إقامتك',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ═══════════════════════════ بطاقة التقييم ═══════════════════════════

/// ألوان هادئة لدائرة الحرف الأول (خلفية، حرف)، ثابتة لكل مستخدم.
const _avatarTones = [
  (Color(0xFFE9EAE0), AppColors.primary),
  (Color(0xFFF4ECDA), AppColors.accentDark),
  (Color(0xFFDFE7DC), Color(0xFF4F6B4A)),
  (Color(0xFFF1E4DA), Color(0xFF8A5A44)),
];

class ReviewCard extends StatelessWidget {
  final ReviewModel review;

  /// للاختبارات (التاريخ النسبي)؛ الافتراضي الآن.
  final DateTime? now;

  const ReviewCard({super.key, required this.review, this.now});

  @override
  Widget build(BuildContext context) {
    final name = (review.userName ?? '').trim();
    final displayName = name.isEmpty ? 'مستخدم' : name;
    final tone = _avatarTones[review.userId.hashCode.abs() % _avatarTones.length];
    final comment = (review.comment ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: tone.$1,
                child: Text(displayName.characters.first,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: tone.$2)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.charcoal)),
                        ),
                        const SizedBox(width: 8),
                        RatingStars(
                            rating: review.rating.toDouble(), size: 13),
                      ],
                    ),
                    Text(relativeTimeAr(review.createdAt, now: now),
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            color: AppColors.textHint)),
                  ],
                ),
              ),
            ],
          ),
          if (review.stayType != null || review.isVerifiedStay) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (review.stayType != null)
                  _Badge(text: stayTypeLabel(review.stayType!)),
                if (review.isVerifiedStay)
                  const _Badge(text: 'إقامة مؤكدة', verified: true),
              ],
            ),
          ],
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            ExpandableReviewText(text: comment),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final bool verified;
  const _Badge({required this.text, this.verified = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: verified ? AppColors.primaryPale : AppColors.sand,
        borderRadius: BorderRadius.circular(99),
      ),
      // علامة التحقق أيقونة لا حرف "✓": خط Cairo لا يحويه فيظهر مربعاً.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (verified) ...[
            const Icon(Icons.check_rounded, size: 13, color: AppColors.primary),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      verified ? AppColors.primary : AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// نص التقييم: أكثر من [maxLines] يُطوى مع "قراءة المزيد" / "عرض أقل".
class ExpandableReviewText extends StatefulWidget {
  final String text;
  final int maxLines;
  const ExpandableReviewText(
      {super.key, required this.text, this.maxLines = 3});

  @override
  State<ExpandableReviewText> createState() => _ExpandableReviewTextState();
}

class _ExpandableReviewTextState extends State<ExpandableReviewText> {
  bool _expanded = false;

  static const _style = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 14,
      height: 1.7,
      color: Color(0xFF45443A));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: _style),
        maxLines: widget.maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();

      final text = Text(widget.text,
          style: _style,
          maxLines: _expanded || !overflows ? null : widget.maxLines,
          overflow: _expanded || !overflows ? null : TextOverflow.ellipsis);
      if (!overflows) return text;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: AlignmentDirectional.topStart,
            child: text,
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_expanded ? 'عرض أقل' : 'قراءة المزيد',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
          ),
        ],
      );
    });
  }
}

/// هيكل بطاقة تقييم أثناء التحميل.
class ReviewCardSkeleton extends StatelessWidget {
  const ReviewCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(6)),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Shimmer.fromColors(
        baseColor: AppColors.sand,
        highlightColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [bar(110, 12), const SizedBox(height: 6), bar(60, 10)],
              ),
            ]),
            const SizedBox(height: 14),
            bar(double.infinity, 10),
            const SizedBox(height: 8),
            bar(double.infinity, 10),
            const SizedBox(height: 8),
            bar(160, 10),
          ],
        ),
      ),
    );
  }
}
