import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/error_reporter.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/paged_list.dart';
import '../../widgets/reviews/review_widgets.dart';
import '../../widgets/reviews/write_review_sheet.dart';

/// مصادر بيانات شاشة التقييمات (قابلة للحقن بالاختبارات).
class ReviewsScreenSource {
  final Future<ReviewSummary> Function(String chaletId) summary;
  final Future<List<ReviewModel>> Function(
      String chaletId, ReviewSort sort, int page) page;
  final Future<BookingModel?> Function(String chaletId) awaitingReview;

  const ReviewsScreenSource({
    required this.summary,
    required this.page,
    required this.awaitingReview,
  });

  static ReviewsScreenSource get live => ReviewsScreenSource(
        summary: ReviewsService.instance.getChaletReviewSummary,
        page: (id, sort, page) => ReviewsService.instance
            .getChaletReviewsPage(id, sort: sort, page: page),
        awaitingReview: (id) =>
            ReviewsService.instance.latestBookingAwaitingReview(chaletId: id),
      );
}

/// كل تقييمات شاليه: الملخص، ترتيب (الأحدث/الأعلى/الأدنى)، وتحميل تدريجي
/// بصفحات من [ReviewsService.reviewsPageSize] عند الاقتراب من نهاية القائمة.
class ReviewsScreen extends StatefulWidget {
  final String chaletId;
  final String chaletName;
  final ReviewsScreenSource? source;

  const ReviewsScreen({
    super.key,
    required this.chaletId,
    required this.chaletName,
    this.source,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late final _src = widget.source ?? ReviewsScreenSource.live;
  final _scroll = ScrollController();

  ReviewSummary? _summary;
  bool _summaryFailed = false;

  ReviewSort _sort = ReviewSort.newest;
  late final _pager = PagedList<ReviewModel>(
    (page) => _src.page(widget.chaletId, _sort, page),
    pageSize: ReviewsService.reviewsPageSize,
  );
  bool _listLoading = true;
  bool _listFailed = false;

  /// إقامة مكتملة للمستخدم بهذا الشاليه لم يقيّمها بعد (زر "قيّم إقامتك").
  BookingModel? _awaiting;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadAll();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadSummary(), _loadList(), _loadAwaiting()]);
  }

  Future<void> _loadSummary() async {
    setState(() {
      _summary = null;
      _summaryFailed = false;
    });
    try {
      final s = await _src.summary(widget.chaletId);
      if (mounted) setState(() => _summary = s);
    } catch (e, st) {
      reportError(e, st, context: 'reviews.summary');
      if (mounted) setState(() => _summaryFailed = true);
    }
  }

  Future<void> _loadList() async {
    setState(() {
      _listLoading = true;
      _listFailed = false;
    });
    try {
      if (!await _pager.reset()) return;
      if (mounted) setState(() => _listLoading = false);
    } catch (e, st) {
      reportError(e, st, context: 'reviews.page');
      if (mounted) {
        setState(() {
          _listLoading = false;
          _listFailed = true;
        });
      }
    }
  }

  Future<void> _loadAwaiting() async {
    try {
      final b = await _src.awaitingReview(widget.chaletId);
      if (mounted) setState(() => _awaiting = b);
    } catch (e, st) {
      // ثانوي: بدونه يختفي زر "قيّم إقامتك" فقط.
      reportError(e, st, context: 'reviews.awaiting');
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients || _listLoading || _listFailed) return;
    if (_scroll.position.extentAfter < 400) _loadMore();
  }

  Future<void> _loadMore() async {
    if (!_pager.hasMore || _pager.loadingMore) return;
    setState(() {});
    try {
      await _pager.loadMore();
    } catch (e, st) {
      reportError(e, st, context: 'reviews.load_more');
    }
    if (mounted) setState(() {});
  }

  void _setSort(ReviewSort sort) {
    if (sort == _sort) return;
    _sort = sort;
    _loadList();
  }

  Future<void> _writeReview() async {
    final booking = _awaiting;
    if (booking == null) return;
    final sent = await showWriteReviewSheet(context, booking: booking);
    if (sent && mounted) {
      setState(() => _awaiting = null);
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.chaletName.isEmpty ? 'التقييمات' : 'تقييمات ${widget.chaletName}';
    final summary = _summary;
    final hasReviews = summary != null && !summary.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: AppColors.primary,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(child: _summaryCard()),
            ),
            if (_awaiting != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(child: _writeReviewCta()),
              ),
            if (hasReviews) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                sliver: SliverToBoxAdapter(child: _sortChips()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: _list(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final summary = _summary;
    final Widget child;
    if (_summaryFailed) {
      child = _error('تعذر تحميل التقييمات', _loadAll);
    } else if (summary == null) {
      child = const ReviewCardSkeleton();
    } else if (summary.isEmpty) {
      child = const ReviewsEmptyState();
    } else {
      child = Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: ReviewSummaryView(summary: summary),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey(_summaryFailed
            ? 'failed'
            : summary == null
                ? 'loading'
                : 'loaded'),
        child: child,
      ),
    );
  }

  Widget _writeReviewCta() {
    return FadeSlideIn(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: reviewGold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: reviewGold.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: reviewGold),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('أقمت هنا مؤخراً، شاركنا رأيك',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal)),
            ),
            TextButton(
              key: const Key('reviews_write_cta'),
              onPressed: _writeReview,
              child: const Text('قيّم إقامتك',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in ReviewSort.values)
          GestureDetector(
            key: Key('review_sort_${s.name}'),
            onTap: () => _setSort(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: s == _sort ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                    color: s == _sort ? AppColors.primary : AppColors.border),
              ),
              child: Text(s.label,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: s == _sort ? Colors.white : AppColors.textSecondary)),
            ),
          ),
      ],
    );
  }

  Widget _list() {
    if (_listFailed) {
      return SliverToBoxAdapter(
          child: _error('تعذر تحميل التقييمات', _loadList));
    }
    if (_listLoading) {
      return SliverList.separated(
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const ReviewCardSkeleton(),
      );
    }
    final items = _pager.items;
    // صفحة جديدة قيد التحميل: هيكلان في الأسفل.
    final extra = _pager.loadingMore ? 2 : 0;
    return SliverList.separated(
      itemCount: items.length + extra,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => i < items.length
          ? FadeSlideIn(
              key: ValueKey(items[i].id), child: ReviewCard(review: items[i]))
          : const ReviewCardSkeleton(),
    );
  }

  Widget _error(String text, VoidCallback retry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(text,
              style: const TextStyle(
                  fontFamily: 'Cairo', color: AppColors.textSecondary)),
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}
