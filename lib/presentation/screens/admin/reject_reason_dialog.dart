part of 'admin_dashboard_screen.dart';

// ═══════════════════════ حوار سبب رفض الشاليه ══════════════════════════════

/// اقتراحات سريعة لسبب الرفض؛ الضغط يضيفها للنص (ويمكن تعديله بعدها).
const rejectReasonSuggestions = [
  'الصور غير واضحة',
  'معلومات ناقصة',
  'الموقع غير دقيق',
  'الأسعار غير منطقية',
];

/// أقل طول لسبب الرفض بعد حذف المسافات (يطابق admin_reject_chalet).
const rejectReasonMinLength = 3;

/// يطلب سبب الرفض (إلزامي) ويرجعه منظّفاً، أو null عند الإلغاء. الرفض لا
/// يحذف الشاليه: يصل السبب للمالك ليعدّله ويعيد إرساله.
Future<String?> showRejectReasonDialog(BuildContext context) =>
    showDialog<String>(
        context: context, builder: (_) => const RejectReasonDialog());

class RejectReasonDialog extends StatefulWidget {
  const RejectReasonDialog({super.key});

  @override
  State<RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<RejectReasonDialog> {
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String get _text => _reason.text.trim();
  bool get _valid => _text.length >= rejectReasonMinLength;

  void _addSuggestion(String s) {
    if (_text.contains(s)) return;
    final next = _text.isEmpty ? s : '$_text، $s';
    _reason.value = TextEditingValue(
        text: next, selection: TextSelection.collapsed(offset: next.length));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('رفض الشاليه',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'يبقى الشاليه عند المالك مع سبب الرفض ليعدّله ثم يعيد إرساله للمراجعة.',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                key: const Key('reject_reason_field'),
                controller: _reason,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'سبب الرفض',
                  hintText: 'ما الذي يجب أن يعدّله المالك؟',
                  helperText: _valid ? null : 'السبب إلزامي',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in rejectReasonSuggestions)
                    ActionChip(
                      label: Text(s,
                          style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 12)),
                      onPressed: () => _addSuggestion(s),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          TextButton(
            key: const Key('reject_reason_confirm'),
            onPressed: _valid ? () => Navigator.pop(context, _text) : null,
            child: Text('رفض',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    color: _valid ? AppColors.error : AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}
