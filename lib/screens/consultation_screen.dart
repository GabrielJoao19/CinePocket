import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/movie.dart';
import '../navigation/route_names.dart';
import '../providers/favorites_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';

/// A consulta protegida é a tela principal após login/restauração da sessão.
class ConsultationScreen extends StatefulWidget {
  final bool initialFavorites;
  const ConsultationScreen({super.key, this.initialFavorites = false});
  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  List<Movie> _movies = [];
  String? _error;
  bool _busy = true;
  late bool _favoritesOnly = widget.initialFavorites;
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _movies = [];
    });
    try {
      final api = context.read<ApiService>();
      // A identidade exibida vem do servidor, nunca de um perfil fixo/local.
      await api.fetchMe();
      final movies = await api.fetchMovies(query: _query.text.trim());
      if (!mounted) return;
      await context.read<FavoritesProvider>().load();
      if (mounted) setState(() => _movies = movies);
    } on SessionExpired {
      // Redirecionamento global feito pelo ApiService.
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearSearch() {
    _query.clear();
    _load();
  }

  Future<void> _toggle(Movie movie) async {
    try {
      await context.read<FavoritesProvider>().toggleFavorite(movie);
    } on SessionExpired {
      // O callback global remove as telas da sessão e abre o login.
    } on ApiFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
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
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.login, (_) => false,
          arguments: message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final user = context.read<ApiService>().currentUser;
    final visible = _favoritesOnly ? favorites.movies : _movies;
    return Scaffold(
      appBar: AppBar(title: const Text('CinePocket · Filmes'), actions: [
        IconButton(
            onPressed: _busy || favorites.busy ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar'),
        IconButton(
            onPressed: _busy || favorites.busy ? null : _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Sair'),
      ]),
      body: Column(children: [
        if (user != null)
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border)),
            child: ListTile(
              leading:
                  const Icon(Icons.verified_user, color: AppColors.yellow),
              title: Text('${user.name} · ${user.email}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Sessão no armazenamento seguro. Favoritos exclusivos desta conta.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        if (!_favoritesOnly)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _query,
                builder: (_, value, __) => TextField(
                  controller: _query,
                  enabled: !_busy,
                  decoration: InputDecoration(
                      labelText: 'Buscar filmes...',
                      border: const OutlineInputBorder(),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (value.text.isNotEmpty)
                            IconButton(
                                onPressed: _busy || favorites.busy
                                    ? null
                                    : _clearSearch,
                                icon: const Icon(Icons.clear),
                                tooltip: 'Limpar busca'),
                          IconButton(
                              onPressed:
                                  _busy || favorites.busy ? null : _load,
                              icon: const Icon(Icons.search),
                              tooltip: 'Buscar'),
                        ],
                      )),
                  onSubmitted: (_) => _load(),
                ),
              )),
        Expanded(
            child: _busy
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cloud_off,
                                      size: 40, color: AppColors.textSecondary),
                                  const SizedBox(height: 12),
                                  Text(_error!, textAlign: TextAlign.center),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                      onPressed: _load,
                                      child: const Text('Tentar novamente'))
                                ])))
                    : visible.isEmpty
                        ? Center(
                            child: Text(_favoritesOnly
                                ? 'Nenhum favorito nesta conta.'
                                : 'Nenhum filme encontrado.'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: visible.length,
                              itemBuilder: (_, index) {
                                final movie = visible[index];
                                final isFav = favorites.isFavorite(movie);
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  color: AppColors.surface,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(
                                          color: AppColors.border)),
                                  child: ListTile(
                                    title: Text(movie.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    subtitle: Text(
                                        'Ano: ${movie.year}\nNota: ${movie.rating}\nDireção: ${movie.director}'),
                                    isThreeLine: true,
                                    trailing: IconButton(
                                      tooltip: isFav
                                          ? 'Remover dos favoritos'
                                          : 'Adicionar aos favoritos',
                                      onPressed: favorites.busy
                                          ? null
                                          : () => _toggle(movie),
                                      icon: Icon(
                                        isFav
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: isFav
                                            ? AppColors.heart
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                    onTap: () => Navigator.of(context)
                                        .pushNamed(RouteNames.details,
                                            arguments: movie),
                                  ),
                                );
                              },
                            ))),
      ]),
      bottomNavigationBar: NavigationBar(
          selectedIndex: _favoritesOnly ? 1 : 0,
          onDestinationSelected: (index) {
            if (_busy || favorites.busy) return;
            setState(() => _favoritesOnly = index == 1);
            if (!_busy) _load();
          },
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.movie), label: 'Filmes'),
            NavigationDestination(
                icon: const Icon(Icons.favorite),
                label: 'Meus favoritos (${favorites.count})'),
          ]),
    );
  }
}
