import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// أنواع الإقامة المدعومة — تطابق check constraint بجدول chalet_stay_types
/// بقاعدة البيانات: ('morning','evening','full_day_morning','full_day_evening').
///
/// ملاحظة: القيمة 'default' المستخدمة داخل chalet_weekday_prices و
/// chalet_date_prices هي قيمة داخلية فقط (تمثّل السلوك القديم قبل إضافة
/// أنواع الإقامة) ولا تُعرض كخيار للمستخدم، لذلك لا تظهر بهذا enum.
enum ChaletStayType {
  morning,
  evening,
  fullDayMorning,
  fullDayEvening;

  String get dbValue {
    switch (this) {
      case ChaletStayType.morning:
        return 'morning';
      case ChaletStayType.evening:
        return 'evening';
      case ChaletStayType.fullDayMorning:
        return 'full_day_morning';
      case ChaletStayType.fullDayEvening:
        return 'full_day_evening';
    }
  }

  static ChaletStayType fromDb(String value) {
    return ChaletStayType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => ChaletStayType.morning,
    );
  }

  /// عنوان معروض بالواجهة (يطابق تسميات تطبيق المنافس بالضبط)
  String get label {
    switch (this) {
      case ChaletStayType.morning:
        return 'إقامة صباحية';
      case ChaletStayType.evening:
        return 'إقامة مسائية';
      case ChaletStayType.fullDayMorning:
        return 'يوم كامل - صباحي';
      case ChaletStayType.fullDayEvening:
        return 'يوم كامل - مسائي';
    }
  }

  /// عنوان مختصر (للاستخدام بالتابات/الفلاتر الضيقة)
  String get shortLabel {
    switch (this) {
      case ChaletStayType.morning:
        return 'صباحية';
      case ChaletStayType.evening:
        return 'مسائية';
      case ChaletStayType.fullDayMorning:
        return 'يوم كامل صباحي';
      case ChaletStayType.fullDayEvening:
        return 'يوم كامل مسائي';
    }
  }

  IconData get icon {
    switch (this) {
      case ChaletStayType.morning:
        return Icons.wb_sunny_rounded;
      case ChaletStayType.evening:
        return Icons.nightlight_round;
      case ChaletStayType.fullDayMorning:
      case ChaletStayType.fullDayEvening:
        return Icons.calendar_month_rounded;
    }
  }

  /// افتراضي معقول لوقت الوصول/المغادرة عند إضافة النوع لأول مرة
  /// (صاحب الشاليه يقدر يعدلهم بعدين).
  TimeOfDay get defaultCheckin {
    switch (this) {
      case ChaletStayType.morning:
        return const TimeOfDay(hour: 10, minute: 0);
      case ChaletStayType.evening:
        return const TimeOfDay(hour: 22, minute: 0);
      case ChaletStayType.fullDayMorning:
        return const TimeOfDay(hour: 10, minute: 0);
      case ChaletStayType.fullDayEvening:
        return const TimeOfDay(hour: 22, minute: 0);
    }
  }

  TimeOfDay get defaultCheckout {
    switch (this) {
      case ChaletStayType.morning:
        return const TimeOfDay(hour: 21, minute: 0);
      case ChaletStayType.evening:
        return const TimeOfDay(hour: 9, minute: 0);
      case ChaletStayType.fullDayMorning:
        return const TimeOfDay(hour: 10, minute: 0);
      case ChaletStayType.fullDayEvening:
        return const TimeOfDay(hour: 22, minute: 0);
    }
  }
}

/// إعداد نوع إقامة معيّن لشاليه محدد (صف من chalet_stay_types).
class ChaletStayTypeConfig {
  final String? id;
  final ChaletStayType type;
  final bool isEnabled;
  final TimeOfDay checkinTime;
  final TimeOfDay checkoutTime;
  final double? basePrice;
  final int sortOrder;

  const ChaletStayTypeConfig({
    this.id,
    required this.type,
    this.isEnabled = true,
    required this.checkinTime,
    required this.checkoutTime,
    this.basePrice,
    this.sortOrder = 0,
  });

  static TimeOfDay _parseTime(String raw) {
    // Postgres "time" يرجع كـ "HH:MM:SS"
    final parts = raw.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  static String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  factory ChaletStayTypeConfig.fromJson(Map<String, dynamic> json) {
    return ChaletStayTypeConfig(
      id: json['id'] as String?,
      type: ChaletStayType.fromDb(json['stay_type'] as String),
      isEnabled: json['is_enabled'] as bool? ?? true,
      checkinTime: _parseTime(json['checkin_time'] as String),
      checkoutTime: _parseTime(json['checkout_time'] as String),
      basePrice: (json['base_price'] as num?)?.toDouble(),
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson(String chaletId) => {
        'chalet_id': chaletId,
        'stay_type': type.dbValue,
        'is_enabled': isEnabled,
        'checkin_time': _formatTime(checkinTime),
        'checkout_time': _formatTime(checkoutTime),
        'base_price': basePrice,
        'sort_order': sortOrder,
        'updated_at': DateTime.now().toIso8601String(),
      };
}

/// نموذج يمثل سعر خاص بتاريخ محدد (مثلاً عيد أو مناسبة) لنوع إقامة معيّن.
class ChaletDatePrice {
  final DateTime date;
  final double price;
  final String? note;
  final String stayType; // 'default' أو أحد قيم ChaletStayType.dbValue

  ChaletDatePrice({
    required this.date,
    required this.price,
    this.note,
    this.stayType = 'default',
  });

  factory ChaletDatePrice.fromJson(Map<String, dynamic> json) {
    return ChaletDatePrice(
      date: DateTime.parse(json['date'] as String),
      price: (json['price'] as num).toDouble(),
      note: json['note'] as String?,
      stayType: json['stay_type'] as String? ?? 'default',
    );
  }
}

/// معلومة سعر يوم واحد جاهزة للعرض بالتقويم: السعر الأصلي (سعر يوم
/// الأسبوع، قبل أي خصم خاص) والسعر النهائي (بعد تطبيق أي سعر خاص بالتاريخ)،
/// مع علم isSpecialOffer لعرض باج "حصري" عند وجود خصم فعلي.
class DayPriceInfo {
  final double originalPrice;
  final double finalPrice;

  const DayPriceInfo({
    required this.originalPrice,
    required this.finalPrice,
  });

  bool get isSpecialOffer => finalPrice < originalPrice;
}

/// خدمة إدارة تسعير الشاليه: أنواع إقامة + سعر أسبوعي متكرر لكل نوع +
/// أسعار خاصة لتواريخ محددة لكل نوع.
///
/// ترتيب الأولوية عند حساب سعر أي ليلة لنوع إقامة معيّن (يطابق دالة SQL
/// get_chalet_night_price بالسيرفر بالضبط):
/// 1) سعر خاص بالتاريخ لنفس النوع
/// 2) سعر خاص بالتاريخ عام (stay_type='default')
/// 3) سعر يوم الأسبوع لنفس النوع
/// 4) سعر يوم الأسبوع عام (stay_type='default')
/// 5) السعر الأساسي لنوع الإقامة نفسه (chalet_stay_types.base_price)
/// 6) السعر الافتراضي القديم (chalets.price_per_night)
///
/// أيام الأسبوع مرمّزة زي PostgreSQL: 0=الأحد, 1=الاثنين, ... 6=السبت.
class ChaletPricingService {
  static ChaletPricingService? _instance;
  static ChaletPricingService get instance =>
      _instance ??= ChaletPricingService._();
  ChaletPricingService._();

  final _supabase = Supabase.instance.client;

  static const String defaultStayType = 'default';

  static const List<String> weekdayLabels = [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  // ==========================================================
  // أنواع الإقامة (chalet_stay_types)
  // ==========================================================

  /// يرجع كل أنواع الإقامة المُعرَّفة لهذا الشاليه (سواء مفعّلة أو لا)،
  /// مرتبة حسب sort_order.
  Future<List<ChaletStayTypeConfig>> getStayTypes(String chaletId) async {
    final data = await _supabase
        .from('chalet_stay_types')
        .select()
        .eq('chalet_id', chaletId)
        .order('sort_order', ascending: true);

    return (data as List)
        .map((e) => ChaletStayTypeConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// يرجع فقط أنواع الإقامة المفعّلة (لعرضها للضيف بشاشة الحجز).
  Future<List<ChaletStayTypeConfig>> getEnabledStayTypes(
      String chaletId) async {
    final all = await getStayTypes(chaletId);
    return all.where((t) => t.isEnabled).toList();
  }

  /// يحفظ/يحدّث إعداد نوع إقامة (يفعّله ويحدد أوقاته وسعره الأساسي).
  Future<void> upsertStayType({
    required String chaletId,
    required ChaletStayTypeConfig config,
  }) async {
    await _supabase.from('chalet_stay_types').upsert(
          config.toInsertJson(chaletId),
          onConflict: 'chalet_id,stay_type',
        );
  }

  /// يعطّل نوع إقامة (بدون حذف بياناته/أسعاره المرتبطة به).
  Future<void> setStayTypeEnabled({
    required String chaletId,
    required ChaletStayType type,
    required bool isEnabled,
  }) async {
    await _supabase
        .from('chalet_stay_types')
        .update({
          'is_enabled': isEnabled,
          'updated_at': DateTime.now().toIso8601String()
        })
        .eq('chalet_id', chaletId)
        .eq('stay_type', type.dbValue);
  }

  /// يحذف نوع إقامة نهائيًا مع كل أسعاره اليومية/الخاصة المرتبطة به.
  Future<void> deleteStayType({
    required String chaletId,
    required ChaletStayType type,
  }) async {
    await _supabase
        .from('chalet_weekday_prices')
        .delete()
        .eq('chalet_id', chaletId)
        .eq('stay_type', type.dbValue);
    await _supabase
        .from('chalet_date_prices')
        .delete()
        .eq('chalet_id', chaletId)
        .eq('stay_type', type.dbValue);
    await _supabase
        .from('chalet_stay_types')
        .delete()
        .eq('chalet_id', chaletId)
        .eq('stay_type', type.dbValue);
  }

  // ==========================================================
  // السعر الأسبوعي (لكل نوع إقامة، أو 'default' للسلوك القديم)
  // ==========================================================

  /// يرجع خريطة (يوم الأسبوع 0-6 → السعر) لنوع إقامة معيّن.
  /// الأيام الغير موجودة بالخريطة معناها لسا بتستخدم الطبقة الأعلى بالأولوية.
  Future<Map<int, double>> getWeekdayPrices(
    String chaletId, {
    String stayType = defaultStayType,
  }) async {
    final data = await _supabase
        .from('chalet_weekday_prices')
        .select('weekday, price')
        .eq('chalet_id', chaletId)
        .eq('stay_type', stayType);

    final result = <int, double>{};
    for (final row in (data as List)) {
      result[row['weekday'] as int] = (row['price'] as num).toDouble();
    }
    return result;
  }

  /// يحفظ/يحدّث سعر يوم أسبوع معيّن (0=أحد..6=سبت) لنوع إقامة معيّن.
  Future<void> setWeekdayPrice({
    required String chaletId,
    required int weekday,
    required double price,
    String stayType = defaultStayType,
  }) async {
    await _supabase.from('chalet_weekday_prices').upsert(
      {
        'chalet_id': chaletId,
        'weekday': weekday,
        'stay_type': stayType,
        'price': price,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'chalet_id,weekday,stay_type',
    );
  }

  /// يحذف سعر يوم أسبوع معيّن لنوع إقامة معيّن.
  Future<void> clearWeekdayPrice({
    required String chaletId,
    required int weekday,
    String stayType = defaultStayType,
  }) async {
    await _supabase
        .from('chalet_weekday_prices')
        .delete()
        .eq('chalet_id', chaletId)
        .eq('weekday', weekday)
        .eq('stay_type', stayType);
  }

  // ==========================================================
  // أسعار خاصة بتواريخ محددة (لكل نوع إقامة، أو 'default')
  // ==========================================================

  /// يرجع كل الأسعار الخاصة بتواريخ محددة لهذا الشاليه ونوع إقامة معيّن
  /// (مرتبة بالتاريخ).
  Future<List<ChaletDatePrice>> getDateOverrides(
    String chaletId, {
    DateTime? from,
    DateTime? to,
    String stayType = defaultStayType,
  }) async {
    var query = _supabase
        .from('chalet_date_prices')
        .select('date, price, note, stay_type')
        .eq('chalet_id', chaletId)
        .eq('stay_type', stayType);

    if (from != null) {
      query = query.gte('date', from.toIso8601String().split('T').first);
    }
    if (to != null) {
      query = query.lte('date', to.toIso8601String().split('T').first);
    }

    final data = await query.order('date', ascending: true);

    return (data as List)
        .map((e) => ChaletDatePrice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// يحفظ/يحدّث سعر خاص لتاريخ معيّن ونوع إقامة معيّن.
  Future<void> setDateOverride({
    required String chaletId,
    required DateTime date,
    required double price,
    String? note,
    String stayType = defaultStayType,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;
    await _supabase.from('chalet_date_prices').upsert(
      {
        'chalet_id': chaletId,
        'date': dateStr,
        'stay_type': stayType,
        'price': price,
        'note': note,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'chalet_id,date,stay_type',
    );
  }

  /// يحذف السعر الخاص لتاريخ معيّن ونوع إقامة معيّن.
  Future<void> deleteDateOverride({
    required String chaletId,
    required DateTime date,
    String stayType = defaultStayType,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;
    await _supabase
        .from('chalet_date_prices')
        .delete()
        .eq('chalet_id', chaletId)
        .eq('date', dateStr)
        .eq('stay_type', stayType);
  }

  // ==========================================================
  // حساب الأسعار (يستدعي دوال SQL الموحّدة على السيرفر)
  // ==========================================================

  /// يحسب سعر ليلة واحدة بتاريخ معيّن ونوع إقامة معيّن.
  Future<double> getPriceForDate({
    required String chaletId,
    required DateTime date,
    String stayType = defaultStayType,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;
    final result = await _supabase.rpc(
      'get_chalet_night_price',
      params: {
        'p_chalet_id': chaletId,
        'p_date': dateStr,
        'p_stay_type': stayType,
      },
    );
    return (result as num).toDouble();
  }

  /// يحسب إجمالي سعر فترة إقامة كاملة لنوع إقامة معيّن (مجموع كل ليلة على
  /// حدة حسب هرم الأولوية الكامل). هذا هو المصدر الموثوق لحساب مبلغ أي حجز.
  Future<double> calculateStayPrice({
    required String chaletId,
    required DateTime checkIn,
    required DateTime checkOut,
    String stayType = defaultStayType,
  }) async {
    final checkInStr = checkIn.toIso8601String().split('T').first;
    final checkOutStr = checkOut.toIso8601String().split('T').first;

    final result = await _supabase.rpc(
      'calculate_chalet_stay_price',
      params: {
        'p_chalet_id': chaletId,
        'p_check_in': checkInStr,
        'p_check_out': checkOutStr,
        'p_stay_type': stayType,
      },
    );
    return (result as num).toDouble();
  }

  /// يبني تقويم أسعار شهر كامل لعرضه بالواجهة لنوع إقامة معيّن (بدون طلب
  /// RPC لكل يوم لحاله): يرجع خريطة (تاريخ → DayPriceInfo) تحتوي السعر
  /// الأصلي (سعر يوم الأسبوع، بدون أي خصم خاص) والسعر النهائي (بعد أي سعر
  /// خاص بالتاريخ)، محسوبة محليًا بنفس هرم الأولوية المستخدم بالسيرفر.
  Future<Map<DateTime, DayPriceInfo>> getMonthPricing({
    required String chaletId,
    required int year,
    required int month,
    required double defaultPrice,
    String stayType = defaultStayType,
  }) async {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);

    // ✅ مُصلَّح: نبدأ كل الاستعلامات مع بعض (بدون await فوري) عشان تنطلق
    // بالتوازي بدل ما ينتظر كل استعلام يلي قبله يخلص. هذا يقلّل زمن
    // الاستجابة الكلي بشكل كبير (من مجموع 5 رحلات شبكة متتالية إلى أطول
    // رحلة شبكة واحدة فقط)، وهو السبب اللي كان يخلي تبديل نوع الإقامة
    // يبين "متأخر خطوة" عن الضغطة الفعلية.
    final weekdayForTypeFuture = getWeekdayPrices(chaletId, stayType: stayType);
    final weekdayDefaultFuture = stayType == defaultStayType
        ? weekdayForTypeFuture
        : getWeekdayPrices(chaletId, stayType: defaultStayType);

    final dateOverridesForTypeFuture = getDateOverrides(
      chaletId,
      from: firstDay,
      to: lastDay,
      stayType: stayType,
    );
    final dateOverridesDefaultFuture = stayType == defaultStayType
        ? dateOverridesForTypeFuture
        : getDateOverrides(
            chaletId,
            from: firstDay,
            to: lastDay,
            stayType: defaultStayType,
          );

    final stayTypesFuture = stayType == defaultStayType
        ? Future.value(<ChaletStayTypeConfig>[])
        : getStayTypes(chaletId);

    // الآن ننتظر كلهم مع بعض — كل الطلبات فوق صارت شغّالة بالتوازي فعليًا.
    final weekdayForType = await weekdayForTypeFuture;
    final weekdayDefault = await weekdayDefaultFuture;
    final dateOverridesForType = await dateOverridesForTypeFuture;
    final dateOverridesDefault = await dateOverridesDefaultFuture;
    final types = await stayTypesFuture;

    // سعر أساسي لنوع الإقامة نفسه (الطبقة رقم 5 بالأولوية) — لو معرّف.
    double? stayTypeBasePrice;
    if (stayType != defaultStayType) {
      final match = types.where((t) => t.type.dbValue == stayType);
      if (match.isNotEmpty) stayTypeBasePrice = match.first.basePrice;
    }

    String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

    final overrideForTypeMap = <String, double>{
      for (final o in dateOverridesForType) dayKey(o.date): o.price,
    };
    final overrideDefaultMap = <String, double>{
      for (final o in dateOverridesDefault) dayKey(o.date): o.price,
    };

    final result = <DateTime, DayPriceInfo>{};
    // ✅ إصلاح: كان d.add(Duration(days: 1)) يضيف 24 ساعة بالضبط، فبعد
    // انتهاء التوقيت الصيفي (أواخر أكتوبر بتوقيت القدس) يصير المفتاح
    // 23:00 لليوم السابق بدل منتصف الليل — فلا يجد التقويم أسعار الأيام
    // الأخيرة من الشهر (تأكدت بتشغيل تجربة: 6 مفاتيح خاطئة بأكتوبر 2026 ويوم
    // 31 مفقود). بناء التاريخ بمكوّناته يتجاوز المشكلة تماماً.
    for (var d = firstDay;
        !d.isAfter(lastDay);
        d = DateTime(d.year, d.month, d.day + 1)) {
      final key = dayKey(d);
      final ourWeekday = d.weekday % 7;

      final originalPrice = weekdayForType[ourWeekday] ??
          weekdayDefault[ourWeekday] ??
          stayTypeBasePrice ??
          defaultPrice;

      final finalPrice =
          overrideForTypeMap[key] ?? overrideDefaultMap[key] ?? originalPrice;

      result[d] = DayPriceInfo(
        originalPrice: originalPrice,
        finalPrice: finalPrice,
      );
    }

    return result;
  }
}
