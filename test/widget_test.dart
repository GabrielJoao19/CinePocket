import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cinepocket/providers/favorites_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinepocket/main.dart';
import 'package:cinepocket/theme.dart';

Widget catalogApp() =>
    MaterialApp(theme: buildAppTheme(), home: const MainShell());

void main() {
  testWidgets('Test clicking on movie details and returning',
      (WidgetTester tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => FavoritesProvider(), child: catalogApp()));
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

  testWidgets('Test navigation between tabs and drawer',
      (WidgetTester tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => FavoritesProvider(), child: catalogApp()));
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
  testWidgets('Favoritos compartilham alterações entre detalhes e lista',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final favorites = FavoritesProvider();
    await tester.pumpWidget(
        ChangeNotifierProvider.value(value: favorites, child: catalogApp()));
    await tester.pumpAndSettle();
    final initialCount = favorites.count;
    await tester.tap(find.text('Duna: Parte 2').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Adicionar aos Favoritos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar aos Favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Nos Favoritos'), findsOneWidget);
    expect(favorites.count, initialCount + 1);
    Navigator.of(tester.element(find.text('Nos Favoritos'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoritos'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Duna: Parte 2'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Duna: Parte 2'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Remover dos favoritos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remover dos favoritos').last);
    await tester.pumpAndSettle();
    expect(favorites.count, initialCount);
    expect(find.text('Duna: Parte 2'), findsNothing);
  });
}
