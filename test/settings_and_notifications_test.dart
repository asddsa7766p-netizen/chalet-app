import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/core/settings/locale_notifier.dart';
import 'package:makan/core/theme/theme_notifier.dart';
import 'package:makan/data/models/notification_model.dart';
import 'package:makan/presentation/screens/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NotificationModel (النموذج الوحيد)', () {
    test('يقرأ أعمدة الجدول ويتحمّل body/type الفارغين', () {
      final n = NotificationModel.fromJson({
        'id': 'n1',
        'user_id': 'u1',
        'title': 'حجز جديد',
        'body': null,
        'type': null,
        'is_read': null,
        'created_at': '2030-03-10T08:00:00Z',
      });
      expect(n.title, 'حجز جديد');
      expect(n.body, isNull);
      expect(n.isRead, isFalse);
      expect(n.createdAt, DateTime.utc(2030, 3, 10, 8));
    });

    test('copyWith يغيّر حالة القراءة فقط', () {
      final n = NotificationModel(
          id: 'n1', userId: 'u1', title: 't', createdAt: DateTime(2030));
      final read = n.copyWith(isRead: true);
      expect(read.isRead, isTrue);
      expect(read.id, 'n1');
      expect(read.title, 't');
    });
  });

  testWidgets(
      'الإعدادات: لا خيار لغة ولا وضع مظلم (غير مدعومين)، ولا عملة ولا مفتاح إشعارات وهمي',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('اللغة'), findsNothing);
    expect(find.text('English'), findsNothing);
    expect(find.text('الوضع المظلم'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('العملة'), findsNothing);
    expect(find.textContaining('شيكل'), findsNothing);
  });

  test('تفضيل English/الوضع المظلم المحفوظ سابقاً يُتجاهل: عربي وفاتح دائماً',
      () async {
    SharedPreferences.setMockInitialValues({
      LocaleNotifier.kLanguageKey: 'en',
      ThemeNotifier.kDarkModeKey: true,
    });
    final locale = LocaleNotifier();
    final theme = ThemeNotifier();
    await locale.loadFromPrefs();
    await theme.loadFromPrefs();
    expect(locale.locale.languageCode, 'ar');
    expect(theme.themeMode, ThemeMode.light);
  });
}
