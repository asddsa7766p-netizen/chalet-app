import 'package:http/http.dart' as http;

/// عميل HTTP لـ Supabase يلتقط رفض تجديد الجلسة لأن الحساب محظور.
///
/// لماذا هنا؟ عند فشل التجديد (`/auth/v1/token?grant_type=refresh_token`)
/// يحذف GoTrue الجلسة ويبث `signedOut` فقط، بلا سبب، فلا يمكن التمييز بين
/// الحظر وأي خروج آخر إلا من الرد نفسه (`"error_code":"user_banned"`).
/// رفض تسجيل الدخول نفسه لا يمر من هنا: يُعالج بـ [AuthService.signIn].
class SuspensionAwareHttpClient extends http.BaseClient {
  SuspensionAwareHttpClient({
    required this.onSuspended,
    http.Client? inner,
  }) : _inner = inner ?? http.Client();

  /// يُستدعى مرة لكل رد تجديد جلسة مرفوض بسبب الحظر.
  final void Function() onSuspended;
  final http.Client _inner;

  static bool _isRefresh(http.BaseRequest request) =>
      request.url.path.endsWith('/auth/v1/token') &&
      request.url.queryParameters['grant_type'] == 'refresh_token';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (!_isRefresh(request) || response.statusCode < 400) return response;

    // الرد مقروء مرة واحدة: نقرؤه ثم نعيد بناءه كما هو لـ GoTrue.
    final bytes = await response.stream.toBytes();
    if (String.fromCharCodes(bytes).contains('user_banned')) onSuspended();
    return http.StreamedResponse(
      http.ByteStream.fromBytes(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
