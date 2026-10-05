import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../screens/favorites_screen.dart';
import '../screens/home_screen.dart';
import '../screens/movie_details_screen.dart';
import '../screens/search_screen.dart';
import 'route_names.dart';

/// Rotas INTERNAS das abas. Cada aba tem seu próprio Navigator, e todos
/// usam este mesmo gerador (centralizado), variando só a tela raiz.
class TabRoutes {
  static const int home = 0;
  static const int search = 1;
  static const int favorites = 2;

  static Route<dynamic> generate(RouteSettings settings, int tabIndex) {
    switch (settings.name) {
      case RouteNames.tabRoot:
        return _page(settings, _rootFor(tabIndex));

      case RouteNames.details:
        // Leitura dos ARGUMENTS passados em pushNamed(..., arguments: movie)
        final args = settings.arguments;
        final movie = args is Movie ? args : featuredMovies.first;
        return _page(settings, MovieDetailsScreen(movie: movie));

      default:
        return _page(
          settings,
          Scaffold(
            appBar: AppBar(title: const Text('Rota desconhecida')),
            body: Center(child: Text('Sem rota para "${settings.name}"')),
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

  // `settings` precisa ser repassado para a rota guardar nome e arguments.
  static MaterialPageRoute<dynamic> _page(RouteSettings s, Widget child) {
    return MaterialPageRoute<dynamic>(settings: s, builder: (_) => child);
  }
}
