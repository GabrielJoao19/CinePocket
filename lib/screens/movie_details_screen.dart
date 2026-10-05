import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

class MovieDetailsScreen extends StatelessWidget {
  final Movie movie;
  const MovieDetailsScreen({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    final original =
        movie.originalTitle.isNotEmpty ? movie.originalTitle : movie.title;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _banner(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(movie.title,
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(original,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.yellow,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoPill('${movie.year}'),
                    _infoPill(movie.ageRating.isEmpty ? '14+' : movie.ageRating),
                    _infoPill(
                        movie.duration.isEmpty ? '2h 46m' : movie.duration),
                    _infoPill('IMAX 4K', highlight: true),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final g in movie.genres)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(g,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _ratingCard(),
                const SizedBox(height: 14),
                _primaryButton(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _secondaryButton(
                            Icons.bookmark_border, 'Na Minha Lista')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _secondaryButton(
                            Icons.check_circle_outline, 'Já Assisti')),
                  ],
                ),
                const SizedBox(height: 18),
                _synopsis(),
                const SizedBox(height: 18),
                _cast(),
                const SizedBox(height: 18),
                _techSheet(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PosterPlaceholder(
            colors: movie.colors,
            borderRadius: BorderRadius.zero,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _circleButton(Icons.arrow_back,
                      onTap: () => Navigator.pop(context)),
                  _circleButton(Icons.share_outlined),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_fill,
                      color: AppColors.yellow, size: 16),
                  SizedBox(width: 4),
                  Text('Ver Trailer',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration:
            const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _infoPill(String text, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: highlight ? AppColors.yellow : AppColors.border),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlight ? AppColors.yellow : Colors.white70)),
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _ratingCard() {
    return _card(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child:
                    const Icon(Icons.star, color: AppColors.yellow, size: 26),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(movie.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      const Text(' / 10',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  const Text('450k avaliações',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.border),
          const Row(
            children: [
              Icon(Icons.star_border, color: AppColors.textSecondary),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sua Nota',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Toque para avaliar',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _primaryButton() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite, color: Colors.black, size: 18),
          SizedBox(width: 8),
          Text('Adicionar aos Favoritos',
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _secondaryButton(IconData icon, String label) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _synopsis() {
    return _card(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeaderInline('Sinopse'),
          SizedBox(height: 10),
          Text(
            'Paul Atreides se une a Chani e aos Fremen enquanto busca vingança '
            'contra os conspiradores que destruíram sua família...',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          SizedBox(height: 6),
          Text('Ler mais ⌄',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.yellow,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _cast() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: SectionHeaderInline('Elenco Principal')),
              Text('Ver todos',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.yellow,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final c in castMembers)
                Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceLight,
                        border: Border.all(color: AppColors.border, width: 2),
                      ),
                      child: const Icon(Icons.person,
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 90,
                      child: Text(c.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    Text(c.character,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _techSheet() {
    Widget item(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ficha Técnica',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(children: [
            item('Direção', 'Denis Villeneuve'),
            item('Distribuição', 'Warner Bros. Pictures'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            item('Trilha Sonora', 'Hans Zimmer'),
            item('Idioma Original', 'Inglês'),
          ]),
        ],
      ),
    );
  }
}

/// Título com barrinha amarela, para uso dentro de cards.
class SectionHeaderInline extends StatelessWidget {
  final String title;
  const SectionHeaderInline(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14, color: AppColors.yellow),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
