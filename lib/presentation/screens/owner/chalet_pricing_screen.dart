import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/services/pricing_service.dart';
import 'base_price_notice.dart';
import 'effective_price_panel.dart';
import 'pricing_data_source.dart';
import 'pricing_preview.dart';

/// شاشة تسعير الشاليه بلوحة تحكم المالك.
///
/// الأقسام (من الأعلى):
/// 1) لوحة "السعر الفعلي": جدول الأيام × الأنواع المفعّلة يعرض السعر الذي
///    سيُطبَّق فعلاً ومصدره، ويعكس المسودة (وسم "بعد الحفظ").
/// 2) أنواع الإقامة: تفعيل النوع، الوصول/المغادرة، و"سعر احتياطي للأيام التي
///    بلا سعر" مع إشعار فوري بأثره الفعلي.
/// 3) التسعير الأسبوعي: تبويبات (عام + الأنواع المفعّلة). لكل تبويب مسودته،
///    فتبديل التبويب لا يفقد أي شيء.
/// 4) أسعار التواريخ الخاصة (حفظ فوري، تتفوق على كل ما سبق بتواريخها).
///
/// حماية التعديلات: أي حقل يختلف عن المحفوظ يُعلَّم "لم يُحفظ"، ويظهر شريط
/// "حفظ الكل"، وأي إجراء يفقد المسودة (خروج، سحب للتحديث، إيقاف نوع، تجاهل)
/// يطلب تأكيدًا.
///
/// واجهة فقط: لا يغيّر منطق التسعير ولا قاعدة البيانات، ويستخدم نفس دوال
/// [ChaletPricingService] عبر [PricingDataSource].
class ChaletPricingScreen extends StatefulWidget {
  final String chaletId;
  final String chaletName;
  final double defaultPricePerNight;

  /// مصدر البيانات (للاختبار). الافتراضي: خدمة التسعير الحقيقية.
  final PricingDataSource? dataSource;

  const ChaletPricingScreen({
    super.key,
    required this.chaletId,
    required this.chaletName,
    required this.defaultPricePerNight,
    this.dataSource,
  });

  @override
  State<ChaletPricingScreen> createState() => _ChaletPricingScreenState();
}

/// حقل سعر بمسودة: النص الحالي في [ctrl] مقابل آخر قيمة محفوظة.
class _PriceField {
  _PriceField({required this.allowNegative});

  final bool allowNegative;
  final TextEditingController ctrl = TextEditingController();
  String savedText = '';
  double? savedValue;

  String get text => ctrl.text.trim();
  bool get dirty => text != savedText;

  double? get _parsed {
    final v = parseLocalizedDouble(text);
    if (v == null || (!allowNegative && v < 0)) return null;
    return v;
  }

  /// نص غير فاضي وغير صالح كسعر.
  bool get invalid => dirty && text.isNotEmpty && _parsed == null;

  /// القيمة التي ستُحفظ لو ضُغط حفظ الآن. النص غير الصالح لا يؤثر
  /// (تبقى القيمة المحفوظة) حتى لا يفسد اللوحة أثناء الكتابة.
  double? get draftValue {
    if (!dirty) return savedValue;
    if (text.isEmpty) return null;
    return _parsed ?? savedValue;
  }

  void load(double? value) {
    savedValue = value;
    savedText = value == null ? '' : formatPriceNumber(value);
    ctrl.text = savedText;
  }

  /// بعد حفظ ناجح للنص [savedFromText] (ربما تغيّر الحقل أثناء الحفظ).
  void markSaved(String savedFromText) {
    savedText = savedFromText;
    savedValue =
        savedFromText.isEmpty ? null : parseLocalizedDouble(savedFromText);
  }

  void reset() {
    ctrl.text = savedText;
  }
}

enum _LeaveChoice { save, discard, stay }

typedef _DateOverrideInput = ({String price, String note});

/// حوار "سعر خاص لتاريخ محدد": يرجع النصين عند الحفظ، أو null عند الإلغاء.
class _DateOverrideDialog extends StatefulWidget {
  const _DateOverrideDialog({required this.date, required this.scopeLabel});

  final DateTime date;
  final String scopeLabel;

  @override
  State<_DateOverrideDialog> createState() => _DateOverrideDialogState();
}

class _DateOverrideDialogState extends State<_DateOverrideDialog> {
  final _price = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.date;
    return AlertDialog(
      title: const Text('سعر خاص لتاريخ محدد',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${d.year}/${d.month}/${d.day}',
            style:
                const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.scopeLabel,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'السعر لهذا اليوم'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري، مثلاً: عيد الفطر)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop<_DateOverrideInput>(
              context, (price: _price.text.trim(), note: _note.text.trim())),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _ChaletPricingScreenState extends State<ChaletPricingScreen> {
  static const String _defaultKey = ChaletPricingService.defaultStayType;
  static final List<String> _allKeys = [
    _defaultKey,
    for (final t in ChaletStayType.values) t.dbValue,
  ];

  late final PricingDataSource _ds =
      widget.dataSource ?? const ServicePricingDataSource();

  bool _loading = true;
  String? _error;
  bool _savingAll = false;
  bool _suspendDraftListener = false;

  // ---- أنواع الإقامة ----
  // إعداد كل نوع كما هو محفوظ (null = لسا ما انضاف/انفعّل)
  final Map<ChaletStayType, ChaletStayTypeConfig?> _stayTypeConfigs = {
    for (final t in ChaletStayType.values) t: null,
  };
  final Set<ChaletStayType> _stayTypeEnabled = {};
  final Set<ChaletStayType> _savingStayType = {};

  // السعر الاحتياطي لكل نوع (مسودة + محفوظ)
  final Map<ChaletStayType, _PriceField> _baseFields = {
    for (final t in ChaletStayType.values) t: _PriceField(allowNegative: true),
  };
  // أوقات الوصول/المغادرة: المسودة والمحفوظ
  final Map<ChaletStayType, TimeOfDay> _draftCheckin = {
    for (final t in ChaletStayType.values) t: t.defaultCheckin,
  };
  final Map<ChaletStayType, TimeOfDay> _draftCheckout = {
    for (final t in ChaletStayType.values) t: t.defaultCheckout,
  };
  final Map<ChaletStayType, TimeOfDay> _savedCheckin = {
    for (final t in ChaletStayType.values) t: t.defaultCheckin,
  };
  final Map<ChaletStayType, TimeOfDay> _savedCheckout = {
    for (final t in ChaletStayType.values) t: t.defaultCheckout,
  };

  // ---- التسعير الأسبوعي: مسودة لكل نوع (المفتاح 'default' أو dbValue) ----
  final Map<String, Map<int, _PriceField>> _weekdayFields = {
    for (final key in _allKeys)
      key: {for (var d = 0; d < 7; d++) d: _PriceField(allowNegative: false)},
  };
  final Set<String> _savingWeekday = {}; // '$key:$day'

  /// نوع الإقامة الذي تُعدَّل أسعاره الآن (تبويب). 'default' = عام.
  String _selectedEditingType = _defaultKey;

  // ---- أسعار التواريخ الخاصة (للتبويب المحدد، حفظ فوري) ----
  List<ChaletDatePrice> _dateOverrides = [];
  bool _loadingOverrides = false;
  bool _savingDateOverride = false;

  final GlobalKey _weekdaySectionKey = GlobalKey();

  Iterable<_PriceField> get _allFields sync* {
    for (final f in _baseFields.values) {
      yield f;
    }
    for (final days in _weekdayFields.values) {
      yield* days.values;
    }
  }

  @override
  void initState() {
    super.initState();
    for (final f in _allFields) {
      f.ctrl.addListener(_onDraftChanged);
    }
    _loadAll();
  }

  @override
  void dispose() {
    for (final f in _allFields) {
      f.ctrl.dispose();
    }
    super.dispose();
  }

  void _onDraftChanged() {
    if (_suspendDraftListener || !mounted) return;
    setState(() {});
  }

  // ==========================================================
  // التحميل
  // ==========================================================

  /// يحمّل أنواع الإقامة وأسعار أيام "عام" وكل الأنواع دفعة واحدة بالتوازي
  /// (لأن لوحة السعر الفعلي تحتاجها كلها)، مع أسعار التواريخ الخاصة للتبويب
  /// الحالي.
  Future<void> _loadAll({bool spinner = true}) async {
    setState(() {
      if (spinner) _loading = true;
      _error = null;
    });

    try {
      final id = widget.chaletId;
      final results = await Future.wait<dynamic>([
        _ds.getStayTypes(id),
        _ds.getDateOverrides(id, stayType: _selectedEditingType),
        for (final key in _allKeys) _ds.getWeekdayPrices(id, stayType: key),
      ]);
      if (!mounted) return;

      final stayTypes = results[0] as List<ChaletStayTypeConfig>;
      final overrides = results[1] as List<ChaletDatePrice>;

      _suspendDraftListener = true;
      try {
        _stayTypeEnabled.clear();
        for (final t in ChaletStayType.values) {
          _stayTypeConfigs[t] = null;
          _baseFields[t]!.load(null);
          _savedCheckin[t] = _draftCheckin[t] = t.defaultCheckin;
          _savedCheckout[t] = _draftCheckout[t] = t.defaultCheckout;
        }
        for (final config in stayTypes) {
          final t = config.type;
          _stayTypeConfigs[t] = config;
          if (config.isEnabled) _stayTypeEnabled.add(t);
          _savedCheckin[t] = _draftCheckin[t] = config.checkinTime;
          _savedCheckout[t] = _draftCheckout[t] = config.checkoutTime;
          _baseFields[t]!.load(config.basePrice);
        }
        for (var i = 0; i < _allKeys.length; i++) {
          final prices = results[2 + i] as Map<int, double>;
          for (var d = 0; d < 7; d++) {
            _weekdayFields[_allKeys[i]]![d]!.load(prices[d]);
          }
        }
      } finally {
        _suspendDraftListener = false;
      }

      // تبويب نوع لم يعد مفعّلاً (بعد تحديث) يرجع لـ"عام".
      if (_selectedEditingType != _defaultKey &&
          !_stayTypeEnabled
              .contains(ChaletStayType.fromDb(_selectedEditingType))) {
        _selectedEditingType = _defaultKey;
        _dateOverrides = [];
        setState(() => _loading = false);
        await _reloadOverrides();
        return;
      }

      setState(() {
        _dateOverrides = overrides;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'تعذر تحميل الأسعار، يرجى المحاولة لاحقاً';
          _loading = false;
        });
      }
    }
  }

  Future<void> _reloadOverrides() async {
    final key = _selectedEditingType;
    setState(() => _loadingOverrides = true);
    try {
      final list = await _ds.getDateOverrides(widget.chaletId, stayType: key);
      if (!mounted || key != _selectedEditingType) return;
      setState(() => _dateOverrides = list);
    } catch (_) {
      if (mounted && key == _selectedEditingType) {
        _showSnack('تعذر تحميل الأسعار الخاصة', isError: true);
      }
    } finally {
      if (mounted && key == _selectedEditingType) {
        setState(() => _loadingOverrides = false);
      }
    }
  }

  // ==========================================================
  // اللقطات (المحفوظ / المسودة) ومساعدات الحالة
  // ==========================================================

  PricingSnapshot _snapshot({required bool draft}) {
    double? pick(_PriceField f) => draft ? f.draftValue : f.savedValue;

    Map<int, double> daysOf(String key) {
      final out = <int, double>{};
      for (final e in _weekdayFields[key]!.entries) {
        final v = pick(e.value);
        if (v != null) out[e.key] = v;
      }
      return out;
    }

    return PricingSnapshot(
      chaletDefaultPrice: widget.defaultPricePerNight,
      defaultWeekday: daysOf(_defaultKey),
      typeWeekday: {
        for (final t in ChaletStayType.values) t: daysOf(t.dbValue),
      },
      basePrice: {
        for (final t in ChaletStayType.values) t: pick(_baseFields[t]!),
      },
    );
  }

  List<ChaletStayType> get _enabledTypes => [
        for (final t in ChaletStayType.values)
          if (_stayTypeEnabled.contains(t)) t,
      ];

  List<String> get _visibleKeys =>
      [_defaultKey, for (final t in _enabledTypes) t.dbValue];

  bool _cardDirty(ChaletStayType t) =>
      _stayTypeEnabled.contains(t) &&
      (_baseFields[t]!.dirty ||
          _draftCheckin[t] != _savedCheckin[t] ||
          _draftCheckout[t] != _savedCheckout[t]);

  int _dirtyWeekdays(String key) =>
      _weekdayFields[key]!.values.where((f) => f.dirty).length;

  int _typeDraftCount(ChaletStayType t) =>
      _dirtyWeekdays(t.dbValue) +
      (_baseFields[t]!.dirty ? 1 : 0) +
      (_draftCheckin[t] != _savedCheckin[t] ||
              _draftCheckout[t] != _savedCheckout[t]
          ? 1
          : 0);

  int get _dirtyCount {
    var n = 0;
    for (final key in _visibleKeys) {
      n += _dirtyWeekdays(key);
    }
    for (final t in _enabledTypes) {
      if (_cardDirty(t)) n++;
    }
    return n;
  }

  bool get _hasDirty => _dirtyCount > 0;

  void _discardType(ChaletStayType t) {
    for (final f in _weekdayFields[t.dbValue]!.values) {
      f.reset();
    }
    _baseFields[t]!.reset();
    _draftCheckin[t] = _savedCheckin[t]!;
    _draftCheckout[t] = _savedCheckout[t]!;
  }

  void _discardAll() {
    setState(() {
      for (final key in _allKeys) {
        for (final f in _weekdayFields[key]!.values) {
          f.reset();
        }
      }
      for (final t in ChaletStayType.values) {
        _baseFields[t]!.reset();
        _draftCheckin[t] = _savedCheckin[t]!;
        _draftCheckout[t] = _savedCheckout[t]!;
      }
    });
  }

  // ==========================================================
  // تبديل التبويب (لا يفقد أي مسودة)
  // ==========================================================

  Future<void> _selectEditingType(String key) async {
    if (key == _selectedEditingType) return;
    setState(() {
      _selectedEditingType = key;
      _dateOverrides = [];
    });
    await _reloadOverrides();
  }

  /// يفتح تبويب النوع ويمرّر الشاشة لقسم الأسعار الأسبوعية.
  Future<void> _openTypePrices(String key) async {
    final future = _selectEditingType(key);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _weekdaySectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    await future;
  }

  // ==========================================================
  // أنواع الإقامة
  // ==========================================================

  Future<void> _toggleStayType(ChaletStayType type, bool enabled) async {
    if (!enabled && _typeDraftCount(type) > 0) {
      final ok = await _confirmDialog(
        title: 'تعديلات غير محفوظة',
        body: 'إيقاف "${type.label}" رح يمسح ${_typeDraftCount(type)} '
            'تعديل غير محفوظ خاص فيه. بدك تكمل؟',
        confirmLabel: 'أوقفه وتجاهل التعديلات',
      );
      if (ok != true || !mounted) return;
      setState(() => _discardType(type));
    }

    setState(() => _savingStayType.add(type));
    try {
      // التبديل يحفظ حالة التفعيل فقط: يستخدم آخر سعر/أوقات محفوظة، ولا
      // يحفظ مسودة لم يضغط المالك حفظ لها.
      final existing = _stayTypeConfigs[type];
      final config = ChaletStayTypeConfig(
        id: existing?.id,
        type: type,
        isEnabled: enabled,
        checkinTime: _savedCheckin[type]!,
        checkoutTime: _savedCheckout[type]!,
        basePrice: _baseFields[type]!.savedValue,
        sortOrder: type.index,
      );
      await _ds.upsertStayType(chaletId: widget.chaletId, config: config);
      var switchedTab = false;
      if (mounted) {
        setState(() {
          _stayTypeConfigs[type] = config;
          if (enabled) {
            _stayTypeEnabled.add(type);
          } else {
            _stayTypeEnabled.remove(type);
            if (_selectedEditingType == type.dbValue) {
              _selectedEditingType = _defaultKey;
              _dateOverrides = [];
              switchedTab = true;
            }
          }
        });
      }
      _showSnack(
          enabled ? 'تم تفعيل "${type.label}"' : 'تم إيقاف "${type.label}"');
      if (switchedTab) await _reloadOverrides();
    } catch (_) {
      _showSnack('فشل الحفظ، يرجى المحاولة لاحقاً', isError: true);
    } finally {
      if (mounted) setState(() => _savingStayType.remove(type));
    }
  }

  /// يحفظ بطاقة نوع (السعر الاحتياطي + الأوقات). يرجع نجاح العملية.
  Future<bool> _persistCard(ChaletStayType type, {required bool quiet}) async {
    final base = _baseFields[type]!;
    if (base.invalid) {
      if (!quiet) _showSnack('سعر غير صحيح', isError: true);
      return false;
    }
    final baseText = base.text;
    final baseValue = baseText.isEmpty ? null : parseLocalizedDouble(baseText);
    final checkin = _draftCheckin[type]!;
    final checkout = _draftCheckout[type]!;

    setState(() => _savingStayType.add(type));
    try {
      final config = ChaletStayTypeConfig(
        id: _stayTypeConfigs[type]?.id,
        type: type,
        isEnabled: _stayTypeEnabled.contains(type),
        checkinTime: checkin,
        checkoutTime: checkout,
        basePrice: baseValue,
        sortOrder: type.index,
      );
      await _ds.upsertStayType(chaletId: widget.chaletId, config: config);
      if (mounted) {
        setState(() {
          _stayTypeConfigs[type] = config;
          base.markSaved(baseText);
          _savedCheckin[type] = checkin;
          _savedCheckout[type] = checkout;
        });
      }
      if (!quiet) _showSnack('تم حفظ إعدادات "${type.label}"');
      return true;
    } catch (_) {
      if (!quiet) _showSnack('فشل الحفظ، يرجى المحاولة لاحقاً', isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _savingStayType.remove(type));
    }
  }

  Future<void> _pickTime({
    required ChaletStayType type,
    required bool isCheckin,
  }) async {
    final initial = isCheckin ? _draftCheckin[type]! : _draftCheckout[type]!;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    setState(() {
      if (isCheckin) {
        _draftCheckin[type] = picked;
      } else {
        _draftCheckout[type] = picked;
      }
    });
  }

  // ==========================================================
  // التسعير الأسبوعي
  // ==========================================================

  /// يحفظ سعر يوم واحد لنوع (أو 'default'). يرجع نجاح العملية.
  Future<bool> _persistWeekday(String key, int day,
      {required bool quiet}) async {
    final field = _weekdayFields[key]![day]!;
    if (field.invalid) {
      if (!quiet) _showSnack('سعر غير صحيح', isError: true);
      return false;
    }
    final text = field.text;
    final id = '$key:$day';

    setState(() => _savingWeekday.add(id));
    try {
      if (text.isEmpty) {
        await _ds.clearWeekdayPrice(
          chaletId: widget.chaletId,
          weekday: day,
          stayType: key,
        );
      } else {
        await _ds.setWeekdayPrice(
          chaletId: widget.chaletId,
          weekday: day,
          // الحقل صالح هنا (field.invalid فُحص أعلاه).
          price: parseLocalizedDouble(text)!,
          stayType: key,
        );
      }
      if (mounted) setState(() => field.markSaved(text));
      if (!quiet) {
        _showSnack('تم حفظ سعر ${ChaletPricingService.weekdayLabels[day]}');
      }
      return true;
    } catch (_) {
      if (!quiet) _showSnack('فشل الحفظ، يرجى المحاولة لاحقاً', isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _savingWeekday.remove(id));
    }
  }

  /// يحفظ كل التعديلات (بطاقات الأنواع + أسعار الأيام). الحقول التي فشل
  /// حفظها (أو غير صالحة) تبقى معلَّمة "لم يُحفظ". يرجع true لو نجح الكل.
  Future<bool> _saveAll() async {
    if (_savingAll) return false;
    setState(() => _savingAll = true);
    var ok = 0;
    var failed = 0;
    try {
      for (final t in _enabledTypes) {
        if (!_cardDirty(t)) continue;
        (await _persistCard(t, quiet: true)) ? ok++ : failed++;
      }
      for (final key in _visibleKeys) {
        for (var day = 0; day < 7; day++) {
          if (!_weekdayFields[key]![day]!.dirty) continue;
          (await _persistWeekday(key, day, quiet: true)) ? ok++ : failed++;
        }
      }
    } finally {
      if (mounted) setState(() => _savingAll = false);
    }
    if (failed == 0) {
      _showSnack('تم حفظ $ok تعديل');
    } else {
      _showSnack('تم حفظ $ok، وفشل $failed — راجع الحقول المعلَّمة',
          isError: true);
    }
    return failed == 0;
  }

  // ==========================================================
  // أسعار خاصة بتواريخ محددة (لنوع الإقامة المحدد حاليًا، حفظ فوري)
  // ==========================================================

  Future<void> _addDateOverride() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (pickedDate == null || !mounted) return;

    // الحوار يملك حقوله ويتخلّص منها بنفسه (كانت تُنشأ هنا ولا تُحرَّر أبداً).
    final result = await showDialog<_DateOverrideInput>(
      context: context,
      builder: (_) => _DateOverrideDialog(
        date: pickedDate,
        scopeLabel: _selectedEditingType == _defaultKey
            ? 'لكل أنواع الإقامة (عام)'
            : 'لنوع: ${ChaletStayType.fromDb(_selectedEditingType).label}',
      ),
    );

    if (result == null || !mounted) return;

    final price = parseLocalizedDouble(result.price);
    if (price == null || price < 0) {
      _showSnack('سعر غير صحيح', isError: true);
      return;
    }

    final key = _selectedEditingType;
    setState(() => _savingDateOverride = true);
    try {
      await _ds.setDateOverride(
        chaletId: widget.chaletId,
        date: pickedDate,
        price: price,
        note: result.note.isEmpty ? null : result.note,
        stayType: key,
      );
      final overrides =
          await _ds.getDateOverrides(widget.chaletId, stayType: key);
      if (mounted && key == _selectedEditingType) {
        setState(() => _dateOverrides = overrides);
      }
      _showSnack('تم إضافة السعر الخاص');
    } catch (_) {
      _showSnack('فشل الحفظ، يرجى المحاولة لاحقاً', isError: true);
    } finally {
      if (mounted) setState(() => _savingDateOverride = false);
    }
  }

  Future<void> _deleteDateOverride(ChaletDatePrice item) async {
    try {
      await _ds.deleteDateOverride(
        chaletId: widget.chaletId,
        date: item.date,
        stayType: _selectedEditingType,
      );
      if (!mounted) return;
      setState(() {
        _dateOverrides.removeWhere((o) => o.date == item.date);
      });
      _showSnack('تم الحذف');
    } catch (_) {
      _showSnack('فشل الحذف، يرجى المحاولة لاحقاً', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
      ),
    );
  }

  // ==========================================================
  // حوارات التأكيد وحماية التعديلات
  // ==========================================================

  Future<bool?> _confirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Text(body, style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            key: const ValueKey('dialogCancel'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            key: const ValueKey('dialogConfirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: const TextStyle(
                    fontFamily: 'Cairo', color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<_LeaveChoice?> _leaveDialog() {
    return showDialog<_LeaveChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديلات غير محفوظة',
            style:
                TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Text(
          'عندك $_dirtyCount تعديل ما انحفظ. شو بدك تسوي قبل ما تطلع؟',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            key: const ValueKey('leaveStay'),
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.stay),
            child: const Text('البقاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            key: const ValueKey('leaveDiscard'),
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.discard),
            child: const Text('تجاهل',
                style: TextStyle(fontFamily: 'Cairo', color: AppColors.error)),
          ),
          FilledButton(
            key: const ValueKey('leaveSave'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(0, 40),
            ),
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.save),
            child: const Text('حفظ وخروج',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  Future<void> _onPopBlocked() async {
    final choice = await _leaveDialog();
    if (!mounted) return;
    switch (choice) {
      case _LeaveChoice.save:
        if (await _saveAll() && mounted) Navigator.of(context).pop();
      case _LeaveChoice.discard:
        Navigator.of(context).pop();
      case _LeaveChoice.stay:
      case null:
        break;
    }
  }

  Future<void> _onRefresh() async {
    if (_hasDirty) {
      final ok = await _confirmDialog(
        title: 'تجاهل التعديلات؟',
        body: 'التحديث رح يمسح $_dirtyCount تعديل ما انحفظ.',
        confirmLabel: 'تجاهل وحدّث',
      );
      if (ok != true || !mounted) return;
    }
    await _loadAll(spinner: false);
  }

  Future<void> _onDiscardPressed() async {
    final ok = await _confirmDialog(
      title: 'تجاهل التعديلات؟',
      body: 'رح ترجع كل الحقول لآخر قيم محفوظة ($_dirtyCount تعديل).',
      confirmLabel: 'تجاهل',
    );
    if (ok == true && mounted) _discardAll();
  }

  // ==========================================================
  // البناء
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final dirty = _dirtyCount;
    return PopScope(
      canPop: dirty == 0 && !_savingAll,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPopBlocked();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('تسعير: ${widget.chaletName}'),
        ),
        bottomNavigationBar: dirty > 0 ? _buildDirtyBar(dirty) : null,
        body: _loading && _error == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          style: const TextStyle(
                              fontFamily: 'Cairo', color: AppColors.error)),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildEffectivePanel(),
                        const SizedBox(height: 16),
                        _buildStayTypesSection(),
                        const SizedBox(height: 16),
                        _buildWeekdaySection(),
                        const SizedBox(height: 24),
                        _buildDateOverridesSection(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildDirtyBar(int count) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.sand)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.edit_note_rounded,
                  color: AppColors.accentDark, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'لديك $count تعديل غير محفوظ',
                  key: const ValueKey('dirtyBarText'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('discardAllButton'),
                onPressed: _savingAll ? null : _onDiscardPressed,
                child: const Text('تجاهل',
                    style: TextStyle(
                        fontFamily: 'Cairo', color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 4),
              FilledButton(
                key: const ValueKey('saveAllButton'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(96, 40),
                ),
                onPressed: _savingAll ? null : _saveAll,
                child: _savingAll
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('حفظ الكل',
                        style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- لوحة السعر الفعلي ----------------

  Widget _buildEffectivePanel() {
    final enabled = _enabledTypes;
    return EffectivePricePanel(
      columns: enabled.isEmpty ? const [null] : enabled,
      saved: _snapshot(draft: false),
      draft: _snapshot(draft: true),
      selectedKey: _selectedEditingType,
      chaletDefaultPrice: widget.defaultPricePerNight,
      onSelect: _openTypePrices,
    );
  }

  // ---------------- أنواع الإقامة ----------------

  Widget _buildStayTypesSection() {
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
            'أنواع الإقامة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'كل فترة مفعّلة يحجزها الضيف ليوم واحد. حدد وقت بداية ونهاية '
            'الفترة، وسعراً احتياطياً للأيام التي بلا سعر (زي: إقامة صباحية، '
            'إقامة مسائية، يوم كامل...)',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          for (final type in ChaletStayType.values) ...[
            _buildStayTypeCard(type),
            if (type != ChaletStayType.values.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildStayTypeCard(ChaletStayType type) {
    final enabled = _stayTypeEnabled.contains(type);
    final isSaving = _savingStayType.contains(type);
    final base = _baseFields[type]!;
    final cardDirty = _cardDirty(type);

    return Container(
      key: ValueKey('stayCard_${type.dbValue}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.primaryPale.withValues(alpha: 0.15)
            : AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.sand,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(type.icon,
                  size: 20,
                  color: enabled ? AppColors.primary : AppColors.textHint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  type.label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: enabled ? AppColors.charcoal : AppColors.textHint,
                  ),
                ),
              ),
              if (isSaving && !_savingAll)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  key: ValueKey('stayToggle_${type.dbValue}'),
                  value: enabled,
                  activeColor: AppColors.primary,
                  onChanged: _savingAll ? null : (v) => _toggleStayType(type, v),
                ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _timeTile(
                    label: 'بداية الفترة',
                    time: _draftCheckin[type]!,
                    onTap: () => _pickTime(type: type, isCheckin: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _timeTile(
                    label: 'نهاية الفترة',
                    time: _draftCheckout[type]!,
                    onTap: () => _pickTime(type: type, isCheckin: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: ValueKey('baseField_${type.dbValue}'),
              controller: base.ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'سعر احتياطي للأيام التي بلا سعر',
                hintText: 'اختياري',
                helperText:
                    'يُطبَّق فقط على الأيام التي ليس لها سعر يوم (لا لهذا النوع '
                    'ولا «عام»).',
                helperMaxLines: 2,
                errorText: base.invalid ? 'سعر غير صحيح' : null,
                suffixText: base.dirty ? 'لم يُحفظ' : null,
                suffixStyle: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentDark),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: _fieldBorder(dirty: base.dirty),
                enabledBorder: _fieldBorder(dirty: base.dirty),
              ),
            ),
            BasePriceNotice(
              type: type,
              impact: basePriceImpact(_snapshot(draft: true), type),
              onOpenTypePrices: () => _openTypePrices(type.dbValue),
            ),
            const SizedBox(height: 6),
            // Wrap بدل Row+Spacer: يلتف للسطر التالي عند النص الكبير بدل الفيض.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  key: ValueKey('openTypePrices_${type.dbValue}'),
                  onPressed: () => _openTypePrices(type.dbValue),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.calendar_view_week_rounded, size: 16),
                  label: const Text('أسعار الأيام لهذا النوع',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                ),
                _saveButton(
                  key: ValueKey('cardSave_${type.dbValue}'),
                  dirty: cardDirty,
                  saving: isSaving,
                  onTap: () => _persistCard(type, quiet: false),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  OutlineInputBorder _fieldBorder({required bool dirty}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: dirty ? AppColors.accent : AppColors.sand,
          width: dirty ? 1.6 : 1,
        ),
      );

  /// زر "حفظ": بارز عند وجود تعديل، ومعطّل (باهت) بغير ذلك.
  Widget _saveButton({
    required Key key,
    required bool dirty,
    required bool saving,
    required VoidCallback onTap,
  }) {
    if (saving) {
      return const SizedBox(
        width: 64,
        height: 34,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }
    return FilledButton(
      key: key,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        disabledBackgroundColor: AppColors.sand,
        disabledForegroundColor: AppColors.textHint,
        minimumSize: const Size(64, 34),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: dirty && !_savingAll ? onTap : null,
      child: const Text('حفظ',
          style: TextStyle(
              fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }

  Widget _timeTile({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.sand),
        ),
        child: Builder(builder: (context) {
          final labelText = Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: AppColors.textSecondary));
          final timeText = Text(
            time.format(context),
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal),
          );
          // النص الكبير: عمود بدل صف، فلا يفيض (البلاطة نصف عرض البطاقة).
          if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, timeText],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [labelText, timeText],
          );
        }),
      ),
    );
  }

  // ---------------- التسعير الأسبوعي (تبويبات) ----------------

  Widget _buildWeekdaySection() {
    final key = _selectedEditingType;
    final isDefault = key == _defaultKey;
    final type = isDefault ? null : ChaletStayType.fromDb(key);
    final draftSnap = _snapshot(draft: true);

    return Container(
      key: _weekdaySectionKey,
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
            'التسعير الأسبوعي',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'اختر النوع اللي بدك تعدّل أسعار أيامه. تعديلاتك بكل نوع بتنحفظ '
            'كمسودة لحد ما تضغط "حفظ".',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _typeTab(label: 'كل الأنواع (عام)', value: _defaultKey),
              for (final t in _enabledTypes)
                _typeTab(label: t.shortLabel, value: t.dbValue),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isDefault
                ? 'أنت تعدّل: أسعار «عام»'
                : 'أنت تعدّل: أسعار "${type!.label}"',
            key: const ValueKey('editingTitle'),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isDefault
                ? 'تسري على كل نوع ما له سعر خاص بيومه. اتركه فاضي = يرجع '
                    'للسعر الاحتياطي للنوع (إن وُجد) ثم الافتراضي.'
                : 'تتفوق على أسعار «عام» لهذا النوع. اتركه فاضي = يرجع لسعر '
                    '«عام»، ثم السعر الاحتياطي، ثم الافتراضي.',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          for (var weekday = 0; weekday < 7; weekday++) ...[
            _buildWeekdayRow(key, type, weekday, draftSnap),
            if (weekday != 6) const Divider(height: 22),
          ],
        ],
      ),
    );
  }

  Widget _typeTab({required String label, required String value}) {
    final selected = _selectedEditingType == value;
    final hasDraft = _dirtyWeekdays(value) > 0;
    // تبويب مخصّص بدل ChoiceChip: ارتفاع الشريحة ثابت فيقصّ النص عندما تكبر
    // مقاييس سطر الخط (لوحظ بخط التطبيق الفعلي على الويب). هنا الارتفاع يتبع
    // النص مع حشوة.
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : AppColors.cream,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppColors.primary : AppColors.sand),
        ),
        child: InkWell(
          key: ValueKey('editTab_$value'),
          customBorder: const StadiumBorder(),
          onTap: () => _selectEditingType(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasDraft) ...[
                  Container(
                    key: ValueKey('tabDot_$value'),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.charcoal,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _weekdayHint(ChaletStayType? type, int day, PricingSnapshot draftSnap) {
    final fb = effectiveWeekdayPrice(
        draftSnap.withoutWeekday(type, day), type, day);
    final from = switch (fb.source) {
      PriceSource.defaultWeekday => 'من «عام»',
      PriceSource.typeBase => 'احتياطي',
      PriceSource.chaletDefault => 'افتراضي',
      PriceSource.typeWeekday => '',
    };
    return 'فارغ ← ${formatPriceNumber(fb.price)} $from'.trim();
  }

  Widget _buildWeekdayRow(
    String key,
    ChaletStayType? type,
    int weekday,
    PricingSnapshot draftSnap,
  ) {
    final field = _weekdayFields[key]![weekday]!;
    final isSaving = _savingWeekday.contains('$key:$weekday');
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            ChaletPricingService.weekdayLabels[weekday],
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            key: ValueKey('weekdayField_${key}_$weekday'),
            controller: field.ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              isDense: true,
              hintText: _weekdayHint(type, weekday, draftSnap),
              hintMaxLines: 1,
              hintStyle: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textHint),
              errorText: field.invalid ? 'سعر غير صحيح' : null,
              suffixText: field.dirty ? 'لم يُحفظ' : null,
              suffixStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentDark),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: _fieldBorder(dirty: field.dirty),
              enabledBorder: _fieldBorder(dirty: field.dirty),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 66,
          child: Center(
            child: _saveButton(
              key: ValueKey('weekdaySave_${key}_$weekday'),
              dirty: field.dirty,
              saving: isSaving && !_savingAll,
              onTap: () => _persistWeekday(key, weekday, quiet: false),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- أسعار خاصة بتواريخ محددة ----------------

  Widget _buildDateOverridesSection() {
    final isDefault = _selectedEditingType == _defaultKey;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'أسعار خاصة لتواريخ محددة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _savingDateOverride ? null : _addDateOverride,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              ),
            ],
          ),
          Text(
            isDefault
                ? 'هاد السعر له الأولوية دايمًا فوق السعر الأسبوعي لنفس اليوم '
                    '(مثلاً أعياد أو مناسبات)، وأسعار «عام» هنا تسري على كل '
                    'الأنواع حتى لو لها سعر خاص بيومها. (تُحفظ فورًا)'
                : 'هاد السعر له الأولوية دايمًا فوق السعر الأسبوعي لنفس اليوم '
                    '(مثلاً أعياد أو مناسبات). (يُحفظ فورًا)',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (_loadingOverrides)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_dateOverrides.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'لا يوجد أسعار خاصة مضافة بعد',
                  style:
                      TextStyle(fontFamily: 'Cairo', color: AppColors.textHint),
                ),
              ),
            )
          else
            ...(_dateOverrides.map((o) => _buildDateOverrideRow(o))),
        ],
      ),
    );
  }

  Widget _buildDateOverrideRow(ChaletDatePrice item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.date.year}/${item.date.month}/${item.date.day}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                if (item.note != null && item.note!.isNotEmpty)
                  Text(
                    item.note!,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          Text(
            '₪${formatPriceNumber(item.price)}',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            onPressed: () => _deleteDateOverride(item),
          ),
        ],
      ),
    );
  }
}
