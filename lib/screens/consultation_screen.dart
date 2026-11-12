import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../navigation/route_names.dart';
import '../services/api_service.dart';

class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({super.key});
  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  List<ProtectedMovie> _movies = [];
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _login(String? message) {
    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        RouteNames.login, (_) => false,
        arguments: message);
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
      _movies = [];
    });
    try {
      final movies = await context.read<ApiService>().fetchMovies();
      if (mounted) setState(() => _movies = movies);
    } on SessionExpired catch (error) {
      if (mounted) _login(error.message);
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    String? message;
    try {
      await context.read<ApiService>().logout();
    } on ApiFailure catch (error) {
      message = error.message;
    }
    if (mounted) _login(message);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Filmes da API'), actions: [
          IconButton(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar'),
          IconButton(
              onPressed: _busy ? null : _logout,
              icon: const Icon(Icons.logout),
              tooltip: 'Sair'),
        ]),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: _load,
                              child: const Text('Tentar novamente')),
                        ])))
                : _movies.isEmpty
                    ? const Center(child: Text('Nenhum filme encontrado.'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _movies.length,
                            itemBuilder: (_, index) {
                              final movie = _movies[index];
                              return ListTile(
                                  title: Text(movie.title),
                                  subtitle: Text('Ano: ${movie.year}'),
                                  trailing: Text('Nota: ${movie.rating}'));
                            })),
        bottomNavigationBar: SafeArea(
            child: TextButton(
          onPressed: _busy
              ? null
              : () => Navigator.of(context).pushNamed(RouteNames.home),
          child: const Text('Explorar catálogo demonstrativo'),
        )),
      );
}
