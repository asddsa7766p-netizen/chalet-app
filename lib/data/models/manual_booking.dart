import 'models.dart';

/// بيانات ضيف الحجز اليدوي كما تظهر بالواجهة.
class ManualGuest {
  final String? name;
  final String? phone;

  /// ملاحظات المالك (الملاحظات فقط، بعد أن صار الاسم والهاتف بعمودين).
  final String? note;

  const ManualGuest({this.name, this.phone, this.note});
}

/// نقطة الوصول الوحيدة لقاعدة "الحجز اليدوي" وبيانات ضيفه: كل الواجهة تمرّ
/// من هنا. المصدر هو العمود `bookings.source` (محمي بـ trigger).
extension ManualBookingX on BookingModel {
  bool get isManual => source == 'external';

  ManualGuest get manualGuest => ManualGuest(
        name: _clean(externalGuestName),
        phone: _clean(externalGuestPhone),
        note: _clean(notes),
      );
}

String? _clean(String? value) {
  final v = value?.trim();
  return (v == null || v.isEmpty) ? null : v;
}
