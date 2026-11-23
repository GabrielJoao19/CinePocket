import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/movie.dart';
import '../providers/favorites_provider.dart';
import '../services/api_service.dart';

class MovieDetailsScreen extends StatelessWidget {
  final Movie movie;
  const MovieDetailsScreen({super.key, required this.movie});

  Future<void> _toggle(BuildContext context) async {
    try {
      await context.read<FavoritesProvider>().toggleFavorite(movie);
      if (!context.mounted) return;
      final saved = context.read<FavoritesProvider>().isFavorite(movie);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(saved
              ? 'Filme salvo nos favoritos da sua conta.'
              : 'Filme removido dos seus favoritos.')));
    } on SessionExpired {
      // O callback global remove as telas da sessão e abre o login.
    } on ApiFailure catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final saved = favorites.isFavorite(movie);
    return Scaffold(
      appBar: AppBar(title: Text(movie.title)),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Text(movie.title, style: Theme.of(context).textTheme.headlineMedium),
        if (movie.originalTitle.isNotEmpty) Text(movie.originalTitle),
        const SizedBox(height: 16),
        Text('Ano: ${movie.year}'),
        Text('Nota: ${movie.rating}'),
        Text('Direção: ${movie.director}'),
        Text('Duração: ${movie.duration}'),
        const SizedBox(height: 20),
        FilledButton.icon(
            onPressed: favorites.busy ? null : () => _toggle(context),
            icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
            label: Text(
                saved ? 'Remover dos favoritos' : 'Adicionar aos favoritos')),
        const SizedBox(height: 24),
        Text('Sinopse', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(movie.description.isEmpty
            ? 'Sinopse indisponível.'
            : movie.description),
      ]),
    );
  }
}
