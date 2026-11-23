import '../models/movie.dart';
import 'api_service.dart';

/// Toda consulta do aplicativo passa pela API própria e exige o JWT da conta.
class FilmService {
  final ApiService api;
  FilmService(this.api);
  Future<List<Movie>> fetchFilms({String query = ''}) =>
      api.fetchMovies(query: query);
}
