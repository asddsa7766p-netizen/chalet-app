part of 'admin_dashboard_screen.dart';

// ════════════════════════ تبويب 3: المستخدمون ════════════════════════════

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late final _pager = PagedList<Map<String, dynamic>>(
      (page) =>
          AdminService.instance.getUsers(page: page, search: _searchQuery),
      pageSize: AdminService.pageSize);
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  Timer? _searchDebounce;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
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
            _errorText(e, 'تعذر تحميل المستخدمين، يرجى المحاولة مرة أخرى.');
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

  void _onSearchChanged(String v) {
    _searchQuery = v;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _load);
  }

  /// يستبدل صف المستخدم بالقائمة بالصف المحدَّث الذي أرجعته الدالة.
  void _replaceUser(Map<String, dynamic> updated) {
    setState(() {
      _pager.items = [
        for (final u in _pager.items)
          u['id'] == updated['id'] ? {...u, ...updated} : u,
      ];
    });
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    if (_actionLoading) return;
    final currentlyActive = (user['is_active'] as bool?) ?? true;
    if (currentlyActive) {
      final confirmed = await _confirm(
        context,
        title: 'حظر المستخدم',
        message:
            'لن يتمكن هذا المستخدم من استخدام حسابه حتى تعيد تفعيله. هل تريد المتابعة؟',
        action: 'حظر',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _actionLoading = true);
    try {
      final updated =
          await AdminService.instance.toggleUserActive(user['id'] as String);
      if (!mounted) return;
      _replaceUser(updated);
      _showSnack(context,
          currentlyActive ? 'تم حظر المستخدم' : 'تم تفعيل المستخدم');
    } catch (e) {
      if (!mounted) return;
      _showSnack(context,
          _errorText(e, 'فشل تنفيذ العملية، يرجى المحاولة مرة أخرى.'),
          isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _toggleAdmin(Map<String, dynamic> user) async {
    if (_actionLoading) return;
    final currentlyAdmin = (user['is_admin'] as bool?) ?? false;
    final confirmed = await _confirm(
      context,
      title: currentlyAdmin ? 'إلغاء صلاحية الأدمن' : 'منح صلاحية الأدمن',
      message: currentlyAdmin
          ? 'سيفقد هذا المستخدم الوصول للوحة تحكم الأدمن.'
          : 'سيتمكن هذا المستخدم من الوصول الكامل للوحة تحكم الأدمن.',
      action: currentlyAdmin ? 'إلغاء الصلاحية' : 'منح الصلاحية',
    );
    if (!confirmed || !mounted) return;
    setState(() => _actionLoading = true);
    try {
      final updated =
          await AdminService.instance.toggleUserAdmin(user['id'] as String);
      if (!mounted) return;
      _replaceUser(updated);
      _showSnack(context,
          currentlyAdmin ? 'تم إلغاء صلاحية الأدمن' : 'تم منح صلاحية الأدمن ✅');
    } catch (e) {
      if (!mounted) return;
      _showSnack(context,
          _errorText(e, 'فشل تنفيذ العملية، يرجى المحاولة مرة أخرى.'),
          isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _pager.items;
    Widget body;
    if (_loading) {
      body = const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    } else if (_error != null) {
      body = _errorView(_error!, _load);
    } else if (users.isEmpty) {
      body = const Center(
          child: Text('لا يوجد نتائج',
              style: TextStyle(
                  fontFamily: 'Cairo', color: AppColors.textSecondary)));
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: users.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => i == users.length
              ? LoadMoreFooter(pager: _pager, onLoadMore: _loadMore)
              : _userTile(users[i]),
        ),
      );
    }

    return Column(
      children: [
        // شريط البحث (على السيرفر، يشمل الصفحات غير المحمَّلة)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: _onSearchChanged,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو البريد',
              hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _userTile(Map<String, dynamic> u) {
    final name = (u['full_name'] as String?)?.trim().isNotEmpty == true
        ? (u['full_name'] as String).trim()
        : 'بدون اسم';
    final email = u['email'] as String? ?? '';
    final isOwner = (u['is_owner'] as bool?) ?? false;
    final isAdmin = (u['is_admin'] as bool?) ?? false;
    final isActive = (u['is_active'] as bool?) ?? true;
    final initial = name.characters.first;

    return Container(
      decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(initial,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الاسم + الشارات
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    if (isAdmin) _badge('أدمن', AppColors.primary),
                    if (isOwner) _badge('مالك', const Color(0xFF8A6D3B)),
                    if (!isActive) _badge('محظور', AppColors.error),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          // قائمة الإجراءات
          PopupMenuButton<String>(
            enabled: !_actionLoading,
            icon: const Icon(Icons.more_vert_rounded,
                size: 20, color: AppColors.textMuted),
            onSelected: (value) {
              if (value == 'toggle_active') _toggleActive(u);
              if (value == 'toggle_admin') _toggleAdmin(u);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                  value: 'toggle_active',
                  child: Row(children: [
                    Icon(
                        isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18,
                        color: isActive ? AppColors.error : AppColors.primary),
                    const SizedBox(width: 8),
                    Text(isActive ? 'حظر المستخدم' : 'تفعيل المستخدم',
                        style:
                            const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                  ])),
              PopupMenuItem(
                  value: 'toggle_admin',
                  child: Row(children: [
                    Icon(
                        isAdmin
                            ? Icons.remove_moderator_rounded
                            : Icons.admin_panel_settings_rounded,
                        size: 18,
                        color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(isAdmin ? 'إلغاء صلاحية الأدمن' : 'منح صلاحية الأدمن',
                        style:
                            const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                  ])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color)),
    );
  }
}
