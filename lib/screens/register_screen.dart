import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

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
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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
        body: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                      key: _form,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        TextFormField(
                            controller: _name,
                            enabled: !_busy,
                            decoration:
                                const InputDecoration(labelText: 'Nome'),
                            validator: (value) =>
                                (value?.trim().length ?? 0) < 2
                                    ? 'Informe seu nome.'
                                    : null),
                        TextFormField(
                            controller: _email,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            decoration:
                                const InputDecoration(labelText: 'E-mail'),
                            validator: (value) =>
                                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch(value?.trim() ?? '')
                                    ? 'Informe um e-mail válido.'
                                    : null),
                        TextFormField(
                            controller: _password,
                            enabled: !_busy,
                            obscureText: true,
                            enableSuggestions: false,
                            autocorrect: false,
                            decoration: const InputDecoration(
                                labelText: 'Senha (mínimo 8 caracteres)'),
                            validator: (value) => (value?.length ?? 0) < 8
                                ? 'Use pelo menos 8 caracteres.'
                                : null,
                            onFieldSubmitted: (_) => _register()),
                        const SizedBox(height: 16),
                        if (_error != null)
                          Text(_error!,
                              style: const TextStyle(color: Colors.redAccent)),
                        FilledButton(
                            onPressed: _busy ? null : _register,
                            child: Text(_busy ? 'Criando...' : 'Cadastrar')),
                      ])),
                ))),
      );
}
