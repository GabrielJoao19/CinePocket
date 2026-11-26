import 'dart:convert';
import 'package:cinepocket/main.dart';
import 'package:cinepocket/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'api_service_test.dart' show MemoryTokens, testToken;

void main() {
  testWidgets(
      'switching accounts isolates favorites and restores saved collection on next login',
      (tester) async {
    final store = MemoryTokens();
    var owner = '';
    final collections = <String, bool>{'alice': false, 'bob': false};
    const movie = {
      'id': 'film-1',
      'title': 'Castle in the Sky',
      'year': 1986,
      'rating': 9.5
    };
    final api = ApiService(
        baseUrl: 'https://api.example.test',
        tokens: store,
        client: MockClient((request) async {
          if (request.url.path == '/auth/login') {
            owner =
                (jsonDecode(request.body)['email'] as String).split('@').first;
            return http.Response(jsonEncode({'access_token': testToken}), 200);
          }
          if (request.url.path == '/me') {
            return http.Response(
                jsonEncode({
                  'id': owner,
                  'name': owner,
                  'email': '$owner@example.test'
                }),
                200);
          }
          if (request.url.path == '/favorites') {
            if (request.method == 'POST') {
              collections[owner] = true;
              return http.Response('', 204);
            }
            return http.Response(
                jsonEncode(collections[owner]! ? [movie] : []), 200);
          }
          return http.Response(jsonEncode([movie]), 200);
        }));
    await tester.pumpWidget(CinePocketApp(api: api));
    Future<void> login(String name) async {
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField).first, '$name@example.test');
      await tester.enterText(find.byType(TextFormField).last, 'password');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
    }

    await login('alice');
    await tester.tap(find.byTooltip('Adicionar aos favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Meus favoritos (1)'), findsOneWidget);
    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();
    await login('bob');
    expect(find.text('Meus favoritos (0)'), findsOneWidget);
    await tester.tap(find.text('Meus favoritos (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum favorito nesta conta.'), findsOneWidget);
    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();
    await login('alice');
    expect(find.text('Meus favoritos (1)'), findsOneWidget);
  });
}
