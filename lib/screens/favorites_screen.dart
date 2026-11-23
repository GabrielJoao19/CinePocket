import 'package:flutter/material.dart';
import 'consultation_screen.dart';

/// A coleção agora é carregada do servidor conforme o usuário do JWT.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const ConsultationScreen(initialFavorites: true);
}
