// lib/presentation/widgets/common/amenity_chip.dart
//
// ARCH-02: Widget موحد للمميزات — يحل تكرار:
//   • _buildFacilitiesGrid  (chalet_detail_screen)
//   • _buildAmenities       (chalet_detail_screen)
//   • _amenityChip          (owner_add_chalet_screen)

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/chalet_model.dart';

/// chip واحدة للميزة (wifi, pool, bbq, parking, ...)
class AmenityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  /// لو onChanged == null → وضع عرض فقط (read-only)
  final ValueChanged<bool>? onChanged;

  const AmenityChip({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isInteractive = onChanged != null;
    return GestureDetector(
      onTap: isInteractive ? () => onChanged!(!active) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryPale.withOpacity(0.35)
              : AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.sand,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 17,
                color: active ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? AppColors.primary : AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

/// شبكة المميزات — تعمل في وضع عرض (للتفاصيل) أو تعديل (للإضافة/التعديل)
class AmenitiesGrid extends StatelessWidget {
  final ChaletModel chalet;

  /// لو null → عرض فقط | لو مُعطى → تفاعلي
  final void Function(String amenity, bool value)? onChanged;

  const AmenitiesGrid({
    super.key,
    required this.chalet,
    this.onChanged,
  });

  static const _amenities = [
    (key: 'wifi', icon: Icons.wifi_rounded, label: 'واي فاي'),
    (key: 'pool', icon: Icons.pool_rounded, label: 'مسبح'),
    (key: 'bbq', icon: Icons.outdoor_grill_rounded, label: 'باربيكيو'),
    (key: 'parking', icon: Icons.local_parking_rounded, label: 'باركينج'),
  ];

  bool _isActive(String key, ChaletModel c) {
    switch (key) {
      case 'wifi':
        return c.hasWifi;
      case 'pool':
        return c.hasPool;
      case 'bbq':
        return c.hasBbq;
      case 'parking':
        return c.hasParking;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _amenities.map((a) {
        final active = _isActive(a.key, chalet);
        return AmenityChip(
          icon: a.icon,
          label: a.label,
          active: active,
          onChanged: onChanged != null ? (val) => onChanged!(a.key, val) : null,
        );
      }).toList(),
    );
  }
}
