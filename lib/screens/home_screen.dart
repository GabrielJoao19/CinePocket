import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';
import 'movie_details_screen.dart';

/// Largura a partir da qual usamos o layout de tablet/desktop.
const double kWideBreakpoint = 600;

void _openDetails(BuildContext context, Movie movie) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: movie)),
  );
}

// ============================================================
// TELA PRINCIPAL: escolhe o layout conforme a largura disponível
// ============================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CineAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < kWideBreakpoint) {
            return const MobileLayout();
          }
          return const DesktopLayout();
        },
      ),
    );
  }
}

// ============================================================
// LAYOUT MOBILE: tudo em uma coluna rolável
// ============================================================
class MobileLayout extends StatelessWidget {
  const MobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SearchSection(),
        ),
        SizedBox(height: 12),
        CategoryChips(padding: EdgeInsets.symmetric(horizontal: 16)),
        SizedBox(height: 20),
        SectionHeader('Filmes em Destaque', action: 'Ver todos'),
        SizedBox(height: 12),
        // Carrossel horizontal de destaques
        FeaturedCarousel(),
        SizedBox(height: 24),
        SectionHeader('Populares da Semana', action: 'Top 10 Brasil'),
        SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: PopularGrid(columns: 2),
        ),
      ],
    );
  }
}

// ============================================================
// LAYOUT DESKTOP/TABLET: busca no topo e duas colunas lado a lado
// ============================================================
class DesktopLayout extends StatelessWidget {
  const DesktopLayout({super.key});

  @override
  Widget build(BuildContext context) {
    // Mais colunas no grid conforme a tela cresce.
    final width = MediaQuery.of(context).size.width;
    final gridColumns = width >= 1100 ? 4 : 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seção 1: busca + categorias na mesma linha
          const Row(
            children: [
              Expanded(flex: 2, child: SearchSection()),
              SizedBox(width: 16),
              Expanded(flex: 3, child: CategoryChips()),
            ],
          ),
          const SizedBox(height: 20),
          // Seções 2 e 3: duas colunas, cada uma rola independente
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      const SectionHeader('Filmes em Destaque',
                          action: 'Ver todos'),
                      const SizedBox(height: 12),
                      for (final m in featuredMovies) ...[
                        SizedBox(height: 220, child: FeaturedCard(movie: m)),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 3,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      const SectionHeader('Populares da Semana',
                          action: 'Top 10 Brasil'),
                      const SizedBox(height: 12),
                      PopularGrid(columns: gridColumns),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SEÇÕES REUTILIZÁVEIS
// ============================================================

/// Campo de busca (apenas visual).
class SearchSection extends StatelessWidget {
  const SearchSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: const SizedBox(
        height: 44,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Buscar filmes, diretores, atores...',
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
              Icon(Icons.tune, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista horizontal de categorias (pílulas).
class CategoryChips extends StatelessWidget {
  final EdgeInsets padding;
  const CategoryChips({super.key, this.padding = EdgeInsets.zero});

  static const _categories = ['Em Alta', 'Ação', 'Ficção Científica', 'Drama'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = i == 0;
          return ChoiceChip(
            label: Text(_categories[i]),
            selected: selected,
            showCheckmark: false,
            selectedColor: AppColors.yellow,
            backgroundColor: AppColors.surfaceLight,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.black : Colors.white70,
            ),
            onSelected: (_) {},
          );
        },
      ),
    );
  }
}

/// Carrossel horizontal de destaques (usado no mobile).
class FeaturedCarousel extends StatelessWidget {
  const FeaturedCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: featuredMovies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: 290,
          child: FeaturedCard(movie: featuredMovies[i], showHdr: i == 0),
        ),
      ),
    );
  }
}

/// Card de destaque: imagem larga em cima, textos embaixo.
/// Ocupa o espaço que o pai der (largura e altura).
class FeaturedCard extends StatelessWidget {
  final Movie movie;
  final bool showHdr;
  const FeaturedCard({super.key, required this.movie, this.showHdr = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => _openDetails(context, movie),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PosterPlaceholder(
                    colors: movie.colors,
                    borderRadius: BorderRadius.zero,
                  ),
                  Positioned(
                      top: 8, left: 8, child: RatingBadge(movie.rating)),
                  if (showHdr)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Chip(
                        label: Text('4K HDR'),
                        labelStyle: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.black54,
                        side: BorderSide.none,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${movie.year}  •  ${movie.genres.first}  •  ${movie.duration}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grade de populares. O número de colunas vem do layout que a usa.
class PopularGrid extends StatelessWidget {
  final int columns;
  const PopularGrid({super.key, required this.columns});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // Dentro de um ListView: calcula a própria altura e não rola sozinho.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: popularMovies.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: columns == 2 ? 0.58 : 0.64,
      ),
      itemBuilder: (_, i) => PopularCard(movie: popularMovies[i]),
    );
  }
}

/// Card de filme popular: pôster com selos, título, gênero e classificação.
class PopularCard extends StatelessWidget {
  final Movie movie;
  const PopularCard({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => _openDetails(context, movie),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PosterPlaceholder(colors: movie.colors),
                    Positioned(
                        top: 6, left: 6, child: RatingBadge(movie.rating)),
                    const Positioned(
                      bottom: 6,
                      right: 6,
                      child: CircleAvatar(
                        radius: 13,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.favorite_border,
                            size: 14, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${movie.year}  •  ${movie.genres.join(', ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      movie.ageRating,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ),
                  const Icon(Icons.bookmark_border,
                      size: 14, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
