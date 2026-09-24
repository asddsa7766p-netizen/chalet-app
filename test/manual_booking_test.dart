import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:makan/data/models/manual_booking.dart';
import 'package:makan/data/models/models.dart';
import 'package:makan/presentation/screens/owner/manual_booking_actions.dart';
import 'package:makan/presentation/screens/owner/manual_booking_sheet.dart';

BookingModel _booking({
  String source = 'app',
  String? guestName,
  String? guestPhone,
  String? notes,
  BookingStatus status = BookingStatus.confirmed,
  DateTime? checkOut,
}) =>
    BookingModel(
      id: 'b1',
      chaletId: 'c1',
      userId: 'owner-1',
      checkIn: DateTime(2030, 3, 12),
      checkOut: checkOut ?? DateTime(2030, 3, 14),
      guestsCount: 2,
      totalPrice: 1000,
      status: status,
      notes: notes,
      createdAt: DateTime(2030, 3, 1),
      source: source,
      externalGuestName: guestName,
      externalGuestPhone: guestPhone,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  group('BookingModel والأعمدة الجديدة', () {
    test('fromJson يقرأ source وguest_name وguest_phone', () {
      final b = BookingModel.fromJson({
        'id': 'b1',
        'chalet_id': 'c1',
        'user_id': 'u1',
        'check_in': '2030-03-12',
        'check_out': '2030-03-14',
        'created_at': '2030-03-01T00:00:00Z',
        'source': 'external',
        'guest_name': 'أبو أحمد',
        'guest_phone': '0599123456',
        'notes': 'سرير أطفال',
        'profiles': {'full_name': 'صاحب الحساب', 'phone': '000'},
      });
      expect(b.source, 'external');
      expect(b.externalGuestName, 'أبو أحمد');
      expect(b.externalGuestPhone, '0599123456');
      // بيانات ملف صاحب الحساب تبقى منفصلة عن ضيف الحجز اليدوي.
      expect(b.guestName, 'صاحب الحساب');
    });

    test('بدون الأعمدة: الافتراضي حجز تطبيق', () {
      final b = BookingModel.fromJson({
        'id': 'b1',
        'chalet_id': 'c1',
        'user_id': 'u1',
        'check_in': '2030-03-12',
        'check_out': '2030-03-14',
        'created_at': '2030-03-01T00:00:00Z',
      });
      expect(b.source, 'app');
      expect(b.isManual, isFalse);
    });
  });

  group('isManual و manualGuest (من الأعمدة)', () {
    test('اليدوي هو source == external فقط', () {
      expect(_booking(source: 'external').isManual, isTrue);
      expect(_booking(source: 'app').isManual, isFalse);
    });

    test('الضيف من العمودين والملاحظة من notes فقط', () {
      final g = _booking(
        source: 'external',
        guestName: ' سامي ',
        guestPhone: '0568000000',
        notes: 'يحتاج سرير أطفال',
      ).manualGuest;
      expect(g.name, 'سامي');
      expect(g.phone, '0568000000');
      expect(g.note, 'يحتاج سرير أطفال');
    });

    test('القيم الفارغة تصبح null', () {
      final g = _booking(
              source: 'external', guestName: '  ', guestPhone: '', notes: ' ')
          .manualGuest;
      expect(g.name, isNull);
      expect(g.phone, isNull);
      expect(g.note, isNull);
    });
  });

  group('canCancelManualBooking', () {
    final now = DateTime(2030, 3, 10);

    test('يدوي فعّال لم تنتهِ مغادرته', () {
      expect(canCancelManualBooking(_booking(source: 'external'), now: now),
          isTrue);
      expect(
          canCancelManualBooking(
              _booking(source: 'external', status: BookingStatus.pending),
              now: now),
          isTrue);
    });

    test('غير اليدوي أو الملغى أو المنتهي: لا', () {
      expect(canCancelManualBooking(_booking(source: 'app'), now: now), isFalse);
      expect(
          canCancelManualBooking(
              _booking(source: 'external', status: BookingStatus.cancelled),
              now: now),
          isFalse);
      expect(
          canCancelManualBooking(
              _booking(source: 'external', checkOut: DateTime(2030, 3, 9)),
              now: now),
          isFalse);
    });

    testWidgets('نافذة التأكيد: تعرض الاسم والتواريخ، و"تراجع" لا يلغي شيئاً',
        (tester) async {
      final b = _booking(source: 'external', guestName: 'سامي');
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async =>
                  result = await confirmAndCancelManualBooking(context, b),
              child: const Text('cancel'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('cancel'));
      await tester.pumpAndSettle();

      expect(find.text('إلغاء الحجز اليدوي؟'), findsOneWidget);
      expect(find.textContaining('سامي'), findsOneWidget);
      expect(find.textContaining('12/3/2030'), findsOneWidget);

      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('التحقق من المدخلات', () {
    test('الهاتف', () {
      expect(validateManualGuestPhone(''), isNotNull);
      expect(validateManualGuestPhone('123'), isNotNull);
      expect(validateManualGuestPhone('abc12345'), isNotNull);
      expect(validateManualGuestPhone('0599123456'), isNull);
      expect(validateManualGuestPhone('+970 599-123-456'), isNull);
    });

    test('الاسم', () {
      expect(validateManualGuestName(' '), isNotNull);
      expect(validateManualGuestName('س'), isNotNull);
      expect(validateManualGuestName('سامي'), isNull);
    });

    test('السعر: تحويل الأرقام العربية والفاصلة', () {
      expect(parseManualPrice('1500'), 1500);
      expect(parseManualPrice('١٢٣٤'), 1234);
      expect(parseManualPrice('1,5'), 1.5);
      expect(parseManualPrice('١٢،٥'), 12.5);
      expect(parseManualPrice('abc'), isNull);
      expect(parseManualPrice(''), isNull);
    });

    test('السعر: يرفض الفارغ والصفر والسالب (السيرفر يرفض ≤ 0)', () {
      expect(validateManualPrice(''), isNotNull);
      expect(validateManualPrice('abc'), isNotNull);
      expect(validateManualPrice('0'), isNotNull);
      expect(validateManualPrice('-5'), isNotNull);
      expect(validateManualPrice('1200'), isNull);
    });
  });

  group('ورقة الحجز اليدوي (اعتماديات وهمية، بدون قاعدة بيانات)', () {
    final today = DateTime(2030, 3, 10);
    // الليلتان المحجوزتان: 14 و15 مارس.
    final booked = [DateTime(2030, 3, 14), DateTime(2030, 3, 15)];

    late List<ManualBookingRequest> submitted;
    late List<String> bookedLoadedFor;
    late int quoteCalls;
    late bool? sheetResult;

    Future<void> openSheet(
      WidgetTester tester, {
      List<ManualBookingChalet>? chalets,
      double price = 1500,
    }) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      submitted = [];
      bookedLoadedFor = [];
      quoteCalls = 0;
      sheetResult = null;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  sheetResult = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ManualBookingSheet(
                      today: today,
                      chalets: chalets ??
                          const [
                            ManualBookingChalet(
                                id: 'c1', name: 'شاليه الندى', maxGuests: 3),
                          ],
                      loadBookedNights: (id) async {
                        bookedLoadedFor.add(id);
                        return booked;
                      },
                      quotePrice: (id, ci, co) async {
                        quoteCalls++;
                        return price;
                      },
                      submit: (r) async => submitted.add(r),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> pickDates(WidgetTester tester) async {
      await tester.tap(find.text('12'));
      await tester.pump();
      await tester.tap(find.text('13'));
      await tester.pumpAndSettle();
    }

    TextFormField field(WidgetTester tester, int i) =>
        tester.widget<TextFormField>(find.byType(TextFormField).at(i));

    // ترتيب الحقول: 0 السعر، 1 الاسم، 2 الهاتف.
    String priceText(WidgetTester tester) =>
        tester.widget<EditableText>(find.byType(EditableText).at(0)).controller.text;

    testWidgets('شاليه واحد: لا اختيار، والأيام المحجوزة لا تُختار كوصول',
        (tester) async {
      await openSheet(tester);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('شاليه الندى'), findsOneWidget);
      expect(bookedLoadedFor, ['c1']);

      await tester.tap(find.text('14'));
      await tester.pump();
      expect(find.text('هذا اليوم محجوز'), findsOneWidget);
      expect(quoteCalls, 0);
    });

    testWidgets('فترة تتضمن أياماً محجوزة تُرفض، والمغادرة على ليلة محجوزة تجوز',
        (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('12'));
      await tester.pump();
      expect(find.textContaining('اختر يوم المغادرة'), findsOneWidget);

      await tester.tap(find.text('16'));
      await tester.pump();
      expect(find.text('الفترة المختارة تتضمن أياماً محجوزة'), findsOneWidget);
      expect(quoteCalls, 0);

      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 ليالٍ'), findsOneWidget);
      expect(quoteCalls, 1);
      // سعر التقويم يُعرض كمقترح ويملأ الحقل مبدئياً.
      expect(find.text('سعر التقويم: ₪1500'), findsOneWidget);
      expect(priceText(tester), '1500');
    });

    testWidgets('الحفظ يرسل الاسم والهاتف والضيوف والسعر ويُغلق الورقة',
        (tester) async {
      await openSheet(tester);
      await pickDates(tester);

      // بدون اسم وهاتف: التحقق يمنع الإرسال (السعر مملوء من التقويم).
      await tester.tap(find.text('حجز التواريخ'));
      await tester.pump();
      expect(find.text('اسم الضيف مطلوب'), findsOneWidget);
      expect(find.text('رقم الهاتف مطلوب'), findsOneWidget);
      expect(submitted, isEmpty);

      await tester.enterText(find.byType(TextFormField).at(1), 'أبو أحمد');
      await tester.enterText(find.byType(TextFormField).at(2), '0599123456');
      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
      await tester.pump();

      await tester.tap(find.text('حجز التواريخ'));
      await tester.pumpAndSettle();

      expect(submitted, hasLength(1));
      final r = submitted.single;
      expect(r.chaletId, 'c1');
      expect(r.checkIn, DateTime(2030, 3, 12));
      expect(r.checkOut, DateTime(2030, 3, 13));
      expect(r.guestsCount, 2);
      expect(r.guestName, 'أبو أحمد');
      expect(r.guestPhone, '0599123456');
      expect(r.notes, isNull);
      expect(r.totalPrice, 1500);
      expect(sheetResult, isTrue);
    });

    testWidgets('المالك يكتب سعره المتفق عليه، ويستعيد سعر التقويم بنقرة',
        (tester) async {
      await openSheet(tester);
      await pickDates(tester);

      expect(find.text('استعادة سعر التقويم'), findsNothing);

      await tester.enterText(find.byType(TextFormField).at(0), '1200');
      await tester.pump();
      expect(find.text('استعادة سعر التقويم'), findsOneWidget);

      await tester.tap(find.text('استعادة سعر التقويم'));
      await tester.pump();
      expect(priceText(tester), '1500');
      expect(find.text('استعادة سعر التقويم'), findsNothing);

      await tester.enterText(find.byType(TextFormField).at(0), '1200');
      await tester.enterText(find.byType(TextFormField).at(1), 'سامي');
      await tester.enterText(find.byType(TextFormField).at(2), '0599123456');
      await tester.tap(find.text('حجز التواريخ'));
      await tester.pumpAndSettle();

      expect(submitted.single.totalPrice, 1200);
    });

    testWidgets('سعر مكتوب بيد المالك لا يُستبدل عند تغيير التواريخ',
        (tester) async {
      await openSheet(tester);
      await pickDates(tester);

      await tester.enterText(find.byType(TextFormField).at(0), '900');
      await tester.pump();

      // غيّر التواريخ: وصول جديد ثم مغادرة.
      await tester.tap(find.text('17'));
      await tester.pump();
      await tester.tap(find.text('19'));
      await tester.pumpAndSettle();

      expect(quoteCalls, 2);
      expect(priceText(tester), '900');
      expect(find.text('استعادة سعر التقويم'), findsOneWidget);
    });

    testWidgets('عدد الضيوف لا يتجاوز سعة الشاليه', (tester) async {
      await openSheet(tester);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
        await tester.pump();
      }
      final text =
          tester.widget<Text>(find.byKey(const Key('manual_guests_count')));
      expect(text.data, '3');
    });

    testWidgets('لا سعر مقترح: الحقل فارغ ويجب أن يكتب المالك سعراً > 0',
        (tester) async {
      await openSheet(tester, price: 0);
      await pickDates(tester);

      expect(find.textContaining('لا يوجد سعر مقترح'), findsOneWidget);
      expect(priceText(tester), '');

      await tester.enterText(find.byType(TextFormField).at(1), 'سامي');
      await tester.enterText(find.byType(TextFormField).at(2), '0599123456');
      await tester.tap(find.text('حجز التواريخ'));
      await tester.pump();
      expect(find.text('اكتب السعر المتفق عليه'), findsOneWidget);
      expect(submitted, isEmpty);

      await tester.enterText(find.byType(TextFormField).at(0), '0');
      await tester.tap(find.text('حجز التواريخ'));
      await tester.pump();
      expect(find.text('السعر يجب أن يكون أكبر من صفر'), findsOneWidget);
      expect(submitted, isEmpty);

      await tester.enterText(find.byType(TextFormField).at(0), '850');
      await tester.tap(find.text('حجز التواريخ'));
      await tester.pumpAndSettle();
      expect(submitted.single.totalPrice, 850);
    });

    testWidgets('لا تنبيه "لا يمكن الإلغاء" بعد توفر دالة الإلغاء',
        (tester) async {
      await openSheet(tester);
      expect(find.textContaining('لا يمكن إلغاء'), findsNothing);
      expect(field(tester, 0), isNotNull);
    });

    testWidgets('يفتح بشاليه ووصول محدّدين مسبقاً (من يوم بالتقويم)', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final asked = <String>[];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ManualBookingSheet(
            today: today,
            initialChaletId: 'c2',
            initialCheckIn: DateTime(2030, 3, 12),
            chalets: const [
              ManualBookingChalet(id: 'c1', name: 'الأول'),
              ManualBookingChalet(id: 'c2', name: 'الثاني'),
            ],
            loadBookedNights: (id) async {
              asked.add(id);
              return booked;
            },
            quotePrice: (id, ci, co) async => 1500,
            submit: (r) async {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // الشاليه المحدد هو المحمَّل، وتاريخ الوصول محدد فالمطلوب المغادرة.
      expect(asked, ['c2']);
      expect(find.textContaining('اختر يوم المغادرة'), findsOneWidget);
    });

    testWidgets('وصول محدد مسبقاً صار غير متاح: يُهمل ويختار المالك من جديد',
        (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ManualBookingSheet(
            today: today,
            initialCheckIn: DateTime(2030, 3, 14), // ليلة محجوزة/محجوبة
            chalets: const [ManualBookingChalet(id: 'c1', name: 'الأول')],
            loadBookedNights: (id) async => booked,
            quotePrice: (id, ci, co) async => 1500,
            submit: (r) async {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('اختر يوم المغادرة'), findsNothing);
    });

    testWidgets('وصول ماضٍ لا يُطبَّق', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ManualBookingSheet(
            today: today,
            initialCheckIn: DateTime(2030, 3, 2),
            chalets: const [ManualBookingChalet(id: 'c1', name: 'الأول')],
            loadBookedNights: (id) async => booked,
            quotePrice: (id, ci, co) async => 1500,
            submit: (r) async {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('اختر يوم المغادرة'), findsNothing);
    });

    testWidgets('عدة شاليهات: اختيار الشاليه يعيد تحميل الأيام المحجوزة',
        (tester) async {
      await openSheet(tester, chalets: const [
        ManualBookingChalet(id: 'c1', name: 'الأول'),
        ManualBookingChalet(id: 'c2', name: 'الثاني'),
      ]);
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      expect(bookedLoadedFor, ['c1']);

      await tester.tap(find.text('الثاني'));
      await tester.pumpAndSettle();
      expect(bookedLoadedFor, ['c1', 'c2']);
    });
  });
}
