import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../screens/favorites_screen.dart';
import '../screens/home_screen.dart';
import '../screens/movie_details_screen.dart';
import '../screens/search_screen.dart';
import 'route_names.dart';

class TabRoutes {
  static const int home = 0;
  static const int search = 1;
  static const int favorites = 2;

  static Route<dynamic> generate(RouteSettings settings, int tabIndex) {
    debugPrint(
      'ROTA: aba=$tabIndex | nome=${settings.name} | arguments=${settings.arguments}',
    );

    switch (settings.name) {
      case RouteNames.tabRoot:
        debugPrint('ROOT: abrindo raiz da aba $tabIndex');

        return _page(
          settings,
          _rootFor(tabIndex),
        );

      case RouteNames.details:
        final args = settings.arguments;
        final movie = args is Movie ? args : featuredMovies.first;

        debugPrint(
          'PUSH: abrindo detalhes do filme "${movie.title}" na aba $tabIndex',
        );

        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => MovieDetailsScreen(movie: movie),
        );

      default:
        debugPrint(
          'ERRO: rota desconhecida "${settings.name}" na aba $tabIndex',
        );

        return _page(
          settings,
          Scaffold(
            appBar: AppBar(
              title: const Text('Rota desconhecida'),
            ),
            body: Center(
              child: Text(
                'Sem rota para "${settings.name}"',
              ),
            ),
          ),
        );
    }
  }

  static Widget _rootFor(int tabIndex) {
    switch (tabIndex) {
      case search:
        return const SearchScreen();

      case favorites:
        return const FavoritesScreen();

      case home:
      default:
        return const HomeScreen();
    }
  }

  static MaterialPageRoute<dynamic> _page(
      RouteSettings s,
      Widget child,
      ) {
    return MaterialPageRoute<dynamic>(
      settings: s,
      builder: (_) => child,
    );
  }
}