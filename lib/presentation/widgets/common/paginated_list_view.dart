import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// PERF-02: Widget عام لعرض قوائم مع Lazy Loading تلقائي
///
/// الاستخدام:
/// ```dart
/// PaginatedListView<ReviewModel>(
///   fetcher: (offset, limit) => ReviewService.instance.getReviews(
///     chaletId: chaletId, offset: offset, limit: limit,
///   ),
///   itemBuilder: (context, review) => ReviewCard(review: review),
///   emptyMessage: 'لا توجد تقييمات بعد',
/// )
/// ```
class PaginatedListView<T> extends StatefulWidget {
  /// دالة الجلب — تستقبل offset و limit وترجع List<T>
  final Future<List<T>> Function(int offset, int limit) fetcher;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;
  final int pageSize;
  final Widget? separator;

  const PaginatedListView({
    super.key,
    required this.fetcher,
    required this.itemBuilder,
    this.emptyMessage = 'لا توجد بيانات',
    this.pageSize = 10,
    this.separator,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final List<T> _items = [];
  final ScrollController _scrollCtrl = ScrollController();

  bool _loadingFirst = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFirst();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loadingFirst = true;
      _error = null;
      _items.clear();
      _hasMore = true;
    });
    try {
      final results = await widget.fetcher(0, widget.pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(results);
        _hasMore = results.length == widget.pageSize;
        _loadingFirst = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFirst = false;
        _error = 'تعذر التحميل، اسحب للأسفل للمحاولة';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loadingFirst) return;
    setState(() => _loadingMore = true);
    try {
      final results = await widget.fetcher(_items.length, widget.pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(results);
        _hasMore = results.length == widget.pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFirst) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _loadFirst,
        color: AppColors.primary,
        child: ListView(children: [
          const SizedBox(height: 100),
          Center(
              child: Text(_error!,
                  style: const TextStyle(
                      fontFamily: 'Cairo', color: AppColors.textSecondary))),
        ]),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFirst,
        color: AppColors.primary,
        child: ListView(children: [
          const SizedBox(height: 120),
          const Icon(Icons.inbox_rounded, size: 52, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Center(
              child: Text(widget.emptyMessage,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary))),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFirst,
      color: AppColors.primary,
      child: ListView.separated(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            widget.separator ?? const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
            );
          }
          return widget.itemBuilder(context, _items[i]);
        },
      ),
    );
  }
}
