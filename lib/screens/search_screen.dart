import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../navigation/route_names.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

/// Aba "Buscar": filtra os filmes por título. Cada toque faz push de
/// detalhes no Navigator DESTA aba.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final List<Movie> _all = _uniqueMovies();
  String _query = '';

  List<Movie> _uniqueMovies() {
    final seen = <String>{};
    return [...featuredMovies, ...popularMovies, ...favoriteMovies]
        .where((m) => seen.add(m.title))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _all
        .where((m) => m.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: const CineAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar filmes...',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Text('Nenhum filme encontrado',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final m = results[i];
                      return ListTile(
                        leading: PosterPlaceholder(
                            colors: m.colors, width: 40, height: 56),
                        title: Text(m.title),
                        subtitle: Text('${m.year}  •  ${m.genres.join(', ')}'),
                        trailing: RatingBadge(m.rating),
                        onTap: () => openMovieDetails(context, m),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
