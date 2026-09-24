import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// يسجّل خطأ غير متوقَّع في Sentry (إن كان مفعّلاً بـ SENTRY_DSN؛ وإلا
/// لا يفعل Sentry شيئاً) ويطبعه بوضع التطوير. للأخطاء التي تُعالَج بالواجهة
/// (رسالة أو حالة خطأ) لكن يجب أن تظهر بلوحة مراقبة الإنتاج أيضاً.
void reportError(Object error, StackTrace? stack, {String? context}) {
  if (kDebugMode) {
    debugPrint('${context ?? 'ERROR'}: $error');
  }
  Sentry.captureException(
    error,
    stackTrace: stack,
    withScope: context == null ? null : (scope) => scope.setTag('where', context),
  );
}
