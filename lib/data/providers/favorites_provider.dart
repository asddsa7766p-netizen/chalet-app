import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chalet_model.dart';

class FavoritesNotifier extends StateNotifier<List<ChaletModel>> {
  FavoritesNotifier() : super([]);

  bool isFavorite(String chaletId) {
    return state.any((chalet) => chalet.id == chaletId);
  }

  void toggleFavorite(ChaletModel chalet) {
    if (isFavorite(chalet.id)) {
      state = state.where((item) => item.id != chalet.id).toList();
    } else {
      state = [...state, chalet];
    }
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<ChaletModel>>(
  (ref) => FavoritesNotifier(),
);
