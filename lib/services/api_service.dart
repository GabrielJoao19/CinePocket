import 'dart:async';
import 'dart:convert';
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

class ProtectedMovie {
  final String title;
  final int year;
  final double rating;
  const ProtectedMovie(this.title, this.year, this.rating);

  factory ProtectedMovie.fromJson(dynamic json) {
    if (json is! Map<String, dynamic> ||
        json['title'] is! String ||
        (json['title'] as String).trim().isEmpty ||
        json['year'] is! int ||
        json['rating'] is! num) {
      throw const FormatException('Invalid movie');
    }
    return ProtectedMovie(
        json['title'], json['year'], (json['rating'] as num).toDouble());
  }
}

class ApiService {
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
    this.baseUrl = const String.fromEnvironment('API_BASE_URL'),
    this.loginPath = const String.fromEnvironment('API_LOGIN_PATH',
        defaultValue: '/auth/login'),
    this.moviesPath = const String.fromEnvironment('API_MOVIES_PATH',
        defaultValue: '/movies'),
    this.timeout = const Duration(seconds: 15),
  })  : client = client ?? http.Client(),
        tokens = tokens ?? SecureTokenStore();

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
      {String? token, Map<String, String>? body}) async {
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
    } on Exception {
      _blocked = true;
      throw const ApiFailure(
          'Não foi possível salvar a sessão no armazenamento seguro. Tente entrar novamente.');
    }
  }

  Future<void> logout() async {
    _blocked = true;
    try {
      await tokens.delete();
    } on Exception {
      throw const ApiFailure(
          'Não foi possível remover a sessão do armazenamento seguro. Tente novamente.');
    }
  }

  Future<List<ProtectedMovie>> fetchMovies() async {
    if (_blocked) throw const SessionExpired();
    String? token;
    try {
      token = await tokens.read();
    } on Exception {
      throw const ApiFailure(
          'Não foi possível ler o armazenamento seguro. Tente novamente.');
    }
    if (token == null || token.isEmpty) throw const SessionExpired();
    final response = await _request('GET', moviesPath, token: token);
    if (response.statusCode == 401) {
      try {
        await logout();
      } on ApiFailure {
        throw const SessionExpired(
            'Sessão expirada. Falha ao remover o token do armazenamento seguro. Entre novamente ou tente limpar a sessão.');
      }
      throw const SessionExpired();
    }
    _checkStatus(response);
    final json = _json(response);
    try {
      if (json is! List) throw const FormatException('Expected list');
      return json.map(ProtectedMovie.fromJson).toList();
    } on FormatException {
      throw const ApiFailure('A API retornou dados de filmes inválidos.');
    }
  }

  void close() => client.close();
}
