import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../navigation/route_names.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CineAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: const [
              Icon(Icons.favorite, color: AppColors.yellow, size: 22),
              SizedBox(width: 8),
              Text('Meus Favoritos',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Coleção de clássicos e destaques salvos',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle,
                        size: 13, color: Colors.lightBlueAccent),
                    SizedBox(width: 4),
                    Text('Salvos no dispositivo',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('${favoriteMovies.length} filmes salvos',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.yellow,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          _filters(),
          const SizedBox(height: 14),
          for (final m in favoriteMovies) ...[
            _favoriteCard(context, m),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          _storageCard(),
        ],
      ),
    );
  }

  Widget _filters() {
    const labels = ['Mais Recentes', 'Melhor Avaliados', 'Gêneros'];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = i == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.yellow.withOpacity(0.15)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: selected ? AppColors.yellow : AppColors.border),
            ),
            child: Row(
              children: [
                if (i == 1) ...const [
                  Icon(Icons.star, size: 12, color: AppColors.yellow),
                  SizedBox(width: 4),
                ],
                Text(labels[i],
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.yellow : Colors.white70)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _favoriteCard(BuildContext context, Movie m) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => openMovieDetails(context, m),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PosterPlaceholder(colors: m.colors, width: 64, height: 92),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(m.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        RatingBadge(m.rating),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${m.year}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [for (final g in m.genres) GenreTag(g)],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(m.savedAt,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ),
              const Icon(Icons.favorite, size: 18, color: AppColors.heart),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _storageCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage, color: AppColors.yellow, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Espaço Ocupado',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text('4.8 MB de metadados em cache local',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text('Gerenciar',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
