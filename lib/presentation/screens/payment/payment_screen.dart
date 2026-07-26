import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/common_widgets.dart';

class PaymentScreen extends StatefulWidget {
  final ChaletModel chalet;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guestsCount;

  const PaymentScreen({
    super.key,
    required this.chalet,
    required this.checkIn,
    required this.checkOut,
    required this.guestsCount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _paymentMethod = 'cash';
  bool _loading = false;

  double? _totalPrice;
  double? _depositAmount;
  bool _priceLoading = true;
  String? _priceError;

  int get _nights => widget.checkOut.difference(widget.checkIn).inDays;

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  Future<void> _loadPrice() async {
    setState(() {
      _priceLoading = true;
      _priceError = null;
    });
    try {
      final price = await BookingService.instance.calculateBookingPrice(
        chaletId: widget.chalet.id,
        checkIn: widget.checkIn,
        checkOut: widget.checkOut,
        guestsCount: widget.guestsCount,
      );
      if (mounted) {
        setState(() {
          _totalPrice = price;
          _depositAmount = price * 0.30; // عربون 30%
          _priceLoading = false;
        });
      }
    } catch (e) {
      print('PRICE ERROR: $e');
      if (mounted) {
        setState(() {
          _priceError = e.toString();
          _priceLoading = false;
        });
      }
    }
  }

  Future<void> _confirm() async {
    if (_nights < 1) return;
    if (_loading) return;
    if (_totalPrice == null) return;

    setState(() => _loading = true);
    try {
      await BookingService.instance.createBooking(
        chaletId: widget.chalet.id,
        checkIn: widget.checkIn,
        checkOut: widget.checkOut,
        guestsCount: widget.guestsCount,
        paymentMethod: _paymentMethod,
        totalPrice: _totalPrice!,
        notes: null,
      );

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      print('BOOKING ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString(),
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFDFF0D8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.success,
                  size: 46,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                AppStrings.bookingSuccess,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                AppStrings.bookingSuccessMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/home');
                  },
                  child: const Text(
                    'العودة للرئيسية',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/home/bookings');
                },
                child: const Text(
                  'عرض حجوزاتي',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إتمام الحجز'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBookingSummary(),
            const SizedBox(height: 14),
            _buildPaymentSelection(),
            const SizedBox(height: 14),
            _buildPriceSummary(),
            const SizedBox(height: 20),
            AppButton(
              label: AppStrings.confirmBooking,
              onPressed:
                  (_priceLoading || _totalPrice == null) ? null : _confirm,
              loading: _loading,
              icon: Icons.check_circle_outline_rounded,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              widget.chalet.coverImage,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: AppColors.sand,
                child: const Icon(Icons.home_work_rounded,
                    color: AppColors.textHint),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chalet.name,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.date_range_outlined,
                        size: 13, color: AppColors.textHint),
                    const SizedBox(width: 3),
                    Text(
                      '${_fmt(widget.checkIn)} - ${_fmt(widget.checkOut)}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'الضيوف: ${widget.guestsCount} ضيف',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.paymentMethod,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _payOption(
            'cash',
            Icons.money_rounded,
            AppStrings.cashOnArrival,
            'نقداً عند وصولك للشاليه',
          ),
          const SizedBox(height: 8),
          _payOption(
            'card',
            Icons.credit_card_rounded,
            'دفع إلكتروني',
            'ادفع إلكترونياً بأمان عبر التطبيق',
          ),
        ],
      ),
    );
  }

  Widget _payOption(
    String value,
    IconData icon,
    String title,
    String sub,
  ) {
    final selected = _paymentMethod == value;

    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryPale.withOpacity(0.3)
              : AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.sand,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.sand,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : AppColors.textHint,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : AppColors.charcoal,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _paymentMethod,
              onChanged: (v) => setState(() => _paymentMethod = v!),
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryPale),
      ),
      child: _priceLoading
          ? const Center(child: CircularProgressIndicator())
          : _priceError != null
              ? Column(
                  children: [
                    Text(
                      _priceError!,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _loadPrice,
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'إعادة المحاولة',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    // سعر الليالي
                    _priceRow(
                      '${AppCurrency.formatPrice(widget.chalet.pricePerNight)} × $_nights ليلة',
                      AppCurrency.formatPrice(_totalPrice!),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    // المجموع الكلي
                    _priceRow(
                      'المجموع الكلي',
                      AppCurrency.formatPrice(_totalPrice!),
                      total: true,
                    ),
                    const SizedBox(height: 12),
                    // صندوق العربون
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFD54F)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 16, color: Color(0xFFF57F17)),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'تفاصيل الدفع',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF57F17),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _depositRow(
                            'عربون الآن (30%)',
                            AppCurrency.formatPrice(_depositAmount!),
                            color: const Color(0xFFE65100),
                          ),
                          const SizedBox(height: 4),
                          _depositRow(
                            'الباقي عند الوصول (70%)',
                            AppCurrency.formatPrice(_totalPrice! - _depositAmount!),
                            color: Colors.black87,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _priceRow(String label, String value, {bool total = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: total ? 15 : 13,
            fontWeight: total ? FontWeight.w800 : FontWeight.w500,
            color: total ? AppColors.charcoal : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: total ? 18 : 14,
            fontWeight: FontWeight.w900,
            color: total ? AppColors.primary : AppColors.charcoal,
          ),
        ),
      ],
    );
  }

  Widget _depositRow(String label, String value, {required Color color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime d) => DateFormat('d/M/yyyy').format(d);
}
