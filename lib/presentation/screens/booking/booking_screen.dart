import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/common_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BookingScreen extends StatefulWidget {
  final ChaletModel chalet;
  const BookingScreen({super.key, required this.chalet});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? _checkIn;
  DateTime? _checkOut;
  int _guests = 2;
  String _paymentMethod = 'cash';
  bool _loading = false;
  bool _showCalendar = false;
  bool _selectingCheckIn = true;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  int get _nights => _checkIn != null && _checkOut != null
      ? _checkOut!.difference(_checkIn!).inDays
      : 0;

  double get _total => _nights * widget.chalet.pricePerNight;

  Future<void> _confirm() async {
    if (_checkIn == null || _checkOut == null) {
      _showSnack('يرجى تحديد تواريخ الوصول والمغادرة');
      return;
    }
    if (_nights < 1) {
      _showSnack('يجب أن تكون مدة الإقامة ليلة واحدة على الأقل');
      return;
    }

    setState(() => _loading = true);
    try {
      // Check availability
      final available = await ChaletService.instance.isAvailable(
        chaletId: widget.chalet.id,
        checkIn: _checkIn!,
        checkOut: _checkOut!,
      );
      if (!available) {
        _showSnack('الشاليه غير متاح في التواريخ المحددة');
        return;
      }

      await BookingService.instance.createBooking(
        chaletId: widget.chalet.id,
        checkIn: _checkIn!,
        checkOut: _checkOut!,
        guestsCount: _guests,
        totalPrice: _total,
        paymentMethod: _paymentMethod,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      );

      if (mounted) _showSuccessDialog();
    } catch (e) {
      _showSnack('حدث خطأ أثناء الحجز، يرجى المحاولة مجدداً');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
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
                    color: Color(0xFFDFF0D8), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.success, size: 46),
              ),
              const SizedBox(height: 20),
              const Text(AppStrings.bookingSuccess,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.charcoal)),
              const SizedBox(height: 10),
              const Text(AppStrings.bookingSuccessMsg,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/home');
                  },
                  child: const Text('العودة للرئيسية',
                      style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/home');
                },
                child: const Text('عرض حجوزاتي',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
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
        title: const Text('تفاصيل الحجز'),
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
            // Chalet Summary Card
            _buildChaletSummary(),
            const SizedBox(height: 14),

            // Dates Section
            _buildDatesSection(),
            const SizedBox(height: 14),

            // Guests
            _buildGuestsSection(),
            const SizedBox(height: 14),

            // Payment
            _buildPaymentSection(),
            const SizedBox(height: 14),

            // Notes
            _buildNotesSection(),
            const SizedBox(height: 14),

            // Price Summary
            if (_nights > 0) _buildPriceSummary(),
            const SizedBox(height: 20),

            // Confirm Button
            AppButton(
              label: AppStrings.confirmBooking,
              onPressed: _confirm,
              loading: _loading,
              icon: Icons.check_circle_outline_rounded,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildChaletSummary() {
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
            child: CachedNetworkImage(
              imageUrl: widget.chalet.mainImage,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: const Icon(
                  Icons.home_work_rounded,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.chalet.name,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: AppColors.textHint),
                  const SizedBox(width: 3),
                  Text(widget.chalet.city,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ]),
                const SizedBox(height: 6),
                Text(
                    '₪${widget.chalet.pricePerNight.toStringAsFixed(0)} / ليلة',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesSection() {
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
          const Text('مواعيد الإقامة',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _dateBox(
                label: 'تاريخ الوصول',
                date: _checkIn,
                onTap: () => setState(() {
                  _selectingCheckIn = true;
                  _showCalendar = true;
                }),
                highlight: _selectingCheckIn && _showCalendar,
              )),
              Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.textHint, size: 20)),
              Expanded(
                  child: _dateBox(
                label: 'تاريخ المغادرة',
                date: _checkOut,
                onTap: () => setState(() {
                  _selectingCheckIn = false;
                  _showCalendar = true;
                }),
                highlight: !_selectingCheckIn && _showCalendar,
              )),
            ],
          ),
          if (_showCalendar) ...[
            const SizedBox(height: 12),
            const Divider(),
            TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _checkIn ?? DateTime.now(),
              selectedDayPredicate: (day) {
                if (_selectingCheckIn) return isSameDay(_checkIn, day);
                return isSameDay(_checkOut, day);
              },
              rangeStartDay: _checkIn,
              rangeEndDay: _checkOut,
              calendarFormat: CalendarFormat.month,
              rangeSelectionMode: RangeSelectionMode.toggledOn,
              onDaySelected: (selected, focused) {
                setState(() {
                  if (_selectingCheckIn) {
                    _checkIn = selected;
                    _checkOut = null;
                    _selectingCheckIn = false;
                  } else {
                    if (selected.isAfter(_checkIn ?? DateTime.now())) {
                      _checkOut = selected;
                      _showCalendar = false;
                    } else {
                      _checkIn = selected;
                    }
                  }
                });
              },
              calendarStyle: const CalendarStyle(
                selectedDecoration: BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                rangeHighlightColor: AppColors.primaryPale,
                rangeStartDecoration: BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                rangeEndDecoration: BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(
                    color: AppColors.accent, shape: BoxShape.circle),
                defaultTextStyle: TextStyle(fontFamily: 'Cairo'),
                weekendTextStyle:
                    TextStyle(fontFamily: 'Cairo', color: AppColors.error),
              ),
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle:
                    TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
              ),
            ),
          ],
          if (_nights > 0)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryPale.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('مدة الإقامة: $_nights ليالٍ',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Widget _dateBox(
      {required String label,
      DateTime? date,
      required VoidCallback onTap,
      bool highlight = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.primaryPale.withOpacity(0.3)
              : AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight ? AppColors.primary : AppColors.sand,
            width: highlight ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              date != null
                  ? '${date.day}/${date.month}/${date.year}'
                  : 'اختر التاريخ',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      date != null ? AppColors.charcoal : AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('عدد الضيوف',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            Text('الحد الأقصى: ${widget.chalet.maxGuests} ضيف',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.textSecondary)),
          ]),
          Row(
            children: [
              _circleBtn(Icons.remove_rounded, () {
                if (_guests > 1) setState(() => _guests--);
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('$_guests',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.charcoal)),
              ),
              _circleBtn(Icons.add_rounded, () {
                if (_guests < widget.chalet.maxGuests) {
                  setState(() => _guests++);
                }
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
    );
  }

  Widget _buildPaymentSection() {
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
          const Text(AppStrings.paymentMethod,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _payOption('cash', Icons.money_rounded, AppStrings.cashOnArrival,
              'ادفع نقداً عند وصولك للشاليه'),
          const SizedBox(height: 8),
          _payOption('online', Icons.credit_card_rounded,
              AppStrings.onlinePayment, 'ادفع إلكترونياً بأمان عبر التطبيق'),
        ],
      ),
    );
  }

  Widget _payOption(String value, IconData icon, String title, String sub) {
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
              child: Icon(icon,
                  color: selected ? Colors.white : AppColors.textHint,
                  size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.primary
                                : AppColors.charcoal)),
                    Text(sub,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ]),
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

  Widget _buildNotesSection() {
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
          const Text('ملاحظات إضافية (اختياري)',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          CustomTextField(
            controller: _notesCtrl,
            label: '',
            hint: 'أي طلبات أو ملاحظات خاصة...',
            maxLines: 3,
          ),
        ],
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
      child: Column(
        children: [
          _priceRow(
              '₪${widget.chalet.pricePerNight.toStringAsFixed(0)} × $_nights ليلة',
              '₪${_total.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _priceRow('المجموع الكلي', '₪${_total.toStringAsFixed(0)}',
              total: true),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool total = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: total ? 15 : 13,
                fontWeight: total ? FontWeight.w800 : FontWeight.w500,
                color: total ? AppColors.charcoal : AppColors.textSecondary)),
        Text(value,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: total ? 18 : 14,
                fontWeight: FontWeight.w900,
                color: total ? AppColors.primary : AppColors.charcoal)),
      ],
    );
  }
}
