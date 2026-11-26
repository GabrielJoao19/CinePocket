import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/movie.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiFailure implements Exception {
  final String message;
  const ApiFailure(this.message);
  @override
  String toString() => message;
}

class SessionExpired extends ApiFailure {
  const SessionExpired([super.message = 'Sessão expirada. Entre novamente.']);
}

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  final FlutterSecureStorage storage;
  SecureTokenStore({this.storage = const FlutterSecureStorage()});
  static const _key = 'cinepocket_access_token';
  @override
  Future<String?> read() => storage.read(key: _key);
  @override
  Future<void> write(String token) => storage.write(key: _key, value: token);
  @override
  Future<void> delete() => storage.delete(key: _key);
}

class SessionUser {
  final String id;
  final String name;
  final String email;
  const SessionUser(this.id, this.name, this.email);
  factory SessionUser.fromJson(dynamic json) {
    if (json is! Map<String, dynamic> ||
        [
          'id',
          'name',
          'email'
        ].any((key) => json[key] is! String || (json[key] as String).isEmpty)) {
      throw const FormatException();
    }
    return SessionUser(json['id'], json['name'], json['email']);
  }
}

class ApiService extends ChangeNotifier {
  SessionUser? currentUser;
  int sessionVersion = 0;
  void Function(String message)? onSessionExpired;
  final http.Client client;
  final TokenStore tokens;
  final String baseUrl;
  final String loginPath;
  final String moviesPath;
  final Duration timeout;
  // A failed deletion must never allow the old token to be reused in this process.
  bool _blocked = false;

  ApiService({
    http.Client? client,
    TokenStore? tokens,
    this.baseUrl = const String.fromEnvironment('API_BASE_URL',
        defaultValue: 'https://localhost:8443'),
    this.loginPath = const String.fromEnvironment('API_LOGIN_PATH',
        defaultValue: '/auth/login'),
    this.moviesPath = const String.fromEnvironment('API_MOVIES_PATH',
        defaultValue: '/movies'),
    this.timeout = const Duration(seconds: 15),
  })  : client = client ?? http.Client(),
        tokens = tokens ?? SecureTokenStore();

  Future<bool> hasSession() async {
    if (_blocked) return false;
    try {
      final token = await tokens.read();
      return token != null && token.isNotEmpty;
    } on Exception {
      throw const ApiFailure(
          'Não foi possível ler o armazenamento seguro. Tente novamente.');
    }
  }

  Uri _endpoint(String path) {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        !path.startsWith('/') ||
        path.startsWith('//')) {
      throw const ApiFailure('Configure uma API HTTPS válida para continuar.');
    }
    final uri =
        Uri.tryParse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path');
    if (uri == null || uri.origin != base.origin || uri.hasFragment) {
      throw const ApiFailure('Endpoint da API inválido.');
    }
    return uri;
  }

  Future<http.Response> _request(String method, String path,
      {String? token, Map<String, dynamic>? body}) async {
    final request = http.Request(method, _endpoint(path))
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      return await (() async {
        final response = await client.send(request);
        return http.Response.fromStream(response);
      })()
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiFailure('Tempo de conexão esgotado. Tente novamente.');
    } on Exception {
      throw const ApiFailure(
          'Servidor indisponível. Verifique sua conexão e tente novamente.');
    }
  }

  dynamic _json(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiFailure('A API retornou uma resposta JSON inválida.');
    }
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode >= 500) {
      throw const ApiFailure(
          'Servidor indisponível. Tente novamente mais tarde.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFailure(
          'Não foi possível concluir a requisição (${response.statusCode}).');
    }
  }

  Future<void> login(String email, String password) async {
    final response = await _request('POST', loginPath,
        body: {'email': email, 'password': password});
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ApiFailure('E-mail ou senha inválidos.');
    }
    _checkStatus(response);
    final json = _json(response);
    final token = json is Map<String, dynamic> ? json['access_token'] : null;
    if (token is! String ||
        token.isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$')
            .hasMatch(token)) {
      throw const ApiFailure('A API não retornou um JWT Access Token válido.');
    }
    try {
      await tokens.write(token);
      _blocked = false;
      currentUser = null;
      sessionVersion++;
      notifyListeners();
    } on Exception {
      _blocked = true;
      throw const ApiFailure(
          'Não foi possível salvar a sessão no armazenamento seguro. Tente entrar novamente.');
    }
  }

  Future<void> logout() async {
    _blocked = true;
    currentUser = null;
    sessionVersion++;
    notifyListeners();
    try {
      await tokens.delete();
    } on Exception {
      throw const ApiFailure(
          'Não foi possível remover a sessão do armazenamento seguro. Tente novamente.');
    }
  }

  Future<http.Response> _authorizedRequest(String method, String path,
      {Map<String, dynamic>? body}) async {
    final version = sessionVersion;
    if (_blocked) throw const SessionExpired();
    String? token;
    try {
      token = await tokens.read();
    } on Exception {
      throw const ApiFailure(
          'Não foi possível ler o armazenamento seguro. Tente novamente.');
    }
    if (token == null || token.isEmpty) {
      onSessionExpired?.call('Sessão ausente. Entre novamente.');
      throw const SessionExpired('Sessão ausente. Entre novamente.');
    }
    if (version != sessionVersion) throw const SessionExpired();
    final response = await _request(method, path, token: token, body: body);
    if (version != sessionVersion) throw const SessionExpired();
    if (response.statusCode == 401) {
      String message = 'Sessão expirada. Entre novamente.';
      try {
        await logout();
      } on ApiFailure {
        message =
            'Sessão expirada. Falha ao remover o token do armazenamento seguro. Entre novamente ou tente limpar a sessão.';
      }
      onSessionExpired?.call(message);
      throw SessionExpired(message);
    }
    _checkStatus(response);
    return response;
  }

  Future<void> register(String name, String email, String password) async {
    final response = await _request('POST', '/auth/register',
        body: {'name': name, 'email': email, 'password': password});
    if (response.statusCode == 409) {
      throw const ApiFailure('E-mail já cadastrado.');
    }
    if (response.statusCode == 422) {
      throw const ApiFailure(
          'Confira o nome, e-mail e a senha (mínimo de 8 caracteres).');
    }
    _checkStatus(response);
    try {
      SessionUser.fromJson(_json(response));
    } on FormatException {
      throw const ApiFailure('A API retornou dados de cadastro inválidos.');
    }
  }

  Future<SessionUser> fetchMe() async {
    final response = await _authorizedRequest('GET', '/me');
    try {
      final user = SessionUser.fromJson(_json(response));
      currentUser = user;
      return user;
    } on FormatException {
      throw const ApiFailure('A API retornou dados de usuário inválidos.');
    }
  }

  Future<List<Movie>> _movieList(String path) async {
    final response = await _authorizedRequest('GET', path);
    final json = _json(response);
    try {
      if (json is! List) throw const FormatException();
      return json.map(Movie.fromJson).toList();
    } on FormatException {
      throw const ApiFailure('A API retornou dados de filmes inválidos.');
    }
  }

  Future<List<Movie>> fetchMovies({String query = ''}) =>
      _movieList(query.isEmpty
          ? moviesPath
          : '$moviesPath?q=${Uri.encodeQueryComponent(query)}');
  Future<List<Movie>> fetchFavorites() => _movieList('/favorites');

  Future<void> setFavorite(Movie movie, bool value) async {
    if (movie.id.isEmpty) {
      throw const ApiFailure('Filme sem identificação no catálogo.');
    }
    await _authorizedRequest(value ? 'POST' : 'DELETE',
        value ? '/favorites' : '/favorites/${Uri.encodeComponent(movie.id)}',
        body: value ? {'movie_id': movie.id} : null);
  }

  void close() => client.close();
}
