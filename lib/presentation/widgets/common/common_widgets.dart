import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/chalet_model.dart';

// ============================================
// APP BUTTON
// ============================================
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outline;
  final Color? color;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.outline = false,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (outline) {
      return OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
        label: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color ?? AppColors.primary,
          side: BorderSide(color: color ?? AppColors.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppColors.primary,
        disabledBackgroundColor: AppColors.primaryLight.withOpacity(0.5),
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8)
                ],
                Text(label),
              ],
            ),
    );
  }
}

// ============================================
// CUSTOM TEXT FIELD
// ============================================
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final void Function(String)? onChanged;
  final bool enabled;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      onChanged: onChanged,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.textHint, size: 20)
            : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ============================================
// APP LOGO
// ============================================
class AppLogo extends StatelessWidget {
  final bool dark;
  const AppLogo({super.key, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withOpacity(0.1)
                : AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  dark ? Colors.white.withOpacity(0.2) : AppColors.primaryPale,
              width: 1.5,
            ),
          ),
          child: Icon(Icons.home_work_rounded,
              size: 38, color: dark ? AppColors.accent : AppColors.primary),
        ),
        const SizedBox(height: 10),
        Text(AppStrings.appName,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: dark ? Colors.white : AppColors.primary,
            )),
        Text(AppStrings.appTagline,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: dark
                  ? Colors.white.withOpacity(0.6)
                  : AppColors.textSecondary,
            )),
      ],
    );
  }
}

// ============================================
// CHALET CARD
// ============================================
class ChaletCard extends StatelessWidget {
  final ChaletModel chalet;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onTap;
  final bool horizontal;

  /// Fixed height to keep images consistent and avoid cutting.
  final double fixedHeight;

  const ChaletCard({
    super.key,
    required this.chalet,
    this.isFavorite = false,
    this.onFavoriteTap,
    this.onTap,
    this.horizontal = false,
    this.fixedHeight = 300,
  });

  @override
  Widget build(BuildContext context) {
    if (horizontal) return _buildHorizontal(context);
    return _buildVertical(context);
  }

  Widget _buildVertical(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.sand),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            SizedBox(
              height: fixedHeight * 0.62,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(15)),
                    child: CachedNetworkImage(
                      imageUrl: chalet.mainImage,
                      height: fixedHeight * 0.62,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Shimmer.fromColors(
                        baseColor: AppColors.sand,
                        highlightColor: AppColors.cream,
                        child: Container(
                          height: fixedHeight * 0.62,
                          color: AppColors.sand,
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: fixedHeight * 0.62,
                        color: AppColors.sand,
                        child: const Icon(
                          Icons.home_work_rounded,
                          size: 40,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  ),

                  // City badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        chalet.city,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Favorite
                  Positioned(
                    top: 10,
                    left: 10,
                    child: GestureDetector(
                      onTap: onFavoriteTap,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color:
                              isFavorite ? AppColors.error : AppColors.textHint,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chalet.name,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Expanded(
                          child: Text(chalet.location,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textHint,
                                  fontFamily: 'Cairo'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Amenities
                      if (chalet.hasPool) _chip(Icons.pool_rounded, 'مسبح'),
                      if (chalet.hasBbq)
                        _chip(Icons.outdoor_grill_rounded, 'شواء'),
                      if (chalet.hasWifi) _chip(Icons.wifi_rounded, 'واي فاي'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Rating
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppColors.accent),
                          const SizedBox(width: 3),
                          Text(chalet.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Cairo',
                                  color: AppColors.charcoal)),
                          Text(' (${chalet.reviewsCount})',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textHint,
                                  fontFamily: 'Cairo')),
                        ],
                      ),
                      // Price
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  '₪${chalet.pricePerNight.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary),
                            ),
                            const TextSpan(
                              text: '/ليلة',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sand),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(13),
                bottomRight: Radius.circular(13),
              ),
              child: CachedNetworkImage(
                imageUrl: chalet.mainImage,
                width: 110,
                height: 110,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(width: 110, height: 110, color: AppColors.sand),
                errorWidget: (_, __, ___) => Container(
                    width: 110,
                    height: 110,
                    color: AppColors.sand,
                    child: const Icon(Icons.home_work_rounded)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(chalet.name,
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                        GestureDetector(
                          onTap: onFavoriteTap,
                          child: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFavorite
                                  ? AppColors.error
                                  : AppColors.textHint,
                              size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: AppColors.textHint),
                      const SizedBox(width: 2),
                      Text(chalet.city,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                              fontFamily: 'Cairo')),
                    ]),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(Icons.star_rounded,
                              size: 13, color: AppColors.accent),
                          const SizedBox(width: 2),
                          Text(chalet.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Cairo')),
                        ]),
                        Text('₪${chalet.pricePerNight.toStringAsFixed(0)}/ليلة',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryPale.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 11, color: AppColors.primary),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, fontFamily: 'Cairo', color: AppColors.primary)),
        ],
      ),
    );
  }
}

// ============================================
// SECTION HEADER
// ============================================
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader(
      {super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

// ============================================
// SHIMMER LOADING CARD
// ============================================
class ShimmerCard extends StatelessWidget {
  final double height;
  const ShimmerCard({super.key, this.height = 260});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.sand,
      highlightColor: AppColors.cream,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.sand,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
