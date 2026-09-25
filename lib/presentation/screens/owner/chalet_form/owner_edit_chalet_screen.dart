import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../data/services/location_service.dart';
import 'chalet_edit_data_source.dart';
import 'chalet_edit_model.dart';
import 'chalet_edit_validation.dart';
import 'chalet_images_editor.dart';
import '../pricing/chalet_pricing_screen.dart';
import '../../../../core/utils/error_reporter.dart';

typedef PickChaletImages = Future<List<XFile>> Function();
typedef LocateChalet = Future<({double latitude, double longitude})?> Function();

/// شاشة تعديل شاليه موجود (للمالك فقط).
///
/// - تجلب الصف بمعرّفه وتتحقق أن `owner_id` هو المستخدم الحالي، وإلا لا تعرض
///   أي نموذج (سياسة SELECT تسمح بقراءة أي شاليه معتمد، فلا تكفي القراءة).
/// - الحمولة بالفروقات فقط: لا يُرسل إلا ما غيّره المالك فعلاً، ولا يُرسل أبداً
///   is_approved/is_featured/owner_id/rating/reviews_count/updated_at.
/// - نجاح التحديث يُتحقَّق منه بإرجاع الصف (رفض الـRLS = صفر صفوف بلا خطأ).
/// - ترتيب الصور: رفع الجديد ← تحديث الصف ← حذف المزال. فشل رفع أي صورة يوقف
///   الحفظ كاملاً ولا يُسقط الصورة بصمت.
/// - حماية التعديلات بأسلوب شاشة أسعار الإقامة: تتبّع تغيّر كل حقل، شريط حفظ،
///   وحوارات تأكيد للخروج والتجاهل.
class OwnerEditChaletScreen extends StatefulWidget {
  final String chaletId;

  /// للاختبار. الافتراضي: Supabase الفعلي.
  final ChaletEditDataSource? dataSource;
  final PickChaletImages? pickImages;
  final LocateChalet? locate;

  const OwnerEditChaletScreen({
    super.key,
    required this.chaletId,
    this.dataSource,
    this.pickImages,
    this.locate,
  });

  @override
  State<OwnerEditChaletScreen> createState() => _OwnerEditChaletScreenState();
}

enum _LoadState { loading, error, forbidden, ready }

enum _LeaveChoice { save, discard, stay }

class _OwnerEditChaletScreenState extends State<OwnerEditChaletScreen> {
  static const List<String> _baseCities = AppStrings.cities;

  // مفاتيح الحقول بترتيب ظهورها (للتمرير لأول خطأ).
  static const List<String> _fieldOrder = [
    'name',
    'description',
    'max_guests',
    'city',
    'location',
    'address',
    'latitude',
    'longitude',
    'images',
    'video_url',
    'price_per_night',
  ];

  static const Map<String, Set<String>> _sections = {
    'basic': {'name', 'description'},
    'capacity': {'max_guests', 'bedrooms', 'bathrooms'},
    'amenities': {'has_wifi', 'has_pool', 'has_bbq', 'has_parking'},
    'location': {'city', 'location', 'address', 'latitude', 'longitude'},
    'media': {'images', 'video_url'},
    'pricing': {'price_per_night', 'is_available'},
  };

  late final ChaletEditDataSource _ds =
      widget.dataSource ?? const SupabaseChaletEditDataSource();

  _LoadState _state = _LoadState.loading;
  bool _saving = false;
  bool _locating = false;
  bool _suspend = false;

  Map<String, dynamic>? _row;
  ChaletEditValues? _orig;
  bool _approved = false;
  String _bookingType = 'يومي';
  Map<String, String> _origSnapshot = {};

  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _guests = TextEditingController();
  final _location = TextEditingController();
  final _address = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _video = TextEditingController();
  final _price = TextEditingController();

  int _bedrooms = 1;
  int _bathrooms = 1;
  bool _wifi = false;
  bool _pool = false;
  bool _bbq = false;
  bool _parking = false;
  bool _available = true;
  String? _city;
  List<DraftImage> _images = [];
  String? _imageError;

  final Map<String, GlobalKey> _fieldKeys = {
    for (final k in _fieldOrder) k: GlobalKey(),
  };

  // تُحسب مرة لكل build وتستخدمها دوال البناء.
  Set<String> _d = {};
  Map<String, String> _e = {};

  List<TextEditingController> get _controllers =>
      [_name, _desc, _guests, _location, _address, _lat, _lng, _video, _price];

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(_onChanged);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (_suspend || !mounted) return;
    setState(() {});
  }

  // ==========================================================
  // التحميل والتحقق من الملكية
  // ==========================================================

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final row = await _ds.fetchChalet(widget.chaletId);
      if (!mounted) return;
      final uid = _ds.currentUserId;
      if (row == null || uid == null || row['owner_id'] != uid) {
        setState(() => _state = _LoadState.forbidden);
        return;
      }
      _applyRow(row);
      setState(() => _state = _LoadState.ready);
    } catch (_) {
      if (mounted) setState(() => _state = _LoadState.error);
    }
  }

  /// يضبط كل الحقول من صف (محمّل أو بعد حفظ ناجح) ويعتمده كخط أساس.
  void _applyRow(Map<String, dynamic> row) {
    final o = ChaletEditValues.fromRow(row);
    _suspend = true;
    try {
      _row = row;
      _orig = o;
      _approved = row['is_approved'] == true;
      _bookingType = (row['booking_type'] as String?) ?? 'يومي';
      _name.text = o.name;
      _desc.text = o.description;
      _guests.text = '${o.maxGuests}';
      _location.text = o.location;
      _address.text = o.address ?? '';
      _lat.text = o.latitude?.toString() ?? '';
      _lng.text = o.longitude?.toString() ?? '';
      _video.text = o.videoUrl ?? '';
      _price.text = _priceText(o.pricePerNight);
      _bedrooms = o.bedrooms;
      _bathrooms = o.bathrooms;
      _wifi = o.hasWifi;
      _pool = o.hasPool;
      _bbq = o.hasBbq;
      _parking = o.hasParking;
      _available = o.isAvailable;
      _city = o.city.isEmpty ? null : o.city;
      _images = [for (final u in o.images) DraftImage.existing(u)];
      _imageError = null;
    } finally {
      _suspend = false;
    }
    _origSnapshot = _snapshot();
  }

  static String _priceText(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  // ==========================================================
  // تتبّع التعديلات
  // ==========================================================

  static String _canon(String s) {
    final t = normalizeDigits(s).trim();
    final v = double.tryParse(t);
    return (v == null || !v.isFinite) ? t : v.toString();
  }

  Map<String, String> _snapshot() => {
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'max_guests': _canon(_guests.text),
        'bedrooms': '$_bedrooms',
        'bathrooms': '$_bathrooms',
        'has_wifi': '$_wifi',
        'has_pool': '$_pool',
        'has_bbq': '$_bbq',
        'has_parking': '$_parking',
        'city': _city ?? '',
        'location': _location.text.trim(),
        'address': _address.text.trim(),
        'latitude': _canon(_lat.text),
        'longitude': _canon(_lng.text),
        'images': _images.map((e) => e.signature).join('|'),
        'video_url': _video.text.trim(),
        'price_per_night': _canon(_price.text),
        'is_available': '$_available',
      };

  Set<String> _dirtyKeys() {
    if (_orig == null) return {};
    final now = _snapshot();
    return {
      for (final e in now.entries)
        if (_origSnapshot[e.key] != e.value) e.key,
    };
  }

  /// أخطاء الحقول المعدَّلة فقط. الحقول التي لم يلمسها المالك لا تُفحص ولا
  /// تمنع الحفظ (لن تُرسل أصلاً)، فبيانات قديمة ناقصة لا تعطّل تعديلاً آخر.
  Map<String, String> _blockingErrors(Set<String> dirty) {
    final out = <String, String>{};
    void add(String key, String? msg, {bool force = false}) {
      if (msg != null && (force || dirty.contains(key))) out[key] = msg;
    }

    add('name', ChaletEditValidation.name(_name.text));
    add('description', ChaletEditValidation.description(_desc.text));
    add('max_guests', ChaletEditValidation.maxGuests(_guests.text));
    add('price_per_night', ChaletEditValidation.price(_price.text));
    add('city', ChaletEditValidation.city(_city));
    add('location', ChaletEditValidation.optionalText(_location.text, ChaletEditValidation.locationMax));
    add('address', ChaletEditValidation.optionalText(_address.text, ChaletEditValidation.addressMax));
    add('video_url', ChaletEditValidation.videoUrl(_video.text));
    add('images', ChaletEditValidation.imagesCount(_images.length));

    final coordsDirty =
        dirty.contains('latitude') || dirty.contains('longitude');
    final c = ChaletEditValidation.coordinates(_lat.text, _lng.text);
    add('latitude', c.latError, force: coordsDirty);
    add('longitude', c.lngError, force: coordsDirty);
    return out;
  }

  // ==========================================================
  // الصور (مسودة)
  // ==========================================================

  Future<void> _addImages() async {
    final total = _images.length;
    if (total >= ChaletEditValidation.imagesMax) {
      _showSnack('الحد الأقصى ${ChaletEditValidation.imagesMax} صور',
          isError: true);
      return;
    }

    List<XFile> picked;
    try {
      picked = await (widget.pickImages ??
          () => ImagePicker().pickMultiImage(imageQuality: 85))();
    } catch (_) {
      _showSnack('تعذر فتح معرض الصور، يرجى المحاولة لاحقاً', isError: true);
      return;
    }
    if (picked.isEmpty || !mounted) return;

    final remaining = ChaletEditValidation.imagesMax - total;
    final errors = <String>[];
    final added = <DraftImage>[];
    for (final x in picked) {
      if (added.length >= remaining) {
        errors.add('الحد الأقصى ${ChaletEditValidation.imagesMax} صور');
        break;
      }
      // اسم للعرض بالرسائل: الاسم، وإلا آخر جزء من المسار، وإلا "صورة".
      final fileName = x.name.isNotEmpty
          ? x.name
          : (x.path.split(RegExp(r'[\\/]')).last.isNotEmpty
              ? x.path.split(RegExp(r'[\\/]')).last
              : 'صورة');
      Uint8List bytes;
      try {
        bytes = await x.readAsBytes();
      } catch (_) {
        errors.add('تعذرت قراءة الصورة "$fileName"');
        continue;
      }
      if (bytes.isEmpty) {
        errors.add('تعذرت قراءة الصورة "$fileName"');
        continue;
      }
      final err = ChaletEditValidation.imageFile(
        fileName: fileName,
        mimeType: x.mimeType,
        sizeBytes: bytes.length,
      );
      if (err != null) {
        errors.add(err);
        continue;
      }
      added.add(DraftImage.fresh(x, bytes));
    }
    if (!mounted) return;
    setState(() {
      _images = [..._images, ...added];
      _imageError = errors.isEmpty ? null : errors.join('\n');
    });
  }

  void _removeImage(int i) => setState(() {
        _images = [..._images]..removeAt(i);
        _imageError = null;
      });

  void _makeCover(int i) => setState(() {
        final list = [..._images];
        final img = list.removeAt(i);
        list.insert(0, img);
        _images = list;
      });

  // ==========================================================
  // الموقع (GPS)
  // ==========================================================

  Future<void> _useMyLocation() async {
    final ok = await _confirm(
      title: 'تحديث الموقع',
      body: 'هل أنت الآن عند الشاليه؟ رح نستبدل الإحداثيات بموقعك الحالي.',
      confirmLabel: 'نعم، حدّث',
      destructive: false,
    );
    if (ok != true || !mounted) return;

    setState(() => _locating = true);
    try {
      final pos = await (widget.locate ?? _defaultLocate)();
      if (!mounted) return;
      if (pos == null) {
        _showSnack('تعذر الوصول لموقعك، تأكد من تفعيل GPS ومنح صلاحية الموقع',
            isError: true);
        return;
      }
      _suspend = true;
      _lat.text = pos.latitude.toStringAsFixed(6);
      _lng.text = pos.longitude.toStringAsFixed(6);
      _suspend = false;
      setState(() {});
      _showSnack('تم تحديث الإحداثيات، اضغط "حفظ التعديلات" لتثبيتها');
    } finally {
      _suspend = false;
      if (mounted) setState(() => _locating = false);
    }
  }

  static Future<({double latitude, double longitude})?> _defaultLocate() async {
    final p = await LocationService.instance.getCurrentPosition();
    if (p == null) return null;
    return (latitude: p.latitude, longitude: p.longitude);
  }

  // ==========================================================
  // الحفظ
  // ==========================================================

  /// يبني القيم التالية: الحقل المعدَّل بقيمته المكتوبة، وغير المعدَّل بقيمته
  /// الأصلية حرفياً، فلا يدخل بالفروقات أبداً ما لم يلمسه المالك.
  ChaletEditValues _buildNext(Set<String> dirty) {
    final o = _orig!;
    bool d(String k) => dirty.contains(k);

    final locText = _location.text.trim();
    final cityValue = _city ?? o.city;
    final locationValue = !d('location')
        ? o.location
        : (locText.isNotEmpty
            ? locText
            : (cityValue.trim().isNotEmpty ? cityValue.trim() : 'غير محدد'));

    final coordsDirty = d('latitude') || d('longitude');
    final bothEmpty = _lat.text.trim().isEmpty && _lng.text.trim().isEmpty;

    return ChaletEditValues(
      name: d('name') ? _name.text : o.name,
      description: d('description') ? _desc.text : o.description,
      location: locationValue,
      city: d('city') ? cityValue : o.city,
      address: d('address') ? _address.text : o.address,
      pricePerNight:
          d('price_per_night') ? ChaletEditValidation.parseNumber(_price.text)! : o.pricePerNight,
      maxGuests: d('max_guests') ? ChaletEditValidation.parseInt(_guests.text)! : o.maxGuests,
      bedrooms: _bedrooms,
      bathrooms: _bathrooms,
      hasPool: _pool,
      hasWifi: _wifi,
      hasBbq: _bbq,
      hasParking: _parking,
      isAvailable: _available,
      latitude: !coordsDirty
          ? o.latitude
          : (bothEmpty ? null : ChaletEditValidation.parseNumber(_lat.text)),
      longitude: !coordsDirty
          ? o.longitude
          : (bothEmpty ? null : ChaletEditValidation.parseNumber(_lng.text)),
      images: o.images,
      videoUrl: d('video_url') ? _video.text : o.videoUrl,
    );
  }

  Future<bool> _save() async {
    if (_saving || _orig == null) return false;
    final dirty = _dirtyKeys();
    if (dirty.isEmpty) return true;

    final errors = _blockingErrors(dirty);
    if (errors.isNotEmpty) {
      _showSnack('راجع الحقول المعلَّمة (${errors.length})', isError: true);
      _scrollToFirst(errors.keys);
      return false;
    }

    setState(() => _saving = true);
    final uploaded = <String>[];
    var rowUpdated = false;
    try {
      final id = widget.chaletId;
      final changes = _orig!.diffTo(_buildNext(dirty));

      List<String>? finalImages;
      if (dirty.contains('images')) {
        final fresh = _images.where((i) => i.isNew).toList();
        var urls = <String>[];
        if (fresh.isNotEmpty) {
          urls = await _ds.uploadImages(
            id,
            [for (final f in fresh) f.file!],
            [for (final f in fresh) f.bytes!],
          );
          uploaded.addAll(urls);
          if (urls.length != fresh.length) {
            final failed = fresh.length - urls.length;
            await _bestEffortDelete(uploaded);
            uploaded.clear();
            _showSnack('تعذر رفع $failed من الصور، لم تُحفظ التعديلات',
                isError: true);
            return false;
          }
        }
        var k = 0;
        finalImages = [for (final i in _images) i.isNew ? urls[k++] : i.url!];
        changes['images'] = finalImages;
      }

      if (changes.isEmpty) {
        // تغيّر شكلي لا يغيّر قيمة محفوظة (مثل مسح "المنطقة" لتصير اسم المدينة
        // نفسه). لا شيء يُرسل.
        setState(() => _applyRow(_row!));
        _showSnack('لا توجد تغييرات لحفظها');
        return true;
      }

      final updated = await _ds.updateChalet(id, changes);
      if (updated == null) {
        await _bestEffortDelete(uploaded);
        uploaded.clear();
        _showSnack(
            'لم تُحفظ التعديلات، ربما لا تملك صلاحية تعديل هذا الشاليه',
            isError: true);
        return false;
      }
      rowUpdated = true;

      if (finalImages != null) {
        final keep = finalImages.toSet();
        final removed = [
          for (final u in _orig!.images)
            if (!keep.contains(u)) u,
        ];
        await _bestEffortDelete(removed);
      }

      if (mounted) setState(() => _applyRow(updated));
      _showSnack('تم حفظ التعديلات');
      return true;
    } catch (_) {
      if (!rowUpdated) await _bestEffortDelete(uploaded);
      _showSnack('تعذر الحفظ، تحقق من الاتصال وحاول مرة ثانية', isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _bestEffortDelete(List<String> urls) async {
    if (urls.isEmpty) return;
    try {
      await _ds.deleteImageUrls(widget.chaletId, urls);
    } catch (e, st) {
      // ملفات يتيمة بالتخزين لا تؤثر على المالك؛ لا نفشل الحفظ بسببها.
      reportError(e, st, context: 'chalet_edit.delete_images');
    }
  }

  void _scrollToFirst(Iterable<String> errorKeys) {
    final set = errorKeys.toSet();
    for (final k in _fieldOrder) {
      if (!set.contains(k)) continue;
      final ctx = _fieldKeys[k]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          alignment: 0.1,
        );
      }
      return;
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
  // حوارات
  // ==========================================================

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = true,
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
                style: TextStyle(
                    fontFamily: 'Cairo',
                    color: destructive ? AppColors.error : AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<_LeaveChoice?> _leaveDialog(int count) {
    return showDialog<_LeaveChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديلات غير محفوظة',
            style:
                TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Text(
          'عندك $count تعديل ما انحفظ. شو بدك تسوي قبل ما تطلع؟',
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
    final choice = await _leaveDialog(_d.length);
    if (!mounted) return;
    switch (choice) {
      case _LeaveChoice.save:
        if (await _save() && mounted) Navigator.of(context).pop();
      case _LeaveChoice.discard:
        Navigator.of(context).pop();
      case _LeaveChoice.stay:
      case null:
        break;
    }
  }

  Future<void> _onDiscardPressed() async {
    final ok = await _confirm(
      title: 'تجاهل التعديلات؟',
      body: 'رح ترجع كل الحقول والصور لآخر نسخة محفوظة (${_d.length} تعديل).',
      confirmLabel: 'تجاهل',
    );
    if (ok == true && mounted) setState(() => _applyRow(_row!));
  }

  Future<void> _openPricing() async {
    final o = _orig;
    if (o == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChaletPricingScreen(
          chaletId: widget.chaletId,
          chaletName: o.name.trim().isEmpty ? 'بدون اسم' : o.name,
          defaultPricePerNight: o.pricePerNight,
        ),
      ),
    );
  }

  // ==========================================================
  // البناء
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final ready = _state == _LoadState.ready;
    _d = ready ? _dirtyKeys() : {};
    _e = ready ? _blockingErrors(_d) : {};

    return PopScope(
      canPop: _d.isEmpty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _onPopBlocked();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(ready ? 'تعديل: ${_orig!.name}' : 'تعديل الشاليه'),
        ),
        bottomNavigationBar: ready && _d.isNotEmpty ? _buildBar() : null,
        body: switch (_state) {
          _LoadState.loading => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          _LoadState.error => _message(
              icon: Icons.wifi_off_rounded,
              text: 'تعذر تحميل بيانات الشاليه، يرجى المحاولة لاحقاً',
              action: FilledButton(
                key: const ValueKey('retryLoad'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
                onPressed: _load,
                child: const Text('إعادة المحاولة',
                    style: TextStyle(fontFamily: 'Cairo')),
              ),
            ),
          _LoadState.forbidden => _message(
              icon: Icons.lock_outline_rounded,
              text: 'الشاليه غير موجود أو لا تملك صلاحية تعديله',
              action: FilledButton(
                key: const ValueKey('forbiddenBack'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
                onPressed: () => Navigator.of(context).maybePop(),
                child:
                    const Text('رجوع', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ),
          _LoadState.ready => _buildForm(),
        },
      ),
    );
  }

  Widget _message(
      {required IconData icon, required String text, required Widget action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(text,
                key: const ValueKey('stateMessage'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.charcoal)),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }

  Widget _buildBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.sand)),
        boxShadow: [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -3)),
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
                  'لديك ${_d.length} تعديل غير محفوظ',
                  key: const ValueKey('dirtyBarText'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('discardAllButton'),
                onPressed: _saving ? null : _onDiscardPressed,
                child: const Text('تجاهل',
                    style: TextStyle(
                        fontFamily: 'Cairo', color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 4),
              FilledButton(
                key: const ValueKey('saveButton'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(96, 40),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('حفظ التعديلات',
                        style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(),
            const SizedBox(height: 14),
            _buildBasic(),
            const SizedBox(height: 14),
            _buildCapacity(),
            const SizedBox(height: 14),
            _buildAmenities(),
            const SizedBox(height: 14),
            _buildLocation(),
            const SizedBox(height: 14),
            _buildMedia(),
            const SizedBox(height: 14),
            _buildPricing(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ---------------- مساعدات عرض ----------------

  Widget _section({
    required String id,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final dirty = _d.any(_sections[id]!.contains);
    return Container(
      key: ValueKey('section_$id'),
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
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              if (dirty)
                Container(
                  key: ValueKey('sectionDot_$id'),
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  OutlineInputBorder _border(bool dirty, {bool error = false}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: error
              ? AppColors.error
              : dirty
                  ? AppColors.accent
                  : AppColors.sand,
          width: dirty || error ? 1.6 : 1,
        ),
      );

  Widget _field({
    required String fieldKey,
    required TextEditingController ctrl,
    required String label,
    String? hint,
    String? helper,
    int maxLines = 1,
    TextInputType? type,
    TextDirection? direction,
    int? counterMax,
  }) {
    final dirty = _d.contains(fieldKey);
    final error = _e[fieldKey];
    final multiline = maxLines > 1;
    return KeyedSubtree(
      key: _fieldKeys[fieldKey],
      child: TextField(
        key: ValueKey('field_$fieldKey'),
        controller: ctrl,
        keyboardType: type,
        textDirection: direction,
        maxLines: maxLines,
        minLines: multiline ? 3 : 1,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 3,
          errorText: error,
          errorMaxLines: 3,
          suffixText: dirty && !multiline ? 'لم يُحفظ' : null,
          suffixStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.accentDark),
          counterText: counterMax == null
              ? null
              : '${dirty ? 'لم يُحفظ — ' : ''}${ctrl.text.length}/$counterMax',
          counterStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: dirty ? AppColors.accentDark : AppColors.textHint),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: _border(dirty),
          enabledBorder: _border(dirty),
          errorBorder: _border(dirty, error: true),
          focusedErrorBorder: _border(dirty, error: true),
        ),
      ),
    );
  }

  // ---------------- الحالة ----------------

  Widget _buildStatusCard() {
    final color = _approved ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _approved
                ? Icons.verified_outlined
                : Icons.hourglass_top_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _approved ? 'معتمد' : 'قيد المراجعة',
                  key: const ValueKey('approvalBadge'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
                const Text(
                  'حالة الاعتماد تحددها الإدارة ولا يمكن تغييرها من هنا.',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- الأقسام ----------------

  Widget _buildBasic() {
    return _section(
      id: 'basic',
      title: 'المعلومات الأساسية',
      icon: Icons.info_outline_rounded,
      children: [
        _field(
          fieldKey: 'name',
          ctrl: _name,
          label: 'اسم الشاليه',
        ),
        const SizedBox(height: 14),
        _field(
          fieldKey: 'description',
          ctrl: _desc,
          label: 'وصف الشاليه',
          maxLines: 6,
          counterMax: ChaletEditValidation.descriptionMax,
        ),
      ],
    );
  }

  Widget _stepper({
    required String id,
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final dirty = _d.contains(id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dirty ? AppColors.accent : AppColors.sand,
          width: dirty ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  height: 1.3,
                  color: dirty
                      ? AppColors.accentDark
                      : AppColors.textSecondary)),
          Row(
            children: [
              IconButton(
                key: ValueKey('${id}Minus'),
                visualDensity: VisualDensity.compact,
                onPressed: value > ChaletEditValidation.roomsMin
                    ? () => onChanged(value - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
                tooltip: 'إنقاص',
              ),
              Expanded(
                child: Text('$value',
                    key: ValueKey('${id}Value'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
              IconButton(
                key: ValueKey('${id}Plus'),
                visualDensity: VisualDensity.compact,
                onPressed: value < ChaletEditValidation.roomsMax
                    ? () => onChanged(value + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
                tooltip: 'زيادة',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapacity() {
    return _section(
      id: 'capacity',
      title: 'السعة',
      icon: Icons.group_outlined,
      children: [
        LayoutBuilder(builder: (context, c) {
          final stack = c.maxWidth < 260 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final beds = _stepper(
            id: 'bedrooms',
            label: 'غرف النوم',
            value: _bedrooms,
            onChanged: (v) => setState(() => _bedrooms = v),
          );
          final baths = _stepper(
            id: 'bathrooms',
            label: 'الحمامات',
            value: _bathrooms,
            onChanged: (v) => setState(() => _bathrooms = v),
          );
          if (stack) {
            return Column(children: [beds, const SizedBox(height: 10), baths]);
          }
          return Row(children: [
            Expanded(child: beds),
            const SizedBox(width: 10),
            Expanded(child: baths),
          ]);
        }),
        const SizedBox(height: 14),
        _field(
          fieldKey: 'max_guests',
          ctrl: _guests,
          label: 'عدد الأشخاص المسموح بهم',
          type: TextInputType.number,
        ),
      ],
    );
  }

  Widget _amenity(String id, String label, IconData icon, bool value,
      ValueChanged<bool> onChanged) {
    final dirty = _d.contains(id);
    return Semantics(
      toggled: value,
      label: label,
      child: Material(
        color: value ? AppColors.primary : AppColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: dirty
                ? AppColors.accent
                : value
                    ? AppColors.primary
                    : AppColors.sand,
            width: dirty ? 1.8 : 1,
          ),
        ),
        child: InkWell(
          key: ValueKey('amenity_$id'),
          customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: value ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: value ? Colors.white : AppColors.charcoal)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmenities() {
    return _section(
      id: 'amenities',
      title: 'المرافق',
      icon: Icons.star_outline_rounded,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _amenity('has_wifi', 'واي فاي', Icons.wifi_rounded, _wifi,
                  (v) => setState(() => _wifi = v)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _amenity('has_pool', 'مسبح', Icons.pool_rounded, _pool,
                  (v) => setState(() => _pool = v)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _amenity('has_bbq', 'باربيكيو',
                  Icons.outdoor_grill_rounded, _bbq,
                  (v) => setState(() => _bbq = v)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _amenity('has_parking', 'باركينج',
                  Icons.local_parking_rounded, _parking,
                  (v) => setState(() => _parking = v)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocation() {
    final cities = [
      ..._baseCities,
      if (_orig != null &&
          _orig!.city.trim().isNotEmpty &&
          !_baseCities.contains(_orig!.city))
        _orig!.city,
    ];
    final cityDirty = _d.contains('city');
    final coordsDirty = _d.contains('latitude') || _d.contains('longitude');
    final coords = ChaletEditValidation.coordinates(_lat.text, _lng.text);

    return _section(
      id: 'location',
      title: 'الموقع',
      icon: Icons.location_on_outlined,
      children: [
        KeyedSubtree(
          key: _fieldKeys['city'],
          child: DropdownButtonFormField<String>(
            key: const ValueKey('field_city'),
            initialValue: cities.contains(_city) ? _city : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'المدينة',
              errorText: _e['city'],
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: _border(cityDirty),
              enabledBorder: _border(cityDirty),
              errorBorder: _border(cityDirty, error: true),
            ),
            items: [
              for (final c in cities)
                DropdownMenuItem(
                  value: c,
                  child: Text(c,
                      style: const TextStyle(
                          fontFamily: 'Cairo', fontSize: 14)),
                ),
            ],
            onChanged: (v) => setState(() => _city = v),
          ),
        ),
        const SizedBox(height: 14),
        _field(
          fieldKey: 'location',
          ctrl: _location,
          label: 'المنطقة/الحي',
          hint: 'مثال: قرب مدخل بيتا',
          helper: 'إن تركته فارغاً سنستخدم اسم المدينة.',
        ),
        const SizedBox(height: 14),
        _field(
          fieldKey: 'address',
          ctrl: _address,
          label: 'العنوان التفصيلي (اختياري)',
          helper: 'يظهر في صفحة الشاليه مع الخريطة.',
        ),
        const SizedBox(height: 14),
        // المفتاحان latitude/longitude يحملهما حقلاهما نفسهما (للتمرير لأول خطأ)،
        // فلا لفافة خارجية بنفس المفتاح.
        LayoutBuilder(builder: (context, c) {
            final stack = c.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3;
            final lat = _field(
              fieldKey: 'latitude',
              ctrl: _lat,
              label: 'خط العرض',
              hint: '32.2211',
              direction: TextDirection.ltr,
              type: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
            );
            final lng = _field(
              fieldKey: 'longitude',
              ctrl: _lng,
              label: 'خط الطول',
              hint: '35.2544',
              direction: TextDirection.ltr,
              type: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
            );
            if (stack) {
              return Column(children: [lat, const SizedBox(height: 10), lng]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: lat),
                const SizedBox(width: 10),
                Expanded(child: lng),
              ],
            );
          }),
        if (coordsDirty && coords.warning != null)
          Container(
            key: const ValueKey('coordsWarning'),
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.55)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(coords.warning!,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.charcoal)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('useMyLocation'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: _locating ? null : _useMyLocation,
            icon: _locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('تحديث بموقعي الحالي',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildMedia() {
    final dirty = _d.contains('images');
    return _section(
      id: 'media',
      title: 'الصور والفيديو',
      icon: Icons.photo_camera_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'الصور (${_images.length}/${ChaletEditValidation.imagesMax})',
                key: const ValueKey('imagesCounter'),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: dirty ? AppColors.accentDark : AppColors.charcoal,
                ),
              ),
            ),
            if (dirty)
              const Text('لم يُحفظ',
                  key: ValueKey('imagesDirty'),
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentDark)),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'الصورة الأولى هي الغلاف. الحد الأقصى 8 صور، وكل صورة حتى 10 ميغابايت '
          '(JPG وPNG وWEBP وHEIC).',
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        KeyedSubtree(
          key: _fieldKeys['images'],
          child: ChaletImagesEditor(
            images: _images,
            maxImages: ChaletEditValidation.imagesMax,
            enabled: !_saving,
            onAdd: _addImages,
            onRemove: _removeImage,
            onMakeCover: _makeCover,
          ),
        ),
        if (_e['images'] != null) ...[
          const SizedBox(height: 8),
          Text(_e['images']!,
              key: const ValueKey('imagesError'),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.error)),
        ],
        if (_imageError != null) ...[
          const SizedBox(height: 8),
          Text(_imageError!,
              key: const ValueKey('imagePickError'),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.error)),
        ],
        const SizedBox(height: 16),
        _field(
          fieldKey: 'video_url',
          ctrl: _video,
          label: 'رابط فيديو يوتيوب (اختياري)',
          hint: 'https://youtube.com/watch?v=...',
          direction: TextDirection.ltr,
          type: TextInputType.url,
        ),
      ],
    );
  }

  String _bookingTypeLabel(String t) {
    switch (t) {
      case 'يومي':
      case 'daily':
        return 'يومي';
      case 'خارجي':
      case 'external':
        return 'خارجي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      default:
        return t;
    }
  }

  Widget _buildPricing() {
    final priceDirty = _d.contains('price_per_night');
    final availDirty = _d.contains('is_available');
    final priceValid = ChaletEditValidation.price(_price.text) == null;

    return _section(
      id: 'pricing',
      title: 'السعر والحجز',
      icon: Icons.attach_money_rounded,
      children: [
        _field(
          fieldKey: 'price_per_night',
          ctrl: _price,
          label: 'السعر الأساسي (يبدأ من)',
          type: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 8),
        const Text(
          'يظهر للضيوف كـ"السعر يبدأ من" في البحث وصفحة الشاليه، ويُطبَّق على أي '
          'يوم ليس له سعر يوم أو سعر خاص بالفترة. لتسعير أيام أو فترات '
          'محددة استخدم أسعار الأيام.',
          key: ValueKey('priceHelp'),
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary),
        ),
        if (priceDirty && priceValid)
          Container(
            key: const ValueKey('priceChangeNotice'),
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.55)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تغيير السعر سيؤثر على الأيام التي بلا سعر مضبوط.',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal),
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('openPricing'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 36),
            ),
            onPressed: _openPricing,
            icon: const Icon(Icons.calendar_view_week_rounded, size: 18),
            label: const Text('أسعار الأيام وأنواع الإقامة',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const Divider(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: availDirty ? AppColors.accent : AppColors.sand,
              width: availDirty ? 1.6 : 1,
            ),
          ),
          child: SwitchListTile(
            key: const ValueKey('availableSwitch'),
            contentPadding: EdgeInsets.zero,
            value: _available,
            onChanged: _saving ? null : (v) => setState(() => _available = v),
            title: const Text('متاح للحجز',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            subtitle: Text(
              availDirty
                  ? 'لم يُحفظ — عند الإيقاف لا يظهر الشاليه للضيوف.'
                  : 'عند الإيقاف لا يظهر الشاليه للضيوف. والشاليه قيد المراجعة '
                      'لا يظهر أصلاً حتى تعتمده الإدارة.',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 12, height: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('bookingTypeReadOnly'),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.sand),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'نوع الحجز: ${_bookingTypeLabel(_bookingType)}',
                      key: const ValueKey('bookingTypeValue'),
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13.5,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'يحدد كيف تُصنَّف حجوزات هذا الشاليه في إحصائيات لوحتك: «يومي» '
                'حجوزات عادية، و«خارجي» حجوزات خارجية. لا يمكن تغييره من هذه '
                'الصفحة.',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
