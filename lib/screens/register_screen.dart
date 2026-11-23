import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context
          .read<ApiService>()
          .register(_name.text.trim(), _email.text.trim(), _password.text);
      _password.clear();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
            content: Text('Conta criada. Entre com seu e-mail e senha.')));
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Criar conta')),
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
                                const Icon(Icons.person_add_alt_1,
                                    size: 56, color: AppColors.yellow),
                                const SizedBox(height: 8),
                                const Text('Nova conta CinePocket',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.yellow)),
                                const SizedBox(height: 20),
                                TextFormField(
                                    controller: _name,
                                    enabled: !_busy,
                                    autofillHints: const [AutofillHints.name],
                                    decoration: const InputDecoration(
                                        labelText: 'Nome',
                                        border: OutlineInputBorder()),
                                    validator: (value) =>
                                        (value?.trim().length ?? 0) < 2
                                            ? 'Informe seu nome.'
                                            : null),
                                const SizedBox(height: 12),
                                TextFormField(
                                    controller: _email,
                                    enabled: !_busy,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    decoration: const InputDecoration(
                                        labelText: 'E-mail',
                                        border: OutlineInputBorder()),
                                    validator: (value) => !RegExp(
                                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                            .hasMatch(value?.trim() ?? '')
                                        ? 'Informe um e-mail válido.'
                                        : null),
                                const SizedBox(height: 12),
                                TextFormField(
                                    controller: _password,
                                    enabled: !_busy,
                                    obscureText: true,
                                    enableSuggestions: false,
                                    autocorrect: false,
                                    autofillHints: const [
                                      AutofillHints.newPassword
                                    ],
                                    decoration: const InputDecoration(
                                        labelText:
                                            'Senha (mínimo 8 caracteres)',
                                        border: OutlineInputBorder()),
                                    validator: (value) =>
                                        (value?.length ?? 0) < 8
                                            ? 'Use pelo menos 8 caracteres.'
                                            : null,
                                    onFieldSubmitted: (_) => _register()),
                                const SizedBox(height: 20),
                                if (_error != null)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Text(_error!,
                                          semanticsLabel: _error,
                                          style: const TextStyle(
                                              color: Colors.redAccent))),
                                FilledButton(
                                    onPressed: _busy ? null : _register,
                                    child: _busy
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : const Text('Cadastrar')),
                              ])),
                    )))),
      );
}
