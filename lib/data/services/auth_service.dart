part of 'services.dart';

// ============================================
// AUTH SERVICE
// ============================================
class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();

  User? get currentUser => supabase.auth.currentUser;
  Session? get currentSession => supabase.auth.currentSession;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  /// يزيد عند أي تغيير محتمل بصلاحيات المستخدم (دخول/خروج/become_owner/
  /// become_customer). كاش الصلاحيات بـ AppRouter يقارنه ليعيد الجلب،
  /// فلا يحتاج أي مستدعٍ لتذكّر مسح الكاش بنفسه.
  int get rolesEpoch => _rolesEpoch;
  int _rolesEpoch = 0;
  void _rolesChanged() => _rolesEpoch++;

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'phone': phone},
      );

      // ✅ إصلاح: عند تفعيل تأكيد البريد لا توجد جلسة بعد التسجيل، فيرفض
      // RLS (profiles_insert_own: id = auth.uid()) الـ upsert ويُعرض للمستخدم
      // خطأ رغم أن الحساب أُنشئ فعلاً (والبروفايل ينشئه trigger
      // handle_new_user). نحدّث البروفايل فقط عند وجود جلسة، ولا نُفشل
      // التسجيل بسبب هذه الخطوة الثانوية.
      if (response.user != null && response.session != null) {
        try {
          await supabase.from('profiles').upsert({
            'id': response.user!.id,
            'full_name': fullName,
            'phone': phone,
            'email': email,
          });
        } catch (e, st) {
          // ثانوي: البروفايل ينشئه trigger handle_new_user أصلاً؛ لا نُفشل التسجيل.
          reportError(e, st, context: 'auth.sign_up_profile_upsert');
        }
      }

      return response;
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    } finally {
      _rolesChanged();
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    } finally {
      // بدون هذا، لو خرج أدمن ودخل مستخدم آخر بنفس جلسة التطبيق، يبقى
      // كاش الصلاحيات القديم.
      _rolesChanged();
    }
  }

  /// Reset password
  ///
  /// ملاحظة مهمة: هذا التطبيق موبايل بدون deep link/app link مُعدّ حالياً
  /// (لا scheme ولا intent-filter)، فرابط "Reset Password" الافتراضي من
  /// Supabase (المخصص لتطبيقات الويب) لن يفتح التطبيق. لهذا نعتمد بدلاً
  /// منه على رمز التحقق (OTP) المكوّن من 6 أرقام الذي يرسله Supabase مع
  /// نفس بريد "Reset Password" ضمن المتغيّر {{ .Token }}. راجع
  /// [verifyPasswordRecoveryOtp] و [updatePassword] بالأسفل.
  ///
  /// ⚠️ إعداد خارجي مطلوب يدويًا في Supabase Dashboard (لا يمكن ضبطه من
  /// الكود): Authentication → Email Templates → Reset Password، تأكد أن
  /// نص الرسالة يتضمن {{ .Token }} (رمز الاسترداد المكوّن من 6 أرقام) —
  /// القالب الافتراضي أحياناً يحتوي فقط على {{ .ConfirmationURL }}.
  Future<void> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// يتحقق من رمز استرداد كلمة المرور (OTP المكوّن من 6 أرقام المُرسَل
  /// بالبريد بعد [resetPassword])، وينشئ جلسة "recovery" مؤقتة تسمح
  /// بعدها فقط بمناداة [updatePassword] لتعيين كلمة مرور جديدة.
  Future<void> verifyPasswordRecoveryOtp({
    required String email,
    required String token,
  }) async {
    try {
      await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  // ملاحظة: بعد التحقق من رمز الاسترداد أعلاه، استخدم updatePassword()
  // الموجودة بالأسفل بنفس هذا الكلاس لتعيين كلمة المرور الجديدة.

  /// Update password
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      return await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Get current profile
  Future<UserProfile?> getCurrentProfile() async {
    if (currentUser == null) return null;
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();
      return UserProfile.fromJson(data);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  /// Update profile
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    if (currentUser == null) return;
    try {
      await supabase.from('profiles').update({
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }).eq('id', currentUser!.id);
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    }
  }

  Future<bool> becomeOwner() async {
    if (currentUser == null) return false;

    try {
      final result = await supabase.rpc('become_owner');
      return result as bool;
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    } finally {
      _rolesChanged();
    }
  }

  Future<bool> becomeCustomer() async {
    if (currentUser == null) return false;

    try {
      final result = await supabase.rpc('become_customer');
      return result as bool;
    } catch (e) {
      throw Exception(_translateSupabaseError(e));
    } finally {
      _rolesChanged();
    }
  }

  /// يحذف حساب المستخدم الحالي نهائياً عبر `delete_my_account` (الخادم يرفض
  /// إن كانت له حجوزات قادمة أو شاليهات، ويفك ربط حجوزاته السابقة ويحذف
  /// مستخدم auth). عند الرفض يرمي [AccountDeletionException] برسالة جاهزة
  /// للعرض. بعد النجاح يخرج محلياً: المستخدم لم يعد موجوداً بالخادم، فطلب
  /// الخروج من الخادم لا معنى له وقد يفشل.
  Future<void> deleteMyAccount() async {
    try {
      final result = await supabase.rpc('delete_my_account');
      if (result is! Map || result['deleted'] != true) {
        throw const AccountDeletionException(accountDeletionFailedMessage);
      }
    } catch (e) {
      throw AccountDeletionException(accountDeletionErrorMessage(e));
    }
    try {
      await supabase.auth.signOut(scope: SignOutScope.local);
    } finally {
      _rolesChanged();
    }
  }
}

const accountDeletionFailedMessage = 'تعذر حذف الحساب، يرجى المحاولة لاحقاً';

/// رفض أو فشل حذف الحساب؛ [message] جاهزة للعرض كما هي.
class AccountDeletionException implements Exception {
  final String message;
  const AccountDeletionException(this.message);

  @override
  String toString() => message;
}

/// رسالة خطأ حذف الحساب للعرض. رفض الخادم المقصود (RAISE EXCEPTION برمز
/// P0001، أو 42501 لغير المسجّل) يحمل رسالة عربية جاهزة تُعرض حرفياً، مثل
/// "لديك حجوزات قادمة. ألغِها أولاً ثم احذف الحساب."؛ أي خطأ آخر (شبكة، خطأ
/// قاعدة غير متوقع) يُسجَّل ويُعرض برسالة عامة بدل النص التقني الخام.
String accountDeletionErrorMessage(Object error) {
  if (error is AccountDeletionException) return error.message;
  if (error is PostgrestException &&
      (error.code == 'P0001' || error.code == '42501') &&
      error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  reportError(error, StackTrace.current, context: 'auth.delete_my_account');
  return accountDeletionFailedMessage;
}

/// Holds a pending action requested by a guest that needs authentication.
class PendingAuthAction {
  final String type;
  final Map<String, dynamic> data;
  const PendingAuthAction(this.type, [this.data = const {}]);
}

/// Simple in-memory storage for a pending auth action. Not persisted.
class AuthRedirectService {
  static PendingAuthAction? _pending;

  static void setPendingAction(PendingAuthAction action) {
    _pending = action;
  }

  static PendingAuthAction? consumePendingAction() {
    final a = _pending;
    _pending = null;
    return a;
  }
}
