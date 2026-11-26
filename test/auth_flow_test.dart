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
      'login consults protected movies; 401 on favorites clears stack and data',
      (tester) async {
    final store = MemoryTokens();
    var expired = false;
    final api = ApiService(
        baseUrl: 'https://api.example.test',
        tokens: store,
        client: MockClient((request) async {
          if (request.url.path == '/auth/login') {
            return http.Response(jsonEncode({'access_token': testToken}), 200);
          }
          expect(request.headers['Authorization'], 'Bearer $testToken');
          if (expired) return http.Response('', 401);
          if (request.url.path == '/me') {
            return http.Response(
                '{"id":"alice","name":"Alice","email":"alice@example.test"}',
                200);
          }
          if (request.url.path == '/favorites') return http.Response('[]', 200);
          return http.Response(
              '[{"id":"film-1","title":"Cinema","year":2026,"rating":9}]', 200);
        }));
    await tester.pumpWidget(CinePocketApp(api: api));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'alice@example.test');
    await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Cinema'), findsOneWidget);
    expect(find.textContaining('Ano: 2026'), findsOneWidget);
    expect(find.textContaining('Alice · alice@example.test'), findsOneWidget);
    expired = true;
    await tester.tap(find.byTooltip('Adicionar aos favoritos'));
    await tester.pumpAndSettle();
    expect(store.value, isNull);
    expect(find.text('Sessão expirada. Entre novamente.'), findsOneWidget);
    expect(find.text('Cinema'), findsNothing);
    expect(find.textContaining('Alice ·'), findsNothing);
    expect(Navigator.of(tester.element(find.text('Entrar'))).canPop(), isFalse);
  });

  testWidgets('failed secure write stays on login', (tester) async {
    final store = MemoryTokens()..failWrite = true;
    final api = ApiService(
        baseUrl: 'https://api.example.test',
        tokens: store,
        client: MockClient((_) async =>
            http.Response(jsonEncode({'access_token': testToken}), 200)));
    await tester.pumpWidget(CinePocketApp(api: api));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'alice@example.test');
    await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
