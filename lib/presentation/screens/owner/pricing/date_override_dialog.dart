part of 'chalet_pricing_screen.dart';

typedef _DateOverrideInput = ({String price, String note});

/// حوار "سعر خاص لتاريخ محدد": يرجع النصين عند الحفظ، أو null عند الإلغاء.
class _DateOverrideDialog extends StatefulWidget {
  const _DateOverrideDialog({required this.date, required this.scopeLabel});

  final DateTime date;
  final String scopeLabel;

  @override
  State<_DateOverrideDialog> createState() => _DateOverrideDialogState();
}

class _DateOverrideDialogState extends State<_DateOverrideDialog> {
  final _price = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.date;
    return AlertDialog(
      title: const Text('سعر خاص لتاريخ محدد',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${d.year}/${d.month}/${d.day}',
            style:
                const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.scopeLabel,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'السعر لهذا اليوم'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري، مثلاً: عيد الفطر)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop<_DateOverrideInput>(
              context, (price: _price.text.trim(), note: _note.text.trim())),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
