import 'package:flutter/foundation.dart';
import '../models/movie.dart';
import '../services/api_service.dart';

/// Cache da conta atual. O servidor é a fonte dos favoritos persistidos.
class FavoritesProvider extends ChangeNotifier {
  final ApiService api;
  final Map<String, Movie> _movies = {};
  int _version;
  bool busy = false;
  FavoritesProvider(this.api) : _version = api.sessionVersion {
    api.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (_version == api.sessionVersion) return;
    _version = api.sessionVersion;
    _movies.clear();
    busy = false;
    notifyListeners();
  }

  int get count => _movies.length;
  List<Movie> get movies => List.unmodifiable(_movies.values);
  bool isFavorite(Movie movie) => _movies.containsKey(movie.id);

  Future<void> load() async {
    final version = api.sessionVersion;
    final movies = await api.fetchFavorites();
    if (version != api.sessionVersion) return;
    _movies
      ..clear()
      ..addEntries(movies.map((m) => MapEntry(m.id, m)));
    notifyListeners();
  }

  Future<void> setFavorite(Movie movie, bool value) async {
    if (busy || isFavorite(movie) == value) return;
    final version = api.sessionVersion;
    busy = true;
    notifyListeners();
    try {
      await api.setFavorite(movie, value);
      if (version != api.sessionVersion) return;
      if (value) {
        _movies[movie.id] = movie;
      } else {
        _movies.remove(movie.id);
      }
    } finally {
      if (version == api.sessionVersion) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleFavorite(Movie movie) =>
      setFavorite(movie, !isFavorite(movie));

  @override
  void dispose() {
    api.removeListener(_sessionChanged);
    super.dispose();
  }
}
