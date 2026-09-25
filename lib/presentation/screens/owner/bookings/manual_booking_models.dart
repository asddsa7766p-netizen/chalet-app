part of 'manual_booking_sheet.dart';

/// شاليه كما يحتاجه نموذج الحجز اليدوي.
class ManualBookingChalet {
  final String id;
  final String name;
  final int? maxGuests;

  const ManualBookingChalet({
    required this.id,
    required this.name,
    this.maxGuests,
  });

  factory ManualBookingChalet.fromRow(Map<String, dynamic> row) {
    final name = (row['name'] as String?)?.trim() ?? '';
    return ManualBookingChalet(
      id: row['id'] as String,
      name: name.isEmpty ? 'بدون اسم' : name,
      maxGuests: (row['max_guests'] as num?)?.toInt(),
    );
  }
}

class ManualBookingRequest {
  final String chaletId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guestsCount;
  final String guestName;
  final String guestPhone;
  final String? notes;

  /// السعر المتفق عليه مع الضيف (يكتبه المالك، ومقترحه سعر التقويم).
  final double totalPrice;

  /// نوع الإقامة ('default' إن لم يعرّف الشاليه أنواع إقامة).
  final String stayType;

  const ManualBookingRequest({
    required this.chaletId,
    required this.checkIn,
    required this.checkOut,
    required this.guestsCount,
    required this.guestName,
    required this.guestPhone,
    required this.notes,
    required this.totalPrice,
    this.stayType = BookingService.defaultStayType,
  });
}

/// توفر الفترتين (صباحية/مسائية) لكل يوم — نفس مصدر تقويم الضيف.
typedef LoadDaySlots = Future<Map<DateTime, ChaletDaySlot>> Function(
    String chaletId);
typedef LoadStayTypes = Future<List<ChaletStayTypeConfig>> Function(
    String chaletId);
typedef QuotePrice = Future<double> Function(
    String chaletId, DateTime checkIn, DateTime checkOut, String stayType);
typedef SubmitManualBooking = Future<void> Function(
    ManualBookingRequest request);

/// رقم الهاتف: أرقام فقط بعد إزالة المسافات والشرطات والأقواس وعلامة +.
String? validateManualGuestPhone(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return 'رقم الهاتف مطلوب';
  final digits = raw.replaceAll(RegExp(r'[\s\-()+]'), '');
  if (!RegExp(r'^[0-9٠-٩]{7,15}$').hasMatch(digits)) {
    return 'أدخل رقم هاتف صحيح';
  }
  return null;
}

String? validateManualGuestName(String? value) {
  final name = (value ?? '').trim();
  if (name.isEmpty) return 'اسم الضيف مطلوب';
  if (name.length < 2) return 'الاسم قصير جداً';
  return null;
}

/// يحوّل نص السعر لرقم (يقبل الأرقام العربية-الهندية وفاصلة عشرية "،" أو ",").
double? parseManualPrice(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return null;
  // الفاصلة (، أو ,) هنا عشرية، كما يكتبها المالك عادةً بالسعر.
  return parseLocalizedDouble(
      raw.replaceAll('،', '.').replaceAll(',', '.').replaceAll(' ', ''));
}

/// السيرفر يرفض السعر ≤ 0 (لا حجز مجاني)، فنرفضه هنا برسالة واضحة.
String? validateManualPrice(String? value) {
  if ((value ?? '').trim().isEmpty) return 'اكتب السعر المتفق عليه';
  final price = parseManualPrice(value);
  if (price == null) return 'أدخل رقماً صحيحاً';
  if (price <= 0) return 'السعر يجب أن يكون أكبر من صفر';
  return null;
}
