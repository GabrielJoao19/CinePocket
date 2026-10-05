import 'package:flutter/material.dart';
import '../models/movie.dart';

/// Nomes de rotas centralizados (evita strings soltas pelo código).
class RouteNames {
  // --- Rotas RAIZ (Navigator do MaterialApp) ---
  static const login = '/login';
  static const home = '/home'; // contém Drawer + BottomNavigationBar
  static const settings = '/settings';

  // --- Rotas INTERNAS das abas (Navigator aninhado de cada aba) ---
  static const tabRoot = '/'; // tela inicial de cada aba
  static const details = '/details'; // recebe um Movie via arguments
}

/// Chave do Scaffold do shell: permite que as telas das abas (que têm seu
/// próprio Scaffold) abram o Drawer, que pertence ao Scaffold externo.
final GlobalKey<ScaffoldState> shellScaffoldKey = GlobalKey<ScaffoldState>();

/// Abre os detalhes de um filme na aba atual (push no Navigator da aba).
///
///  - ARGUMENTS: o filme vai em `arguments`.
///  - RESULTADO: a tela de detalhes devolve um `bool` (favoritado?) via
///    `Navigator.pop(context, valor)`, que chega aqui no `await`.
Future<void> openMovieDetails(BuildContext context, Movie movie) async {
  final result = await Navigator.of(context).pushNamed(
    RouteNames.details,
    arguments: movie,
  );

  if (result == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Resultado recebido: "${movie.title}" foi favoritado ♥'),
        behavior: SnackBarBehavior.floating,
      ));
  }
}
