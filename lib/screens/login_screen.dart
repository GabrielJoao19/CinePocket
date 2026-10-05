import 'package:flutter/material.dart';
import '../navigation/route_names.dart';
import '../theme.dart';

/// Tela de login (mock). Entrar usa pushReplacementNamed: o login SAI da
/// pilha, então o botão voltar da home não retorna para o login.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.movie_creation,
                      size: 64, color: AppColors.yellow),
                  const SizedBox(height: 8),
                  const Text(
                    'CinePocket',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.yellow,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.of(context)
                        .pushReplacementNamed(RouteNames.home),
                    child: const Text('Entrar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
