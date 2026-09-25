import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';

/// صورة داخل مسودة التعديل: إما موجودة أصلاً (رابط بالتخزين) أو جديدة لم
/// تُرفع بعد (ملف + بايتات بالذاكرة).
class DraftImage {
  static int _seq = 0;

  final int id = ++_seq;
  final String? url;
  final XFile? file;
  final Uint8List? bytes;

  DraftImage.existing(String this.url)
      : file = null,
        bytes = null;

  DraftImage.fresh(XFile this.file, Uint8List this.bytes) : url = null;

  bool get isNew => file != null;

  /// بصمة ثابتة للمقارنة (رابط للموجودة، معرّف فريد للجديدة).
  String get signature => isNew ? 'new:$id' : url!;
}

/// شبكة صور التعديل: الصورة الأولى هي الغلاف، ولكل صورة حذف و"اجعلها الغلاف".
/// عرض فقط: كل تغيير يُبلَّغ به عبر callbacks والمسودة تُدار بالشاشة.
class ChaletImagesEditor extends StatelessWidget {
  final List<DraftImage> images;
  final int maxImages;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onMakeCover;

  const ChaletImagesEditor({
    super.key,
    required this.images,
    required this.maxImages,
    required this.onAdd,
    required this.onRemove,
    required this.onMakeCover,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 520 ? 4 : 3;
      const gap = 8.0;
      final size = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < images.length; i++)
            SizedBox(width: size, height: size, child: _tile(i)),
          if (images.length < maxImages)
            SizedBox(width: size, height: size, child: _addTile()),
        ],
      );
    });
  }

  Widget _tile(int i) {
    final img = images[i];
    return ClipRRect(
      key: ValueKey('imgTile_$i'),
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (img.isNew)
            Image.memory(
              img.bytes!,
              fit: BoxFit.cover,
              // صورة تالفة أو بصيغة لا يفكّها الجهاز (مثل HEIC بالويب) لا يجوز أن
              // تنهار الشبكة بها.
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.sand,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.textHint, size: 28),
              ),
            )
          else
            Image.network(
              img.url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.sand,
                alignment: Alignment.center,
                child: const Icon(Icons.image_outlined,
                    color: AppColors.textHint, size: 28),
              ),
            ),
          PositionedDirectional(
            top: 4,
            start: 4,
            child: _circleButton(
              key: ValueKey('imgDelete_$i'),
              icon: Icons.close_rounded,
              tooltip: 'حذف الصورة',
              color: AppColors.error,
              onTap: enabled ? () => onRemove(i) : null,
            ),
          ),
          if (img.isNew)
            PositionedDirectional(
              top: 4,
              end: 4,
              child: _pill('جديدة', AppColors.accentDark, Colors.white),
            ),
          PositionedDirectional(
            bottom: 4,
            start: 4,
            end: 4,
            child: i == 0
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _pill('الغلاف', AppColors.primary, Colors.white,
                        key: const ValueKey('coverBadge')),
                  )
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _coverButton(i),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _coverButton(int i) {
    return Semantics(
      button: true,
      label: 'اجعلها الغلاف',
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: ValueKey('imgCover_$i'),
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? () => onMakeCover(i) : null,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'اجعلها الغلاف',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg, {Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10.5,
          height: 1.3,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  Widget _circleButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          key: key,
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(5),
            child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _addTile() {
    return Material(
      color: AppColors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
      child: InkWell(
        key: const ValueKey('imgAdd'),
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: enabled ? onAdd : null,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: AppColors.primary, size: 26),
                  SizedBox(height: 4),
                  Text(
                    'إضافة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
