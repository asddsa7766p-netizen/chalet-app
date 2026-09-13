import 'package:geolocator/geolocator.dart';

/// خدمة الموقع الجغرافي (GPS)
///
/// مسؤولة عن: طلب صلاحية الموقع، جلب الموقع الحالي، وحساب المسافة
/// بين موقعين. لا تفترض شيء عن حالة الصلاحية مسبقاً — تتحقق فعلياً
/// دائماً، وتتعامل بهدوء (ترجع null) عند أي رفض أو خطأ بدل رمي استثناء.
class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  /// يتحقق من تفعيل GPS بالجهاز ثم يطلب الصلاحية إذا لزم، ثم يرجع
  /// الموقع الحالي. يرجع null بهدوء عند أي رفض/تعطيل/خطأ.
  Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// المسافة بالكيلومتر بين نقطتين
  double distanceInKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final meters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return meters / 1000;
  }
}
