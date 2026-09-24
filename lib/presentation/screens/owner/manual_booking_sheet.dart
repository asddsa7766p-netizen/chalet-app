import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/services/chalet_slot_availability.dart';
import '../../../data/services/pricing_service.dart';
import '../../../data/services/services.dart';

/// شاليه كما يحتاجه نموذج الحجز اليدوي.
class ManualBookingChalet {
  final String id;
  final String name;
  final int? maxGuests;

  const ManualBookingChalet({
    required this.id,
    required this.name,
    this.maxGuests,
  });

  factory ManualBookingChalet.fromRow(Map<String, dynamic> row) {
    final name = (row['name'] as String?)?.trim() ?? '';
    return ManualBookingChalet(
      id: row['id'] as String,
      name: name.isEmpty ? 'بدون اسم' : name,
      maxGuests: (row['max_guests'] as num?)?.toInt(),
    );
  }
}

class ManualBookingRequest {
  final String chaletId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guestsCount;
  final String guestName;
  final String guestPhone;
  final String? notes;

  /// السعر المتفق عليه مع الضيف (يكتبه المالك، ومقترحه سعر التقويم).
  final double totalPrice;

  /// نوع الإقامة ('default' إن لم يعرّف الشاليه أنواع إقامة).
  final String stayType;

  const ManualBookingRequest({
    required this.chaletId,
    required this.checkIn,
    required this.checkOut,
    required this.guestsCount,
    required this.guestName,
    required this.guestPhone,
    required this.notes,
    required this.totalPrice,
    this.stayType = BookingService.defaultStayType,
  });
}

/// توفر الفترتين (صباحية/مسائية) لكل يوم — نفس مصدر تقويم الضيف.
typedef LoadDaySlots = Future<Map<DateTime, ChaletDaySlot>> Function(
    String chaletId);
typedef LoadStayTypes = Future<List<ChaletStayTypeConfig>> Function(
    String chaletId);
typedef QuotePrice = Future<double> Function(
    String chaletId, DateTime checkIn, DateTime checkOut, String stayType);
typedef SubmitManualBooking = Future<void> Function(
    ManualBookingRequest request);

/// رقم الهاتف: أرقام فقط بعد إزالة المسافات والشرطات والأقواس وعلامة +.
String? validateManualGuestPhone(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return 'رقم الهاتف مطلوب';
  final digits = raw.replaceAll(RegExp(r'[\s\-()+]'), '');
  if (!RegExp(r'^[0-9٠-٩]{7,15}$').hasMatch(digits)) {
    return 'أدخل رقم هاتف صحيح';
  }
  return null;
}

String? validateManualGuestName(String? value) {
  final name = (value ?? '').trim();
  if (name.isEmpty) return 'اسم الضيف مطلوب';
  if (name.length < 2) return 'الاسم قصير جداً';
  return null;
}

/// يحوّل نص السعر لرقم (يقبل الأرقام العربية-الهندية وفاصلة عشرية "،" أو ",").
double? parseManualPrice(String? value) {
  var raw = (value ?? '').trim();
  if (raw.isEmpty) return null;
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < arabicDigits.length; i++) {
    raw = raw.replaceAll(arabicDigits[i], '$i');
  }
  raw = raw.replaceAll('،', '.').replaceAll(',', '.').replaceAll(' ', '');
  return double.tryParse(raw);
}

/// السيرفر يرفض السعر ≤ 0 (لا حجز مجاني)، فنرفضه هنا برسالة واضحة.
String? validateManualPrice(String? value) {
  if ((value ?? '').trim().isEmpty) return 'اكتب السعر المتفق عليه';
  final price = parseManualPrice(value);
  if (price == null) return 'أدخل رقماً صحيحاً';
  if (price <= 0) return 'السعر يجب أن يكون أكبر من صفر';
  return null;
}

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
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late final DateTime _today;
  late ManualBookingChalet _chalet;

  Map<DateTime, ChaletDaySlot> _slots = {};
  bool _loadingBooked = true;
  String? _bookedLoadError;

  // أنواع الإقامة المفعّلة للشاليه؛ فارغة = السلوك القديم ('default').
  List<ChaletStayTypeConfig> _stayTypes = [];
  String _stayType = BookingService.defaultStayType;

  DateTime _focusedDay = DateTime.now();
  DateTime? _checkIn;
  DateTime? _checkOut;
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
      _checkIn = _dateOnly(initial);
      _focusedDay = _checkIn!;
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

  // ─── التواريخ ─────────────────────────────────────────────

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadBookedNights() async {
    final chaletId = _chalet.id;
    setState(() {
      _loadingBooked = true;
      _bookedLoadError = null;
    });
    // أنواع الإقامة ثانوية: فشلها يعيد السلوك القديم ('default') فقط.
    final typesFuture = widget
        .loadStayTypes(chaletId)
        .catchError((_) => <ChaletStayTypeConfig>[]);
    try {
      final slots = await widget.loadDaySlots(chaletId);
      final types = await typesFuture;
      if (!mounted || chaletId != _chalet.id) return;
      setState(() {
        _slots = {for (final e in slots.entries) _dateOnly(e.key): e.value};
        _stayTypes = types;
        final known = types.any((t) => t.type.dbValue == _stayType);
        if (!known) {
          // نفس اختيار شاشة الضيف: أول نوع مفعّل، وإلا 'default'.
          _stayType = types.isEmpty
              ? BookingService.defaultStayType
              : types.first.type.dbValue;
        }
        _loadingBooked = false;
        // وصول محدَّد مسبقاً لكنه صار غير متاح: نتركه للمالك ليختار من جديد.
        final ci = _checkIn;
        if (ci != null && _checkOut == null && _isBlocked(ci)) {
          _checkIn = null;
        }
      });
    } catch (_) {
      final types = await typesFuture;
      if (!mounted || chaletId != _chalet.id) return;
      setState(() {
        _slots = {};
        _stayTypes = types;
        _loadingBooked = false;
        _bookedLoadError = 'تعذر تحميل الأيام المحجوزة';
      });
    }
  }

  bool get _selectingEnd => _checkIn != null && _checkOut == null;

  /// قاعدة التعطيل الوحيدة (تستخدمها الخلايا والنقر معاً) — نفس قاعدة
  /// تقويم الضيف، حسب نوع الإقامة المختار.
  bool _isBlocked(DateTime day) => isDayDisabledForStaySlot(
        day,
        slots: _slots,
        stayType: _stayType,
        checkIn: _checkIn,
        selectingEnd: _selectingEnd,
      );

  /// فترة واحدة فقط محجوزة بهذا اليوم (يُعلَّم بالتقويم).
  ChaletDaySlot? _partialSlot(DateTime day) {
    final s = _slots[_dateOnly(day)];
    return s != null && s.isPartiallyBooked ? s : null;
  }

  void _onDayTapped(DateTime selected) {
    final day = _dateOnly(selected);

    if (_isBlocked(day)) {
      final String hint;
      if (_selectingEnd && day.isAfter(_checkIn!)) {
        hint = 'الفترة المختارة تتضمن أياماً محجوزة';
      } else if (_partialSlot(day) != null) {
        hint = 'الفترة المطلوبة محجوزة بهذا اليوم — جرّب نوع إقامة آخر';
      } else {
        hint = 'هذا اليوم محجوز';
      }
      setState(() => _dateHint = hint);
      return;
    }

    if (_selectingEnd && isSameDay(day, _checkIn)) {
      setState(() =>
          _dateHint = 'المغادرة يجب أن تكون بعد الوصول بيوم على الأقل');
      return;
    }

    setState(() {
      _dateHint = null;
      _submitError = null;
      if (_selectingEnd && day.isAfter(_checkIn!)) {
        _checkOut = day;
      } else {
        _checkIn = day;
        _checkOut = null;
        _resetQuote();
      }
    });

    if (_checkIn != null && _checkOut != null) _fetchPrice();
  }

  void _onChaletChanged(ManualBookingChalet chalet) {
    if (chalet.id == _chalet.id) return;
    setState(() {
      _chalet = chalet;
      _checkIn = null;
      _checkOut = null;
      _dateHint = null;
      _resetQuote();
      _submitError = null;
      final max = chalet.maxGuests;
      if (max != null && _guests > max) _guests = max;
    });
    _loadBookedNights();
  }

  /// تغيير نوع الإقامة يغيّر الأيام المتاحة والسعر: التواريخ المختارة تبقى
  /// إن بقيت متاحة للنوع الجديد، وإلا تُمسح.
  void _onStayTypeChanged(String stayType) {
    if (stayType == _stayType) return;
    setState(() {
      _stayType = stayType;
      _dateHint = null;
      _submitError = null;
      _resetQuote();
      final ci = _checkIn;
      final co = _checkOut;
      final stillValid = ci != null &&
          isDayAvailableForStayType(ci, stayType: stayType, slots: _slots) &&
          (co == null ||
              !rangeHasUnavailableDayForStayType(ci, co,
                  stayType: stayType, slots: _slots));
      if (!stillValid) {
        _checkIn = null;
        _checkOut = null;
      }
    });
    if (_checkIn != null && _checkOut != null) _fetchPrice();
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
    setState(() {
      _priceLoading = true;
      _quote = null;
      _quoteError = null;
    });
    try {
      final value =
          await widget.quotePrice(_chalet.id, checkIn, checkOut, _stayType);
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
      !_saving &&
      _checkIn != null &&
      _checkOut != null &&
      !_priceLoading;

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
        stayType: _stayType,
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

  static const _monthNames = [
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
    'ديسمبر',
  ];

  String _fmt(DateTime d) => '${d.day} ${_monthNames[d.month - 1]}';

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
                const Text('لزبون كلّمك بالتلفون أو وجاهياً — تنحجز التواريخ فوراً',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                _buildChaletPicker(),
                _buildStayTypePicker(),
                _buildCalendar(),
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
                        : const Text('حجز التواريخ',
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

  Widget _buildChaletPicker() {
    if (widget.chalets.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            const Icon(Icons.home_work_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_chalet.name,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal)),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in widget.chalets)
            ChoiceChip(
              label: Text(c.name,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: c.id == _chalet.id
                        ? Colors.white
                        : AppColors.charcoal,
                  )),
              selected: c.id == _chalet.id,
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              onSelected: (_) => _onChaletChanged(c),
            ),
        ],
      ),
    );
  }

  /// أنواع الإقامة المفعّلة (تُخفى إن لم يعرّف الشاليه أي نوع).
  Widget _buildStayTypePicker() {
    if (_stayTypes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in _stayTypes)
            ChoiceChip(
              key: Key('manual_stay_${t.type.dbValue}'),
              avatar: Icon(t.type.icon,
                  size: 16,
                  color: t.type.dbValue == _stayType
                      ? Colors.white
                      : AppColors.primary),
              label: Text(t.type.label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: t.type.dbValue == _stayType
                        ? Colors.white
                        : AppColors.charcoal,
                  )),
              selected: t.type.dbValue == _stayType,
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              showCheckmark: false,
              onSelected: (_) => _onStayTypeChanged(t.type.dbValue),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand),
      ),
      child: Stack(
        children: [
          TableCalendar(
            locale: 'ar',
            firstDay: _today,
            lastDay: _today.add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            rowHeight: 44,
            // نفس نمط شاشة حجز الزبون: الوضع toggledOn لعرض المدى فقط، والنقر
            // يصل عبر onDaySelected لأن قاعدة التعطيل مخصّصة (_isBlocked).
            rangeSelectionMode: RangeSelectionMode.toggledOn,
            rangeStartDay: _checkIn,
            rangeEndDay: _checkOut,
            onDaySelected: (selected, focused) {
              _focusedDay = focused;
              _onDayTapped(selected);
            },
            onPageChanged: (focused) => _focusedDay = focused,
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focused) =>
                  _dayCell(day, isToday: false),
              todayBuilder: (context, day, focused) =>
                  _dayCell(day, isToday: true),
            ),
            calendarStyle: const CalendarStyle(
              rangeHighlightColor: AppColors.primaryPale,
              rangeStartDecoration: BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              rangeEndDecoration: BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              defaultTextStyle: TextStyle(fontFamily: 'Cairo'),
            ),
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              titleTextStyle: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w800),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12),
              weekendStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12),
            ),
          ),
          if (_loadingBooked)
            const Positioned(
              top: 12,
              left: 12,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime day, {required bool isToday}) {
    final blocked = _isBlocked(day);
    final partial = _partialSlot(day);
    final number = Text(
      '${day.day}',
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: blocked ? AppColors.textHint : AppColors.charcoal,
        decoration: blocked ? TextDecoration.lineThrough : null,
      ),
    );
    return Semantics(
      label: partial == null
          ? null
          : partial.morningBooked
              ? 'الفترة الصباحية محجوزة'
              : 'الفترة المسائية محجوزة',
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.all(3),
        decoration: isToday && !blocked
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 1.5),
              )
            : null,
        // يوم محجوز جزئياً: شمس (الصباحية محجوزة) أو قمر (المسائية) تحت الرقم.
        child: partial == null
            ? number
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  number,
                  Icon(
                    partial.morningBooked
                        ? Icons.wb_sunny_rounded
                        : Icons.nightlight_round,
                    size: 9,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSelectionSummary() {
    String text;
    Color color = AppColors.textSecondary;
    if (_bookedLoadError != null) {
      text = _bookedLoadError!;
      color = AppColors.error;
    } else if (_dateHint != null) {
      text = _dateHint!;
      color = AppColors.error;
    } else if (_checkIn == null) {
      text = 'اختر يوم الوصول';
    } else if (_checkOut == null) {
      text = 'الوصول ${_fmt(_checkIn!)} — اختر يوم المغادرة';
    } else {
      final nights = nightsBetween(_checkIn!, _checkOut!);
      text = 'من ${_fmt(_checkIn!)} إلى ${_fmt(_checkOut!)} · $nights ليالٍ';
      color = AppColors.primary;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }

  Widget _buildPriceField() {
    final quote = _quote;
    final differs = quote != null &&
        parseManualPrice(_priceCtrl.text) != quote.roundToDouble();

    String? helper;
    if (_priceLoading) {
      helper = 'جارٍ جلب سعر التقويم…';
    } else if (_quoteError != null) {
      helper = _quoteError;
    } else if (quote != null) {
      helper = 'سعر التقويم: ₪${quote.toStringAsFixed(0)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.start,
          validator: validateManualPrice,
          onChanged: (_) => setState(() => _priceEdited = true),
          decoration: _inputDecoration('السعر المتفق عليه',
                  icon: Icons.payments_outlined)
              .copyWith(
            prefixText: '₪ ',
            suffixIcon: _priceLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (helper != null || differs)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                if (helper != null)
                  Expanded(
                    child: Text(helper,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  )
                else
                  const Spacer(),
                if (differs)
                  TextButton(
                    onPressed: () => setState(_applyQuoteToField),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('استعادة سعر التقويم',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGuestsStepper() {
    final max = _chalet.maxGuests;
    final canAdd = max == null || _guests < max;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_outlined,
              size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('عدد الضيوف',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
          ),
          IconButton(
            tooltip: 'إنقاص',
            onPressed:
                _guests > 1 ? () => setState(() => _guests--) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          Text('$_guests',
              key: const Key('manual_guests_count'),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          IconButton(
            tooltip: 'زيادة',
            onPressed: canAdd ? () => setState(() => _guests++) : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}
