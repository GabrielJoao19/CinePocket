import 'dart:convert';
import 'package:cinepocket/models/movie.dart';
import 'package:cinepocket/providers/favorites_provider.dart';
import 'package:cinepocket/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'api_service_test.dart' show MemoryTokens, testToken;

const filmJson = {
  'id': 'film-1',
  'title': 'Castle in the Sky',
  'year': 1986,
  'rating': 9.5,
  'director': 'Hayao Miyazaki'
};

void main() {
  test(
      'favorites use stored Bearer; request cannot choose owner; logout clears cache',
      () async {
    final store = MemoryTokens()..value = testToken;
    var saved = false;
    final api = ApiService(
        tokens: store,
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer $testToken');
          if (request.method == 'POST') {
            expect(jsonDecode(request.body), {'movie_id': 'film-1'});
            saved = true;
            return http.Response('', 204);
          }
          if (request.method == 'DELETE') {
            saved = false;
            return http.Response('', 204);
          }
          expect(request.url.path, '/favorites');
          return http.Response(jsonEncode(saved ? [filmJson] : []), 200);
        }));
    final favorites = FavoritesProvider(api);
    expect(favorites.movies, isEmpty);
    await favorites.load();
    final movie = Movie.fromJson(filmJson);
    await favorites.setFavorite(movie, true);
    expect(favorites.isFavorite(movie), isTrue);
    await favorites.load();
    expect(favorites.movies.single.title, 'Castle in the Sky');
    await api.logout();
    expect(favorites.movies, isEmpty);
    expect(api.currentUser, isNull);
    favorites.dispose();
    api.close();
    api.dispose();
  });

  test(
      '401 on favorite mutation clears account cache and triggers global redirect',
      () async {
    final store = MemoryTokens()..value = testToken;
    var expired = false;
    var redirects = 0;
    final api = ApiService(
        tokens: store,
        baseUrl: 'https://api.example.test',
        client: MockClient((_) async => expired
            ? http.Response('', 401)
            : http.Response(jsonEncode([filmJson]), 200)));
    api.onSessionExpired = (_) => redirects++;
    final favorites = FavoritesProvider(api);
    await favorites.load();
    expired = true;
    await expectLater(favorites.setFavorite(Movie.fromJson(filmJson), false),
        throwsA(isA<SessionExpired>()));
    expect(store.value, isNull);
    expect(favorites.movies, isEmpty);
    expect(redirects, 1);
    favorites.dispose();
    api.close();
    api.dispose();
  });

  test('failed write on server does not change local favorites', () async {
    final store = MemoryTokens()..value = testToken;
    final api = ApiService(
        tokens: store,
        baseUrl: 'https://api.example.test',
        client: MockClient((_) async => http.Response('', 503)));
    final favorites = FavoritesProvider(api);
    await expectLater(favorites.setFavorite(Movie.fromJson(filmJson), true),
        throwsA(isA<ApiFailure>()));
    expect(favorites.count, 0);
    expect(favorites.busy, isFalse);
    favorites.dispose();
    api.close();
    api.dispose();
  });

  test('movie search is sent to protected server endpoint', () async {
    final api = ApiService(
        tokens: MemoryTokens()..value = testToken,
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          expect(request.url.path, '/movies');
          expect(request.url.queryParameters['q'], 'Castle & Sky');
          expect(request.headers['Authorization'], 'Bearer $testToken');
          return http.Response(jsonEncode([filmJson]), 200);
        }));
    expect((await api.fetchMovies(query: 'Castle & Sky')).single.year, 1986);
    api.close();
    api.dispose();
  });
}
