part of 'admin_dashboard_screen.dart';

// ════════════════════ تبويب 2: موافقة الشاليهات ══════════════════════════

/// قائمتان: "بانتظار الموافقة" (غير المرفوضة) و"المرفوضة" (بسبب الرفض
/// وتاريخه، بانتظار تعديل المالك). لا أزرار قرار على البطاقات: الضغط يفتح
/// شاشة المراجعة، وهي الطريق الوحيد للاعتماد أو الرفض.
class _ChaletApprovalsTab extends StatefulWidget {
  const _ChaletApprovalsTab();
  @override
  State<_ChaletApprovalsTab> createState() => _ChaletApprovalsTabState();
}

class _ChaletApprovalsTabState extends State<_ChaletApprovalsTab> {
  bool _showRejected = false;

  // قرار من إحدى القائمتين يغيّر الأخرى (رفض ← المرفوضة، اعتماد مرفوض ←
  // يخرج منها)، فيزيد عدّادها لتُعاد قراءتها.
  int _pendingVersion = 0;
  int _rejectedVersion = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<bool>(
            key: const Key('approvals_filter'),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AdminColors.navy,
              selectedForegroundColor: AdminColors.onNavy,
              foregroundColor: AdminColors.navy,
            ),
            segments: const [
              ButtonSegment(
                  value: false,
                  label: Text('بانتظار الموافقة',
                      style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.w700))),
              ButtonSegment(
                  value: true,
                  label: Text('المرفوضة',
                      style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.w700))),
            ],
            selected: {_showRejected},
            onSelectionChanged: (s) => setState(() => _showRejected = s.first),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _showRejected ? 1 : 0,
            children: [
              ChaletQueueList(
                key: const Key('pending_queue'),
                fetch: (page) =>
                    AdminService.instance.getPendingChalets(page: page),
                emptyText: 'لا توجد شاليهات بانتظار الموافقة',
                version: _pendingVersion,
                onDecided: () => setState(() => _rejectedVersion++),
              ),
              // لا تُجلب المرفوضة قبل فتحها أول مرة.
              if (_showRejected || _rejectedVersion > 0)
                ChaletQueueList(
                  key: const Key('rejected_queue'),
                  fetch: (page) =>
                      AdminService.instance.getRejectedChalets(page: page),
                  emptyText: 'لا توجد شاليهات مرفوضة',
                  version: _rejectedVersion,
                  onDecided: () => setState(() => _pendingVersion++),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}

/// قائمة شاليهات مرقّمة بصفحات (معلّقة أو مرفوضة). الضغط على بطاقة يفتح
/// المراجعة؛ القرار منها يزيل الشاليه ويستدعي [onDecided]. تغيّر [version]
/// يعيد التحميل.
class ChaletQueueList extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function(int page) fetch;
  final String emptyText;
  final int version;
  final VoidCallback? onDecided;

  /// للاختبارات؛ الافتراضي يفتح [AdminChaletReviewScreen] ويرجع قراره.
  final Future<bool?> Function(BuildContext context, String chaletId)?
      openReview;

  const ChaletQueueList({
    super.key,
    required this.fetch,
    required this.emptyText,
    this.version = 0,
    this.onDecided,
    this.openReview,
  });

  @override
  State<ChaletQueueList> createState() => _ChaletQueueListState();
}

class _ChaletQueueListState extends State<ChaletQueueList> {
  late final _pager = PagedList<Map<String, dynamic>>(
      (page) => widget.fetch(page),
      pageSize: AdminService.pageSize);
  bool _loading = true;
  String? _error;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ChaletQueueList old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await _pager.reset() || !mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            _errorText(e, 'تعذر تحميل الشاليهات، يرجى المحاولة مرة أخرى.');
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() {});
    try {
      await _pager.loadMore();
    } catch (e) {
      if (mounted) {
        _showSnack(context, _errorText(e, 'تعذر تحميل المزيد'), isError: true);
      }
    }
    if (mounted) setState(() {});
  }

  /// يفتح شاشة المراجعة — الطريق الوحيد للاعتماد أو الرفض؛ القرار منها
  /// يزيل الشاليه من القائمة.
  Future<void> _openReview(Map<String, dynamic> chalet) async {
    if (_opening) return; // ضغطتان سريعتان لا تفتحان شاشتين
    _opening = true;
    try {
      final id = chalet['id'] as String;
      final decided =
          await (widget.openReview ?? _defaultOpenReview)(context, id);
      if (decided == true && mounted) {
        setState(() => _pager.items =
            _pager.items.where((c) => c['id'] != id).toList());
        widget.onDecided?.call();
      }
    } finally {
      _opening = false;
    }
  }

  static Future<bool?> _defaultOpenReview(
          BuildContext context, String chaletId) =>
      Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => AdminChaletReviewScreen(chaletId: chaletId)));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) return _errorView(_error!, _load);
    final chalets = _pager.items;
    if (chalets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(children: [
          const SizedBox(height: 120),
          const Icon(Icons.check_circle_outline_rounded,
              size: 56, color: AppColors.textMuted),
          const SizedBox(height: 14),
          Center(
              child: Text(widget.emptyText,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary))),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: chalets.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == chalets.length) {
            return LoadMoreFooter(pager: _pager, onLoadMore: _loadMore);
          }
          final c = chalets[i];
          return PendingChaletCard(
            key: Key('pending_chalet_${c['id']}'),
            chalet: c,
            onTap: () => _openReview(c),
          );
        },
      ),
    );
  }
}

/// بطاقة شاليه بانتظار القرار (أو مرفوض: بسبب الرفض وتاريخه). لا أزرار
/// اعتماد أو رفض عليها: الضغط يفتح شاشة المراجعة، وهي الطريق الوحيد للقرار.
class PendingChaletCard extends StatelessWidget {
  final Map<String, dynamic> chalet;
  final VoidCallback onTap;

  const PendingChaletCard(
      {super.key, required this.chalet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = chalet;
    final name = (c['name'] as String?)?.trim().isNotEmpty == true
        ? c['name'] as String
        : 'بدون اسم';
    final city = c['city'] as String? ?? '';
    final price = (c['price_per_night'] as num?)?.toDouble() ?? 0;
    // images مخزنة كـ text[] في Supabase
    final images = (c['images'] as List?)?.cast<String>() ?? [];
    final cover = images.isNotEmpty ? images.first : null;
    final rejectedAt = c.rejectedAt;

    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: rejectedAt != null
                  ? AppColors.error.withValues(alpha: 0.4)
                  : AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // صورة الغلاف
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: cover != null
                    ? Image.network(cover,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('$city · يبدأ من ₪${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    if (rejectedAt != null) ...[
                      Text('رُفض في ${formatRejectionDate(rejectedAt)}',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.error)),
                      Text('السبب: ${c.rejectionReason ?? '—'}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: AppColors.textPrimary)),
                    ] else
                      const Text('اضغط لمراجعة التفاصيل والاعتماد أو الرفض',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AdminColors.navy)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left_rounded, color: AdminColors.navy),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 68,
        height: 68,
        color: AppColors.sand,
        child: const Icon(Icons.home_work_rounded, color: AppColors.primary),
      );
}
