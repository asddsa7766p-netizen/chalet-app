part of 'profile_screen.dart';

/// ورقة تعديل الاسم والهاتف: تملك حقولها وتتخلّص منها، وترجع true عند
/// الحفظ الناجح. فشل الحفظ يُعرض داخل الورقة ولا يغلقها.
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile});

  final UserProfile? profile;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.profile?.fullName);
  late final _phone = TextEditingController(text: widget.profile?.phone);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService.instance
          .updateProfile(fullName: _name.text.trim(), phone: _phone.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('تعديل البيانات',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          CustomTextField(
              controller: _name,
              label: AppStrings.fullName,
              prefixIcon: Icons.person_outline),
          const SizedBox(height: 12),
          CustomTextField(
              controller: _phone,
              label: AppStrings.phone,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 12.5, color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'حفظ التغييرات',
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
