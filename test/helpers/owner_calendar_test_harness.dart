import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/models/models.dart';
import 'package:makan/data/services/chalet_slot_availability.dart';
import 'package:makan/data/services/pricing_service.dart';
import 'package:makan/presentation/screens/owner/calendar/owner_calendar_data_source.dart';
import 'package:makan/presentation/screens/owner/calendar/owner_calendar_screen.dart';

import 'pricing_test_harness.dart';

/// اليوم المثبّت بكل اختبارات التقويم: الأحد 10 مارس 2030.
final calendarToday = DateTime(2030, 3, 10);

DateTime d(int y, int m, int day) => DateTime(y, m, day);

BookingModel fakeBooking(
  String id,
  DateTime checkIn,
  DateTime checkOut, {
  String chaletId = 'c1',
  BookingStatus status = BookingStatus.confirmed,
  String source = 'app',
  String? guestName,
  String? guestPhone,
  double price = 1500,
  int guests = 4,
  String? notes,
  String stayType = 'default',
  String? periodStart,
  String? periodEnd,
}) =>
    BookingModel(
      id: id,
      chaletId: chaletId,
      userId: 'u-$id',
      checkIn: checkIn,
      checkOut: checkOut,
      guestsCount: guests,
      totalPrice: price,
      status: status,
      notes: notes,
      createdAt: DateTime(2030, 1, 1),
      source: source,
      guestName: source == 'app' ? guestName : null,
      guestPhone: source == 'app' ? guestPhone : null,
      externalGuestName: source == 'external' ? guestName : null,
      externalGuestPhone: source == 'external' ? guestPhone : null,
      stayType: stayType,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

/// مصدر بيانات وهمي داخل الاختبار فقط — لا اتصال بقاعدة بيانات.
class FakeOwnerCalendarDataSource implements OwnerCalendarDataSource {
  FakeOwnerCalendarDataSource({
    List<CalendarChalet>? chalets,
    Map<String, List<BookingModel>>? bookings,
    Map<String, Set<DateTime>>? blocked,
    Map<String, int>? pending,
    this.priceOf,
  })  : chalets = chalets ??
            const [
              CalendarChalet(
                  id: 'c1', name: 'شاليه الندى', pricePerNight: 1000),
            ],
        bookings = {
          for (final e in (bookings ?? {}).entries) e.key: [...e.value],
        },
        blocked = {
          for (final e in (blocked ?? {}).entries) e.key: {...e.value},
        },
        pending = pending ?? {};

  final List<CalendarChalet> chalets;
  final Map<String, List<BookingModel>> bookings;
  final Map<String, Set<DateTime>> blocked;
  final Map<String, int> pending;

  /// سعر يوم (افتراضياً 1000 لكل الأيام).
  final DayPriceInfo Function(DateTime day)? priceOf;

  /// سجل الاستدعاءات، مثل: "bookings c1 2030-02-01..2030-05-01".
  final List<String> log = [];

  Object? chaletsError;
  Object? bookingsError;
  Object? writeError;

  static String _s(DateTime x) =>
      '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';

  @override
  Future<List<CalendarChalet>> loadChalets() async {
    log.add('chalets');
    if (chaletsError != null) throw chaletsError!;
    return chalets;
  }

  @override
  Future<Map<String, int>> loadPendingCounts(List<String> chaletIds) async {
    log.add('pendingCounts');
    return {...pending};
  }

  @override
  Future<List<BookingModel>> loadBookings(
      String chaletId, DateTime from, DateTime toExclusive) async {
    log.add('bookings $chaletId ${_s(from)}..${_s(toExclusive)}');
    if (bookingsError != null) throw bookingsError!;
    return [
      for (final b in bookings[chaletId] ?? const <BookingModel>[])
        if ((b.status == BookingStatus.pending ||
                b.status == BookingStatus.confirmed) &&
            b.checkIn.isBefore(toExclusive) &&
            b.checkOut.isAfter(from))
          b,
    ];
  }

  @override
  Future<Set<DateTime>> loadBlocked(
      String chaletId, DateTime from, DateTime to) async {
    log.add('blocked $chaletId ${_s(from)}..${_s(to)}');
    return {
      for (final x in blocked[chaletId] ?? const <DateTime>{})
        if (!x.isBefore(from) && !x.isAfter(to)) x,
    };
  }

  /// توفر الفترات لكل يوم (يُملأ صراحة بالاختبار؛ افتراضياً لا شيء).
  final Map<String, Map<DateTime, ChaletDaySlot>> slots = {};

  @override
  Future<Map<DateTime, ChaletDaySlot>> loadDaySlots(
      String chaletId, DateTime from, DateTime to) async {
    log.add('slots $chaletId ${_s(from)}..${_s(to)}');
    return {
      for (final e in (slots[chaletId] ?? const {}).entries)
        if (!e.key.isBefore(from) && !e.key.isAfter(to)) e.key: e.value,
    };
  }

  @override
  Future<void> blockDates(String chaletId, List<DateTime> dates) async {
    log.add('block $chaletId ${dates.map(_s).join(',')}');
    if (writeError != null) throw writeError!;
    blocked.putIfAbsent(chaletId, () => {}).addAll(dates);
  }

  @override
  Future<void> unblockDates(String chaletId, List<DateTime> dates) async {
    log.add('unblock $chaletId ${dates.map(_s).join(',')}');
    if (writeError != null) throw writeError!;
    blocked[chaletId]?.removeAll(dates);
  }

  @override
  Future<Map<DateTime, DayPriceInfo>> loadMonthPricing(
      CalendarChalet chalet, int year, int month) async {
    log.add('pricing ${chalet.id} $year-$month');
    final last = DateTime(year, month + 1, 0).day;
    return {
      for (var i = 1; i <= last; i++)
        DateTime(year, month, i): priceOf?.call(DateTime(year, month, i)) ??
            const DayPriceInfo(originalPrice: 1000, finalPrice: 1000),
    };
  }

  @override
  Future<int> loadUnreadCount() async => 0;

  @override
  Future<void> confirmBooking(String bookingId) async {
    log.add('confirm $bookingId');
    _setStatus(bookingId, BookingStatus.confirmed);
  }

  @override
  Future<void> rejectBooking(String bookingId) async {
    log.add('reject $bookingId');
    _setStatus(bookingId, BookingStatus.rejected);
  }

  @override
  Future<void> cancelManualBooking(String bookingId) async {
    log.add('cancelManual $bookingId');
    _setStatus(bookingId, BookingStatus.cancelled);
  }

  void _setStatus(String id, BookingStatus status) {
    for (final list in bookings.values) {
      for (var i = 0; i < list.length; i++) {
        final b = list[i];
        if (b.id != id) continue;
        list[i] = BookingModel(
          id: b.id,
          chaletId: b.chaletId,
          userId: b.userId,
          checkIn: b.checkIn,
          checkOut: b.checkOut,
          guestsCount: b.guestsCount,
          totalPrice: b.totalPrice,
          status: status,
          createdAt: b.createdAt,
          notes: b.notes,
          guestName: b.guestName,
          guestPhone: b.guestPhone,
          source: b.source,
          externalGuestName: b.externalGuestName,
          externalGuestPhone: b.externalGuestPhone,
          stayType: b.stayType,
          periodStart: b.periodStart,
          periodEnd: b.periodEnd,
        );
      }
    }
  }
}

/// بيانات مارس 2030 (اليوم = 10 مارس) تغطي كل الحالات:
///  - 3→6 مؤكد من التطبيق (ماضٍ منتهٍ)
///  - 8→12 يدوي جارٍ (مغادرته بعد اليوم فيمكن إلغاؤه)
///  - 12→15 مؤكد من التطبيق (ظهر يوم 12 = مغادرة الحجز اليدوي)
///  - 18→20 يدوي، 24→26 معلّق، 28..30 محجوب، 3 أبريل محجوب
FakeOwnerCalendarDataSource sampleDataSource({
  Map<String, int>? pending,
  List<CalendarChalet>? chalets,
}) =>
    FakeOwnerCalendarDataSource(
      chalets: chalets,
      pending: pending,
      bookings: {
        'c1': [
          fakeBooking('past', d(2030, 3, 3), d(2030, 3, 6),
              guestName: 'رنا حداد', guestPhone: '0599000111'),
          fakeBooking('run', d(2030, 3, 8), d(2030, 3, 12),
              source: 'external',
              guestName: 'خالد يوسف',
              guestPhone: '0568123456',
              price: 3200),
          fakeBooking('app1', d(2030, 3, 12), d(2030, 3, 15),
              guestName: 'سامي الخطيب',
              guestPhone: '0599123456',
              price: 2400,
              notes: 'يصل بعد العصر'),
          fakeBooking('man', d(2030, 3, 18), d(2030, 3, 20),
              source: 'external',
              guestName: 'أبو أحمد',
              guestPhone: '0599765432',
              price: 1800),
          fakeBooking('pend', d(2030, 3, 24), d(2030, 3, 26),
              status: BookingStatus.pending,
              guestName: 'ليلى منصور',
              guestPhone: '0592223344',
              price: 2000),
        ],
      },
      blocked: {
        'c1': {
          d(2030, 3, 28),
          d(2030, 3, 29),
          d(2030, 3, 30),
          d(2030, 4, 3),
        },
      },
    );

class CalendarHarness {
  final GlobalKey boundaryKey = GlobalKey();
  List<String> manualCalls = [];
  List<String> pricingCalls = [];
}

/// يشغّل شاشة التقويم بعرض [width] (منطقي، بكثافة 2×) داخل تطبيق عربي.
Future<CalendarHarness> pumpCalendar(
  WidgetTester tester,
  OwnerCalendarDataSource ds, {
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = Size(width * 2, height * 2);
  addTearDown(tester.view.reset);

  final h = CalendarHarness();
  await tester.pumpWidget(
    RepaintBoundary(
      key: h.boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: testTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: OwnerCalendarScreen(
          dataSource: ds,
          today: calendarToday,
          manualBookingOpener: (context, {chaletId, checkIn}) async {
            h.manualCalls.add('$chaletId ${checkIn?.toIso8601String().substring(0, 10)}');
            return false;
          },
          pricingOpener: (context, chalet) async {
            h.pricingCalls.add(chalet.id);
          },
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return h;
}
