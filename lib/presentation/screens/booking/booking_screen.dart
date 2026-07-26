import 'dart:async';
import 'package:flutter/material.dart';
import 'package:friends_chalets/data/services/pricing_service.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/common_widgets.dart';
import '../../../core/utils/currency_formatter.dart';
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

  // Price from Edge Function (single source of truth)
  bool _priceLoading = false;
  double? _serverTotalPrice;
  bool _isAvailable = true;
  String? _availabilityError;
  bool _serverCalculated = false;

  // Booked dates (RPC) for calendar rendering
  bool _bookedDatesLoading = false;
  Set<DateTime> _bookedDates = {};

  // ✅ جديد: أنواع الإقامة المفعّلة لهذا الشاليه (صباحية/مسائية/يوم كامل...).
  // لو صاحب الشاليه ما فعّل ولا نوع، تبقى فاضية والشاشة تشتغل بنفس السلوك
  // القديم بالضبط (نوع 'default' بدون أي قسم اختيار ظاهر بالواجهة).
  bool _stayTypesLoading = true;
  List<ChaletStayTypeConfig> _enabledStayTypes = [];
  String _selectedStayType = BookingService.defaultStayType;

  // ✅ جديد: أسعار الشهر المعروض حاليًا داخل التقويم (تاريخ → سعر أصلي +
  // سعر نهائي)، لنوع الإقامة المختار حاليًا. تُستخدم فقط لعرض السعر تحت
  // كل يوم بالتقويم، ولا تُستخدم أبدًا لحساب الإجمالي — الإجمالي مصدره
  // الوحيد هو _fetchServerPrice() عبر BookingService.instance.calculateBookingPrice().
  Map<DateTime, DayPriceInfo> _monthPricing = {};
  bool _monthPricingLoading = false;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // ✅ جديد: رقم تسلسلي لكل طلب جلب أسعار شهر. يُستخدم لضمان أن نتيجة
  // الطلب المطبَّقة على الشاشة هي دائمًا نتيجة *آخر* طلب أُرسل (آخر نوع
  // إقامة أو آخر شهر اختاره المستخدم) — وليس بالضرورة آخر رد وصل من
  // الشبكة، لأن ترتيب وصول الردود غير مضمون عند إرسال طلبات متتالية
  // بسرعة (مثلاً تبديل سريع بين "مسائية" و"صباحية"). بدون هذا الحارس،
  // رد متأخر لطلب قديم ممكن يكتب فوق نتيجة الطلب الأحدث ويسبب ظهور
  // أسعار نوع إقامة غلط على التقويم.
  int _monthPricingRequestId = 0;

  // ✅ جديد: مؤقّت لتأجيل استدعاء _fetchServerPrice() عند تغيير عدد
  // الضيوف، عشان ضغطات + / - المتتالية والسريعة ما تولّد طلب شبكة لكل
  // ضغطة. الطلب الفعلي بينطلق فقط بعد ما المستخدم يتوقف عن الضغط لمدة
  // قصيرة (500ms).
  Timer? _guestsDebounce;

  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _guestsDebounce?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _fetchServerPrice() async {
    if (_checkIn == null || _checkOut == null) return;
    if (_nights < 1) return;

    setState(() {
      _priceLoading = true;
      _availabilityError = null;
      _serverTotalPrice = null;
      _isAvailable = true;
      _serverCalculated = false;
    });

    // 1) Availability check (RPC) before calculating price.
    try {
      final available = await ChaletService.instance.isAvailable(
        chaletId: widget.chalet.id,
        checkIn: _checkIn!,
        checkOut: _checkOut!,
      );

      if (!mounted) return;
      if (!available) {
        setState(() {
          _serverTotalPrice = null;
          _isAvailable = false;
          _serverCalculated = false;
          _availabilityError = 'عذراً، هذا الشاليه محجوز في التواريخ المحددة';
        });
        return;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverTotalPrice = null;
        _isAvailable = false;
        _serverCalculated = false;
        _availabilityError =
            'تعذر التحقق من التوفر حالياً، يرجى المحاولة لاحقاً';
      });
      return;
    }

    // 2) Price calculation.
    // ✅ يستخدم النظام الجديد بالكامل (نوع الإقامة ← سعر التاريخ ← سعر يوم
    // الأسبوع ← السعر الافتراضي) عبر BookingService.calculateBookingPrice.
    try {
      final price = await BookingService.instance.calculateBookingPrice(
        chaletId: widget.chalet.id,
        checkIn: _checkIn!,
        checkOut: _checkOut!,
        guestsCount: _guests,
        stayType: _selectedStayType,
      );

      if (!mounted) return;
      setState(() {
        _serverTotalPrice = price;
        _isAvailable = true;
        _availabilityError = null;
        _serverCalculated = true;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final is409 = msg.contains('409');

      setState(() {
        _serverTotalPrice = null;

        // If we hit a 409 conflict, treat it as an availability conflict.
        // Otherwise consider the booking unavailable until we can re-check.
        _isAvailable = is409;

        _serverCalculated = false;
        _availabilityError = is409
            ? 'عذراً، هذا الشاليه محجوز في التواريخ المحددة'
            : 'تعذر حساب السعر حالياً، يرجى المحاولة لاحقاً';
      });
    } finally {
      if (mounted) setState(() => _priceLoading = false);
    }
  }

  /// ✅ جديد: يجلب أنواع الإقامة المفعّلة لهذا الشاليه. لو موجودة، يختار
  /// أول نوع تلقائيًا (الأقل sort_order) ويحمّل تسعير الشهر على أساسه.
  /// لو ما في ولا نوع مفعّل، يبقى النظام يشتغل بنوع 'default' بدون أي
  /// تغيير على الواجهة (توافق كامل مع الشاليهات القديمة).
  Future<void> _loadStayTypes() async {
    setState(() => _stayTypesLoading = true);
    try {
      final types = await ChaletPricingService.instance
          .getEnabledStayTypes(widget.chalet.id);
      if (!mounted) return;
      setState(() {
        _enabledStayTypes = types;
        if (types.isNotEmpty) {
          _selectedStayType = types.first.type.dbValue;
        }
      });
    } catch (_) {
      // فشل تحميل أنواع الإقامة لا يكسر الشاشة؛ تبقى تشتغل بنوع 'default'.
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

  /// يجلب خريطة أسعار كل أيام شهر معيّن (سعر أصلي + سعر نهائي) لنوع
  /// الإقامة المختار حاليًا، لعرضها تحت كل يوم في التقويم.
  ///
  /// ✅ مُصلَّح: يستخدم _monthPricingRequestId كحارس ضد race condition.
  /// كل استدعاء ياخد رقم تسلسلي خاص فيه ويثبّت stayType وقت الإطلاق. لو
  /// وصل رد استدعاء قديم بعد ما صار استدعاء أحدث (مثلاً المستخدم بدّل من
  /// "مسائية" إلى "صباحية" بسرعة قبل ما يوصل رد المسائية)، يُتجاهل بالكامل
  /// — هيك التقويم يعرض دايمًا نتيجة آخر نوع إقامة اختاره المستخدم فعليًا،
  /// بغض النظر عن ترتيب وصول الردود من الشبكة.
  Future<void> _loadMonthPricing(DateTime month) async {
    final requestId = ++_monthPricingRequestId;
    final stayTypeForThisRequest = _selectedStayType;

    setState(() => _monthPricingLoading = true);
    try {
      final pricing = await ChaletPricingService.instance.getMonthPricing(
        chaletId: widget.chalet.id,
        year: month.year,
        month: month.month,
        defaultPrice: widget.chalet.pricePerNight,
        stayType: stayTypeForThisRequest,
      );
      if (!mounted) return;

      // تجاهل أي رد وصل متأخر لطلب سابق (تم تجاوزه بطلب أحدث).
      if (requestId != _monthPricingRequestId) return;

      setState(() {
        _monthPricing = pricing;
        _visibleMonth = month;
      });
    } catch (_) {
      // فشل تحميل أسعار الشهر لا يكسر الشاشة؛ الأيام تُعرض بدون سعر تحتها.
    } finally {
      if (mounted && requestId == _monthPricingRequestId) {
        setState(() => _monthPricingLoading = false);
      }
    }
  }

  DayPriceInfo? _priceInfoForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _monthPricing[key];
  }

  @override
  void initState() {
    super.initState();
    // initial load when dates are already set (usually not).
    _loadStayTypes().then((_) {
      _loadMonthPricing(_visibleMonth);
      _fetchServerPrice();
    });
    _fetchBookedDates();
  }

  @override
  void didUpdateWidget(covariant BookingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Chalet can change via navigation; recalculate for safety.
    if (widget.chalet.id != oldWidget.chalet.id) {
      _serverCalculated = false;
      _loadStayTypes().then((_) {
        _loadMonthPricing(_visibleMonth);
        _fetchServerPrice();
      });
      _fetchBookedDates();
    }
  }

  /// ✅ جديد: يؤجل استدعاء _fetchServerPrice() عند تغيير عدد الضيوف، عشان
  /// ضغطات + / - المتتالية والسريعة ما تولّد طلب شبكة منفصل لكل ضغطة.
  /// يُلغى أي مؤقّت سابق لم يُنفَّذ بعد ويُستبدل بمؤقّت جديد، فالطلب
  /// الفعلي ينطلق فقط بعد ما المستخدم يتوقف عن الضغط لمدة 500ms.
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

    // Disable confirm if server price/availability not ready
    if (!_canConfirm) {
      if (_availabilityError != null) {
        _showSnack(_availabilityError!);
      } else {
        _showSnack('يرجى التأكد من التواريخ المتاحة قبل الحجز');
      }
      return;
    }

    setState(() => _loading = true);
    try {
      // ✅ نحتفظ بنتيجة الحجز الفعلية (بدل تجاهلها) عشان نستخدم رقم الحجز
      // الحقيقي من قاعدة البيانات بدل رقم وهمي ثابت بشاشة النجاح.
      final booking = await BookingService.instance.createBooking(
        chaletId: widget.chalet.id,
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

      // ✅ جديد: قاعدة البيانات صارت تمنع تضارب الحجوزات فعليًا على مستوى
      // القيد (EXCLUDE constraint)، فممكن يوصل خطأ تضارب هون حتى لو فحص
      // التوفر بالواجهة نجح لحظة قبل الضغط على "تأكيد" (مستخدم آخر حجز
      // بنفس اللحظة). نميّز هذا الخطأ ونعطي رسالة واضحة بدل الرسالة العامة.
      final msg = e.toString();
      final isConflict = msg.contains('23505') ||
          msg.contains('23P01') ||
          msg.contains('Booking conflict');

      _showSnack(isConflict
          ? 'عذراً، هذا التاريخ أصبح محجوزاً للتو من مستخدم آخر. يرجى اختيار تواريخ أخرى'
          : 'حدث خطأ أثناء الحجز، يرجى المحاولة مجدداً');

      if (isConflict) {
        // نحدّث قائمة الأيام المحجوزة والتوفر فورًا عشان التقويم والسعر
        // يعكسوا الواقع الجديد بدل ما يبقوا يوهموا المستخدم إنه متاح.
        await _fetchBookedDates();
        await _fetchServerPrice();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchBookedDates() async {
    setState(() => _bookedDatesLoading = true);
    try {
      final dates = await BookingService.instance.getBookedDates(
        widget.chalet.id,
      );
      if (!mounted) return;
      setState(() {
        _bookedDates =
            dates.map((d) => DateTime(d.year, d.month, d.day)).toSet();
      });
    } catch (_) {
      // Ignore calendar loading failures.
    } finally {
      if (mounted) setState(() => _bookedDatesLoading = false);
    }
  }

  bool _isDateBooked(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _bookedDates.contains(d);
  }

  Widget _buildSelectedDatesSummary() {
    String? entryLabel;
    String? exitLabel;

    if (_checkIn != null) {
      entryLabel = '${_checkIn!.day}/${_checkIn!.month}/${_checkIn!.year}';
    }
    if (_checkOut != null) {
      exitLabel = '${_checkOut!.day}/${_checkOut!.month}/${_checkOut!.year}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPale.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.login_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entryLabel ?? 'اختر تاريخ الدخول',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPale.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded,
                          color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exitLabel ?? 'اختر تاريخ المغادرة',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  /// ✅ جديد: مشاركة فعلية لتفاصيل الحجز عبر واتساب (بدل الزر القديم اللي
  /// كان بيرجّع للصفحة الرئيسية فقط بدون أي مشاركة حقيقية). يفتح واتساب
  /// بدون رقم هاتف محدد (wa.me/?text=...) عشان المستخدم يختار هو مع مين
  /// يشارك، مع نص جاهز فيه اسم الشاليه ورقم الحجز والتواريخ.
  Future<void> _shareOnWhatsApp(BookingModel booking) async {
    final bookingCode = '#CH-${booking.id.substring(0, 8).toUpperCase()}';
    final text = Uri.encodeComponent(
      'تم تأكيد حجزي في ${widget.chalet.name} 🎉\n'
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

  /// ✅ جديد: يستقبل الحجز الفعلي المُنشأ (booking) بدل الاعتماد على رقم
  /// حجز وهمي ثابت، عشان رقم الحجز المعروض للمستخدم يطابق فعليًا السجل
  /// المخزَّن بقاعدة البيانات.
  void _showSuccessDialog(BookingModel booking) {
    final bookingCode = '#CH-${booking.id.substring(0, 8).toUpperCase()}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            // Decorative backdrop image (UI-only)
            Positioned.fill(
              child: Opacity(
                opacity: 0.25,
                child: Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCnQkhqL0l2tu9HIUMBEI1rEjjAxXG6yhX-A2sNBkhbAEu9bGI870yuGaqcDoq8ZffGAnrL7X1wcEIVWFbNvwlyPNjQC_ifnLDSMGbMPYnwG_n8kMKYh7p0QLpBza-nakVfUUpivzadHD3tOSMvZ7UxlsIzUpEjoe-hB5NOqxS7bN18zzY2L3IPL2C7qEL_IFTHlMRvR6jaBCyLcISFetPdu0UzhjFpXm6JE6YNsNJJZhc8sT8kdeksbcmy_ftOe2gzFx_ZFJrNgVOv',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Celebration visual
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Opacity(
                        opacity: 0.2,
                        child: Icon(
                          Icons.celebration_rounded,
                          size: 120,
                          color: AppColors.primary,
                        ),
                      ),
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPale.withOpacity(0.10),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.9),
                            width: 4,
                          ),
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 58,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Success message
                  const Text(
                    'تم حجزك بنجاح 🎉',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    'تم تأكيد طلبك وإرسال التفاصيل لهاتفك',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Booking id card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.border.withOpacity(0.8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    // ✅ Column لم تعد const لأن محتواها صار ديناميكيًا
                    // (رقم الحجز الحقيقي بدل النص الثابت).
                    child: Column(
                      children: [
                        const Text(
                          'رقم الحجز الخاص بك',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bookingCode,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.charcoal,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Decorative divider
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.border.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.filter_vintage_rounded,
                        size: 18,
                        color: AppColors.primaryFixedDim.withOpacity(0.6),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryFixedDim.withOpacity(0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Action buttons (keep onPressed logic unchanged)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.pop();
                        context.go('/home',
                            extra: 3); // 3 = index تبويب "الحجوزات"
                      },
                      icon: const Icon(Icons.description_rounded),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      label: const Text(
                        'عرض تفاصيل الحجز',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ✅ جديد: مشاركة فعلية عبر واتساب بدل الرجوع للرئيسية.
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _shareOnWhatsApp(booking),
                      icon: const Icon(Icons.share_rounded),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColors.primaryContainer,
                        side: BorderSide(
                          color: AppColors.primaryContainer,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      label: const Text(
                        'شارك على واتساب',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'سيتم التواصل معك عبر الهاتف للتأكيد النهائي خلال دقائق',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedSummaryPrice = _serverTotalPrice;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('تحديد موعد الحجز'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Chalet Summary Card
                _buildChaletSummary(),
                const SizedBox(height: 14),

                // ✅ جديد: اختيار نوع الإقامة (لو الشاليه معرّف له أنواع)
                if (!_stayTypesLoading && _enabledStayTypes.isNotEmpty) ...[
                  _buildStayTypeSection(),
                  const SizedBox(height: 14),
                ],

                // Dates Section (calendar)
                _buildDatesSection(),
                const SizedBox(height: 14),

                // Selected dates summary (UI-only)
                _buildSelectedDatesSummary(),
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
                const SizedBox(height: 120),
              ],
            ),
          ),

          // Sticky booking summary bottom bar (UI-only)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 18,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'المجموع',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          selectedSummaryPrice == null
                              ? '—'
                              : AppCurrency.formatPrice(selectedSummaryPrice),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canConfirm ? _confirm : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'تأكيد الحجز',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
              imageUrl: widget.chalet.coverImage,
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
                    '${AppCurrency.formatPrice(widget.chalet.pricePerNight)} / ليلة',
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

  /// ✅ جديد: قسم اختيار نوع الإقامة — يطابق تصميم "اختر نوع الإقامة"
  /// بتطبيق المنافس: كل نوع بصف قابل للضغط، فيه أيقونة، السعر الأساسي
  /// ("ابتداءً من")، ووقت الوصول/المغادرة. النوع المختار يبرز بخلفية
  /// وحدود ملوّنة.
  Widget _buildStayTypeSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('اختر نوع الإقامة',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final type in _enabledStayTypes) ...[
            _stayTypeOption(type),
            if (type != _enabledStayTypes.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _stayTypeOption(ChaletStayTypeConfig config) {
    final selected = _selectedStayType == config.type.dbValue;
    final price = config.basePrice ?? widget.chalet.pricePerNight;

    return GestureDetector(
      onTap: () => _onStayTypeSelected(config.type.dbValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.sand,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(config.type.icon,
                color: selected ? Colors.white : AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.type.label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'الوصول: ${config.checkinTime.format(context)} • المغادرة: ${config.checkoutTime.format(context)}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: selected
                          ? Colors.white.withOpacity(0.85)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('ابتداءً من',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10,
                        color: selected
                            ? Colors.white.withOpacity(0.85)
                            : AppColors.textHint)),
                Text(AppCurrency.formatPrice(price),
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : AppColors.primary)),
              ],
            ),
          ],
        ),
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
            // ✅ جديد: مفتاح لون توضيحي للتقويم (سعر أصلي مشطوب / عرض خاص)
            if (_monthPricing.values.any((p) => p.isSpecialOffer))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'عرض خاص على أيام محددة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _checkIn ?? DateTime.now(),
              enabledDayPredicate: (day) {
                if (_isDateBooked(day)) return false;
                return true;
              },
              selectedDayPredicate: (day) {
                if (_selectingCheckIn) return isSameDay(_checkIn, day);
                return isSameDay(_checkOut, day);
              },
              rangeStartDay: _checkIn,
              rangeEndDay: _checkOut,
              calendarFormat: CalendarFormat.month,
              rowHeight: 56,
              rangeSelectionMode: RangeSelectionMode.toggledOn,
              // ✅ عند تقليب الشهر داخل التقويم نجيب أسعار الشهر الجديد
              // (async) عشان تظهر تحت كل يوم لنفس نوع الإقامة المختار.
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
                    // Dates changed: wait for checkOut to be selected.
                    _serverCalculated = false;
                  } else {
                    if (selected.isAfter(_checkIn ?? DateTime.now())) {
                      _checkOut = selected;
                      _showCalendar = false;
                    } else {
                      // User picked an earlier date: treat it as a new checkIn.
                      _checkIn = selected;
                      _checkOut = null;
                      _selectingCheckIn = false;
                    }
                    _serverCalculated = false;
                  }
                });

                // Trigger fetch when both dates are valid.
                if (_checkIn != null && _checkOut != null) {
                  _fetchServerPrice();
                }
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
              // ✅ نبني كل خلية يوم يدويًا لعرض السعر الأصلي المشطوب +
              // السعر النهائي + إشارة عرض خاص.
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) =>
                    _buildDayCell(day),
                todayBuilder: (context, day, focusedDay) =>
                    _buildDayCell(day, isToday: true),
                selectedBuilder: (context, day, focusedDay) =>
                    _buildDayCell(day, isSelected: true),
                disabledBuilder: (context, day, focusedDay) =>
                    _buildDayCell(day, isDisabled: true),
                outsideBuilder: (context, day, focusedDay) =>
                    _buildDayCell(day, isOutside: true),
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

  /// ✅ خلية يوم مخصّصة داخل التقويم تعرض رقم اليوم + السعر النهائي تحته،
  /// وفي حال وجود عرض خاص لهذا التاريخ (سعر أقل من السعر الأصلي لنفس
  /// اليوم بالأسبوع) تعرض أيضًا السعر الأصلي مشطوبًا فوقه + نقطة حمراء
  /// صغيرة تشير لوجود عرض خاص (بديل مصغّر لباج "حصري" بتطبيق المنافس،
  /// لأن مساحة خلية التقويم أصغر بكثير من بطاقات التقويم هناك).
  Widget _buildDayCell(
    DateTime day, {
    bool isToday = false,
    bool isSelected = false,
    bool isDisabled = false,
    bool isOutside = false,
  }) {
    final booked = _isDateBooked(day);
    final priceInfo = _priceInfoForDay(day);
    final isSpecialOffer = priceInfo?.isSpecialOffer ?? false;

    Color textColor = AppColors.charcoal;
    Color? bgColor;
    if (isSelected) {
      bgColor = AppColors.primary;
      textColor = Colors.white;
    } else if (isToday) {
      bgColor = AppColors.accent;
      textColor = Colors.white;
    } else if (isDisabled || booked || isOutside) {
      textColor = AppColors.textHint;
    }

    final priceTextColor =
        isSelected || isToday ? Colors.white70 : AppColors.primary;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
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
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  decoration:
                      booked ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
              if (!isDisabled && !booked && priceInfo != null) ...[
                if (isSpecialOffer)
                  Text(
                    AppCurrency.formatPrice(priceInfo.originalPrice),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                      color: (isSelected || isToday
                          ? Colors.white54
                          : AppColors.textHint),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                Text(
                  AppCurrency.formatPrice(priceInfo.finalPrice),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: isSpecialOffer
                        ? (isSelected || isToday
                            ? Colors.white
                            : AppColors.error)
                        : priceTextColor,
                  ),
                ),
              ] else if (!isDisabled && !booked && _monthPricingLoading)
                const SizedBox(
                  width: 6,
                  height: 6,
                  child: CircularProgressIndicator(strokeWidth: 1),
                ),
            ],
          ),
        ),
        // نقطة صغيرة أعلى الخلية تشير لوجود "عرض خاص" على هذا التاريخ
        if (isSpecialOffer && !booked && !isDisabled)
          Positioned(
            top: -2,
            right: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
      ],
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
              // ✅ جديد: ما عاد يستدعي _fetchServerPrice() فورًا بكل ضغطة؛
              // بيستدعي _onGuestsChanged() اللي يؤجل الطلب (debounce) عشان
              // الضغطات المتتالية والسريعة ما تولّد طلب شبكة لكل ضغطة.
              _circleBtn(Icons.remove_rounded, () {
                if (_guests > 1) {
                  setState(() => _guests--);
                  _onGuestsChanged();
                }
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
                  _onGuestsChanged();
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
      onTap: () => onTap(),
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
    final totalText = _total == null ? '-' : AppCurrency.formatPrice(_total!);

    // ✅ ملاحظة: النص الوصفي صار عام ("محسوب حسب أسعار الأيام المختارة")
    // بدل "₪X × عدد الليالي"، لأن الإجمالي ما عاد بالضرورة = سعر ثابت ×
    // عدد الليالي (كل ليلة ممكن يكون سعرها مختلف حسب اليوم/التاريخ/نوع
    // الإقامة المختار).
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryPale),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ملخص السعر',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
              if (_serverCalculated)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'مؤكد',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _priceLoading
              ? const Center(child: CircularProgressIndicator())
              : _priceRow(
                  'تم احتساب السعر حسب أسعار الأيام المختارة ($_nights ليالٍ)',
                  totalText,
                ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _priceRow(
            'المجموع الكلي',
            totalText,
            total: true,
          ),
          if (_availabilityError != null && !_priceLoading) ...[
            const SizedBox(height: 10),
            Text(
              _availabilityError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool total = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: total ? 15 : 12.5,
                  fontWeight: total ? FontWeight.w800 : FontWeight.w500,
                  color: total ? AppColors.charcoal : AppColors.textSecondary)),
        ),
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
