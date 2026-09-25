import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/support_contact.dart';
import '../../../data/services/services.dart';

class PrivacySecurityScreen extends StatefulWidget {
  /// قابلة للحقن بالاختبارات؛ الافتراضي [AuthService.deleteMyAccount].
  final Future<void> Function()? deleteAccount;

  /// الافتراضي [AuthService.isLoggedIn] (زر الحذف لصاحب حساب فقط).
  final bool? isLoggedIn;

  /// بعد نجاح الحذف (والخروج)؛ الافتراضي: الرئيسية كضيف.
  final VoidCallback? onAccountDeleted;

  const PrivacySecurityScreen({
    super.key,
    this.deleteAccount,
    this.isLoggedIn,
    this.onAccountDeleted,
  });

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _deleting = false;

  bool get _loggedIn => widget.isLoggedIn ?? AuthService.instance.isLoggedIn;

  Future<void> _deleteAccount() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = widget.onAccountDeleted == null ? GoRouter.of(context) : null;
    setState(() => _deleting = true);
    try {
      await (widget.deleteAccount ?? AuthService.instance.deleteMyAccount)();
    } catch (e) {
      // رفض الخادم (حجوزات قادمة/شاليهات مسجلة) رسالته عربية جاهزة: تُعرض كما هي.
      if (mounted) setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(
        content: Text(accountDeletionErrorMessage(e),
            style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    if (mounted) setState(() => _deleting = false);
    messenger.showSnackBar(const SnackBar(
      content: Text('تم حذف حسابك', style: TextStyle(fontFamily: 'Cairo')),
    ));
    if (widget.onAccountDeleted != null) {
      widget.onAccountDeleted!();
    } else {
      router!.go('/home');
    }
  }

  Widget _deleteAccountButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        key: const Key('delete_account_button'),
        onPressed: _deleting ? null : _deleteAccount,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error, width: 1.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: _deleting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.error))
            : const Icon(Icons.delete_forever_outlined),
        label: const Text('حذف الحساب',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<String> bullets,
  }) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.sand, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPale.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryPale),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: bullets
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '•',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                height: 1.7,
                                color: AppColors.charcoal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(AppStrings.privacy),
          leading: const BackButton(
            color: AppColors.charcoal,
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header gradient
                Container(
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(22),
                            border:
                                Border.all(color: AppColors.accent, width: 1),
                          ),
                        ),
                        const Icon(
                          Icons.shield_outlined,
                          size: 52,
                          color: AppColors.white,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  '🔐 الخصوصية والأمان',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'صفحة مبسطة وواضحة توضح كيف نتعامل مع بياناتك داخل تطبيق مكان.',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    height: 1.8,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 14),

                _sectionCard(
                  icon: Icons.person_outline,
                  title: '1. البيانات التي نجمعها',
                  bullets: const [
                    'الاسم ورقم الهاتف',
                    'بيانات الحجز',
                    'معلومات الاستخدام داخل التطبيق',
                  ],
                ),

                const SizedBox(height: 12),

                _sectionCard(
                  icon: Icons.data_usage_outlined,
                  title: '2. كيف نستخدم البيانات',
                  bullets: const [
                    'تأكيد وإدارة الحجوزات',
                    'تحسين تجربة المستخدم',
                    'التواصل عند الحاجة بخصوص الحجز',
                  ],
                ),

                const SizedBox(height: 12),

                _sectionCard(
                  icon: Icons.share_outlined,
                  title: '3. مشاركة البيانات',
                  bullets: const [
                    'لا نقوم ببيع بياناتك لأي طرف ثالث.',
                    'قد نشارك البيانات فقط مع: أصحاب الشاليهات لإتمام الحجز',
                    'جهات الدفع (إن وجدت).',
                  ],
                ),

                const SizedBox(height: 12),

                _sectionCard(
                  icon: Icons.security_outlined,
                  title: '4. الأمان والحماية',
                  bullets: const [
                    'نستخدم تقنيات حماية لضمان حفظ بياناتك بشكل آمن.',
                    'منع الوصول غير المصرح به.',
                    'تشفير البيانات عند الحاجة.',
                  ],
                ),

                const SizedBox(height: 12),

                _sectionCard(
                  icon: Icons.gavel_outlined,
                  title: '5. حقوق المستخدم',
                  bullets: [
                    _loggedIn
                        ? 'لديك الحق في حذف حسابك وبياناتك، من زر "حذف الحساب" أدناه.'
                        : 'لديك الحق في حذف حسابك وبياناتك.',
                    'تعديل معلوماتك.',
                    'معرفة البيانات المخزنة عنك.',
                  ],
                ),

                if (_loggedIn) ...[
                  const SizedBox(height: 12),
                  _deleteAccountButton(),
                ],

                // بيانات التواصل من AppStrings فقط، والقسم يُخفى ما دامت فارغة.
                if (SupportContact.hasAny) ...[
                  const SizedBox(height: 12),
                  _sectionCard(
                    icon: Icons.phone_outlined,
                    title: '6. تواصل معنا',
                    bullets: [
                      if (SupportContact.hasPhone) '📞 ${SupportContact.phone}',
                      if (SupportContact.hasEmail) '📧 ${SupportContact.email}',
                    ],
                  ),
                ],

                const SizedBox(height: 18),

                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.sand),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'الإصدار 1.0.0',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHint,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '© 2026 مكان',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// تأكيد حذف الحساب: يشرح ما يُحذف وأنه نهائي، وزر الحذف لا يتفعّل إلا
/// بكتابة كلمة "حذف". يرجع true عند التأكيد.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  static const _confirmWord = 'حذف';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _matches => _ctrl.text.trim() == _confirmWord;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(
        fontFamily: 'Cairo', fontSize: 13, height: 1.7, color: AppColors.charcoal);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('حذف الحساب نهائياً',
          style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              color: AppColors.error)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '• يُحذف حسابك وبياناتك الشخصية: الاسم، الهاتف، البريد، المفضلة، التقييمات، والإشعارات.\n'
              '• حجوزاتك السابقة تبقى في سجل صاحب الشاليه باسم "مستخدم محذوف" وبدون رقم هاتفك.\n'
              '• إن كانت لديك حجوزات قادمة فألغِها أولاً.\n'
              '• لا يمكن التراجع عن الحذف.',
              style: body,
            ),
            const SizedBox(height: 14),
            const Text('للتأكيد اكتب كلمة "$_confirmWord":',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal)),
            const SizedBox(height: 8),
            TextField(
              key: const Key('delete_account_confirm_field'),
              controller: _ctrl,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontFamily: 'Cairo'),
              decoration: InputDecoration(
                hintText: _confirmWord,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
        ),
        ElevatedButton(
          key: const Key('delete_account_confirm_button'),
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('حذف نهائياً',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
