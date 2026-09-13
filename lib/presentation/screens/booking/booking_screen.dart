import 'dart:async';
import 'package:flutter/material.dart';
import 'package:makan/data/services/pricing_service.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/pricing_constants.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/common_widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BookingScreen extends StatefulWidget {
  final ChaletModel? chalet;
  final String? chaletId;
  const BookingScreen({super.key, this.chalet, this.chaletId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const Color _darkGreen = Color(0xFF3D5228);

  DateTime? _checkIn;
  DateTime? _checkOut;

  // ⚠️ الديزاين يفصل عدد الضيوف لـ 3 فئات (رضع/أطفال/بالغين)، لكن
  // الـ Backend الحالي (BookingService.createBooking) بياخد رقم واحد
  // فقط guestsCount. حافظت على _guests كإجمالي فعلي بيروح للسيرفر،
  // وضفت عدادين إضافيين (UI فقط) للأطفال والرضّع بيندمجوا مع البالغين
  // بحساب الإجمالي. إذا بدك الرضّع/الأطفال يوصلوا فعليًا لقاعدة
  // البيانات، لازم تضيف الحقول دي بجدول bookings وبـ BookingService.
  int _adults = 2;
  int _children = 1;
  int _infants = 0;
  int get _guests => _adults + _children;

  String _paymentMethod = 'cash';
  bool _loading = false;
  bool _showCalendar = false;
  bool _selectingCheckIn = true;

  bool _priceLoading = false;
  double? _serverTotalPrice;
  bool _isAvailable = true;
  String? _availabilityError;
  bool _serverCalculated = false;

  Set<DateTime> _bookedDates = {};

  bool _stayTypesLoading = true;
  List<ChaletStayTypeConfig> _enabledStayTypes = [];
  String _selectedStayType = BookingService.defaultStayType;

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  int _monthPricingRequestId = 0;

  // ✅ إصلاح: نفس فكرة _monthPricingRequestId لكن لطلبات حساب السعر/التوفر.
  // بدونه، لو المستخدم غيّر التواريخ بسرعة، طلب قديم بيرجع متأخر
  // ممكن يكتب فوق نتيجة طلب أحدث ويعرض سعر غلط.
  int _priceRequestId = 0;

  Timer? _guestsDebounce;

  final _notesCtrl = TextEditingController();

  // ✅ إصلاح: حالة تحميل/خطأ صريحة لجلب بيانات الشاليه لما توصل الشاشة
  // بـ chaletId فقط (بدون كائن ChaletModel جاهز)، بدل ما تبني الشاشة
  // بواجهة فاضية/مكسورة لحد ما توصل البيانات.
  bool _chaletLoading = false;
  bool _chaletLoadError = false;

  @override
  void dispose() {
    _guestsDebounce?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  ChaletModel? _chalet;
  String get _chaletId => _chalet?.id ?? widget.chaletId ?? '';
  ChaletModel? get _chaletModel => _chalet ?? widget.chalet;

  int get _nights => _checkIn != null && _checkOut != null
      ? _checkOut!.difference(_checkIn!).inDays
      : 0;

  double? get _total => _serverTotalPrice;

  bool get _canConfirm =>
      _isAvailable &&
      !_priceLoading &&
      _serverTotalPrice != null &&
      _serverCalculated &&
      _checkIn != null &&
      _checkOut != null &&
      _nights > 0;

  /// UI-level confirmation availability.
  /// For online payments we allow proceeding to the payment flow even if
  /// server-side price calculation is still pending (mock payment path).
  bool get _canConfirmForUI {
    if (_paymentMethod == 'online') {
      return _isAvailable &&
          _checkIn != null &&
          _checkOut != null &&
          _nights > 0;
    }
    return _canConfirm;
  }

  Future<void> _fetchServerPrice() async {
    if (_checkIn == null || _checkOut == null) return;
    if (_nights < 1) return;

    final requestId = ++_priceRequestId;

    setState(() {
      _priceLoading = true;
      _availabilityError = null;
      _serverTotalPrice = null;
      _isAvailable = true;
      _serverCalculated = false;
    });

    try {
      final available = await ChaletService.instance.isAvailable(
        chaletId: _chaletId,
        checkIn: _checkIn!,
        checkOut: _checkOut!,
      );

      if (!mounted) return;
      // ✅ إصلاح: تجاهل نتيجة أي طلب قديم إذا صار في طلب أحدث بعده.
      if (requestId != _priceRequestId) return;

      if (!available) {
        setState(() {
          _serverTotalPrice = null;
          _isAvailable = false;
          _serverCalculated = false;
          _availabilityError = 'عذراً، هذا الشاليه محجوز في التواريخ المحددة';
          _priceLoading = false;
        });
        return;
      }
    } catch (_) {
      if (!mounted) return;
      if (requestId != _priceRequestId) return;
      setState(() {
        _serverTotalPrice = null;
        _isAvailable = false;
        _serverCalculated = false;
        _availabilityError =
            'تعذر التحقق من التوفر حالياً، يرجى المحاولة لاحقاً';
        _priceLoading = false;
      });
      return;
    }

    try {
      final price = await BookingService.instance.calculateBookingPrice(
        chaletId: _chaletId,
        checkIn: _checkIn!,
        checkOut: _checkOut!,
        guestsCount: _guests,
        stayType: _selectedStayType,
      );

      if (!mounted) return;
      if (requestId != _priceRequestId) return;
      setState(() {
        _serverTotalPrice = price;
        _isAvailable = true;
        _availabilityError = null;
        _serverCalculated = true;
      });
    } catch (e) {
      if (!mounted) return;
      if (requestId != _priceRequestId) return;
      final msg = e.toString();
      final is409 = msg.contains('409');

      setState(() {
        _serverTotalPrice = null;
        _isAvailable = is409;
        _serverCalculated = false;
        _availabilityError = is409
            ? 'عذراً، هذا الشاليه محجوز في التواريخ المحددة'
            : 'تعذر حساب السعر حالياً، يرجى المحاولة لاحقاً';
      });
    } finally {
      if (mounted && requestId == _priceRequestId) {
        setState(() => _priceLoading = false);
      }
    }
  }

  Future<void> _loadStayTypes() async {
    setState(() => _stayTypesLoading = true);
    try {
      final types =
          await ChaletPricingService.instance.getEnabledStayTypes(_chaletId);
      if (!mounted) return;
      setState(() {
        _enabledStayTypes = types;
        if (types.isNotEmpty) {
          _selectedStayType = types.first.type.dbValue;
        }
      });
    } catch (_) {
      // ⚠️ فشل صامت مقصود: نوع الإقامة ثانوي (تصير الشاشة تعتمد على
      // BookingService.defaultStayType)، لكن يفضّل تسجيله عبر Logging
      // بدل تجاهله كلياً حتى تقدروا تكتشفوا الأعطال بالسيرفر.
    } finally {
      if (mounted) setState(() => _stayTypesLoading = false);
    }
  }

  Future<void> _onStayTypeSelected(String stayType) async {
    if (stayType == _selectedStayType) return;
    setState(() {
      _selectedStayType = stayType;
      _serverCalculated = false;
      _serverTotalPrice = null;
    });
    await _loadMonthPricing(_visibleMonth);
    if (_checkIn != null && _checkOut != null && _nights > 0) {
      await _fetchServerPrice();
    }
  }

  Future<void> _loadMonthPricing(DateTime month) async {
    final requestId = ++_monthPricingRequestId;
    final stayTypeForThisRequest = _selectedStayType;

    try {
      await ChaletPricingService.instance.getMonthPricing(
        chaletId: _chaletId,
        year: month.year,
        month: month.month,
        defaultPrice: _chaletModel?.pricePerNight ?? 0,
        stayType: stayTypeForThisRequest,
      );
      if (!mounted) return;
      if (requestId != _monthPricingRequestId) return;

      setState(() {
        _visibleMonth = month;
      });
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _chalet = widget.chalet;
    if (_chalet == null && widget.chaletId != null) {
      _chaletLoading = true;
      _loadChaletById(widget.chaletId!);
    } else {
      _loadStayTypes().then((_) {
        _loadMonthPricing(_visibleMonth);
        _fetchServerPrice();
      });
    }
    // ✅ إصلاح: كان استدعاء _fetchBookedDates() يحصل فقط بالمسار اللي
    // بيوصل فيه widget.chalet جاهز مباشرة (else branch)، فإذا الشاشة
    // فُتحت بـ chaletId فقط، تبقى _bookedDates فاضية للأبد، وبالتالي
    // enabledDayPredicate ما بيعطّل أي تاريخ محجوز بالتقويم. نقلتها هون
    // عشان تشتغل دايماً بمجرد ما نعرف الـ chaletId، بغض النظر عن المصدر.
    _fetchBookedDates();
  }

  Future<void> _loadChaletById(String id) async {
    try {
      final c = await ChaletService.instance.getChaletById(id);
      if (!mounted) return;
      setState(() {
        _chalet = c;
        _chaletLoading = false;
        _chaletLoadError = c == null;
      });
      if (c != null) {
        _loadStayTypes().then((_) {
          _loadMonthPricing(_visibleMonth);
          _fetchServerPrice();
        });
      }
    } catch (_) {
      // ✅ إصلاح: كان الخطأ يُبلع بصمت (catchError فاضي) والمستخدم يضل
      // شايف مؤشر تحميل بدون أي تفسير أو طريقة لإعادة المحاولة.
      if (!mounted) return;
      setState(() {
        _chaletLoading = false;
        _chaletLoadError = true;
      });
    }
  }

  @override
  void didUpdateWidget(covariant BookingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.chalet?.id ?? oldWidget.chaletId;
    final newId = widget.chalet?.id ?? widget.chaletId;
    if (newId != oldId) {
      setState(() => _serverCalculated = false);
      _loadStayTypes().then((_) {
        _loadMonthPricing(_visibleMonth);
        _fetchServerPrice();
      });
      _fetchBookedDates();
    }
  }

  void _onGuestsChanged() {
    _guestsDebounce?.cancel();
    _guestsDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_checkIn != null && _checkOut != null && _nights > 0) {
        _fetchServerPrice();
      }
    });
  }

  Future<void> _confirm() async {
    if (_loading) return;
    if (_checkIn == null || _checkOut == null) {
      _showSnack('يرجى تحديد تواريخ الوصول والمغادرة');
      return;
    }
    if (_nights < 1) {
      _showSnack('يجب أن تكون مدة الإقامة ليلة واحدة على الأقل');
      return;
    }

    // ✅ إصلاح: الزر بالأسفل يُفعَّل حسب _canConfirmForUI (يسمح بالمتابعة
    // للدفع الإلكتروني حتى لو السعر لسا بيتحسب)، لكن _confirm() كانت
    // تتحقق دايماً من _canConfirm الأصرم (يتطلب سعر جاهز من السيرفر).
    // النتيجة: بحالة الدفع الإلكتروني، المستخدم يضغط زر يبدو مفعّل
    // ويطلع له خطأ "تأكد من التواريخ" رغم عدم وجود مشكلة فعلية.
    // الحل: نفس شرط التفعيل يُستخدم بالتحقق الفعلي عند الإرسال.
    final effectiveCanConfirm =
        _paymentMethod == 'online' ? _canConfirmForUI : _canConfirm;

    if (!effectiveCanConfirm) {
      if (_availabilityError != null) {
        _showSnack(_availabilityError!);
      } else {
        _showSnack('يرجى التأكد من التواريخ المتاحة قبل الحجز');
      }
      return;
    }

    setState(() => _loading = true);

    // If user chose online payment, route to PaymentScreen (mock processing)
    if (_paymentMethod == 'online') {
      setState(() => _loading = false);
      if (_chaletModel == null) {
        _showSnack('تعذر فتح بوابة الدفع الآن');
        return;
      }
      // Use GoRouter route for /payment which expects an extra map with chalet, checkIn, checkOut, guestsCount
      try {
        context.push('/payment', extra: {
          'chalet': _chaletModel!,
          'checkIn': _checkIn!,
          'checkOut': _checkOut!,
          'guestsCount': _guests,
        });
      } catch (_) {
        _showSnack('تعذر فتح بوابة الدفع');
      }
      return;
    }

    try {
      final booking = await BookingService.instance.createBooking(
        chaletId: _chaletId,
        checkIn: _checkIn!,
        checkOut: _checkOut!,
        guestsCount: _guests,
        paymentMethod: _paymentMethod,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        totalPrice: _serverTotalPrice!,
        stayType: _selectedStayType,
      );

      if (mounted) _showSuccessDialog(booking);
    } catch (e) {
      debugPrint('Booking error: $e');
      final msg = e.toString();
      final isConflict = msg.contains('23505') ||
          msg.contains('23P01') ||
          msg.contains('Booking conflict');

      _showSnack(isConflict
          ? 'عذراً، هذا التاريخ أصبح محجوزاً للتو من مستخدم آخر. يرجى اختيار تواريخ أخرى'
          : 'حدث خطأ أثناء الحجز، يرجى المحاولة مجدداً');

      if (isConflict) {
        await _fetchBookedDates();
        await _fetchServerPrice();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchBookedDates() async {
    if (_chaletId.isEmpty) return;
    try {
      final dates = await BookingService.instance.getBookedDates(
        _chaletId,
      );
      if (!mounted) return;
      setState(() {
        _bookedDates =
            dates.map((d) => DateTime(d.year, d.month, d.day)).toSet();
      });
    } catch (_) {}
  }

  bool _isDateBooked(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _bookedDates.contains(d);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  /// ✅ إصلاح: يبني رمز حجز آمن حتى لو الـ id أقصر من 8 أحرف (كان
  /// booking.id.substring(0, 8) يرمي RangeError ويكسر شاشة النجاح).
  String _bookingCode(BookingModel booking) {
    final raw =
        booking.id.length >= 8 ? booking.id.substring(0, 8) : booking.id;
    return '#CH-${raw.toUpperCase()}';
  }

  Future<void> _shareOnWhatsApp(BookingModel booking) async {
    final bookingCode = _bookingCode(booking);
    final text = Uri.encodeComponent(
      'تم تأكيد حجزي في ${_chaletModel?.name ?? ''} 🎉\n'
      'رقم الحجز: $bookingCode\n'
      'من ${booking.checkIn.day}/${booking.checkIn.month}/${booking.checkIn.year} '
      'إلى ${booking.checkOut.day}/${booking.checkOut.month}/${booking.checkOut.year}',
    );
    final uri = Uri.parse('https://wa.me/?text=$text');

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showSnack('تعذر فتح واتساب');
      }
    } catch (_) {
      if (mounted) _showSnack('تعذر فتح واتساب');
    }
  }

  void _showSuccessDialog(BookingModel booking) {
    final bookingCode = _bookingCode(booking);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppColors.primaryPale.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    size: 58, color: _darkGreen),
              ),
              const SizedBox(height: 16),
              const Text('تم حجزك بنجاح 🎉',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _darkGreen),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('تم تأكيد طلبك وإرسال التفاصيل لهاتفك',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border.withOpacity(0.8)),
                ),
                child: Column(children: [
                  const Text('رقم الحجز الخاص بك',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textHint)),
                  const SizedBox(height: 6),
                  Text(bookingCode,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.charcoal)),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.pop();
                    context.go('/home', extra: 3);
                  },
                  icon: const Icon(Icons.description_rounded),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  label: const Text('عرض تفاصيل الحجز',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _shareOnWhatsApp(booking),
                  icon: const Icon(Icons.share_rounded),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: _darkGreen,
                    side: const BorderSide(color: _darkGreen, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  label: const Text('شارك على واتساب',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
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
    // ✅ إصلاح: لما الشاشة تُفتح بـ chaletId فقط، كانت تُبنى فوراً ببيانات
    // فاضية (اسم "شاليه" افتراضي، صورة فاضية...) لحد ما يوصل الطلب، بدل
    // إظهار مؤشر تحميل واضح — أو رسالة خطأ مع زر إعادة محاولة لو فشل.
    if (_chaletModel == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _chaletLoadError
              ? _buildChaletLoadError()
              : const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 12),
                  _buildChaletCard(),
                  const SizedBox(height: 22),
                  _buildDatesSection(),
                  const SizedBox(height: 22),
                  if (!_stayTypesLoading && _enabledStayTypes.isNotEmpty) ...[
                    _buildStayTypeSection(),
                    const SizedBox(height: 22),
                  ],
                  _buildGuestsSection(),
                  const SizedBox(height: 22),
                  _buildPaymentSection(),
                  const SizedBox(height: 22),
                  _buildNotesSection(),
                  const SizedBox(height: 22),
                  if (_nights > 0) _buildPriceSummary(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildChaletLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            const Text('تعذر تحميل بيانات الشاليه',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                if (widget.chaletId == null) {
                  context.pop();
                  return;
                }
                setState(() {
                  _chaletLoading = true;
                  _chaletLoadError = false;
                });
                _loadChaletById(widget.chaletId!);
              },
              icon: const Icon(Icons.refresh_rounded),
              style: ElevatedButton.styleFrom(
                backgroundColor: _darkGreen,
                foregroundColor: Colors.white,
              ),
              label: const Text('إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== TOP BAR =====================
  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFF1EEE6),
            child: Icon(Icons.arrow_back, color: AppColors.charcoal, size: 20),
          ),
        ),
        const Expanded(
          child: Text('الحجز',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal)),
        ),
        const Icon(Icons.favorite_border, color: AppColors.charcoal),
        const SizedBox(width: 14),
        const Icon(Icons.share_outlined, color: AppColors.charcoal),
      ],
    );
  }

  // ===================== CHALET SUMMARY CARD =====================
  Widget _buildChaletCard() {
    // ⚠️ افترضت وجود widget.chalet.rating و widget.chalet.reviewsCount.
    // إذا أسماء الحقول عندك مختلفة بـ ChaletModel، بدّلها هون.
    final rating = _chaletModel?.rating ?? 0.0;
    final reviews = _chaletModel?.reviewsCount ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.sand),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: _chaletModel?.coverImage ?? '',
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 170,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 170,
                    color: Colors.grey[200],
                    child:
                        const Icon(Icons.home_work_rounded, color: Colors.grey),
                  ),
                ),
              ),
              // ⚠️ عداد الصور "1/25" ثابت هون كمثال. إذا عندك قائمة صور
              // فعلية بـ chalet.images (List<String>) بدّل الرقم الثابت
              // بـ _chaletModel?.images.length وفعّل كاروسيل حقيقي.
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('1 / 25',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_chaletModel?.name ?? 'شاليه',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.charcoal)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text(_chaletModel?.city ?? '',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ]),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F2E7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: Color(0xFFE0A63C)),
                  const SizedBox(width: 4),
                  Text('$rating',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 3),
                  Text('($reviews)',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ⚠️ أيقونات المرافق ثابتة (مسبح/جلسات خارجية/موقف خاص) كمثال
          // مطابق للصورة. إذا عندك قائمة amenities ديناميكية بالموديل،
          // بدّل هاد الـ Row بـ loop على _chaletModel?.amenities.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _amenityIcon(Icons.pool_rounded, 'مسبح'),
              _amenityIcon(Icons.deck_outlined, 'جلسات خارجية'),
              _amenityIcon(Icons.local_parking_outlined, 'موقف خاص'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amenityIcon(IconData icon, String label) {
    return Column(children: [
      Icon(icon, color: _darkGreen, size: 22),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: AppColors.textSecondary)),
    ]);
  }

  // ===================== DATES =====================
  static const List<String> _weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد'
  ];

  String _weekdayLabel(DateTime d) => _weekdays[d.weekday - 1];

  static const List<String> _months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر'
  ];

  String _fullDateLabel(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  Widget _buildDatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('اختر التاريخ',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sand),
          ),
          child: Row(
            children: [
              Expanded(
                child: _bigDateBox(
                  label: 'تاريخ المغادرة',
                  date: _checkOut,
                  onTap: () => setState(() {
                    _selectingCheckIn = false;
                    _showCalendar = true;
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F2E7),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(children: [
                    Text('$_nights ${_nights == 1 ? 'ليلة' : 'ليالٍ'}',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal)),
                    const SizedBox(width: 4),
                    const Icon(Icons.nightlight_round,
                        size: 13, color: Color(0xFFE0A63C)),
                  ]),
                ),
              ),
              Expanded(
                child: _bigDateBox(
                  label: 'تاريخ الوصول',
                  date: _checkIn,
                  onTap: () => setState(() {
                    _selectingCheckIn = true;
                    _showCalendar = true;
                  }),
                ),
              ),
            ],
          ),
        ),
        if (_showCalendar) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.sand),
            ),
            child: TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _checkIn ?? DateTime.now(),
              enabledDayPredicate: (day) => !_isDateBooked(day),
              selectedDayPredicate: (day) {
                if (_selectingCheckIn) return isSameDay(_checkIn, day);
                return isSameDay(_checkOut, day);
              },
              rangeStartDay: _checkIn,
              rangeEndDay: _checkOut,
              calendarFormat: CalendarFormat.month,
              rowHeight: 52,
              rangeSelectionMode: RangeSelectionMode.toggledOn,
              onPageChanged: (focusedDay) {
                final newMonth = DateTime(focusedDay.year, focusedDay.month);
                if (newMonth.year != _visibleMonth.year ||
                    newMonth.month != _visibleMonth.month) {
                  _loadMonthPricing(newMonth);
                }
              },
              onDaySelected: (selected, focused) {
                setState(() {
                  if (_selectingCheckIn) {
                    _checkIn = selected;
                    _checkOut = null;
                    _selectingCheckIn = false;
                    _serverCalculated = false;
                  } else {
                    if (selected.isAfter(_checkIn ?? DateTime.now())) {
                      _checkOut = selected;
                      _showCalendar = false;
                    } else {
                      _checkIn = selected;
                      _checkOut = null;
                      _selectingCheckIn = false;
                    }
                    _serverCalculated = false;
                  }
                });
                if (_checkIn != null && _checkOut != null) {
                  _fetchServerPrice();
                }
              },
              calendarStyle: const CalendarStyle(
                selectedDecoration:
                    BoxDecoration(color: _darkGreen, shape: BoxShape.circle),
                rangeHighlightColor: AppColors.primaryPale,
                rangeStartDecoration:
                    BoxDecoration(color: _darkGreen, shape: BoxShape.circle),
                rangeEndDecoration:
                    BoxDecoration(color: _darkGreen, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(
                    color: AppColors.accent, shape: BoxShape.circle),
                defaultTextStyle: TextStyle(fontFamily: 'Cairo'),
              ),
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle:
                    TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _bigDateBox({
    required String label,
    DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(date != null ? _weekdayLabel(date) : '—',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(date != null ? _fullDateLabel(date) : 'اختر التاريخ',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: AppColors.textSecondary)),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEE6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.calendar_today_outlined,
                    size: 12, color: _darkGreen),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================== STAY TYPE =====================
  Widget _buildStayTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('نوع الحجز',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final type in _enabledStayTypes) ...[
              Expanded(child: _stayTypeCard(type)),
              if (type != _enabledStayTypes.last) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }

  Widget _stayTypeCard(ChaletStayTypeConfig config) {
    final selected = _selectedStayType == config.type.dbValue;

    return GestureDetector(
      onTap: () => _onStayTypeSelected(config.type.dbValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? _darkGreen : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _darkGreen : AppColors.sand,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(config.type.label,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color:
                                selected ? Colors.white : AppColors.charcoal)),
                    const SizedBox(width: 4),
                    Icon(config.type.icon,
                        size: 15,
                        color:
                            selected ? Colors.white : const Color(0xFFE0A63C)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${config.checkinTime.format(context)} - ${config.checkoutTime.format(context)}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: selected
                          ? Colors.white.withOpacity(0.85)
                          : AppColors.textSecondary),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: -8,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 12, color: _darkGreen),
                ),
              ),
          ],
        ),
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
          color: selected ? _darkGreen.withOpacity(0.06) : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _darkGreen : AppColors.sand,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? _darkGreen : const Color(0xFFF1EEE6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: selected ? Colors.white : AppColors.textHint,
                  size: 20),
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
                          color: selected ? _darkGreen : AppColors.charcoal)),
                  Text(sub,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _paymentMethod,
              onChanged: (v) => setState(() => _paymentMethod = v!),
              activeColor: _darkGreen,
            ),
          ],
        ),
      ),
    );
  }

  // ===================== GUESTS =====================
  Widget _buildGuestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('عدد الضيوف',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sand),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _guestCounter(
                    label: 'الرضّع',
                    icon: Icons.child_friendly_outlined,
                    value: _infants,
                    // الرضّع لا يُحتسبون ضمن _guests المرسل للسيرفر، فتركت
                    // حدّهم الأقصى مرتبط بسعة الشاليه فقط كحماية معقولة.
                    maxOverride: _chaletModel?.maxGuests ?? 1,
                    onChanged: (v) => setState(() => _infants = v),
                  ),
                  _guestCounter(
                    label: 'الأطفال',
                    icon: Icons.emoji_people_outlined,
                    value: _children,
                    // ✅ إصلاح: كان بالإمكان زيادة الأطفال والبالغين لحد
                    // maxGuests كل واحد لحاله، فيصير المجموع الفعلي (اللي
                    // بيروح للسيرفر) أكبر من سعة الشاليه المسموحة. هلأ
                    // الحد الأقصى لكل فئة = سعة الشاليه ناقص الفئة التانية.
                    maxOverride: (_chaletModel?.maxGuests ?? 1) - _adults,
                    onChanged: (v) {
                      setState(() => _children = v);
                      _onGuestsChanged();
                    },
                  ),
                  _guestCounter(
                    label: 'البالغين',
                    icon: Icons.person_outline,
                    value: _adults,
                    min: 1,
                    maxOverride: (_chaletModel?.maxGuests ?? 1) - _children,
                    onChanged: (v) {
                      setState(() => _adults = v);
                      _onGuestsChanged();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline,
                      size: 13, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    'الحد الأقصى ${_chaletModel?.maxGuests ?? 1} ضيوف (بالغين وأطفال)',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AppColors.textHint),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _guestCounter({
    required String label,
    required IconData icon,
    required int value,
    required ValueChanged<int> onChanged,
    int min = 0,
    int maxOverride = 1,
  }) {
    // الحد الأقصى ما ينزل تحت الحالي، حتى ما يظهر الزر مقفول بشكل مربك
    // إذا صارت إعادة حساب مؤقتة (مثلاً وقت تحميل بيانات الشاليه).
    final max = maxOverride < value ? value : maxOverride;
    return Column(
      children: [
        Row(children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal)),
          const SizedBox(width: 4),
          Icon(icon, size: 14, color: const Color(0xFFE0A63C)),
        ]),
        const SizedBox(height: 10),
        Row(
          children: [
            _counterBtn(
              icon: Icons.remove,
              semanticLabel: 'تقليل $label',
              onTap: () {
                if (value > min) onChanged(value - 1);
              },
            ),
            SizedBox(
              width: 26,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ),
            _counterBtn(
              icon: Icons.add,
              semanticLabel: 'زيادة $label',
              onTap: () {
                if (value < max) {
                  onChanged(value + 1);
                } else {
                  _showSnack(
                      'وصلت للحد الأقصى المسموح لعدد الضيوف بهذا الشاليه');
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _counterBtn({
    required IconData icon,
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    // ✅ إصلاح: كانت منطقة اللمس 26x26 فقط (أصغر من الحد الأدنى الموصى
    // به 44x44 لإمكانية الوصول)، وبدون أي ripple feedback. رفعتها لـ 36
    // وأضفت InkWell وSemantics.
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: const Color(0xFFF1EEE6),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 14, color: AppColors.charcoal),
          ),
        ),
      ),
    );
  }

  // ===================== PAYMENT =====================
  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('طريقة الدفع',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 12),
        _payOption('cash', Icons.money_rounded, AppStrings.cashOnArrival,
            'ادفع نقداً عند وصولك للشاليه'),
        const SizedBox(height: 8),
        _payOption('online', Icons.credit_card_rounded,
            AppStrings.onlinePayment, 'ادفع إلكترونياً بأمان عبر التطبيق'),
      ],
    );
  }

  // ===================== NOTES =====================
  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('ملاحظات إضافية (اختياري)',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _notesCtrl,
          label: '',
          hint: 'أي طلبات أو ملاحظات خاصة...',
          maxLines: 3,
        ),
      ],
    );
  }

  // ===================== PRICE DETAILS =====================
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
                color: total ? _darkGreen : AppColors.charcoal)),
      ],
    );
  }

  Widget _buildPriceSummary() {
    if (_priceLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_total == null) {
      if (_availabilityError != null) {
        return Text(_availabilityError!,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.error));
      }
      return const SizedBox.shrink();
    }

    final base = _total!;
    final serviceFee = base * kServiceFeePercentage;
    // ⚠️ "رسوم المنصة" بالتصميم غير موجودة كثابت واضح بـ pricing_constants.dart
    // يلي عندي. حطيت نسبة مؤقتة placeholder، بدّلها بالثابت الفعلي عندك
    // (مثلاً kPlatformFeePercentage) إذا موجود، أو احذف السطر لو مش مطلوب.
    final platformFee = base * 0.03; // TODO: استبدل بالثابت الحقيقي
    final grandTotal = base + serviceFee + platformFee;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('تفاصيل السعر',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sand),
          ),
          child: Column(
            children: [
              _priceRow('السعر الأساسي (يومي)', AppCurrency.formatPrice(base)),
              const SizedBox(height: 10),
              _priceRow(
                  'ضريبة الخدمة (${(kServiceFeePercentage * 100).toStringAsFixed(0)}%)',
                  AppCurrency.formatPrice(serviceFee)),
              const SizedBox(height: 10),
              _priceRow('رسوم المنصة', AppCurrency.formatPrice(platformFee)),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              _priceRow('المجموع الكلي', AppCurrency.formatPrice(grandTotal),
                  total: true),
            ],
          ),
        ),
      ],
    );
  }

  // ===================== BOTTOM BAR =====================
  Widget _buildBottomBar() {
    final totalText = _total == null ? '—' : AppCurrency.formatPrice(_total!);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.sand),
                ),
                child: Column(children: [
                  Text(
                    _paymentMethod == 'cash'
                        ? 'الدفع عند الوصول'
                        : AppStrings.onlinePayment,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    _paymentMethod == 'cash'
                        ? Icons.money_rounded
                        : Icons.credit_card_rounded,
                    size: 16,
                    color: AppColors.textHint,
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _canConfirmForUI && !_loading ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_outline, size: 16),
                            const SizedBox(width: 8),
                            Text('تأكيد الحجز  $totalText',
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
