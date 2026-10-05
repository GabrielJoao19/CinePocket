import 'package:flutter/material.dart';
import '../theme.dart';

/// Tela de configurações. Aberta com push na pilha RAIZ (cobre a barra
/// inferior). Recebe o nome atual via ARGUMENTS e DEVOLVE o novo nome
/// com Navigator.pop(context, valor).
class SettingsScreen extends StatefulWidget {
  final String currentName;
  const SettingsScreen({super.key, required this.currentName});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.currentName);
  bool _notifications = true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final value = _name.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome não pode ficar vazio')),
      );
      return;
    }
    // Devolve o resultado para quem chamou o pushNamed.
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Voltar pela seta ou pelo sistema = pop sem valor (null) = cancelar.
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nome de exibição',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Notificações de lançamentos'),
            value: _notifications,
            activeThumbColor: AppColors.yellow,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Salvar')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
