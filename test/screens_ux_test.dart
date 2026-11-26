import 'dart:convert';
import 'package:cinepocket/main.dart';
import 'package:cinepocket/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'api_service_test.dart' show MemoryTokens, testToken;

const _moviePayload = {
  'id': 'film-1',
  'title': 'Castle in the Sky',
  'original_title': '天空の城ラピュタ',
  'year': 1986,
  'rating': 9.5,
  'director': 'Hayao Miyazaki',
  'duration': '124 min',
  'description': 'A flying castle.',
  'genres': ['Animação'],
};

http.Response _jsonResponse(Object data, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  testWidgets(
      'register screen creates account, pops to login, and login clears snackbar',
      (tester) async {
    final store = MemoryTokens();
    final api = ApiService(
        baseUrl: 'https://api.example.test',
        tokens: store,
        client: MockClient((request) async {
          if (request.url.path == '/auth/register') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['name'], 'Alice');
            expect(body['email'], 'alice@example.test');
            return _jsonResponse(
                {'id': 'u1', 'name': 'Alice', 'email': 'alice@example.test'},
                201);
          }
          if (request.url.path == '/auth/login') {
            return _jsonResponse({'access_token': testToken});
          }
          if (request.url.path == '/me') {
            return _jsonResponse(
                {'id': 'u1', 'name': 'Alice', 'email': 'alice@example.test'});
          }
          if (request.url.path == '/favorites') return _jsonResponse([]);
          return _jsonResponse([_moviePayload]);
        }));

    await tester.pumpWidget(CinePocketApp(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Alice');
    await tester.enterText(fields.at(1), 'alice@example.test');
    await tester.enterText(fields.at(2), 'senha-segura-123');
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Conta criada. Entre com seu e-mail e senha.'),
        findsOneWidget);

    await tester.enterText(
        find.byType(TextFormField).first, 'alice@example.test');
    await tester.enterText(find.byType(TextFormField).last, 'senha-segura-123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Castle in the Sky'), findsOneWidget);
    expect(find.text('Conta criada. Entre com seu e-mail e senha.'),
        findsNothing);
  });

  testWidgets('register screen displays conflict error (409) and stays on form',
      (tester) async {
    final api = ApiService(
        baseUrl: 'https://api.example.test',
        tokens: MemoryTokens(),
        client: MockClient((_) async => http.Response('', 409)));

    await tester.pumpWidget(CinePocketApp(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Alice');
    await tester.enterText(fields.at(1), 'alice@example.test');
    await tester.enterText(fields.at(2), 'senha-segura-123');
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail já cadastrado.'), findsOneWidget);
    expect(find.text('Cadastrar'), findsOneWidget);
  });

  testWidgets('movie details screen displays metadata and toggles favorite',
      (tester) async {
    final store = MemoryTokens()..value = testToken;
    var fav = false;
    final api = ApiService(
        baseUrl: 'https://api.example.test',
        tokens: store,
        client: MockClient((request) async {
          if (request.url.path == '/me') {
            return _jsonResponse(
                {'id': 'u1', 'name': 'Alice', 'email': 'alice@example.test'});
          }
          if (request.url.path == '/favorites' && request.method == 'POST') {
            fav = true;
            return http.Response('', 204);
          }
          if (request.url.path == '/favorites/film-1' &&
              request.method == 'DELETE') {
            fav = false;
            return http.Response('', 204);
          }
          if (request.url.path == '/favorites') {
            return _jsonResponse(fav ? [_moviePayload] : []);
          }
          return _jsonResponse([_moviePayload]);
        }));

    await tester.pumpWidget(CinePocketApp(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Castle in the Sky'));
    await tester.pumpAndSettle();

    expect(find.text('天空の城ラピュタ'), findsOneWidget);
    expect(find.text('Duração: 124 min'), findsOneWidget);
    expect(find.text('Animação'), findsOneWidget);
    expect(find.text('A flying castle.'), findsOneWidget);

    await tester.tap(find.text('Adicionar aos favoritos'));
    await tester.pumpAndSettle();

    expect(find.text('Remover dos favoritos'), findsOneWidget);
    expect(find.text('Filme salvo nos favoritos da sua conta.'), findsOneWidget);
  });

  testWidgets(
      'consultation screen clear search button resets query and reloads movies',
      (tester) async {
    final store = MemoryTokens()..value = testToken;
    final queries = <String?>[];
    final api = ApiService(
        baseUrl: 'https://api.example.test',
        tokens: store,
        client: MockClient((request) async {
          if (request.url.path == '/me') {
            return _jsonResponse(
                {'id': 'u1', 'name': 'Alice', 'email': 'alice@example.test'});
          }
          if (request.url.path == '/favorites') return _jsonResponse([]);
          if (request.url.path == '/movies') {
            queries.add(request.url.queryParameters['q']);
            return _jsonResponse([_moviePayload]);
          }
          return _jsonResponse([]);
        }));

    await tester.pumpWidget(CinePocketApp(api: api));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Limpar busca'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Castle');
    await tester.pump();

    expect(find.byTooltip('Limpar busca'), findsOneWidget);
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    expect(queries.last, 'Castle');

    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    expect(queries.last, isNull);
    expect(find.byTooltip('Limpar busca'), findsNothing);
  });
}
