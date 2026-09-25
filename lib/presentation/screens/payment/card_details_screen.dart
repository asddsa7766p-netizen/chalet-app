import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:makan/data/models/booking_payment_details.dart';

import '../theme/payment_theme.dart';
import '../widgets/payment_widgets.dart';
import 'payment_processing_screen.dart';

/// شاشة (3): إدخال بيانات البطاقة
class CardDetailsScreen extends StatefulWidget {
  final BookingPaymentDetails booking;

  const CardDetailsScreen({super.key, required this.booking});

  @override
  State<CardDetailsScreen> createState() => _CardDetailsScreenState();
}

class _CardDetailsScreenState extends State<CardDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final f = NumberFormat('#,##0', 'en_US');
    return '${f.format(amount)} ₪';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final cardInput = CardPaymentInput(
      cardNumber: _cardNumberController.text.replaceAll(' ', ''),
      cardHolderName: _cardHolderController.text.trim(),
      expiryMonthYear: _expiryController.text.trim(),
      cvv: _cvvController.text.trim(),
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentProcessingScreen(
          booking: widget.booking,
          card: cardInput,
        ),
      ),
    );
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(PaymentSpacing.cardPadding),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: PaymentColors.cardBackground,
                    borderRadius:
                        BorderRadius.circular(PaymentSpacing.radiusMd),
                    border: Border.all(color: PaymentColors.borderLight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'شامل الضريبة والرسوم',
                        style: PaymentTextStyles.bodySecondary,
                      ),
                      Text(
                        'الإجمالي الكلي  ${_formatCurrency(widget.booking.totalAmount)}',
                        style: PaymentTextStyles.amountLarge,
                      ),
                    ],
                  ),
                ),
                PrimaryButton(
                  label: 'ادفع الآن',
                  trailingIcon: Icons.lock_outline,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(PaymentSpacing.screenPadding),
              children: [
                Text('بيانات البطاقة', style: PaymentTextStyles.sectionTitle),
                const SizedBox(height: 16),
                _FieldLabel('رقم البطاقة'),
                TextFormField(
                  controller: _cardNumberController,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                    _CardNumberFormatter(),
                  ],
                  decoration: _inputDecoration('1234 5678 9012 3456').copyWith(
                      suffixIcon: const Icon(Icons.credit_card_outlined)),
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(' ', '');
                    if (digits.length != 16)
                      return 'رقم البطاقة يجب أن يتكون من 16 رقم';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _FieldLabel('الاسم على البطاقة'),
                TextFormField(
                  controller: _cardHolderController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration('الاسم كما هو على البطاقة'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'الرجاء إدخال اسم حامل البطاقة'
                      : null,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('تاريخ الانتهاء'),
                          TextFormField(
                            controller: _expiryController,
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                              _ExpiryDateFormatter(),
                            ],
                            decoration: _inputDecoration('MM / YY'),
                            validator: (v) {
                              final val = v ?? '';
                              final regex = RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$');
                              if (!regex.hasMatch(val)) return 'تاريخ غير صالح';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('رمز التحقق (CVV)'),
                          TextFormField(
                            controller: _cvvController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            textDirection: TextDirection.ltr,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: _inputDecoration('123').copyWith(
                              suffixIcon:
                                  const Icon(Icons.help_outline, size: 18),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 3)
                                return 'رمز غير صالح';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // أُخفي خيار "حفظ البطاقة": لا يوجد أي حفظ فعلي للبطاقات.
                Container(
                  padding: const EdgeInsets.all(PaymentSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: PaymentColors.cardBackground,
                    borderRadius:
                        BorderRadius.circular(PaymentSpacing.radiusMd),
                    border: Border.all(color: PaymentColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          color: PaymentColors.primaryDark),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'بياناتك مشفرة وآمنة، نستخدم تشفير عالي المستوى لحماية معلوماتك أثناء عملية الدفع.',
                          style: PaymentTextStyles.bodySecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintTextDirection: TextDirection.ltr,
      filled: true,
      fillColor: PaymentColors.cardBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PaymentSpacing.radiusMd),
        borderSide: const BorderSide(color: PaymentColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PaymentSpacing.radiusMd),
        borderSide: const BorderSide(color: PaymentColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PaymentSpacing.radiusMd),
        borderSide:
            const BorderSide(color: PaymentColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PaymentSpacing.radiusMd),
        borderSide: const BorderSide(color: PaymentColors.error),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: PaymentTextStyles.label),
    );
  }
}

/// يضيف مسافة كل 4 أرقام: 1234 5678 9012 3456
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if ((i + 1) % 4 == 0 && i + 1 != digits.length) buffer.write(' ');
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

/// يحوّل MMYY إلى MM/YY أثناء الكتابة
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('/', '');
    String formatted = digits;
    if (digits.length >= 3) {
      formatted = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
