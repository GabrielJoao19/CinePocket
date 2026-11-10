import 'package:flutter/foundation.dart';
import '../models/movie.dart';

/// Fonte única dos favoritos da sessão. Não persiste após reiniciar o app.
class FavoritesProvider extends ChangeNotifier {
  final Map<String, Movie> _movies = {
    for (final movie in favoriteMovies) movie.title: movie,
  };

  int get count => _movies.length;
  List<Movie> get movies => List.unmodifiable(_movies.values);
  bool isFavorite(Movie movie) => _movies.containsKey(movie.title);

  void setFavorite(Movie movie, bool value) {
    if (isFavorite(movie) == value) return;
    if (value) {
      _movies[movie.title] = movie;
    } else {
      _movies.remove(movie.title);
    }
    notifyListeners();
  }

  void toggleFavorite(Movie movie) => setFavorite(movie, !isFavorite(movie));
}
