import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chalet_model.dart';
import '../services/services.dart';

class FavoritesNotifier extends StateNotifier<AsyncValue<Set<String>>> {
  FavoritesNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final ids = await FavoritesService.instance.getFavoriteIds();
      if (mounted) state = AsyncValue.data(ids);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> reload() => _load();

  bool isFavorite(String chaletId) {
    return state.valueOrNull?.contains(chaletId) ?? false;
  }

  Future<void> toggleFavorite(ChaletModel chalet) async {
    final current = state.valueOrNull ?? {};
    final isFav = current.contains(chalet.id);

    // Optimistic update
    state = AsyncValue.data(
      isFav
          ? (Set<String>.from(current)..remove(chalet.id))
          : (Set<String>.from(current)..add(chalet.id)),
    );

    try {
      await FavoritesService.instance.toggleFavorite(chalet.id);
    } catch (_) {
      // Rollback on error
      state = AsyncValue.data(current);
    }
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, AsyncValue<Set<String>>>(
  (ref) => FavoritesNotifier(),
);

// Helper provider: returns true/false for a specific chaletId
final isFavoriteProvider = Provider.family<bool, String>((ref, chaletId) {
  final favState = ref.watch(favoritesProvider);
  return favState.valueOrNull?.contains(chaletId) ?? false;
});
