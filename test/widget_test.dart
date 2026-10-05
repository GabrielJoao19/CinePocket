import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinepocket/main.dart';

void main() {
  testWidgets('Test clicking on movie details and returning', (WidgetTester tester) async {
    await tester.pumpWidget(const CinePocketApp());
    await tester.pumpAndSettle();

    // 1. Verifica se a Home foi carregada com os filmes
    expect(find.text('Duna: Parte 2'), findsWidgets);

    // 2. Clica no filme Duna: Parte 2
    await tester.tap(find.text('Duna: Parte 2').first);
    await tester.pumpAndSettle();

    // 3. Verifica se a tela de detalhes abriu com sucesso
    expect(find.text('Sinopse'), findsOneWidget);
    expect(find.text('Elenco Principal'), findsOneWidget);

    // 4. Clica no botão de voltar da tela de detalhes
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // 5. Verifica se voltou para a Home perfeitamente
    expect(find.text('Filmes em Destaque'), findsOneWidget);
  });

  testWidgets('Test navigation between tabs and drawer', (WidgetTester tester) async {
    await tester.pumpWidget(const CinePocketApp());
    await tester.pumpAndSettle();

    // 1. Troca para a aba Buscar (clicando no item da BottomNavigationBar)
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();

    expect(find.text('Buscar filmes...'), findsOneWidget);

    // 2. Troca para a aba Favoritos
    await tester.tap(find.text('Favoritos'));
    await tester.pumpAndSettle();

    expect(find.text('Meus Favoritos'), findsOneWidget);

    // 3. Abre o Drawer pelo ícone de menu
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // 4. Verifica itens do Drawer
    expect(find.text('Configurações'), findsOneWidget);
    expect(find.text('Sobre'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });
}
