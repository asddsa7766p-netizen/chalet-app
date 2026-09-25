import 'package:url_launcher/url_launcher.dart';

import '../constants/app_strings.dart';

/// قنوات الدعم من [AppStrings.supportPhone]/[AppStrings.supportEmail] فقط.
/// أي واجهة تواصل تظهر فقط إن كانت القناة المقابلة معرَّفة.
class SupportContact {
  SupportContact._();

  static String get phone => AppStrings.supportPhone.trim();
  static String get email => AppStrings.supportEmail.trim();

  static bool get hasPhone => phone.isNotEmpty;
  static bool get hasEmail => email.isNotEmpty;
  static bool get hasAny => hasPhone || hasEmail;

  /// رابط واتساب للرقم (أرقام فقط بلا + ولا مسافات).
  static Uri get whatsappUri =>
      Uri.parse('https://wa.me/${phone.replaceAll(RegExp(r'[^0-9]'), '')}');

  static Uri get emailUri => Uri(scheme: 'mailto', path: email);

  /// يفتح أول قناة متاحة (واتساب ثم البريد). يرجع false إن لم تُفتح.
  static Future<bool> open() async {
    try {
      if (hasPhone) {
        return await launchUrl(whatsappUri,
            mode: LaunchMode.externalApplication);
      }
      if (hasEmail) return await launchUrl(emailUri);
    } catch (_) {
      // لا تطبيق يفتح الرابط: المستدعي يعرض رسالة.
    }
    return false;
  }
}
