import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/models/models.dart';

void main() {
  UserProfile profile(Map<String, dynamic> extra) =>
      UserProfile.fromJson({'id': 'u1', ...extra});

  group('UserProfile.isHost (قاعدة المالك الموحّدة للراوتر وحسابي)', () {
    test('مالك: role و is_owner معاً كما تضبطهما become_owner', () {
      expect(profile({'role': 'owner', 'is_owner': true}).isHost, isTrue);
    });

    test('زبون: become_customer تمسح الاثنين', () {
      expect(profile({'role': 'customer', 'is_owner': false}).isHost, isFalse);
    });

    test('أيّ من العلامتين يكفي', () {
      expect(profile({'role': 'owner'}).isHost, isTrue);
      expect(profile({'is_owner': true}).isHost, isTrue);
    });

    test('الأدمن ليس مالكاً تلقائياً', () {
      final p = profile({'role': 'customer', 'is_admin': true});
      expect(p.isAdmin, isTrue);
      expect(p.isHost, isFalse);
    });
  });
}
