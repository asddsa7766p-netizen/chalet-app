import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:makan/core/utils/support_contact.dart';
import 'package:makan/data/models/booking_payment_details.dart';
import 'package:makan/data/models/chalet_model.dart';
import 'package:makan/presentation/screens/payment/payment_flow_entry.dart';
import 'package:makan/presentation/screens/payment/payment_review_screen.dart';
import 'package:makan/presentation/screens/settings/help_support_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  test('إجمالي الدفع = سعر السيرفر للفترة فقط (لا عمولة 5% وهمية)', () {
    final details = BookingPaymentDetails(
      bookingId: 'x',
      chaletName: 'ن',
      chaletLocation: '',
      chaletImageUrl: '',
      checkIn: DateTime(2030, 3, 12),
      checkOut: DateTime(2030, 3, 13),
      guestsCount: 2,
      periodLabel: 'إقامة صباحية',
      subtotal: 450,
    );
    expect(details.totalAmount, 450);
  });

  testWidgets('شاشة المراجعة: سعر الفترة والإجمالي نفس سعر السيرفر',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: buildPaymentFlow(
        chalet: const ChaletModel(id: 'c', name: 'شاليه', pricePerNight: 300),
        checkIn: DateTime(2030, 3, 12),
        checkOut: DateTime(2030, 3, 13),
        guestsCount: 2,
        totalPrice: 450,
        periodLabel: 'إقامة صباحية',
      ),
    ));
    await tester.pump();

    expect(find.byType(PaymentReviewScreen), findsOneWidget);
    expect(find.text('سعر إقامة صباحية'), findsOneWidget);
    expect(find.textContaining('450'), findsWidgets);
    // لا ضريبة ولا رسوم ولا سعر ليلة × عدد ليالٍ.
    expect(find.textContaining('الضريبة'), findsNothing);
    expect(find.textContaining('472'), findsNothing); // 450 + 5%
  });

  group('بيانات الدعم (فارغة حتى تُعتمد)', () {
    test('لا قنوات دعم معرَّفة بعد', () {
      expect(SupportContact.hasAny, isFalse);
    });

    testWidgets('شاشة الدعم لا تعرض بطاقات تواصل وهمية', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));
      expect(find.text('واتساب'), findsNothing);
      expect(find.text('البريد الإلكتروني'), findsNothing);
      expect(find.textContaining('XXXX'), findsNothing);
      expect(find.text('قنوات التواصل غير متاحة حالياً.'), findsOneWidget);
    });
  });
}
