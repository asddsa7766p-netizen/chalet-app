import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/common_widgets.dart';

class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;

  bool _editMode = false;

  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  // Password
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await AuthService.instance.getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _fullNameCtrl.text = p?.fullName ?? '';
        _phoneCtrl.text = p?.phone ?? '';
        _emailCtrl.text =
            p?.email ?? (AuthService.instance.currentUser?.email ?? '');
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enterEditMode() {
    setState(() {
      _editMode = true;
    });
  }

  void _cancelEditMode() {
    setState(() {
      _editMode = false;
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      _fullNameCtrl.text = _profile?.fullName ?? '';
      _phoneCtrl.text = _profile?.phone ?? '';
      _emailCtrl.text =
          _profile?.email ?? (AuthService.instance.currentUser?.email ?? '');
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_editMode) return;

    setState(() => _saving = true);

    try {
      final fullName = _fullNameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();

      // App currently updates profile only with fullName/phone/avatarUrl.
      // Email is shown (read-only) as "(اختياري)"; we won't try to change it.
      await AuthService.instance.updateProfile(
        fullName: fullName.isEmpty ? null : fullName,
        phone: phone.isEmpty ? null : phone,
        // avatarUrl: null (not implemented)
      );

      if (_newPasswordCtrl.text.isNotEmpty) {
        final newPass = _newPasswordCtrl.text;
        final confirmPass = _confirmPasswordCtrl.text;
        if (newPass != confirmPass) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('كلمات المرور غير متطابقة')),
          );
          return;
        }
        if (newPass.length < 8) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('كلمة المرور يجب أن تكون 8 أحرف على الأقل')),
          );
          return;
        }
        await AuthService.instance.updatePassword(newPass);
      }

      if (!mounted) return;
      await _load();
      setState(() {
        _editMode = false;
        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التغييرات بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ التغييرات: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تأكيد حذف الحساب',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'حذف الحساب سيؤدي إلى:',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• إزالة جميع بياناتك',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.charcoal,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• إلغاء جميع الحجوزات',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.charcoal,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        side:
                            const BorderSide(color: AppColors.sand, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('إلغاء',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('حذف الحساب',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );

    if (confirm != true) return;

    // تنفيذ الحذف (Supabase)
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      // سنحاول حذف المستخدم عبر Supabase Auth.
      // ملاحظة: الحذف الكامل (cascade) يعتمد على صلاحيات/Triggers في Supabase.
      // deleteUser عبر admin API قد يتطلب تهيئة خاصة.
      // لو لم تكن admin غير متاحة لديك، سيظهر الخطأ في snackbar.
      // لا يمكن الاستدعاء هنا إلا بعد إزالة "const" الخاطئة.
      // بما أن الحذف الكامل غير مدمج حاليًا داخل AuthService في هذا المشروع،
      // نُظهر رسالة واضحة بدل تنفيذ جزئي قد يسبب مشاكل في البيانات.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حذف الحساب غير مدمج بالكامل حاليًا')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حذف الحساب: $e')),
      );
    }
  }

  Widget _buildEditableTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return AbsorbPointer(
      absorbing: !enabled,
      child: CustomTextField(
        controller: controller,
        label: label,
        prefixIcon: icon,
        keyboardType: keyboardType,
        obscureText: obscureText,
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
          title: const Text('البيانات الشخصية'),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profile picture + Edit button
                      Card(
                        elevation: 0,
                        color: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side:
                              const BorderSide(color: AppColors.sand, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 38,
                                backgroundColor:
                                    AppColors.primaryPale.withOpacity(0.3),
                                backgroundImage: _profile?.avatarUrl != null &&
                                        _profile!.avatarUrl!.isNotEmpty
                                    ? NetworkImage(_profile!.avatarUrl!)
                                    : null,
                                child: _profile?.avatarUrl == null ||
                                        (_profile!.avatarUrl ?? '').isEmpty
                                    ? Text(
                                        (_profile?.fullName?.trim().isEmpty ??
                                                true)
                                            ? 'م'
                                            : _profile!.fullName!
                                                .trim()
                                                .characters
                                                .first,
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.w900,
                                          fontSize: 24,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '📸 صورة الملف الشخصي',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      '(اختياري)',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 13,
                                        color: AppColors.textHint,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_editMode)
                                IconButton(
                                  onPressed: () {
                                    // Avatar picking is not implemented.
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'تغيير الصورة غير متاح حاليًا')),
                                    );
                                  },
                                  icon: const Icon(Icons.edit_rounded,
                                      color: AppColors.primary),
                                ),
                              if (!_editMode)
                                IconButton(
                                  onPressed: _enterEditMode,
                                  icon: const Icon(Icons.photo_camera_outlined,
                                      color: AppColors.textHint),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Basic info
                      _infoCard(
                        title: '🧾 المعلومات الأساسية',
                        icon: Icons.person_outline_rounded,
                        children: [
                          const SizedBox(height: 2),
                          _buildFieldRow(
                            label: 'الاسم الكامل',
                            icon: Icons.badge_outlined,
                            controller: _fullNameCtrl,
                            enabled: _editMode,
                          ),
                          const SizedBox(height: 12),
                          _buildFieldRow(
                            label: 'رقم الهاتف',
                            icon: Icons.phone_outlined,
                            controller: _phoneCtrl,
                            enabled: _editMode,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          _buildFieldRow(
                            label: 'البريد الإلكتروني (اختياري)',
                            icon: Icons.email_outlined,
                            controller: _emailCtrl,
                            enabled: false,
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Security
                      _infoCard(
                        title: '🔒 الأمان',
                        icon: Icons.lock_outline_rounded,
                        children: [
                          const SizedBox(height: 2),
                          _buildFieldRow(
                            label: 'كلمة المرور الجديدة',
                            icon: Icons.lock_outline_rounded,
                            controller: _newPasswordCtrl,
                            enabled: _editMode,
                            obscureText: true,
                          ),
                          const SizedBox(height: 12),
                          _buildFieldRow(
                            label: 'تأكيد كلمة المرور',
                            icon: Icons.lock_outline_rounded,
                            controller: _confirmPasswordCtrl,
                            enabled: _editMode,
                            obscureText: true,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'إذا تركت حقول كلمة المرور فارغة فلن يتم تغيير كلمة المرور.',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: AppColors.textHint,
                              height: 1.6,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Save / Edit controls
                      Card(
                        elevation: 0,
                        color: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side:
                              const BorderSide(color: AppColors.sand, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: AppButton(
                                      label: _editMode
                                          ? '💾 حفظ التغييرات'
                                          : 'تعديل',
                                      onPressed:
                                          _editMode ? _save : _enterEditMode,
                                      icon: _editMode
                                          ? Icons.save_rounded
                                          : Icons.edit_rounded,
                                    ),
                                  ),
                                  if (_editMode) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _cancelEditMode,
                                        icon: const Icon(Icons.cancel_outlined,
                                            size: 18, color: AppColors.primary),
                                        label: const Text('إلغاء',
                                            style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontWeight: FontWeight.w900)),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize:
                                              const Size(double.infinity, 52),
                                          side: const BorderSide(
                                              color: AppColors.sand,
                                              width: 1.5),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Delete account
                      Card(
                        elevation: 0,
                        color: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                              color: AppColors.error.withOpacity(0.35),
                              width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: AppColors.error),
                                  SizedBox(width: 10),
                                  Text(
                                    '⚠️ منطقة حساسة',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'حذف الحساب سيؤدي إلى:',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '• إزالة جميع بياناتك\n• إلغاء جميع الحجوزات',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  height: 1.6,
                                  color: AppColors.charcoal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                label: 'حذف الحساب',
                                color: AppColors.error,
                                icon: Icons.delete_forever_rounded,
                                onPressed: _confirmDeleteAccount,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'يمكنك طلب حذف حسابك نهائيًا في أي وقت.',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: AppColors.textHint,
                                  height: 1.6,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPale.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
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
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool enabled,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return AbsorbPointer(
      absorbing: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.75,
        child: CustomTextField(
          controller: controller,
          label: label,
          prefixIcon: icon,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
        ),
      ),
    );
  }
}
