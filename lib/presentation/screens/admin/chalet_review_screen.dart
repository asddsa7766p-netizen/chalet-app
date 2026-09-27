part of 'admin_dashboard_screen.dart';

// ═══════════════════ مراجعة شاليه بانتظار الموافقة ═════════════════════════

/// شاشة مراجعة شاليه للأدمن قبل اعتماده: كل التفاصيل (الصور، الوصف،
/// الموقع، المرافق، السعر، الفترات بأوقاتها وأسعارها، المالك وهاتفه) بلا
/// قلب ولا زر حجز، وأسفلها "اعتماد" (حوار تأكيد) و"رفض" (سبب إلزامي). الرفض
/// لا يحذف الشاليه: يعود للمالك مع السبب ليعدّله ويعيد إرساله. الشاليه
/// المرفوض أصلاً يعرض سبب رفضه ويقبل الاعتماد فقط.
///
/// تُغلق بـ `true` بعد اعتماد الشاليه أو رفضه، ليُزال من قائمته.
class AdminChaletReviewScreen extends StatefulWidget {
  final String chaletId;

  /// للاختبارات؛ الافتراضيات دوال [AdminService].
  final Future<AdminChaletReview> Function(String chaletId)? load;
  final Future<void> Function(String chaletId)? approve;
  final Future<void> Function(String chaletId, String reason)? reject;

  const AdminChaletReviewScreen({
    super.key,
    required this.chaletId,
    this.load,
    this.approve,
    this.reject,
  });

  @override
  State<AdminChaletReviewScreen> createState() =>
      _AdminChaletReviewScreenState();
}

class _AdminChaletReviewScreenState extends State<AdminChaletReviewScreen> {
  AdminChaletReview? _data;
  String? _error;
  bool _busy = false;
  int _image = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _data = null;
      _error = null;
    });
    try {
      final data = await (widget.load ??
          AdminService.instance.getChaletForReview)(widget.chaletId);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            _errorText(e, 'تعذر تحميل الشاليه، يرجى المحاولة مرة أخرى.'));
      }
    }
  }

  Future<void> _decide({required bool approve}) async {
    if (_busy) return;
    String? reason;
    if (approve) {
      final confirmed = await _confirm(
        context,
        title: 'اعتماد الشاليه',
        message: 'سيظهر الشاليه للزبائن ويصبح قابلاً للحجز فور اعتماده.',
        action: 'اعتماد',
        actionColor: AppColors.primary,
      );
      if (!confirmed) return;
    } else {
      reason = await showRejectReasonDialog(context);
      if (reason == null) return;
    }
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      if (approve) {
        await (widget.approve ?? AdminService.instance.approveChalet)(
            widget.chaletId);
      } else {
        await (widget.reject ?? AdminService.instance.rejectChalet)(
            widget.chaletId, reason!);
      }
      if (!mounted) return;
      _showSnack(
          context,
          approve
              ? 'تمت الموافقة على الشاليه ✅'
              : 'تم رفض الشاليه وإبلاغ المالك بالسبب');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showSnack(
          context,
          _errorText(
              e,
              approve
                  ? 'فشلت الموافقة، يرجى المحاولة مرة أخرى.'
                  : 'فشل الرفض، يرجى المحاولة مرة أخرى.'),
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AdminColors.navy,
          foregroundColor: AdminColors.onNavy,
          iconTheme: const IconThemeData(color: AdminColors.onNavy),
          title: const Text('مراجعة الشاليه',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AdminColors.onNavy)),
        ),
        body: _error != null
            ? _errorView(_error!, _load)
            : data == null
                ? const Center(
                    child: CircularProgressIndicator(color: AdminColors.navy))
                : _buildDetails(data),
        bottomNavigationBar:
            data == null ? null : _buildActions(canReject: !data.isRejected),
      ),
    );
  }

  Widget _buildDetails(AdminChaletReview data) {
    final c = data.chalet;
    final periods = data.periods.isEmpty
        ? const [BookingPeriod.fullDayDefault]
        : [for (final p in data.periods) BookingPeriod.fromConfig(p)];
    final prices = data.periods.isEmpty
        ? [c.pricePerNight]
        : [for (final p in data.periods) data.priceOf(p)];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildGallery(c.images),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.name.trim().isEmpty ? 'بدون اسم' : c.name,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: data.isRejected
                      ? AppColors.error.withValues(alpha: 0.12)
                      : AdminColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(data.isRejected ? 'مرفوض' : 'بانتظار الموافقة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: data.isRejected
                            ? AppColors.error
                            : AdminColors.navy)),
              ),
            ],
          ),
        ),
        if (data.isRejected)
          Container(
            key: const Key('review_rejection_banner'),
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سبب الرفض · ${formatRejectionDate(data.rejectedAt!)}',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.error)),
                const SizedBox(height: 4),
                Text(data.rejectionReason ?? '—',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                const Text(
                    'بانتظار تعديل المالك وإعادة إرساله. الاعتماد الآن يمسح الرفض.',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        _section('الوصف', Icons.notes_rounded, [
          Text(
              c.description.trim().isEmpty
                  ? 'لا يوجد وصف'
                  : c.description.trim(),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  height: 1.7,
                  color: AppColors.textSecondary)),
        ]),
        _section('المدينة والموقع', Icons.place_outlined, [
          _row('المدينة', c.city),
          _row('المنطقة/الحي', c.location),
          if (c.address?.trim().isNotEmpty == true)
            _row('العنوان', c.address!.trim()),
          if (c.hasLocation) ...[
            _row('الإحداثيات',
                '${c.latitude!.toStringAsFixed(5)}, ${c.longitude!.toStringAsFixed(5)}'),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _open(
                    'https://www.google.com/maps/search/?api=1&query=${c.latitude},${c.longitude}'),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('فتح على الخريطة',
                    style: TextStyle(fontFamily: 'Cairo')),
              ),
            ),
          ] else
            _row('الخريطة', 'لم يحدد المالك موقعاً على الخريطة'),
        ]),
        _section('المرافق', Icons.checklist_rounded, [
          _row('أقصى عدد ضيوف', '${c.maxGuests}'),
          _row('غرف النوم', '${c.bedrooms}'),
          _row('الحمامات', '${c.bathrooms}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _amenity(Icons.pool_rounded, 'مسبح خاص', c.hasPool),
              _amenity(Icons.wifi_rounded, 'واي فاي', c.hasWifi),
              _amenity(
                  Icons.local_parking_rounded, 'موقف سيارات', c.hasParking),
              _amenity(Icons.outdoor_grill_rounded, 'أدوات شواء', c.hasBbq),
            ],
          ),
        ]),
        _section('السعر', Icons.payments_outlined, [
          _row('السعر الأساسي', AppCurrency.formatPrice(c.pricePerNight)),
          if (c.depositAmount > 0)
            _row('العربون', AppCurrency.formatPrice(c.depositAmount)),
        ]),
        _section('الفترات', Icons.schedule_rounded, [
          for (var i = 0; i < periods.length; i++)
            Container(
              key: Key('review_period_$i'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(periods[i].icon, color: AdminColors.navy, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(periods[i].label,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        Text(periods[i].timeLabel ?? 'بلا أوقات محددة',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text(AppCurrency.formatPrice(prices[i]),
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AdminColors.navy)),
                ],
              ),
            ),
        ]),
        _section('المالك', Icons.person_outline_rounded, [
          _row('الاسم', data.ownerName?.trim().isNotEmpty == true
              ? data.ownerName!.trim()
              : 'غير معروف'),
          _row('الهاتف', data.ownerPhone?.trim().isNotEmpty == true
              ? data.ownerPhone!.trim()
              : 'غير مسجّل'),
          if (data.ownerEmail?.trim().isNotEmpty == true)
            _row('البريد', data.ownerEmail!.trim()),
          if (data.ownerPhone?.trim().isNotEmpty == true)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _open('tel:${data.ownerPhone!.trim()}'),
                icon: const Icon(Icons.call_outlined, size: 18),
                label: const Text('اتصال بالمالك',
                    style: TextStyle(fontFamily: 'Cairo')),
              ),
            ),
        ]),
        if (c.videoUrl?.trim().isNotEmpty == true)
          _section('الفيديو', Icons.videocam_outlined, [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _open(c.videoUrl!.trim()),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                label: const Text('فتح الفيديو',
                    style: TextStyle(fontFamily: 'Cairo')),
              ),
            ),
          ]),
      ],
    );
  }

  Widget _buildGallery(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 200,
        color: AppColors.sand,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 40, color: AppColors.textMuted),
            SizedBox(height: 6),
            Text('لا توجد صور',
                style: TextStyle(
                    fontFamily: 'Cairo', color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _image = i),
            itemBuilder: (_, i) => Image.network(
              images[i],
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.sand,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.textMuted),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: 10,
            start: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AdminColors.navy.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${_image + 1} / ${images.length}',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.onNavy)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions({required bool canReject}) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('review_approve'),
                onPressed: _busy ? null : () => _decide(approve: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('اعتماد',
                    style: TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
              ),
            ),
            if (canReject) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('review_reject'),
                  onPressed: _busy ? null : () => _decide(approve: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('رفض',
                      style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: AdminColors.gold),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AdminColors.navy)),
          ]),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value.trim().isEmpty ? '—' : value,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _amenity(IconData icon, String label, bool available) {
    final color = available ? AppColors.primary : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: available
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(available ? icon : Icons.block_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                decoration: available ? null : TextDecoration.lineThrough)),
      ]),
    );
  }

  Future<void> _open(String url) async {
    try {
      final ok =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        _showSnack(context, 'تعذر فتح الرابط', isError: true);
      }
    } catch (_) {
      if (mounted) _showSnack(context, 'تعذر فتح الرابط', isError: true);
    }
  }
}
