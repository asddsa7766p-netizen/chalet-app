part of 'admin_dashboard_screen.dart';

// ════════════════════ تبويب 2: موافقة الشاليهات ══════════════════════════

class _ChaletApprovalsTab extends StatefulWidget {
  const _ChaletApprovalsTab();
  @override
  State<_ChaletApprovalsTab> createState() => _ChaletApprovalsTabState();
}

class _ChaletApprovalsTabState extends State<_ChaletApprovalsTab> {
  final _pager = PagedList<Map<String, dynamic>>(
      (page) => AdminService.instance.getPendingChalets(page: page),
      pageSize: AdminService.pageSize);
  bool _loading = true;
  String? _error;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
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
      final decided = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
              builder: (_) =>
                  AdminChaletReviewScreen(chaletId: chalet['id'] as String)));
      if (decided == true && mounted) {
        setState(() => _pager.items =
            _pager.items.where((c) => c['id'] != chalet['id']).toList());
      }
    } finally {
      _opening = false;
    }
  }

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
        child: ListView(children: const [
          SizedBox(height: 120),
          Icon(Icons.check_circle_outline_rounded,
              size: 56, color: AppColors.textMuted),
          SizedBox(height: 14),
          Center(
              child: Text('لا توجد شاليهات بانتظار الموافقة',
                  style: TextStyle(
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

/// بطاقة شاليه بانتظار الموافقة. لا أزرار اعتماد أو رفض عليها: الضغط يفتح
/// شاشة المراجعة، وهي الطريق الوحيد للقرار.
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

    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border)),
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
