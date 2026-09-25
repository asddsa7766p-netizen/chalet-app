import 'dart:async';
import 'package:flutter/material.dart';
import 'package:makan/data/services/pricing_service.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/error_reporter.dart';
import '../../../data/models/booking_period.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/models/models.dart';
import '../../../data/services/chalet_slot_availability.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/common_widgets.dart';
import '../home/main_screen.dart' show goToMainTab;
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

  // تعارض إدراج حقيقي (23505/exclusion) على مستوى الفترة، وليس يوماً محجوباً
  // (unavailableDatesMessage الأعم تغطي المحجوب أعلاه).
  static const _slotJustBookedMessage =
      'تم حجز هذه الفترة للتو، يرجى اختيار فترة أخرى';

  // الحجز = يوم واحد + فترة واحدة. check_in = اليوم المختار و check_out =
  // اليوم التالي دائماً (booking_slots تحدد الفترة المشغولة من stay_type).
  DateTime? _date;
  DateTime? get _checkIn => _date;
  DateTime? get _checkOut => _date == null ? null : nextDay(_date!);

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

  // ⛔ الدفع الإلكتروني معطّل مؤقتاً لحين اختيار بوابة دفع حقيقية وربطها.
  // حالياً MockPaymentGateway لا ينشئ حجزاً فعلياً بقاعدة البيانات، فمنع
  // اختياره من الواجهة هنا يمنع أي وهم بأن الحجز تم فعلاً. لا تفعّل هذا
  // قبل ربط بوابة دفع حقيقية بمسار /payment.
  static const bool _onlinePaymentEnabled = false;
  bool _loading = false;
  bool _showCalendar = true;

  bool _priceLoading = false;
  double? _serverTotalPrice;
  bool _isAvailable = true;
  String? _availabilityError;
  bool _serverCalculated = false;

  // توفر الفترات (صباحية/مسائية) لكل يوم، من دالة القاعدة الموحّدة
  // get_chalet_slot_availability — الشاليه يقبل حجزاً صباحياً وآخر مسائياً
  // بنفس اليوم، فلم يعد كافياً تمثيل التوفر كمجموعة ليالٍ.
  Map<DateTime, ChaletDaySlot> _daySlots = {};

  bool _stayTypesLoading = true;
  // فترات الحجز: أنواع الإقامة المفعّلة، أو "يوم كامل" لشاليه بلا أنواع.
  List<BookingPeriod> _periods = const [BookingPeriod.fullDayDefault];

  /// الفترة المختارة (stay_type)، أو null قبل أن يختار الضيف.
  String? _selectedStayType;

  BookingPeriod? get _selectedPeriod {
    for (final p in _periods) {
      if (p.stayType == _selectedStayType) return p;
    }
    return null;
  }

  /// نوع الإقامة الذي تُعرض أسعار أيام التقويم له.
  String get _pricingStayType => _selectedStayType ?? _periods.first.stayType;

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // ✅ إصلاح: كانت getMonthPricing تُستدعى وتُنتظر (5 طلبات متوازية أحياناً)
  // ثم تُرمى نتيجتها بالكامل بدون استخدام — تقويم بلا أي سعر يومي رغم أن
  // البيانات الحقيقية جاهزة أصلاً. الآن تُخزَّن لعرضها تحت كل يوم بالتقويم.
  Map<DateTime, DayPriceInfo> _monthPricing = {};

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

  /// اليوم والفترة محددان.
  bool get _hasSelection => _date != null && _selectedStayType != null;

  double? get _total => _serverTotalPrice;

  bool get _canConfirm =>
      _isAvailable &&
      !_priceLoading &&
      _serverTotalPrice != null &&
      _serverCalculated &&
      _hasSelection;

  /// UI-level confirmation availability.
  /// For online payments we allow proceeding to the payment flow even if
  /// server-side price calculation is still pending (mock payment path).
  bool get _canConfirmForUI {
    if (_paymentMethod == 'online') {
      return _isAvailable && _hasSelection;
    }
    return _canConfirm;
  }

  Future<void> _fetchServerPrice() async {
    if (!_hasSelection) return;

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
        stayType: _selectedStayType!,
      );

      if (!mounted) return;
      // ✅ إصلاح: تجاهل نتيجة أي طلب قديم إذا صار في طلب أحدث بعده.
      if (requestId != _priceRequestId) return;

      if (!available) {
        setState(() {
          _serverTotalPrice = null;
          _isAvailable = false;
          _serverCalculated = false;
          _availabilityError = 'عذراً، هذه الفترة محجوزة في اليوم المختار';
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
        stayType: _selectedStayType!,
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
            ? 'عذراً، هذه الفترة محجوزة في اليوم المختار'
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
        _periods = BookingPeriod.forChalet(types);
        _reconcileSelectedPeriod();
      });
    } catch (e, st) {
      // الفترات ثانوية: عند الفشل تبقى فترة "يوم كامل" (default) وحدها.
      reportError(e, st, context: 'booking_stay_types');
    } finally {
      if (mounted) setState(() => _stayTypesLoading = false);
    }
  }

  /// هل الفترة [stayType] متاحة باليوم المختار؟ (مطابقة booking_slots)
  bool _isPeriodAvailable(String stayType) =>
      _date == null ||
      isDayAvailableForStayType(_date!, stayType: stayType, slots: _daySlots);

  /// بعد تغيّر اليوم أو الفترات أو التوفر: تبقى الفترة المختارة إن كانت
  /// متاحة، وإن كانت هناك فترة متاحة واحدة فقط تُختار تلقائياً، وإلا يختار
  /// الضيف بنفسه.
  void _reconcileSelectedPeriod() {
    final current = _selectedStayType;
    if (current != null &&
        _periods.any((p) => p.stayType == current) &&
        _isPeriodAvailable(current)) {
      return;
    }
    final available =
        _periods.where((p) => _isPeriodAvailable(p.stayType)).toList();
    _selectedStayType = available.length == 1 ? available.single.stayType : null;
  }

  Future<void> _onStayTypeSelected(String stayType) async {
    if (stayType == _selectedStayType) return;
    if (!_isPeriodAvailable(stayType)) {
      _showSnack('هذه الفترة محجوزة في اليوم المختار');
      return;
    }
    // ✅ إصلاح: رقم الطلب لم يكن يتغيّر إلا بعد انتظار تسعير الشهر، فطلب
    // سعر قديم (لنوع الإقامة السابق) كان يستطيع الردّ في هذه الفجوة ويُظهر
    // سعراً قديماً على نوع الإقامة الجديد. نُبطله فوراً ونبدأ الحساب مباشرة.
    _priceRequestId++;
    setState(() {
      _selectedStayType = stayType;
      _serverCalculated = false;
      _serverTotalPrice = null;
      _priceLoading = _hasSelection;
    });
    final monthFuture = _loadMonthPricing(_visibleMonth);
    if (_hasSelection) await _fetchServerPrice();
    await monthFuture;
  }

  void _onDaySelected(DateTime selected) {
    _priceRequestId++;
    setState(() {
      _date = dayOnly(selected);
      _serverCalculated = false;
      _serverTotalPrice = null;
      _availabilityError = null;
      _isAvailable = true;
      _reconcileSelectedPeriod();
    });
    if (_hasSelection) _fetchServerPrice();
  }

  Future<void> _loadMonthPricing(DateTime month) async {
    final requestId = ++_monthPricingRequestId;
    final stayTypeForThisRequest = _pricingStayType;

    try {
      final pricing = await ChaletPricingService.instance.getMonthPricing(
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
        _monthPricing = pricing;
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
    // فُتحت بـ chaletId فقط، تبقى _unavailableNights فاضية للأبد، وبالتالي
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
      if (_hasSelection) _fetchServerPrice();
    });
  }

  Future<void> _confirm() async {
    if (_loading) return;
    if (_date == null) {
      _showSnack('يرجى اختيار تاريخ الحجز');
      return;
    }
    if (_selectedStayType == null) {
      _showSnack('يرجى اختيار الفترة');
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
        _showSnack('يرجى التأكد من أن الفترة متاحة قبل الحجز');
      }
      return;
    }

    setState(() => _loading = true);

    // If user chose online payment, route to PaymentScreen (mock processing)
    if (_paymentMethod == 'online') {
      setState(() => _loading = false);
      // ⛔ حارس أمان إضافي: حتى لو وصلت الحالة هون بأي طريقة، امنع
      // الدخول لمسار الدفع الإلكتروني المعطّل مؤقتاً (لا ينشئ حجزاً فعلياً).
      if (!_onlinePaymentEnabled) {
        _showSnack(
            'الدفع الإلكتروني غير متاح حالياً، يرجى اختيار الدفع النقدي');
        return;
      }
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
        stayType: _selectedStayType!,
      );

      if (mounted) _showSuccessDialog(booking);
    } catch (e) {
      debugPrint('Booking error: $e');
      final msg = e.toString();
      // ✅ إصلاح: تأكدت فعلياً بتشغيل التطبيق أن createBooking تمرّر الخطأ
      // عبر _translateSupabaseError أولاً (services.dart) قبل وصوله هنا —
      // فيصبح نصاً عربياً مترجَماً، لا يحتوي أبداً على '23505'/'23P01'/
      // 'Booking conflict' الأصلية (كانت هذه الشروط ميتة عملياً، تفشل
      // دائماً بصمت وتُظهر رسالة الخطأ العامة حتى بحالة تعارض حقيقي).
      // الفحص الآن على نفس النص العربي الفعلي الذي تُرجعه الترجمة.
      // أيام غير متاحة (محجوبة) رفضها الـ trigger: رسالة محايدة لا تدّعي أن
      // اليوم حُجز للتو من أحد.
      final isUnavailable = msg.contains(unavailableDatesMessage);
      final isConflict = isUnavailable ||
          msg.contains('محجوز') ||
          msg.contains('23505') ||
          msg.contains('23P01') ||
          msg.contains('Booking conflict');

      _showSnack(isUnavailable
          ? unavailableDatesMessage
          : isConflict
              ? _slotJustBookedMessage
              : 'حدث خطأ أثناء الحجز، يرجى المحاولة مجدداً');

      if (isConflict) {
        await _fetchBookedDates();
        if (!mounted) return;
        // الفترة التي صارت غير متاحة تُفرَّغ ليختار الضيف فترة أو يوماً آخر.
        if (!_isPeriodAvailable(_selectedStayType!)) {
          setState(() {
            _selectedStayType = null;
            _serverCalculated = false;
            _serverTotalPrice = null;
            _reconcileSelectedPeriod();
          });
          if (_hasSelection) await _fetchServerPrice();
        } else {
          await _fetchServerPrice();
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchBookedDates() async {
    if (_chaletId.isEmpty) return;
    try {
      final slots = await BookingService.instance.getDaySlots(_chaletId);
      if (!mounted) return;
      setState(() {
        _daySlots = slots;
        _reconcileSelectedPeriod();
      });
    } catch (e, st) {
      reportError(e, st, context: 'booking_day_slots');
    }
  }

  /// اليوم قابل للاختيار إن كانت فيه فترة واحدة على الأقل متاحة.
  bool _isDayEnabled(DateTime day) => _periods.any((p) =>
      isDayAvailableForStayType(day, stayType: p.stayType, slots: _daySlots));

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
      'حجزت في ${_chaletModel?.name ?? ''} 🎉\n'
      'رقم الحجز: $bookingCode\n'
      'التاريخ: ${booking.dateLabel}\n'
      'الفترة: ${_selectedPeriod?.label ?? booking.periodLabel}'
      '${_selectedPeriod?.timeLabel == null ? '' : ' (${_selectedPeriod!.timeLabel})'}',
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
              // ✅ إصلاح: النص كان يقول "تم تأكيد طلبك" رغم أن كل حجز
              // يُنشأ دائماً بحالة 'pending' (createBooking بـservices.dart
              // يضع status:'pending' دون استثناء — التأكيد الفعلي إجراء
              // منفصل لاحق من المالك). كان يدّعي أيضاً "إرسال التفاصيل
              // لهاتفك" رغم عدم وجود أي إرسال SMS/إشعار فعلي بالكود. الآن
              // النص يعكس الحالة الحقيقية فقط ويوجّه لمصدر الحقيقة الفعلي
              // (صفحة حجوزاتي) بدل الادّعاء بتواصل غير موجود.
              const Text('تم إرسال طلب حجزك ✅',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _darkGreen),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                  'طلبك الآن قيد انتظار موافقة المالك. يمكنك متابعة حالة حجزك في أي وقت من صفحة حجوزاتي',
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
                    goToMainTab(context, 3);
                  },
                  icon: const Icon(Icons.description_rounded),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  // ✅ إصلاح: النص كان "عرض تفاصيل الحجز" لكنه فعلياً
                  // يفتح قائمة "حجوزاتي" الكاملة (لا توجد شاشة تفاصيل حجز
                  // منفصلة) — لم أُضِف مساراً جديداً، فقط صححت التسمية
                  // لتطابق الوجهة الفعلية.
                  label: const Text('عرض حجوزاتي',
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
                  if (!_stayTypesLoading) ...[
                    _buildStayTypeSection(),
                    const SizedBox(height: 22),
                  ],
                  _buildGuestsSection(),
                  const SizedBox(height: 22),
                  _buildPaymentSection(),
                  const SizedBox(height: 22),
                  _buildNotesSection(),
                  const SizedBox(height: 22),
                  if (_hasSelection) ...[
                    _buildPriceSummary(),
                    const SizedBox(height: 16),
                    _buildBookingStatusNotice(),
                  ],
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
              if ((_chaletModel?.images.length ?? 0) > 1)
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
                    child: Text('${_chaletModel?.images.length ?? 0} صور',
                        style: const TextStyle(
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
          // ✅ إصلاح: كانت الأيقونات (مسبح/جلسات خارجية/موقف خاص) ثابتة لكل
          // الشاليهات بغض النظر عن مرافقها الفعلية — تضليل للمستخدم. الآن من
          // بيانات الشاليه نفسها.
          if (_chaletModel != null &&
              (_chaletModel!.hasPool ||
                  _chaletModel!.hasWifi ||
                  _chaletModel!.hasParking ||
                  _chaletModel!.hasBbq))
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (_chaletModel!.hasPool)
                  _amenityIcon(Icons.pool_rounded, 'مسبح'),
                if (_chaletModel!.hasWifi)
                  _amenityIcon(Icons.wifi_rounded, 'واي فاي'),
                if (_chaletModel!.hasParking)
                  _amenityIcon(Icons.local_parking_outlined, 'موقف خاص'),
                if (_chaletModel!.hasBbq)
                  _amenityIcon(Icons.outdoor_grill_rounded, 'شواء'),
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

  // ===================== DATE (يوم واحد) =====================
  Widget _buildDatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('تاريخ الحجز',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 12),
        GestureDetector(
          key: const Key('booking_date_box'),
          onTap: () => setState(() => _showCalendar = !_showCalendar),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.sand),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EEE6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today_outlined,
                      size: 18, color: _darkGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _date == null ? 'اختر يوم الحجز' : arabicDayLabel(_date!),
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _date == null
                            ? AppColors.textSecondary
                            : AppColors.charcoal),
                  ),
                ),
                Icon(
                    _showCalendar
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
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
              // ✅ إصلاح: بدون هذا كان اسم الشهر وأيام الأسبوع يظهران
              // بالإنجليزية دائماً (مؤكَّد بتشغيل التطبيق فعلياً) رغم أن
              // التقويم داخل شاشة عربية بالكامل.
              locale: 'ar',
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _date ?? DateTime.now(),
              // يوم واحد فقط: مفعّل إن كانت فيه فترة واحدة متاحة على الأقل.
              enabledDayPredicate: _isDayEnabled,
              selectedDayPredicate: (day) => isSameDay(_date, day),
              calendarFormat: CalendarFormat.month,
              rowHeight: 58,
              // ✅ إصلاح: هذه البيانات (سعر كل يوم) كانت تُجلب فعلياً
              // بـ_loadMonthPricing وتُرمى بدون استخدام. الآن تُعرض تحت كل
              // يوم — بيانات حقيقية من نفس المصدر المعتمد بحساب السعر
              // النهائي، وليست قيمة مُخترعة.
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) =>
                    _dayCell(day, false),
                todayBuilder: (context, day, focusedDay) =>
                    _dayCell(day, false, isToday: true),
                // اليوم غير المتاح يظهر مشطوباً بهدوء بلا ذكر السبب (محجوز
                // أم محجوب)، والمعطَّل لسبب آخر (ماضٍ) رمادي فقط.
                disabledBuilder: (context, day, focusedDay) =>
                    _disabledCell(day),
              ),
              onPageChanged: (focusedDay) {
                final newMonth = DateTime(focusedDay.year, focusedDay.month);
                if (newMonth.year != _visibleMonth.year ||
                    newMonth.month != _visibleMonth.month) {
                  _loadMonthPricing(newMonth);
                }
              },
              onDaySelected: (selected, focused) => _onDaySelected(selected),
              calendarStyle: const CalendarStyle(
                selectedDecoration:
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

  // نص قصير يوضّح أي فترة حرة ليوم "جزئي" (فترة واحدة محجوزة والثانية حرة).
  // مستقل عن نوع الإقامة المختار حالياً — يعتمد فقط على حالة الفترتين الخام.
  String? _partialSlotNote(DateTime day) {
    final slot = _daySlots[DateTime(day.year, day.month, day.day)];
    if (slot == null || !slot.isPartiallyBooked) return null;
    return slot.morningBooked ? 'مسائي فقط' : 'صباحي فقط';
  }

  Widget _disabledCell(DateTime day) {
    final slot = _daySlots[DateTime(day.year, day.month, day.day)];
    final unavailable = slot?.isFullyUnavailable ?? false;
    final note = _partialSlotNote(day);
    return Container(
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textHint.withOpacity(0.7),
              decoration: unavailable ? TextDecoration.lineThrough : null,
            ),
          ),
          // يوم جزئي معطّل لنوع الإقامة المختار حالياً (مثلاً "صباحية" وهذا
          // اليوم صباحه محجوز): نوضّح أي فترة تبقى متاحة فعلاً.
          if (note != null)
            Text(
              note,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: AppColors.textHint.withOpacity(0.7),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ إضافة: خلية يوم بالتقويم تعرض السعر الفعلي (من _monthPricing —
  // نفس البيانات الحقيقية المستخدمة أصلاً بحساب السعر، وليست قيمة
  // مُخترعة) تحت رقم اليوم، بدل يوم بلا أي معلومة سعر قبل اختياره.
  //
  // ✅ يوم "جزئي" (فترة واحدة فقط محجوزة) يظهر بلون مميّز مع نص قصير
  // يوضّح أي فترة ما زالت متاحة، بدل السعر، حتى قبل اختيار نوع الإقامة.
  Widget _dayCell(DateTime day, bool _, {bool isToday = false}) {
    final key = DateTime(day.year, day.month, day.day);
    final info = _monthPricing[key];
    final note = _partialSlotNote(day);

    return Container(
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: isToday
                ? const BoxDecoration(
                    color: AppColors.accent, shape: BoxShape.circle)
                : note != null
                    ? BoxDecoration(
                        color: const Color(0xFFE0A63C).withOpacity(0.15),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: const Color(0xFFE0A63C)),
                      )
                    : null,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday ? Colors.white : AppColors.charcoal,
              ),
            ),
          ),
          if (note != null)
            Text(
              note,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE0A63C),
              ),
            )
          else if (info != null)
            Text(
              info.finalPrice.toStringAsFixed(0),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color:
                    info.isSpecialOffer ? AppColors.error : AppColors.textHint,
              ),
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
        const Text('الفترة',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 4),
        Text(
          _date == null
              ? 'اختر يوم الحجز أولاً لمعرفة الفترات المتاحة'
              : 'الفترات المتاحة ليوم ${arabicDayLabel(_date!, withYear: false)}',
          style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        // بطاقتان بكل صف: أسماء الفترات ("يوم كامل - صباحي") وأوقاتها لا
        // تتسع لأربع بطاقات بعرض هاتف.
        LayoutBuilder(builder: (context, constraints) {
          final width = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in _periods)
                SizedBox(
                  width: _periods.length == 1 ? constraints.maxWidth : width,
                  child: _stayTypeCard(p),
                ),
            ],
          );
        }),
      ],
    );
  }

  Widget _stayTypeCard(BookingPeriod period) {
    final selected = _selectedStayType == period.stayType;
    final available = _isPeriodAvailable(period.stayType);

    return Opacity(
      opacity: available ? 1 : 0.45,
      child: GestureDetector(
      key: Key('period_${period.stayType}'),
      onTap: available ? () => _onStayTypeSelected(period.stayType) : null,
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
            // ✅ إصلاح: بطاقة نوع الإقامة كانت تفيض أفقياً فعلياً على
            // شاشة موبايل حقيقية (390px) — "OVERFLOWED BY 28 PIXELS" —
            // لأن تسمية النوع (مثل "يوم كامل - صباحي") ونطاق الوقت لم
            // يكونا مقيَّدين بعرض البطاقة الثلاثية الأعمدة. تأكدت من هذا
            // بتشغيل التطبيق فعلياً على عرض هاتف حقيقي، وليس افتراضاً.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(period.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? Colors.white
                                  : AppColors.charcoal)),
                    ),
                    const SizedBox(width: 4),
                    Icon(period.icon,
                        size: 15,
                        color:
                            selected ? Colors.white : const Color(0xFFE0A63C)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  available
                      ? (period.timeLabel ?? 'طوال اليوم')
                      : 'محجوزة بهذا اليوم',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
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
      ),
    );
  }

  Widget _payOption(String value, IconData icon, String title, String sub,
      {bool enabled = true}) {
    final selected = enabled && _paymentMethod == value;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? () => setState(() => _paymentMethod = value) : null,
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
                    Row(
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? _darkGreen
                                    : AppColors.charcoal)),
                        if (!enabled) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.sand,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('قريباً',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary)),
                          ),
                        ],
                      ],
                    ),
                    Text(enabled ? sub : 'غير متاح حالياً',
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
                onChanged:
                    enabled ? (v) => setState(() => _paymentMethod = v!) : null,
                activeColor: _darkGreen,
              ),
            ],
          ),
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
            'ادفع نقداً في الشاليه يوم الحجز'),
        const SizedBox(height: 8),
        _payOption('online', Icons.credit_card_rounded,
            AppStrings.onlinePayment, 'ادفع إلكترونياً بأمان عبر التطبيق',
            enabled: _onlinePaymentEnabled),
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

    // ✅ إصلاح (قرار عمل): كانت هذه البطاقة تضيف "ضريبة الخدمة 3%" و"رسوم
    // المنصة 3%" (قيمة placeholder غير مرتبطة بأي ثابت حقيقي أصلاً) فوق
    // السعر الأساسي، فيظهر للعميل "مجموع كلي" أكبر بـ6% مما يُحفظ ويُحجز
    // فعلياً بقاعدة البيانات (bookings.total_price = السعر الأساسي فقط،
    // تحقق من ذلك فعلياً عبر RPC calculate_chalet_stay_price وقراءة صف
    // الحجز بعد إنشائه). بقرار صريح: العمولة/الرسوم لا تُعرض للعميل
    // إطلاقاً، والمجموع المعروض هنا يطابق بالضبط ما سيُحفظ وما يظهر على
    // زر التأكيد بالأسفل — رقم واحد فقط، مصدر واحد (_serverTotalPrice).
    final total = _total!;

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
              _priceRow(
                  'سعر ${_selectedPeriod?.label ?? 'الفترة'}',
                  AppCurrency.formatPrice(total)),
              const SizedBox(height: 6),
              _priceRow(
                  arabicDayLabel(_date!, withYear: false),
                  _selectedPeriod?.timeLabel ?? 'طوال اليوم'),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              _priceRow('المجموع الكلي', AppCurrency.formatPrice(total),
                  total: true),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ إضافة: قبل التأكيد، كان المستخدم لا يعرف أبداً ما ستكون عليه حالة
  // حجزه بعد الضغط على "تأكيد الحجز" — createBooking ينشئ الحجز دائماً
  // بحالة 'pending' بانتظار موافقة المالك (services.dart)، لكن لا شيء
  // بالشاشة كان يوضّح ذلك قبل الإرسال. ملاحظة صغيرة صادقة بدل تفاجؤ
  // المستخدم لاحقاً.
  Widget _buildBookingStatusNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryPale.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'بعد التأكيد، سيُرسل طلبك للمالك للموافقة عليه. يمكنك متابعة حالة الحجز في أي وقت من صفحة حجوزاتي.',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
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
                        ? 'الدفع في الشاليه'
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
