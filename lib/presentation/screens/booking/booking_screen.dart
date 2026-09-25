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

part 'widgets/booking_success_dialog.dart';
part 'widgets/booking_header.dart';
part 'widgets/booking_calendar_section.dart';
part 'widgets/booking_form_sections.dart';
part 'widgets/booking_price_summary.dart';

class BookingScreen extends StatefulWidget {
  final ChaletModel? chalet;
  final String? chaletId;
  const BookingScreen({super.key, this.chalet, this.chaletId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // لأجزاء الشاشة (extensions بملفات part) التي لا تستطيع استدعاء
  // setState المحمي مباشرة.
  void _setState(VoidCallback fn) => setState(fn);

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
    } catch (e, st) {
      // أسعار التقويم للعرض فقط (السعر الفعلي من السيرفر عند اختيار الفترة).
      reportError(e, st, context: 'booking.month_pricing');
    }
  }

  @override
  void initState() {
    super.initState();
    _chalet = widget.chalet;
    if (_chalet == null && widget.chaletId != null) {
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

    // الدفع النقدي والإلكتروني كلاهما يحتاج سعر السيرفر للفترة (لا سعر
    // يُحسب بالتطبيق)، فنفس الشرط يفعّل الزر ويُتحقق منه هنا.
    if (!_canConfirm) {
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
          'totalPrice': _serverTotalPrice!,
          'periodLabel': _selectedPeriod?.label ?? '',
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

}
