import '../../../../core/utils/number_utils.dart';

/// تحقق مدخلات شاشة تعديل الشاليه (واجهة فقط، لا يعتمد على أي قيد بالقاعدة).
///
/// كل دالة ترجع رسالة خطأ بالعربية، أو null إن كانت القيمة صالحة. الحدود
/// (100 حرف، 2000، 100,000…) حدود واجهة معتمدة بالتصميم.
class ChaletEditValidation {
  ChaletEditValidation._();

  static const int nameMax = 100;
  static const int descriptionMax = 2000;
  static const int locationMax = 100;
  static const int addressMax = 200;
  static const int guestsMax = 200;
  static const int priceMax = 100000;
  static const int roomsMin = 1;
  static const int roomsMax = 50;
  static const int imagesMax = 8;
  static const int imageMaxBytes = 10 * 1024 * 1024; // حد الـ bucket

  // حدود فلسطين نفسها التي تستخدمها شاشة الخريطة لإخفاء الشاليهات.
  static const double palestineLatMin = 29.0;
  static const double palestineLatMax = 34.0;
  static const double palestineLngMin = 34.0;
  static const double palestineLngMax = 36.5;

  /// عدد صحيح فقط (يرفض الكسور والنص). null إن لم يكن صالحاً.
  static int? parseInt(String input) => parseLocalizedInt(input);

  /// رقم عشري منتهٍ (يرفض NaN وInfinity). null إن لم يكن صالحاً.
  static double? parseNumber(String input) => parseLocalizedDouble(input);

  static String? name(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'اسم الشاليه مطلوب';
    if (t.length > nameMax) {
      return 'الاسم طويل (الحد الأقصى $nameMax حرف)';
    }
    return null;
  }

  static String? description(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'وصف الشاليه مطلوب';
    if (t.length > descriptionMax) {
      return 'الوصف طويل (الحد الأقصى $descriptionMax حرف)';
    }
    return null;
  }

  static String? maxGuests(String v) {
    final n = parseInt(v);
    if (n == null || n < 1 || n > guestsMax) {
      return 'أدخل عدداً صحيحاً بين 1 و$guestsMax';
    }
    return null;
  }

  static String? price(String v) {
    final n = parseNumber(v);
    if (n == null || n <= 0) return 'أدخل سعراً أكبر من صفر';
    if (n > priceMax) return 'سعر غير منطقي';
    return null;
  }

  static String? city(String? v) =>
      (v == null || v.trim().isEmpty) ? 'اختر المدينة' : null;

  static String? optionalText(String v, int max) =>
      v.trim().length > max ? 'النص طويل (الحد الأقصى $max حرف)' : null;

  static bool isYoutubeUrl(String value) {
    final t = value.trim();
    if (t.isEmpty) return true;
    final uri = Uri.tryParse(t);
    if (uri == null || !uri.isAbsolute) return false;
    final host = uri.host.toLowerCase();
    return host == 'youtube.com' ||
        host == 'www.youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'youtu.be' ||
        host == 'www.youtu.be';
  }

  static String? videoUrl(String v) =>
      isYoutubeUrl(v) ? null : 'يرجى إدخال رابط يوتيوب صحيح';

  static String? imagesCount(int count) =>
      count < 1 ? 'أضف صورة واحدة على الأقل' : null;

  static const String coordinatesTogether =
      'أدخل خط العرض وخط الطول معاً أو اتركهما فارغين';
  static const String coordinatesInvalid = 'إحداثيات غير صالحة';
  static const String coordinatesOutsidePalestine =
      'الإحداثيات خارج فلسطين، لن يظهر الشاليه على خريطة فلسطين';

  /// نتيجة فحص زوج الإحداثيات.
  static CoordinatesCheck coordinates(String latText, String lngText) {
    final latEmpty = latText.trim().isEmpty;
    final lngEmpty = lngText.trim().isEmpty;
    if (latEmpty && lngEmpty) return const CoordinatesCheck();
    if (latEmpty) return const CoordinatesCheck(latError: coordinatesTogether);
    if (lngEmpty) return const CoordinatesCheck(lngError: coordinatesTogether);

    final lat = parseNumber(latText);
    final lng = parseNumber(lngText);
    final latBad = lat == null || lat < -90 || lat > 90;
    final lngBad = lng == null || lng < -180 || lng > 180;
    if (latBad || lngBad) {
      return CoordinatesCheck(
        latError: latBad ? coordinatesInvalid : null,
        lngError: lngBad ? coordinatesInvalid : null,
      );
    }
    if (lat == 0 && lng == 0) {
      return const CoordinatesCheck(
        latError: coordinatesInvalid,
        lngError: coordinatesInvalid,
      );
    }
    if (lat < palestineLatMin ||
        lat > palestineLatMax ||
        lng < palestineLngMin ||
        lng > palestineLngMax) {
      return const CoordinatesCheck(warning: coordinatesOutsidePalestine);
    }
    return const CoordinatesCheck();
  }

  static const Set<String> _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
  };
  static const Set<String> _imageMimes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
  };

  /// فحص ملف صورة قبل الرفع (الحجم والصيغة المسموحة بالـ bucket).
  /// الصيغة المجهولة (لا امتداد ولا mime، مثل blob بالويب) تُقبل والسيرفر
  /// هو الحكم.
  static String? imageFile({
    required String fileName,
    String? mimeType,
    required int sizeBytes,
  }) {
    if (sizeBytes > imageMaxBytes) {
      return 'الصورة "$fileName" أكبر من 10 ميغابايت';
    }
    final mime = mimeType?.toLowerCase();
    final dot = fileName.lastIndexOf('.');
    final ext = dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : null;
    final known = (mime != null && mime.isNotEmpty) || (ext != null);
    if (!known) return null;
    final mimeOk = mime != null && mime.isNotEmpty && _imageMimes.contains(mime);
    final extOk = ext != null && _imageExtensions.contains(ext);
    if (mimeOk || extOk) return null;
    return 'صيغة الصورة "$fileName" غير مدعومة (المسموح: JPG وPNG وWEBP وHEIC)';
  }
}

/// نتيجة فحص الإحداثيات: أخطاء مانعة لكل حقل، وتحذير غير مانع.
class CoordinatesCheck {
  final String? latError;
  final String? lngError;
  final String? warning;

  const CoordinatesCheck({this.latError, this.lngError, this.warning});

  bool get ok => latError == null && lngError == null;
}
