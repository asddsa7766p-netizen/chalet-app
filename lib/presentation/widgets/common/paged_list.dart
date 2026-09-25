import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// قائمة مرقّمة بالصفحات: الصفحة الأولى عند [reset]، والتالية بـ [loadMore]
/// ما دامت آخر صفحة ممتلئة. عدّاد جيل يُهمل نتيجة طلب سبقه طلب أحدث.
class PagedList<T> {
  PagedList(this._fetch, {required this.pageSize});

  final Future<List<T>> Function(int page) _fetch;
  final int pageSize;

  List<T> items = [];
  bool hasMore = false;
  bool loadingMore = false;
  int _page = 0;
  int _gen = 0;

  /// يرجع false إن سُبق بطلب أحدث (نتيجته تُهمل).
  Future<bool> reset() async {
    final gen = ++_gen;
    final first = await _fetch(0);
    if (gen != _gen) return false;
    _page = 0;
    items = first;
    hasMore = first.length == pageSize;
    loadingMore = false;
    return true;
  }

  Future<void> loadMore() async {
    if (!hasMore || loadingMore) return;
    final gen = _gen;
    loadingMore = true;
    try {
      final next = await _fetch(_page + 1);
      if (gen != _gen) return;
      _page++;
      items = [...items, ...next];
      hasMore = next.length == pageSize;
    } finally {
      if (gen == _gen) loadingMore = false;
    }
  }
}

/// زر "تحميل المزيد" أسفل قائمة [PagedList] (لا شيء إن لم تبقَ صفحات).
class LoadMoreFooter extends StatelessWidget {
  final PagedList<Object?> pager;
  final VoidCallback onLoadMore;

  const LoadMoreFooter({
    super.key,
    required this.pager,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (!pager.hasMore) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: pager.loadingMore
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary))
            : TextButton(
                key: const Key('load_more'),
                onPressed: onLoadMore,
                child: const Text('تحميل المزيد',
                    style: TextStyle(
                        fontFamily: 'Cairo', color: AppColors.primary))),
      ),
    );
  }
}
