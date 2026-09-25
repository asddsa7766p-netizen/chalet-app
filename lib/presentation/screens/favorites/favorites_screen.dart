import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/services/services.dart';
import '../../../data/providers/favorites_provider.dart';
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
  // ✅ إصلاح: فشل التحميل كان يُبلع ويُعرض كأنه "لا توجد مفضلة" (رسالة
  // مضلّلة لمن عنده مفضلة فعلاً). الآن حالة خطأ صريحة مع إعادة محاولة.
  bool _loadError = false;
  Set<String>? _lastIds;

  Future<void> _loadChalets(Set<String> ids) async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
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
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = true;
        });
      }
    }
  }

  Future<void> _remove(String chaletId) async {
    // firstWhere كان يرمي StateError لو لم يعد العنصر بالقائمة (ضغطتان سريعتان).
    final matches = _favorites.where((c) => c.id == chaletId);
    if (matches.isEmpty) return;
    await ref.read(favoritesProvider.notifier).toggleFavorite(matches.first);
  }

  Widget _buildLoadError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('تعذر تحميل المفضلة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('تحقق من اتصالك بالإنترنت وحاول مجدداً',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _loadChalets(_lastIds ?? {}),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة',
                    style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
      );

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
          : _loadError
              ? _buildLoadError()
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
                          color: AppColors.error.withValues(alpha: 0.1),
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
                                color: AppColors.border.withValues(alpha: 0.6)),
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
