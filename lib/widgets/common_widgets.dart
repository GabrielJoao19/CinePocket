import 'package:flutter/material.dart';
import '../navigation/route_names.dart';
import '../theme.dart';

/// Placeholder de pôster (gradiente + ícone). Futuramente: Image.network(TMDB).
class PosterPlaceholder extends StatelessWidget {
  final List<Color> colors;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const PosterPlaceholder({
    super.key,
    required this.colors,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: colors,
        ),
      ),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.white24, size: 32),
      ),
    );
  }
}

/// Selo amarelo com estrela e nota.
class RatingBadge extends StatelessWidget {
  final double rating;
  const RatingBadge(this.rating, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 11, color: Colors.black),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Título de seção com marcador amarelo e ação opcional à direita.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  const SectionHeader(this.title, {super.key, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: AppColors.yellow),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          if (action != null)
            Text(
              '$action ›',
              style: const TextStyle(
                color: AppColors.yellow,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

/// Pequena etiqueta de gênero.
class GenreTag extends StatelessWidget {
  final String label;
  const GenreTag(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      ),
    );
  }
}

/// Barra superior com logo CinePocket e abertura do Drawer.
class CineAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CineAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: AppColors.yellow),
        tooltip: 'Menu',
        onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
      ),
      title: const Row(
        children: [
          Icon(Icons.movie_creation, color: AppColors.yellow, size: 22),
          SizedBox(width: 8),
          Text(
            'CinePocket',
            style: TextStyle(
              color: AppColors.yellow,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.account_circle_outlined,
              color: AppColors.textSecondary),
          tooltip: 'Perfil',
          onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
