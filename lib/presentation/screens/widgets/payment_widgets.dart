import 'package:flutter/material.dart';
import '../theme/payment_theme.dart';

/// زر أساسي بلون أخضر زيتوني، مطابق لأزرار "متابعة للدفع" / "ادفع الآن"
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: PaymentColors.primaryDark,
          disabledBackgroundColor: PaymentColors.primaryDark.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PaymentSpacing.radiusMd),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: PaymentTextStyles.buttonText),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailingIcon, color: Colors.white, size: 18),
                  ],
                ],
              ),
      ),
    );
  }
}

/// زر ثانوي بحدود فقط (زي "غيّر طريقة الدفع" و"حاول مرة أخرى" بشاشة الفشل)
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? borderColor;
  final Color? textColor;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor ?? PaymentColors.primaryDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PaymentSpacing.radiusMd),
          ),
        ),
        child: Text(
          label,
          style: PaymentTextStyles.buttonText.copyWith(
            color: textColor ?? PaymentColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

/// صف "ملخص الدفع" (سعر الليلة، عدد الليالي، الإضافات...)
class SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle =
        isTotal ? PaymentTextStyles.amountLarge : PaymentTextStyles.body;
    final labelStyle = isTotal
        ? PaymentTextStyles.sectionTitle
        : PaymentTextStyles.bodySecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value, style: valueStyle),
          Text(label, style: labelStyle),
        ],
      ),
    );
  }
}

/// مؤشر الخطوات (1 اختيار التفاصيل - 2 المراجعة - 3 الدفع)
class PaymentStepIndicator extends StatelessWidget {
  final int currentStep; // 1, 2, or 3

  const PaymentStepIndicator({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final steps = [
      {'n': 1, 'label': 'اختيار التفاصيل'},
      {'n': 2, 'label': 'المراجعة'},
      {'n': 3, 'label': 'الدفع'},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: steps.map((s) {
        final n = s['n'] as int;
        final isActive = n == currentStep;
        final isDone = n < currentStep;
        return Column(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isActive || isDone)
                    ? PaymentColors.primaryDark
                    : PaymentColors.borderLight,
              ),
              child: Text(
                '$n',
                style: TextStyle(
                  fontFamily: PaymentTextStyles.fontFamily,
                  fontWeight: FontWeight.bold,
                  color: (isActive || isDone)
                      ? Colors.white
                      : PaymentColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s['label'] as String,
              style: PaymentTextStyles.label.copyWith(
                color: isActive
                    ? PaymentColors.textPrimary
                    : PaymentColors.textSecondary,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// كرت ملخّص الشاليه (صورة + اسم + موقع + تواريخ) المستخدم بأكثر من شاشة
class ChaletSummaryCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String location;
  final String datesLabel;
  final String guestsLabel;

  const ChaletSummaryCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.location,
    required this.datesLabel,
    required this.guestsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PaymentSpacing.cardPadding),
      decoration: BoxDecoration(
        color: PaymentColors.cardBackground,
        borderRadius: BorderRadius.circular(PaymentSpacing.radiusMd),
        border: Border.all(color: PaymentColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imageUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 72,
                height: 72,
                color: PaymentColors.borderLight,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: PaymentTextStyles.sectionTitle),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: PaymentColors.textSecondary),
                    const SizedBox(width: 2),
                    Text(location, style: PaymentTextStyles.bodySecondary),
                  ],
                ),
                const SizedBox(height: 6),
                Text(datesLabel, style: PaymentTextStyles.bodySecondary),
                const SizedBox(height: 2),
                Text(guestsLabel, style: PaymentTextStyles.bodySecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// شريط علوي موحّد لكل شاشات الدفع (سهم رجوع + عنوان "الدفع")
class PaymentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final VoidCallback? onBack;

  const PaymentAppBar({super.key, this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: PaymentColors.background,
      elevation: 0,
      centerTitle: true,
      title: Text(title ?? 'الدفع', style: PaymentTextStyles.screenTitle),
      leading: IconButton(
        // التصميم يعرض السهم متجهاً لليسار دائماً بغض النظر عن اتجاه RTL
        icon: const Icon(Icons.arrow_back, color: PaymentColors.textPrimary),
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// ضيف هاد الكلاس بآخر ملف payment_widgets.dart عندك (نفس الملف
/// يلي فيه PrimaryButton وSecondaryButton وباقي الـwidgets المشتركة)

/// شعار "مكان" + اسم التطبيق بخط جميل، يُستخدم بشاشتي اختيار طريقة
/// الدفع ومعالجة الدفع (مطابق للتصميم الأصلي).
class BrandLogo extends StatelessWidget {
  final double logoSize;
  final bool showName;

  const BrandLogo({
    super.key,
    this.logoSize = 64,
    this.showName = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.home_work_outlined,
            size: logoSize,
            color: PaymentColors.primaryDark,
          ),
        ),
        if (showName) ...[
          const SizedBox(height: 10),
          Text(
            'مكان',
            style: TextStyle(
              fontFamily: PaymentTextStyles.fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: PaymentColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
