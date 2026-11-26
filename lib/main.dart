import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'navigation/route_names.dart';
import 'models/movie.dart';
import 'providers/favorites_provider.dart';
import 'screens/login_screen.dart';
import 'screens/consultation_screen.dart';
import 'services/api_service.dart';
import 'screens/movie_details_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CinePocketApp());
}

class CinePocketApp extends StatefulWidget {
  final ApiService? api;
  const CinePocketApp({super.key, this.api});
  @override
  State<CinePocketApp> createState() => _CinePocketAppState();
}

class _CinePocketAppState extends State<CinePocketApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late final ApiService _api = widget.api ?? ApiService();
  late final FavoritesProvider _favorites = FavoritesProvider(_api);

  @override
  void initState() {
    super.initState();
    _api.onSessionExpired = (message) {
      _navigator.currentState?.pushNamedAndRemoveUntil(
          RouteNames.login, (_) => false,
          arguments: message);
    };
  }

  @override
  void dispose() {
    _api.onSessionExpired = null;
    _favorites.dispose();
    _api.close();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ApiService>.value(value: _api),
          ChangeNotifierProvider<FavoritesProvider>.value(value: _favorites),
        ],
        child: MaterialApp(
          navigatorKey: _navigator,
          title: 'CinePocket',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          initialRoute: RouteNames.login,
          onGenerateInitialRoutes: (_) =>
              [MaterialPageRoute(builder: (_) => const LoginScreen())],
          routes: {
            RouteNames.login: (context) => LoginScreen(
                message: ModalRoute.of(context)?.settings.arguments as String?),
            RouteNames.consultation: (_) => const ConsultationScreen(),
            RouteNames.home: (_) => const ConsultationScreen(),
            RouteNames.details: (context) {
              final movie = ModalRoute.of(context)!.settings.arguments;
              return movie is Movie
                  ? MovieDetailsScreen(movie: movie)
                  : const ConsultationScreen();
            },
          },
        ),
      );
}
