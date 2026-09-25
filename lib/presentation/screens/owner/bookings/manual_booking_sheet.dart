import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../data/models/booking_period.dart';
import '../../../../data/services/chalet_slot_availability.dart';
import '../../../../data/services/pricing_service.dart';
import '../../../../data/services/services.dart';

part 'manual_booking_sections.dart';

part 'manual_booking_models.dart';


/// يفتح ورقة الحجز اليدوي بعد تحميل شاليهات المالك. يرجع true إذا تم الحجز.
///
/// [chaletId] و[checkIn] اختياريان: يحدّدان الشاليه وتاريخ الوصول مسبقاً
/// (عند الفتح من يوم بالتقويم).
Future<bool> openManualBookingSheet(
  BuildContext context, {
  String? chaletId,
  DateTime? checkIn,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  void snack(String msg) => messenger.showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.primary,
      ));

  final ownerId = AuthService.instance.currentUser?.id;
  if (ownerId == null) return false;

  List<ManualBookingChalet> chalets;
  try {
    final rows = await ChaletService.instance.getOwnerChalets(ownerId);
    chalets = rows.map(ManualBookingChalet.fromRow).toList();
  } catch (_) {
    snack('تعذر تحميل شاليهاتك، حاول مرة أخرى');
    return false;
  }
  if (chalets.isEmpty) {
    snack('أضف شاليهاً أولاً حتى تتمكن من إدخال حجز يدوي');
    return false;
  }
  if (!context.mounted) return false;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ManualBookingSheet(
      chalets: chalets,
      initialChaletId: chaletId,
      initialCheckIn: checkIn,
      // المصدر الموحّد: الفترات المحجوزة والأيام المحجوبة معاً (وإلا يقبل
      // التقويم يوماً حجبه المالك ثم يرفضه الـ trigger).
      loadDaySlots: (id) => BookingService.instance.getDaySlots(id),
      loadStayTypes: ChaletPricingService.instance.getEnabledStayTypes,
      quotePrice: (chaletId, checkIn, checkOut, stayType) =>
          BookingService.instance.calculateBookingPrice(
        chaletId: chaletId,
        checkIn: checkIn,
        checkOut: checkOut,
        guestsCount: 1,
        stayType: stayType,
      ),
      submit: (r) => BookingService.instance.createExternalBooking(
        chaletId: r.chaletId,
        checkIn: r.checkIn,
        checkOut: r.checkOut,
        guestsCount: r.guestsCount,
        totalPrice: r.totalPrice,
        guestName: r.guestName,
        guestPhone: r.guestPhone,
        notes: r.notes,
        stayType: r.stayType,
      ),
    ),
  );
  return saved == true;
}

/// ورقة إدخال حجز يدوي: نوع الإقامة (إن عرّفه الشاليه) + تواريخ (بتعطيل
/// الأيام غير المتاحة لنوع الإقامة المختار) + سعر متفق عليه يكتبه المالك
/// (مقترحه سعر التقويم) + اسم وهاتف وعدد ضيوف. الاعتماديات مُمرَّرة من
/// الخارج حتى يمكن اختبار الورقة بدون اتصال فعلي بقاعدة البيانات.
class ManualBookingSheet extends StatefulWidget {
  final List<ManualBookingChalet> chalets;
  final LoadDaySlots loadDaySlots;
  final LoadStayTypes loadStayTypes;
  final QuotePrice quotePrice;
  final SubmitManualBooking submit;

  /// شاليه وتاريخ وصول محدّدان مسبقاً (اختياريان). تاريخ الوصول يُهمل إن كان
  /// ماضياً أو غير متاح بعد تحميل الليالي غير المتاحة.
  final String? initialChaletId;
  final DateTime? initialCheckIn;

  /// لتثبيت "اليوم" في الاختبارات فقط.
  final DateTime? today;

  const ManualBookingSheet({
    super.key,
    required this.chalets,
    required this.loadDaySlots,
    this.loadStayTypes = _noStayTypes,
    required this.quotePrice,
    required this.submit,
    this.initialChaletId,
    this.initialCheckIn,
    @visibleForTesting this.today,
  });

  static Future<List<ChaletStayTypeConfig>> _noStayTypes(String _) async =>
      const [];

  @override
  State<ManualBookingSheet> createState() => _ManualBookingSheetState();
}

class _ManualBookingSheetState extends State<ManualBookingSheet> {
  // لأجزاء الشاشة (extensions بملفات part) التي لا تستطيع استدعاء
  // setState المحمي مباشرة.
  void _setState(VoidCallback fn) => setState(fn);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late final DateTime _today;
  late ManualBookingChalet _chalet;

  Map<DateTime, ChaletDaySlot> _slots = {};
  bool _loadingBooked = true;
  String? _bookedLoadError;

  // فترات الشاليه (أنواع الإقامة المفعّلة، أو "يوم كامل" بلا أنواع).
  List<BookingPeriod> _periods = const [BookingPeriod.fullDayDefault];

  /// الفترة المختارة (stay_type)، أو null قبل أن يختار المالك.
  String? _stayType;

  DateTime _focusedDay = DateTime.now();

  // الحجز = يوم واحد + فترة: check_in = اليوم، check_out = اليوم التالي.
  DateTime? _date;
  DateTime? get _checkIn => _date;
  DateTime? get _checkOut => _date == null ? null : nextDay(_date!);
  String? _dateHint;

  final _priceCtrl = TextEditingController();
  // سعر التقويم المقترح من السيرفر (للعرض فقط، والمالك يكتب سعره).
  double? _quote;
  String? _quoteError;
  bool _priceEdited = false;
  bool _priceLoading = false;
  int _priceToken = 0;

  int _guests = 1;
  bool _showNotes = false;
  bool _saving = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final now = widget.today ?? DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _focusedDay = _today;
    _chalet = widget.chalets.firstWhere(
      (c) => c.id == widget.initialChaletId,
      orElse: () => widget.chalets.first,
    );
    final initial = widget.initialCheckIn;
    if (initial != null && !_dateOnly(initial).isBefore(_today)) {
      _date = _dateOnly(initial);
      _focusedDay = _date!;
    }
    _loadBookedNights();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // ─── اليوم والفترة ────────────────────────────────────────

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  BookingPeriod? get _selectedPeriod {
    for (final p in _periods) {
      if (p.stayType == _stayType) return p;
    }
    return null;
  }

  Future<void> _loadBookedNights() async {
    final chaletId = _chalet.id;
    setState(() {
      _loadingBooked = true;
      _bookedLoadError = null;
    });
    // أنواع الإقامة ثانوية: فشلها يترك فترة "يوم كامل" وحدها.
    final typesFuture = widget
        .loadStayTypes(chaletId)
        .catchError((_) => <ChaletStayTypeConfig>[]);
    try {
      final slots = await widget.loadDaySlots(chaletId);
      final types = await typesFuture;
      if (!mounted || chaletId != _chalet.id) return;
      setState(() {
        _slots = {for (final e in slots.entries) _dateOnly(e.key): e.value};
        _periods = BookingPeriod.forChalet(types);
        _loadingBooked = false;
        // يوم محدَّد مسبقاً لكنه صار بلا أي فترة متاحة: يختار المالك من جديد.
        final d = _date;
        if (d != null && _isBlocked(d)) _date = null;
        _reconcilePeriod();
      });
      if (_date != null && _stayType != null) _fetchPrice();
    } catch (_) {
      final types = await typesFuture;
      if (!mounted || chaletId != _chalet.id) return;
      setState(() {
        _slots = {};
        _periods = BookingPeriod.forChalet(types);
        _loadingBooked = false;
        _bookedLoadError = 'تعذر تحميل الأيام المحجوزة';
        _reconcilePeriod();
      });
    }
  }

  /// هل الفترة [stayType] متاحة باليوم المختار؟ (مطابقة booking_slots)
  bool _isPeriodAvailable(String stayType) =>
      _date == null ||
      isDayAvailableForStayType(_date!, stayType: stayType, slots: _slots);

  /// تبقى الفترة المختارة إن ظلت متاحة، وتُختار تلقائياً إن بقيت فترة
  /// متاحة واحدة فقط، وإلا يختار المالك.
  void _reconcilePeriod() {
    final current = _stayType;
    if (current != null &&
        _periods.any((p) => p.stayType == current) &&
        _isPeriodAvailable(current)) {
      return;
    }
    final available =
        _periods.where((p) => _isPeriodAvailable(p.stayType)).toList();
    _stayType = available.length == 1 ? available.single.stayType : null;
  }

  /// اليوم معطّل إن لم تبقَ فيه أي فترة متاحة (تستخدمها الخلايا والنقر معاً).
  bool _isBlocked(DateTime day) => !_periods.any((p) =>
      isDayAvailableForStayType(day, stayType: p.stayType, slots: _slots));

  /// فترة واحدة فقط محجوزة بهذا اليوم (يُعلَّم بالتقويم).
  ChaletDaySlot? _partialSlot(DateTime day) {
    final s = _slots[_dateOnly(day)];
    return s != null && s.isPartiallyBooked ? s : null;
  }

  void _onDayTapped(DateTime selected) {
    final day = _dateOnly(selected);

    if (_isBlocked(day)) {
      setState(() => _dateHint = 'هذا اليوم محجوز بالكامل');
      return;
    }

    setState(() {
      _dateHint = null;
      _submitError = null;
      _date = day;
      _resetQuote();
      _reconcilePeriod();
    });

    if (_stayType != null) _fetchPrice();
  }

  void _onChaletChanged(ManualBookingChalet chalet) {
    if (chalet.id == _chalet.id) return;
    setState(() {
      _chalet = chalet;
      _date = null;
      _stayType = null;
      _dateHint = null;
      _resetQuote();
      _submitError = null;
      final max = chalet.maxGuests;
      if (max != null && _guests > max) _guests = max;
    });
    _loadBookedNights();
  }

  void _onStayTypeChanged(String stayType) {
    if (stayType == _stayType) return;
    if (!_isPeriodAvailable(stayType)) {
      setState(() => _dateHint = 'هذه الفترة محجوزة في اليوم المختار');
      return;
    }
    setState(() {
      _stayType = stayType;
      _dateHint = null;
      _submitError = null;
      _resetQuote();
    });
    if (_date != null) _fetchPrice();
  }

  // ─── السعر (المقترح من التقويم + حقل يكتبه المالك) ─────────

  /// يمسح المقترح عند تغيّر التواريخ أو الشاليه. سعر كتبه المالك بيده يبقى.
  void _resetQuote() {
    _quote = null;
    _quoteError = null;
    _priceLoading = false;
    _priceToken++;
    if (!_priceEdited) _priceCtrl.clear();
  }

  void _applyQuoteToField() {
    final q = _quote;
    if (q == null) return;
    _priceCtrl.text = q.toStringAsFixed(0);
    _priceEdited = false;
  }

  Future<void> _fetchPrice() async {
    final token = ++_priceToken;
    final checkIn = _checkIn!;
    final checkOut = _checkOut!;
    final stayType = _stayType!;
    setState(() {
      _priceLoading = true;
      _quote = null;
      _quoteError = null;
    });
    try {
      final value =
          await widget.quotePrice(_chalet.id, checkIn, checkOut, stayType);
      if (!mounted || token != _priceToken) return;
      setState(() {
        _priceLoading = false;
        if (value <= 0) {
          _quoteError = 'لا يوجد سعر مقترح لهذه الفترة — اكتب السعر المتفق عليه';
        } else {
          _quote = value;
          if (!_priceEdited) _applyQuoteToField();
        }
      });
    } catch (_) {
      if (!mounted || token != _priceToken) return;
      setState(() {
        _priceLoading = false;
        _quoteError = 'تعذر جلب سعر التقويم — اكتب السعر المتفق عليه';
      });
    }
  }

  // ─── الحفظ ────────────────────────────────────────────────

  bool get _canSubmit =>
      !_saving && _date != null && _stayType != null && !_priceLoading;

  Future<void> _save() async {
    if (!_canSubmit) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _submitError = null;
    });
    try {
      final notes = _notesCtrl.text.trim();
      await widget.submit(ManualBookingRequest(
        chaletId: _chalet.id,
        checkIn: _checkIn!,
        checkOut: _checkOut!,
        guestsCount: _guests,
        guestName: _nameCtrl.text.trim(),
        guestPhone: _phoneCtrl.text.trim(),
        notes: notes.isEmpty ? null : notes,
        totalPrice: parseManualPrice(_priceCtrl.text)!,
        stayType: _stayType!,
      ));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _saving = false;
        _submitError = msg.isEmpty ? 'فشل الحفظ، يرجى المحاولة لاحقاً' : msg;
      });
    }
  }

  // ─── الواجهة ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.sand,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('حجز يدوي',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.charcoal)),
                const SizedBox(height: 2),
                const Text('لزبون كلّمك بالتلفون أو وجاهياً — تنحجز الفترة فوراً',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                _buildChaletPicker(),
                _buildCalendar(),
                const SizedBox(height: 10),
                _buildStayTypePicker(),
                _buildSelectionSummary(),
                const SizedBox(height: 12),
                _buildPriceField(),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  validator: validateManualGuestName,
                  decoration: _inputDecoration('اسم الضيف',
                      icon: Icons.person_outline_rounded),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  validator: validateManualGuestPhone,
                  decoration: _inputDecoration('رقم الهاتف',
                      icon: Icons.phone_outlined),
                ),
                const SizedBox(height: 10),
                _buildGuestsStepper(),
                const SizedBox(height: 6),
                if (_showNotes)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: TextFormField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: _inputDecoration('ملاحظة (اختياري)',
                          icon: Icons.notes_rounded),
                    ),
                  )
                else
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showNotes = true),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('إضافة ملاحظة',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                    ),
                  ),
                if (_submitError != null) ...[
                  const SizedBox(height: 10),
                  Text(_submitError!,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error)),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.2))
                        : const Text('حجز الفترة',
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
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.sand),
      ),
    );
  }
}
