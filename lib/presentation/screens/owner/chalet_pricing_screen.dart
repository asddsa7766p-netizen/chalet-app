import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/pricing_service.dart';

/// شاشة تسعير الشاليه بلوحة تحكم المالك.
///
/// ✅ تحديث جديد: صارت الشاشة تدعم "أنواع الإقامة" (صباحية/مسائية/يوم كامل
/// صباحي/يوم كامل مسائي) بالإضافة للنظام القديم. الأقسام:
///
/// 1) أنواع الإقامة: صاحب الشاليه يفعّل أي نوع بدو، ويحدد وقت الوصول/
///    المغادرة والسعر الأساسي لهذا النوع.
/// 2) محدد "أعدّل أسعار أي نوع؟": شرائح اختيار (chips) — تشمل "عام
///    (افتراضي)" وهو نفس النظام القديم بدون تصنيف نوع، بالإضافة لأي نوع
///    إقامة مفعّل.
/// 3) التسعير الأسبوعي وأسعار التواريخ الخاصة: نفس القسمين القديمين
///    تمامًا بدون أي تغيير بشكلهم، لكنهم الآن يقرؤون/يكتبون فقط لنوع
///    الإقامة المحدد بالخطوة 2.
///
/// هذا يحافظ 100% على توافق العملاء الحاليين: لو صاحب الشاليه ما فعّل أي
/// نوع إقامة إطلاقًا، الشاشة بتشتغل تمامًا متل قبل (نوع 'default' بس).
class ChaletPricingScreen extends StatefulWidget {
  final String chaletId;
  final String chaletName;
  final double defaultPricePerNight;

  const ChaletPricingScreen({
    super.key,
    required this.chaletId,
    required this.chaletName,
    required this.defaultPricePerNight,
  });

  @override
  State<ChaletPricingScreen> createState() => _ChaletPricingScreenState();
}

class _ChaletPricingScreenState extends State<ChaletPricingScreen> {
  bool _loading = true;
  String? _error;

  // ---- أنواع الإقامة ----
  // إعداد كل نوع (null = لسا ما انضاف/انفعّل من صاحب الشاليه)
  final Map<ChaletStayType, ChaletStayTypeConfig?> _stayTypeConfigs = {
    for (final t in ChaletStayType.values) t: null,
  };
  final Map<ChaletStayType, TextEditingController> _stayTypePriceCtrls = {
    for (final t in ChaletStayType.values) t: TextEditingController(),
  };
  final Map<ChaletStayType, TimeOfDay> _stayTypeCheckin = {
    for (final t in ChaletStayType.values) t: t.defaultCheckin,
  };
  final Map<ChaletStayType, TimeOfDay> _stayTypeCheckout = {
    for (final t in ChaletStayType.values) t: t.defaultCheckout,
  };
  final Set<ChaletStayType> _stayTypeEnabled = {};
  final Set<ChaletStayType> _savingStayType = {};

  // ---- نوع الإقامة الذي تُعدَّل أسعاره اليومية/الخاصة حاليًا ----
  // 'default' = عام (النظام القديم بدون تصنيف نوع)
  String _selectedEditingType = ChaletPricingService.defaultStayType;

  // weekday (0..6) -> controller نص السعر (فاضي = يستخدم السعر الافتراضي)
  final Map<int, TextEditingController> _weekdayControllers = {
    for (var i = 0; i < 7; i++) i: TextEditingController(),
  };
  final Set<int> _savingWeekday = {};

  List<ChaletDatePrice> _dateOverrides = [];
  bool _savingDateOverride = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    for (final c in _weekdayControllers.values) {
      c.dispose();
    }
    for (final c in _stayTypePriceCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final stayTypes =
          await ChaletPricingService.instance.getStayTypes(widget.chaletId);
      for (final config in stayTypes) {
        _stayTypeConfigs[config.type] = config;
        _stayTypeEnabled
          ..removeWhere((t) => t == config.type)
          ..addAll(config.isEnabled ? {config.type} : {});
        _stayTypeCheckin[config.type] = config.checkinTime;
        _stayTypeCheckout[config.type] = config.checkoutTime;
        if (config.basePrice != null) {
          _stayTypePriceCtrls[config.type]!.text =
              config.basePrice!.toStringAsFixed(0);
        }
      }

      await _loadWeekdayAndDateSectionsFor(_selectedEditingType);

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'تعذر تحميل الأسعار: $e';
          _loading = false;
        });
      }
    }
  }

  /// يعيد تحميل قسمي "التسعير الأسبوعي" و"أسعار التواريخ الخاصة" فقط،
  /// لنوع إقامة معيّن (بدون إعادة تحميل قسم أنواع الإقامة نفسه).
  Future<void> _loadWeekdayAndDateSectionsFor(String stayType) async {
    // نصفّر الحقول أول شي حتى ما يظهر سعر نوع سابق بالغلط أثناء التحميل
    for (final c in _weekdayControllers.values) {
      c.clear();
    }

    final weekdayPrices = await ChaletPricingService.instance
        .getWeekdayPrices(widget.chaletId, stayType: stayType);
    final overrides = await ChaletPricingService.instance
        .getDateOverrides(widget.chaletId, stayType: stayType);

    for (final entry in weekdayPrices.entries) {
      _weekdayControllers[entry.key]?.text = entry.value.toStringAsFixed(0);
    }

    if (mounted) {
      setState(() => _dateOverrides = overrides);
    }
  }

  Future<void> _onEditingTypeChanged(String newType) async {
    if (newType == _selectedEditingType) return;
    setState(() {
      _selectedEditingType = newType;
      _loading = true;
    });
    await _loadWeekdayAndDateSectionsFor(newType);
    if (mounted) setState(() => _loading = false);
  }

  // ==========================================================
  // أنواع الإقامة
  // ==========================================================

  Future<void> _toggleStayType(ChaletStayType type, bool enabled) async {
    setState(() => _savingStayType.add(type));
    try {
      final existing = _stayTypeConfigs[type];
      final priceText = _stayTypePriceCtrls[type]!.text.trim();
      final config = ChaletStayTypeConfig(
        id: existing?.id,
        type: type,
        isEnabled: enabled,
        checkinTime: _stayTypeCheckin[type]!,
        checkoutTime: _stayTypeCheckout[type]!,
        basePrice: priceText.isEmpty ? null : double.tryParse(priceText),
        sortOrder: type.index,
      );
      await ChaletPricingService.instance.upsertStayType(
        chaletId: widget.chaletId,
        config: config,
      );
      if (mounted) {
        setState(() {
          _stayTypeConfigs[type] = config;
          if (enabled) {
            _stayTypeEnabled.add(type);
          } else {
            _stayTypeEnabled.remove(type);
          }
        });
      }
      _showSnack(
          enabled ? 'تم تفعيل "${type.label}"' : 'تم إيقاف "${type.label}"');
    } catch (e) {
      _showSnack('فشل الحفظ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingStayType.remove(type));
    }
  }

  Future<void> _saveStayTypeDetails(ChaletStayType type) async {
    setState(() => _savingStayType.add(type));
    try {
      final priceText = _stayTypePriceCtrls[type]!.text.trim();
      final price = priceText.isEmpty ? null : double.tryParse(priceText);
      if (priceText.isNotEmpty && price == null) {
        _showSnack('سعر غير صحيح', isError: true);
        return;
      }
      final config = ChaletStayTypeConfig(
        id: _stayTypeConfigs[type]?.id,
        type: type,
        isEnabled: _stayTypeEnabled.contains(type),
        checkinTime: _stayTypeCheckin[type]!,
        checkoutTime: _stayTypeCheckout[type]!,
        basePrice: price,
        sortOrder: type.index,
      );
      await ChaletPricingService.instance.upsertStayType(
        chaletId: widget.chaletId,
        config: config,
      );
      if (mounted) setState(() => _stayTypeConfigs[type] = config);
      _showSnack('تم حفظ إعدادات "${type.label}"');
    } catch (e) {
      _showSnack('فشل الحفظ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingStayType.remove(type));
    }
  }

  Future<void> _pickTime({
    required ChaletStayType type,
    required bool isCheckin,
  }) async {
    final initial =
        isCheckin ? _stayTypeCheckin[type]! : _stayTypeCheckout[type]!;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isCheckin) {
        _stayTypeCheckin[type] = picked;
      } else {
        _stayTypeCheckout[type] = picked;
      }
    });
  }

  // ==========================================================
  // التسعير الأسبوعي (لنوع الإقامة المحدد حاليًا: _selectedEditingType)
  // ==========================================================

  Future<void> _saveWeekdayPrice(int weekday) async {
    final text = _weekdayControllers[weekday]!.text.trim();

    setState(() => _savingWeekday.add(weekday));

    try {
      if (text.isEmpty) {
        await ChaletPricingService.instance.clearWeekdayPrice(
          chaletId: widget.chaletId,
          weekday: weekday,
          stayType: _selectedEditingType,
        );
      } else {
        final price = double.tryParse(text);
        if (price == null || price < 0) {
          _showSnack('سعر غير صحيح', isError: true);
          return;
        }
        await ChaletPricingService.instance.setWeekdayPrice(
          chaletId: widget.chaletId,
          weekday: weekday,
          price: price,
          stayType: _selectedEditingType,
        );
      }
      _showSnack('تم حفظ سعر ${ChaletPricingService.weekdayLabels[weekday]}');
    } catch (e) {
      _showSnack('فشل الحفظ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingWeekday.remove(weekday));
    }
  }

  // ==========================================================
  // أسعار خاصة بتواريخ محددة (لنوع الإقامة المحدد حاليًا)
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

    final priceController = TextEditingController();
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('سعر خاص لتاريخ محدد',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${pickedDate.year}/${pickedDate.month}/${pickedDate.day}',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedEditingType == ChaletPricingService.defaultStayType
                  ? 'لكل أنواع الإقامة (عام)'
                  : 'لنوع: ${ChaletStayType.fromDb(_selectedEditingType).label}',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر لهذا اليوم'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري، مثلاً: عيد الفطر)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final price = double.tryParse(priceController.text.trim());
    if (price == null || price < 0) {
      _showSnack('سعر غير صحيح', isError: true);
      return;
    }

    setState(() => _savingDateOverride = true);
    try {
      await ChaletPricingService.instance.setDateOverride(
        chaletId: widget.chaletId,
        date: pickedDate,
        price: price,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        stayType: _selectedEditingType,
      );
      final overrides = await ChaletPricingService.instance.getDateOverrides(
        widget.chaletId,
        stayType: _selectedEditingType,
      );
      if (mounted) {
        setState(() {
          _dateOverrides = overrides;
        });
      }
      _showSnack('تم إضافة السعر الخاص');
    } catch (e) {
      _showSnack('فشل الحفظ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingDateOverride = false);
    }
  }

  Future<void> _deleteDateOverride(ChaletDatePrice item) async {
    try {
      await ChaletPricingService.instance.deleteDateOverride(
        chaletId: widget.chaletId,
        date: item.date,
        stayType: _selectedEditingType,
      );
      setState(() {
        _dateOverrides.removeWhere((o) => o.date == item.date);
      });
      _showSnack('تم الحذف');
    } catch (e) {
      _showSnack('فشل الحذف: $e', isError: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('تسعير: ${widget.chaletName}'),
      ),
      body: _loading && _dateOverrides.isEmpty && _error == null
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
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildDefaultPriceNote(),
                      const SizedBox(height: 16),
                      _buildStayTypesSection(),
                      const SizedBox(height: 16),
                      _buildEditingTypeSelector(),
                      const SizedBox(height: 16),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary)),
                        )
                      else ...[
                        _buildWeekdaySection(),
                        const SizedBox(height: 24),
                        _buildDateOverridesSection(),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDefaultPriceNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryPale.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryPale),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'السعر الافتراضي الحالي: ₪${widget.defaultPricePerNight.toStringAsFixed(0)}. '
              'أي يوم ما تحدد له سعر تحت، رح يستخدم هذا السعر تلقائيًا.',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  color: AppColors.charcoal),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // قسم أنواع الإقامة
  // ==========================================================

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
            'فعّل أي نوع بدك، وحدد وقت الوصول/المغادرة والسعر الأساسي له '
            '(زي: إقامة صباحية، إقامة مسائية، يوم كامل...)',
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            enabled ? AppColors.primaryPale.withOpacity(0.15) : AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled ? AppColors.primary.withOpacity(0.4) : AppColors.sand,
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
              if (isSaving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: enabled,
                  activeColor: AppColors.primary,
                  onChanged: (v) => _toggleStayType(type, v),
                ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _timeTile(
                    label: 'الوصول',
                    time: _stayTypeCheckin[type]!,
                    onTap: () => _pickTime(type: type, isCheckin: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _timeTile(
                    label: 'المغادرة',
                    time: _stayTypeCheckout[type]!,
                    onTap: () => _pickTime(type: type, isCheckin: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stayTypePriceCtrls[type],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'السعر الأساسي (ابتداءً من)',
                      hintText: widget.defaultPricePerNight.toStringAsFixed(0),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.sand),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: isSaving ? null : () => _saveStayTypeDetails(type),
                  child:
                      const Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
          ],
        ],
      ),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.textSecondary)),
            Text(
              time.format(context),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // محدد "أعدّل أسعار أي نوع؟"
  // ==========================================================

  Widget _buildEditingTypeSelector() {
    final enabledTypes =
        ChaletStayType.values.where((t) => _stayTypeEnabled.contains(t));

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
            'أعدّل الأسعار اليومية لأي نوع؟',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _typeChip(
                label: 'عام (افتراضي)',
                value: ChaletPricingService.defaultStayType,
              ),
              for (final t in enabledTypes)
                _typeChip(label: t.shortLabel, value: t.dbValue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeChip({required String label, required String value}) {
    final selected = _selectedEditingType == value;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.charcoal,
          )),
      selected: selected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.cream,
      onSelected: (_) => _onEditingTypeChanged(value),
    );
  }

  // ==========================================================
  // التسعير الأسبوعي
  // ==========================================================

  Widget _buildWeekdaySection() {
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
            'التسعير الأسبوعي',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedEditingType == ChaletPricingService.defaultStayType
                ? 'حدد سعر كل يوم لحاله (اتركه فاضي لاستخدام السعر الافتراضي)'
                : 'أسعار خاصة بنوع "${ChaletStayType.fromDb(_selectedEditingType).label}" '
                    '(اتركه فاضي ليرجع لسعر "عام" أو الافتراضي)',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          for (var weekday = 0; weekday < 7; weekday++) ...[
            _buildWeekdayRow(weekday),
            if (weekday != 6) const Divider(height: 22),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekdayRow(int weekday) {
    final isSaving = _savingWeekday.contains(weekday);
    return Row(
      children: [
        SizedBox(
          width: 80,
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
            controller: _weekdayControllers[weekday],
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              isDense: true,
              hintText:
                  '${widget.defaultPricePerNight.toStringAsFixed(0)} (افتراضي)',
              hintStyle: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 12, color: AppColors.textHint),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.sand),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: isSaving
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                )
              : TextButton(
                  onPressed: () => _saveWeekdayPrice(weekday),
                  child: const Text('حفظ',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                ),
        ),
      ],
    );
  }

  // ==========================================================
  // أسعار خاصة بتواريخ محددة
  // ==========================================================

  Widget _buildDateOverridesSection() {
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
              const Text(
                'أسعار خاصة لتواريخ محددة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
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
          const Text(
            'هاد السعر له الأولوية دايمًا فوق السعر الأسبوعي لنفس اليوم (مثلاً أعياد أو مناسبات)',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (_dateOverrides.isEmpty)
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
            '₪${item.price.toStringAsFixed(0)}',
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
