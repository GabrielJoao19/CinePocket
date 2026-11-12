import 'dart:async';
import 'dart:convert';
import 'package:cinepocket/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryTokens implements TokenStore {
  String? value;
  bool failRead = false, failWrite = false, failDelete = false;
  @override
  Future<String?> read() async {
    if (failRead) throw Exception('storage');
    return value;
  }

  @override
  Future<void> write(String token) async {
    if (failWrite) throw Exception('storage');
    value = token;
  }

  @override
  Future<void> delete() async {
    if (failDelete) throw Exception('storage');
    value = null;
  }
}

const testToken = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl';
void main() {
  late MemoryTokens store;
  ApiService service(Future<http.Response> Function(http.Request) handler,
          {String url = 'https://api.example.test',
          Duration timeout = const Duration(seconds: 1)}) =>
      ApiService(
          client: MockClient(handler),
          tokens: store,
          baseUrl: url,
          timeout: timeout);
  setUp(() => store = MemoryTokens());
  test('login POST JSON saves JWT; GET reads storage and sends Bearer',
      () async {
    final api = service((request) async {
      expect(request.followRedirects, isFalse);
      if (request.method == 'POST') {
        expect(request.url.path, '/auth/login');
        expect(jsonDecode(request.body),
            {'email': 'user@example.test', 'password': 'secret'});
        expect(request.headers['Content-Type'], 'application/json');
        return http.Response(jsonEncode({'access_token': testToken}), 200);
      }
      expect(request.method, 'GET');
      expect(request.url.path, '/movies');
      expect(request.headers['Authorization'], 'Bearer $testToken');
      return http.Response('[{"title":"Filme","year":2026,"rating":8.5}]', 200);
    });
    await api.login('user@example.test', 'secret');
    expect(store.value, testToken);
    final movies = await api.fetchMovies();
    expect(movies.single.title, 'Filme');
    expect(movies.single.year, 2026);
    expect(movies.single.rating, 8.5);
  });
  test('invalid credentials are not stored', () async {
    final api = service((_) async => http.Response('', 401));
    await expectLater(
        api.login('a', 'b'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.message, 'message', contains('inválidos'))));
    expect(store.value, isNull);
  });
  test('401 deletes token and blocks further requests', () async {
    store.value = testToken;
    var calls = 0;
    final api = service((_) async {
      calls++;
      return http.Response('', 401);
    });
    await expectLater(api.fetchMovies(), throwsA(isA<SessionExpired>()));
    expect(store.value, isNull);
    await expectLater(api.fetchMovies(), throwsA(isA<SessionExpired>()));
    expect(calls, 1);
  });
  test('401 still expires session when secure deletion fails', () async {
    store.value = testToken;
    store.failDelete = true;
    var calls = 0;
    final api = service((_) async {
      calls++;
      return http.Response('', 401);
    });
    await expectLater(
        api.fetchMovies(),
        throwsA(isA<SessionExpired>().having(
            (e) => e.message, 'message', contains('Falha ao remover'))));
    await expectLater(api.fetchMovies(), throwsA(isA<SessionExpired>()));
    expect(calls, 1);
  });
  test('missing token does not reach API', () async {
    final api = service((_) async {
      fail('Unexpected request');
    });
    await expectLater(api.fetchMovies(), throwsA(isA<SessionExpired>()));
  });
  test('read and write storage errors are actionable', () async {
    store.failWrite = true;
    final api = service((_) async =>
        http.Response(jsonEncode({'access_token': testToken}), 200));
    await expectLater(
        api.login('a', 'b'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.message, 'message', contains('salvar'))));
    store.failRead = true;
    final other = service((_) async {
      fail('Unexpected request');
    });
    await expectLater(
        other.fetchMovies(),
        throwsA(isA<ApiFailure>()
            .having((e) => e.message, 'message', contains('ler'))));
  });
  test('logout deletes token', () async {
    store.value = testToken;
    final api = service((_) async => http.Response('[]', 200));
    await api.logout();
    expect(store.value, isNull);
    await expectLater(api.fetchMovies(), throwsA(isA<SessionExpired>()));
  });
  for (final body in ['not json', '{}', '[{"title":4}]']) {
    test('invalid movie payload: $body', () async {
      store.value = testToken;
      await expectLater(
          service((_) async => http.Response(body, 200)).fetchMovies(),
          throwsA(isA<ApiFailure>()));
    });
  }
  for (final body in [
    'not json',
    '{}',
    '{"access_token":""}',
    '{"access_token":42}'
  ]) {
    test('invalid login payload: $body', () async {
      await expectLater(
          service((_) async => http.Response(body, 200)).login('a', 'b'),
          throwsA(isA<ApiFailure>()));
      expect(store.value, isNull);
    });
  }
  test('empty list is valid', () async {
    store.value = testToken;
    expect(await service((_) async => http.Response('[]', 200)).fetchMovies(),
        isEmpty);
  });
  test('network failure', () async {
    await expectLater(
        service((_) async => throw http.ClientException('offline'))
            .login('a', 'b'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.message, 'message', contains('indisponível'))));
  });
  test('timeout', () async {
    await expectLater(
        service((_) => Completer<http.Response>().future,
                timeout: const Duration(milliseconds: 1))
            .login('a', 'b'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.message, 'message', contains('esgotado'))));
  });
  for (final status in [302, 403, 500, 503]) {
    test('GET status $status is not treated as data', () async {
      store.value = testToken;
      await expectLater(
          service((_) async => http.Response('[]', status)).fetchMovies(),
          throwsA(isA<ApiFailure>()));
      expect(store.value, testToken);
    });
  }
  for (final url in [
    '',
    'http://api.example.test',
    'https://user:password@api.example.test'
  ]) {
    test('reject insecure or invalid configuration: $url', () async {
      await expectLater(
          service((_) async {
            fail('Unexpected request');
          }, url: url)
              .login('a', 'b'),
          throwsA(isA<ApiFailure>()));
    });
  }
}
