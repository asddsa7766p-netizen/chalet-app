import 'package:flutter/material.dart';
import 'package:makan/data/models/booking_payment_details.dart';

import '../../../core/utils/support_contact.dart';
import '../theme/payment_theme.dart';
import '../widgets/payment_widgets.dart';
import 'card_details_screen.dart';
import 'payment_processing_screen.dart';

/// شاشة (2): اختيار طريقة الدفع (بطاقة انتمانية/مدى أو محفظة إلكترونية)
class PaymentMethodScreen extends StatefulWidget {
  final BookingPaymentDetails booking;

  const PaymentMethodScreen({super.key, required this.booking});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  PaymentMethodType _selected = PaymentMethodType.cardVisaMastercardMada;

  void _continue() {
    if (_selected == PaymentMethodType.cardVisaMastercardMada) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CardDetailsScreen(booking: widget.booking),
        ),
      );
    } else {
      // الدفع عبر محفظة إلكترونية لا يحتاج شاشة إدخال بيانات — يروح مباشرة للمعالجة
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentProcessingScreen(
            booking: widget.booking,
            walletType: PaymentMethodType.paypal,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: PaymentColors.background,
        appBar: const PaymentAppBar(),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PaymentSpacing.screenPadding,
              8,
              PaymentSpacing.screenPadding,
              16,
            ),
            child: PrimaryButton(label: 'متابعة', onPressed: _continue),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(PaymentSpacing.screenPadding),
            children: [
              Text('اختر طريقة الدفع', style: PaymentTextStyles.sectionTitle),
              const SizedBox(height: 16),
              _MethodOption(
                isSelected:
                    _selected == PaymentMethodType.cardVisaMastercardMada,
                title: 'بطاقة ائتمانية / مدى',
                onTap: () => setState(
                  () => _selected = PaymentMethodType.cardVisaMastercardMada,
                ),
                trailing: const _CardLogosRow(),
              ),
              const SizedBox(height: 12),
              _MethodOption(
                isSelected: _selected == PaymentMethodType.paypal,
                title: 'محفظة إلكترونية',
                onTap: () =>
                    setState(() => _selected = PaymentMethodType.paypal),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.account_balance_wallet_outlined,
                        color: Color(0xFF003087)),
                    SizedBox(width: 6),
                    Text('PayPal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003087),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.verified_outlined,
                      size: 14, color: PaymentColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('طرق دفع آمنة ومعتمدة',
                      style: PaymentTextStyles.bodySecondary),
                ],
              ),
              const SizedBox(height: PaymentSpacing.sectionGap),
              Text('مزايا الحجز مع مكان',
                  style: PaymentTextStyles.sectionTitle),
              const SizedBox(height: 12),
              const _BenefitRow(
                  icon: Icons.verified_user_outlined, text: 'حجز آمن 100%'),
              const _BenefitRow(
                  icon: Icons.event_available_outlined,
                  text: 'إلغاء مجاني وفق سياسة المكان'),
              // لا وعد بدعم متواصل ما دامت قنوات الدعم غير معرَّفة.
              if (SupportContact.hasAny)
                const _BenefitRow(
                    icon: Icons.headset_mic_outlined,
                    text: 'دعم متواصل على مدار الساعة'),
              const SizedBox(height: 32),
              const Center(child: BrandLogo(logoSize: 56)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  final bool isSelected;
  final String title;
  final VoidCallback onTap;
  final Widget trailing;

  const _MethodOption({
    required this.isSelected,
    required this.title,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PaymentSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(PaymentSpacing.cardPadding),
        decoration: BoxDecoration(
          color: PaymentColors.cardBackground,
          borderRadius: BorderRadius.circular(PaymentSpacing.radiusMd),
          border: Border.all(
            color: isSelected
                ? PaymentColors.primaryDark
                : PaymentColors.borderLight,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? PaymentColors.primaryDark
                  : PaymentColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: PaymentTextStyles.body)),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _CardLogosRow extends StatelessWidget {
  const _CardLogosRow();

  @override
  Widget build(BuildContext context) {
    // بدائل نصية بسيطة بدل شعارات الشركات (Visa/Mastercard/mada) لتفادي حقوق الملكية.
    // استبدلها بالأصول الرسمية (assets/icons) الموجودة عندك بالمشروع إن وجدت.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniLogo(label: 'VISA', color: Color(0xFF1A1F71)),
        SizedBox(width: 6),
        _MiniLogo(label: 'MC', color: Color(0xFFEB001B)),
        SizedBox(width: 6),
        _MiniLogo(label: 'mada', color: Color(0xFF6BAA75)),
      ],
    );
  }
}

class _MiniLogo extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniLogo({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: PaymentColors.primaryDark),
          const SizedBox(width: 10),
          Text(text, style: PaymentTextStyles.body),
        ],
      ),
    );
  }
}
