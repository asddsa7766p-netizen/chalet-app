import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:makan/presentation/widgets/common/paged_list.dart';

void main() {
  group('PagedList', () {
    test('يجلب الصفحة الأولى ثم يضيف التالية ما دامت ممتلئة', () async {
      final pages = {
        0: [1, 2],
        1: [3, 4],
        2: [5],
      };
      final pager = PagedList<int>((p) async => pages[p]!, pageSize: 2);

      expect(await pager.reset(), isTrue);
      expect(pager.items, [1, 2]);
      expect(pager.hasMore, isTrue);

      await pager.loadMore();
      expect(pager.items, [1, 2, 3, 4]);
      expect(pager.hasMore, isTrue);

      await pager.loadMore();
      expect(pager.items, [1, 2, 3, 4, 5]);
      expect(pager.hasMore, isFalse, reason: 'صفحة ناقصة = لا مزيد');

      await pager.loadMore(); // لا طلب إضافي
      expect(pager.items, [1, 2, 3, 4, 5]);
    });

    test('reset أحدث يُهمل نتيجة الطلب الأقدم', () async {
      final slow = Completer<List<int>>();
      var call = 0;
      final pager = PagedList<int>((p) {
        call++;
        return call == 1 ? slow.future : Future.value([9]);
      }, pageSize: 10);

      final first = pager.reset();
      expect(await pager.reset(), isTrue);
      slow.complete([1]);
      expect(await first, isFalse);
      expect(pager.items, [9]);
    });

    test('loadMore متأخر بعد reset لا يلوّث القائمة الجديدة', () async {
      final slowPage1 = Completer<List<int>>();
      final pager = PagedList<int>((p) {
        if (p == 1) return slowPage1.future;
        return Future.value([1, 2]);
      }, pageSize: 2);

      await pager.reset();
      final more = pager.loadMore();
      await pager.reset();
      slowPage1.complete([3, 4]);
      await more;
      expect(pager.items, [1, 2]);
      expect(pager.loadingMore, isFalse);
    });
  });
}
