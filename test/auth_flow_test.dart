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
      'login opens protected list; 401 clears stack and returns to login',
      (tester) async {
    final store = MemoryTokens();
    var expired = false;
    final api = ApiService(
        baseUrl: 'https://api.example.test',
        tokens: store,
        client: MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(jsonEncode({'access_token': testToken}), 200);
          }
          return expired
              ? http.Response('', 401)
              : http.Response(
                  '[{"title":"Cinema","year":2026,"rating":9}]', 200);
        }));
    await tester.pumpWidget(CinePocketApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).first, 'user@example.test');
    await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Cinema'), findsOneWidget);
    expect(find.text('Ano: 2026'), findsOneWidget);
    expect(find.text('Nota: 9.0'), findsOneWidget);
    expired = true;
    await tester.tap(find.byTooltip('Atualizar'));
    await tester.pumpAndSettle();
    expect(store.value, isNull);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Sessão expirada. Entre novamente.'), findsOneWidget);
    expect(find.text('Cinema'), findsNothing);
    expect(Navigator.of(tester.element(find.text('Entrar'))).canPop(), isFalse);
  });
  testWidgets('failed storage write keeps user on login and permits retry',
      (tester) async {
    final store = MemoryTokens()..failWrite = true;
    final api = ApiService(
        baseUrl: 'https://api.example.test',
        tokens: store,
        client: MockClient((_) async =>
            http.Response(jsonEncode({'access_token': testToken}), 200)));
    await tester.pumpWidget(CinePocketApp(api: api));
    await tester.enterText(
        find.byType(TextFormField).first, 'user@example.test');
    await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
