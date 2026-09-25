part of 'owner_add_chalet_screen.dart';

class _StepInfo {
  final String label;
  final IconData icon;
  const _StepInfo(this.label, this.icon);
}

class _CoverImageBox extends StatelessWidget {
  final bool hasImages;
  final VoidCallback? onTap;

  const _CoverImageBox({required this.hasImages, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DottedBorderBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_upload_outlined,
                  size: 34, color: Color(0xFFC9A24B)),
              const SizedBox(height: 10),
              const Text('صورة الغلاف الرئيسية',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal)),
              const SizedBox(height: 4),
              const Text('يفضل صورة جديدة تظهر المسبح أو الحديقة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEE6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(hasImages ? 'إضافة المزيد' : 'اختر صورة',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// إطار منقط بسيط (Flutter ما عندها CustomPainter جاهز للحدود المنقطة،
/// فبنينا وحدة بسيطة بـ CustomPaint).
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(),
      child: child,
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9A24B)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, dashArray: [6, 4]);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source, {required List<double> dashArray}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = dashArray[draw ? 0 : 1];
        if (draw) {
          dest.addPath(
              metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NumberFieldInput extends StatefulWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberFieldInput({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_NumberFieldInput> createState() => _NumberFieldInputState();
}

class _NumberFieldInputState extends State<_NumberFieldInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _ctrl,
          textAlign: TextAlign.start,
          keyboardType: TextInputType.number,
          onChanged: (s) {
            final val = parseLocalizedInt(s) ?? widget.min;
            final clamped = val.clamp(widget.min, widget.max);
            widget.onChanged(clamped);
          },
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
