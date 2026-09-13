import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import '../../../data/providers/favorites_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../widgets/common/common_widgets.dart';

// ============================================
// FAVORITES SCREEN
// ============================================
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  List<ChaletModel> _favorites = [];
  bool _loading = true;
  Set<String>? _lastIds;

  Future<void> _loadChalets(Set<String> ids) async {
    setState(() => _loading = true);
    try {
      final favs = await FavoritesService.instance.getFavorites();
      if (mounted) {
        setState(() {
          _favorites = favs;
          _loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('❌ خطأ تحميل المفضلة: $e');
      debugPrint('$st');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(String chaletId) async {
    await ref.read(favoritesProvider.notifier).toggleFavorite(
          _favorites.firstWhere((c) => c.id == chaletId),
        );
  }

  @override
  Widget build(BuildContext context) {
    final favState = ref.watch(favoritesProvider);

    ref.listen(favoritesProvider, (previous, next) {
      final ids = next.valueOrNull;
      if (ids != null && ids != _lastIds) {
        _lastIds = ids;
        _loadChalets(ids);
      }
    });

    if (_lastIds == null && favState.valueOrNull != null) {
      _lastIds = favState.valueOrNull;
      _loadChalets(_lastIds!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: AppColors.textPrimary,
        title: const Text(AppStrings.favorites),
        actions: [
          if (_favorites.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPale,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${_favorites.length}',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _favorites.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: () => _loadChalets(_lastIds ?? {}),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length,
                    itemBuilder: (_, i) => Dismissible(
                      key: Key(_favorites[i].id),
                      direction: DismissDirection.startToEnd,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.error),
                      ),
                      onDismissed: (_) => _remove(_favorites[i].id),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.border.withOpacity(0.6)),
                          ),
                          child: ChaletCard(
                            chalet: _favorites[i],
                            horizontal: true,
                            isFavorite: true,
                            onFavoriteTap: () => _remove(_favorites[i].id),
                            onTap: () => context.push(
                                '/home/chalet/${_favorites[i].id}',
                                extra: _favorites[i]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border_rounded,
                size: 72, color: AppColors.sand),
            const SizedBox(height: 16),
            const Text(AppStrings.noFavorites,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(AppStrings.addFavorites,
                style: TextStyle(
                    fontFamily: 'Cairo', color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            SizedBox(
              width: 180,
              child: OutlinedButton(
                onPressed: () => context.go('/home'),
                child: const Text('استكشف الشاليهات',
                    style: TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
}

// ============================================
// MY BOOKINGS SCREEN
// ============================================
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tabs = ['الحالية', 'القادمة', 'السابقة', 'الملغاة'];
  final _statuses = [
    ['confirmed'],
    ['pending'],
    ['completed'],
    ['cancelled', 'rejected'],
  ];
  Map<int, List<BookingModel>> _bookingsMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await BookingService.instance.getMyBookings();
      final map = <int, List<BookingModel>>{};
      for (int i = 0; i < _statuses.length; i++) {
        map[i] =
            all.where((b) => _statuses[i].contains(b.status.name)).toList();
      }
      if (mounted) {
        setState(() {
          _bookingsMap = map;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(String bookingId, int tabIdx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إلغاء الحجز',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        content: const Text('هل أنت متأكد من إلغاء هذا الحجز؟',
            style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لا', style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('نعم، إلغاء',
                  style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
    if (confirm == true) {
      await BookingService.instance.cancelBooking(bookingId);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: AppColors.textPrimary,
        title: const Text(AppStrings.myBookings),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
              fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600),
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: List.generate(_tabs.length, (i) {
                final bookings = _bookingsMap[i] ?? [];
                if (bookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 60, color: AppColors.sand),
                        const SizedBox(height: 14),
                        Text(
                          'لا يوجد ${_tabs[i]}',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: bookings.length,
                    itemBuilder: (_, j) => _BookingCard(
                      booking: bookings[j],
                      onCancel: bookings[j].status == BookingStatus.pending ||
                              bookings[j].status == BookingStatus.confirmed
                          ? () => _cancel(bookings[j].id, i)
                          : null,
                    ),
                  ),
                );
              }),
            ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onCancel;
  const _BookingCard({required this.booking, this.onCancel});

  Color get _statusColor {
    switch (booking.status) {
      case BookingStatus.pending:
        return AppColors.pending;
      case BookingStatus.confirmed:
        return AppColors.confirmed;
      case BookingStatus.cancelled:
        return AppColors.cancelled;
      case BookingStatus.rejected:
        return AppColors.error;
      case BookingStatus.completed:
        return AppColors.completed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.card;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4)),
        ],
        border: Border.all(color: AppColors.divider.withOpacity(0.6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'حجز #${booking.id.substring(0, 8)}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor.withOpacity(0.9)),
                  ),
                  child: Text(
                    booking.status.arabicLabel,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: booking.chaletImage != null
                      ? CachedNetworkImage(
                          imageUrl: booking.chaletImage!,
                          width: 86,
                          height: 86,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 86,
                            height: 86,
                            color: AppColors.primaryLight.withOpacity(0.35),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 86,
                            height: 86,
                            color: AppColors.primaryLight.withOpacity(0.35),
                            child: const Icon(Icons.home_work_rounded,
                                color: AppColors.textMuted),
                          ),
                        )
                      : Container(
                          width: 86,
                          height: 86,
                          color: AppColors.primaryLight.withOpacity(0.35),
                          child: const Icon(Icons.home_work_rounded,
                              color: AppColors.textMuted),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.chaletName ?? 'شاليه',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.chaletCity ?? '',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${booking.checkIn.day}/${booking.checkIn.month}/${booking.checkIn.year} — ${booking.checkOut.day}/${booking.checkOut.month}/${booking.checkOut.year}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${booking.nightsCount} ليالٍ · ${booking.guestsCount} ضيف',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      AppCurrency.formatPrice(booking.totalPrice),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                if (onCancel != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// REVIEWS SCREEN
// ============================================
class ReviewsScreen extends StatefulWidget {
  final String chaletId;
  final String chaletName;
  const ReviewsScreen(
      {super.key, required this.chaletId, required this.chaletName});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<ReviewModel> _reviews = [];
  bool _loading = true;
  int _myRating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final reviews =
          await ReviewsService.instance.getChaletReviews(widget.chaletId);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_myRating == 0) return;
    setState(() => _submitting = true);
    try {
      await ReviewsService.instance.addReview(
        chaletId: widget.chaletId,
        rating: _myRating,
        comment: _commentCtrl.text.isEmpty ? null : _commentCtrl.text,
      );
      _commentCtrl.clear();
      setState(() {
        _myRating = 0;
        _submitting = false;
      });
      _load();
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        final msg = _ is Exception ? _.toString() : 'error';
        if (msg.contains('not_eligible_review')) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('لا يمكنك إضافة تقييم قبل إكمال حجز'),
            backgroundColor: AppColors.primary,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('حدث خطأ أثناء إضافة التقييم'),
            backgroundColor: AppColors.error,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avg = _reviews.isEmpty
        ? 0.0
        : _reviews.map((r) => r.rating).reduce((a, b) => a + b) /
            _reviews.length;

    return Scaffold(
      appBar: AppBar(title: Text('تقييمات ${widget.chaletName}')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  color: AppColors.white,
                  child: Row(
                    children: [
                      Column(children: [
                        Text(avg.toStringAsFixed(1),
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: AppColors.charcoal)),
                        Row(
                            children: List.generate(
                                5,
                                (i) => Icon(
                                    i < avg.round()
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: AppColors.accent,
                                    size: 18))),
                        Text('${_reviews.length} تقييم',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ]),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: List.generate(5, (i) {
                            final star = 5 - i;
                            final count =
                                _reviews.where((r) => r.rating == star).length;
                            final pct = _reviews.isEmpty
                                ? 0.0
                                : count / _reviews.length;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                Text('$star',
                                    style: const TextStyle(
                                        fontFamily: 'Cairo', fontSize: 11)),
                                const Icon(Icons.star_rounded,
                                    size: 11, color: AppColors.accent),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: pct,
                                          backgroundColor: AppColors.sand,
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                                  AppColors.accent),
                                          minHeight: 6,
                                        ))),
                                const SizedBox(width: 6),
                                SizedBox(
                                    width: 20,
                                    child: Text('$count',
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 11,
                                            color: AppColors.textSecondary))),
                              ]),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildAddReview(),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reviews.length,
                    itemBuilder: (_, i) => _ReviewTile(review: _reviews[i]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAddReview() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AppStrings.addReview,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
                5,
                (i) => GestureDetector(
                      onTap: () => setState(() => _myRating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                            i < _myRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: AppColors.accent,
                            size: 32),
                      ),
                    )),
          ),
          const SizedBox(height: 10),
          CustomTextField(
              controller: _commentCtrl,
              label: '',
              hint: AppStrings.yourReview,
              maxLines: 2),
          const SizedBox(height: 10),
          AppButton(
            label: AppStrings.submitReview,
            onPressed: _myRating > 0 ? _submit : null,
            loading: _submitting,
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ReviewModel review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryPale,
            backgroundImage: review.userAvatar != null
                ? NetworkImage(review.userAvatar!)
                : null,
            child: review.userAvatar == null
                ? Text((review.userName ?? 'م').characters.first,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.sand),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(review.userName ?? 'مستخدم',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      Row(
                          children: List.generate(
                              5,
                              (i) => Icon(
                                  i < review.rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: AppColors.accent,
                                  size: 12))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (review.comment != null)
                    Text(review.comment!,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.6)),
                  const SizedBox(height: 4),
                  Text(
                      '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: AppColors.textHint)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
