import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../navigation/route_names.dart';
import '../services/api_service.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  final String? message;
  const LoginScreen({super.key, this.message});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  late String? _error = widget.message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context
          .read<ApiService>()
          .login(_email.text.trim(), _password.text);
      _password.clear();
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(RouteNames.consultation, (_) => false);
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearSession() async {
    setState(() => _busy = true);
    try {
      await context.read<ApiService>().logout();
      if (mounted) setState(() => _error = 'Sessão removida.');
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.movie_creation,
                        size: 64, color: AppColors.yellow),
                    const Text('CinePocket',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.yellow)),
                    const SizedBox(height: 32),
                    TextFormField(
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                            labelText: 'E-mail', border: OutlineInputBorder()),
                        validator: (value) => value == null ||
                                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(value.trim())
                            ? 'Informe um e-mail válido.'
                            : null),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _login(),
                        decoration: const InputDecoration(
                            labelText: 'Senha', border: OutlineInputBorder()),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Informe a senha.'
                            : null),
                    const SizedBox(height: 20),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_error!,
                              semanticsLabel: _error,
                              style: const TextStyle(color: Colors.redAccent))),
                    FilledButton(
                        onPressed: _busy ? null : _login,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Entrar')),
                    TextButton(
                        onPressed: _busy ? null : _clearSession,
                        child: const Text('Limpar sessão armazenada')),
                  ],
                )),
          ),
        ))),
      );
}
