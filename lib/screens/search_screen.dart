import 'package:flutter/material.dart';
import 'consultation_screen.dart';

/// Compatibilidade com as antigas rotas: usa a consulta protegida da API.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});
  @override
  Widget build(BuildContext context) => const ConsultationScreen();
}
