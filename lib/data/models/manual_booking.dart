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

  /// حجز من حساب حُذف: delete_my_account تفك ربطه (user_id = null)، وتضع
  /// الاسم في guest_name ("مستخدم محذوف" إن لم يكن له اسم) وتمسح الهاتف،
  /// ولا يبقى بروفايل مرتبط.
  bool get isFromDeletedAccount => userId == null && !isManual;

  /// اسم ضيف الحجز للعرض بكل شاشات المالك: من guest_name للحجز اليدوي
  /// ولحجز الحساب المحذوف، وإلا من بروفايل صاحب الحساب. null = بلا اسم.
  String? get displayGuestName =>
      _usesBookingGuestColumns ? _clean(externalGuestName) : _clean(guestName);

  /// هاتف الضيف للعرض، بنفس قاعدة [displayGuestName].
  String? get displayGuestPhone => _usesBookingGuestColumns
      ? _clean(externalGuestPhone)
      : _clean(guestPhone);

  bool get _usesBookingGuestColumns => isManual || userId == null;
}

String? _clean(String? value) {
  final v = value?.trim();
  return (v == null || v.isEmpty) ? null : v;
}
