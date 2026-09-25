import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/common_widgets.dart';

// ============================================
// FAVORITES SCREEN
// ============================================
class ReviewsScreen extends StatefulWidget {
  final String chaletId;
  final String chaletName;
  const ReviewsScreen(
      {super.key, required this.chaletId, required this.chaletName});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<ReviewModel> _reviews = [];
  bool _loading = true;
  bool _loadError = false;
  int _myRating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final reviews =
          await ReviewsService.instance.getChaletReviews(widget.chaletId);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = true;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_myRating == 0 || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ReviewsService.instance.addReview(
        chaletId: widget.chaletId,
        rating: _myRating,
        comment: _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
      );
      if (!mounted) return;
      _commentCtrl.clear();
      setState(() {
        _myRating = 0;
        _submitting = false;
      });
      _load();
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        final msg = _ is Exception ? _.toString() : 'error';
        if (msg.contains('already_reviewed')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('لقد قمت بتقييم إقامتك السابقة في هذا الشاليه'),
            backgroundColor: AppColors.primary,
          ));
        } else if (msg.contains('not_eligible_review')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('لا يمكنك إضافة تقييم قبل إكمال حجز'),
            backgroundColor: AppColors.primary,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('حدث خطأ أثناء إضافة التقييم'),
            backgroundColor: AppColors.error,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avg = _reviews.isEmpty
        ? 0.0
        : _reviews.map((r) => r.rating).reduce((a, b) => a + b) /
            _reviews.length;

    return Scaffold(
      appBar: AppBar(title: Text('تقييمات ${widget.chaletName}')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  color: AppColors.white,
                  child: Row(
                    children: [
                      Column(children: [
                        Text(avg.toStringAsFixed(1),
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: AppColors.charcoal)),
                        Row(
                            children: List.generate(
                                5,
                                (i) => Icon(
                                    i < avg.round()
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: AppColors.accent,
                                    size: 18))),
                        Text('${_reviews.length} تقييم',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ]),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: List.generate(5, (i) {
                            final star = 5 - i;
                            final count =
                                _reviews.where((r) => r.rating == star).length;
                            final pct = _reviews.isEmpty
                                ? 0.0
                                : count / _reviews.length;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                Text('$star',
                                    style: const TextStyle(
                                        fontFamily: 'Cairo', fontSize: 11)),
                                const Icon(Icons.star_rounded,
                                    size: 11, color: AppColors.accent),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: pct,
                                          backgroundColor: AppColors.sand,
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                                  AppColors.accent),
                                          minHeight: 6,
                                        ))),
                                const SizedBox(width: 6),
                                SizedBox(
                                    width: 20,
                                    child: Text('$count',
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 11,
                                            color: AppColors.textSecondary))),
                              ]),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildAddReview(),
                const Divider(height: 1),
                Expanded(
                  child: _loadError
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('تعذر تحميل التقييمات',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('إعادة المحاولة',
                                    style: TextStyle(fontFamily: 'Cairo')),
                              ),
                            ],
                          ),
                        )
                      : _reviews.isEmpty
                          ? const Center(
                              child: Text('لا توجد تقييمات بعد',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: AppColors.textHint)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _reviews.length,
                              itemBuilder: (_, i) =>
                                  _ReviewTile(review: _reviews[i]),
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildAddReview() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AppStrings.addReview,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
                5,
                (i) => GestureDetector(
                      onTap: () => setState(() => _myRating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                            i < _myRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: AppColors.accent,
                            size: 32),
                      ),
                    )),
          ),
          const SizedBox(height: 10),
          CustomTextField(
              controller: _commentCtrl,
              label: '',
              hint: AppStrings.yourReview,
              maxLines: 2),
          const SizedBox(height: 10),
          AppButton(
            label: AppStrings.submitReview,
            onPressed: _myRating > 0 ? _submit : null,
            loading: _submitting,
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ReviewModel review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryPale,
            backgroundImage: review.userAvatar != null
                ? NetworkImage(review.userAvatar!)
                : null,
            child: review.userAvatar == null
                ? Text(
                    // ✅ إصلاح: characters.first كان يرمي StateError لو الاسم
                    // نصاً فاضياً '' (نفس الحماية الموجودة أصلاً بصفحة الشاليه).
                    (review.userName != null &&
                            review.userName!.trim().isNotEmpty)
                        ? review.userName!.trim().characters.first
                        : 'م',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.sand),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(review.userName ?? 'مستخدم',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      Row(
                          children: List.generate(
                              5,
                              (i) => Icon(
                                  i < review.rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: AppColors.accent,
                                  size: 12))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (review.comment != null)
                    Text(review.comment!,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.6)),
                  const SizedBox(height: 4),
                  Text(
                      '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: AppColors.textHint)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
