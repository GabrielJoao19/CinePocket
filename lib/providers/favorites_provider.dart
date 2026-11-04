import 'package:flutter/foundation.dart';

import '../models/movie.dart';

/// Mantém os favoritos da sessão enquanto a API e a persistência não existem.
class FavoritesProvider extends ChangeNotifier {
  final Set<String> _favoriteTitles =
      favoriteMovies.map((movie) => movie.title).toSet();

  int get count => _favoriteTitles.length;

  bool isFavorite(Movie movie) => _favoriteTitles.contains(movie.title);

  void toggleFavorite(Movie movie) {
    if (isFavorite(movie)) {
      _favoriteTitles.remove(movie.title);
    } else {
      _favoriteTitles.add(movie.title);
    }
    notifyListeners();
  }
}