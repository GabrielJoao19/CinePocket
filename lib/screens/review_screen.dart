import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/movie.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

/// Tela "Avaliar filme": simula um pequeno sistema de interação para
/// demonstrar o ciclo  AÇÃO → PROCESSAMENTO → FEEDBACK.
///
/// Eventos usados:
///  - TextField ........ onChanged
///  - Botão 1 .......... onPressed  (Enviar, condicional)
///  - Botão 2 .......... onPressed + onLongPress (Limpar / Limpar tudo)
///  - Área de gestos ... onTap, onDoubleTap, onLongPress (InkWell)
///  - Feedback ......... SnackBar e AlertDialog
class ReviewScreen extends StatefulWidget {
  final Movie movie;
  const ReviewScreen({super.key, required this.movie});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  static const int _minChars = 10;
  static const int _maxStars = 5;

  final _controller = TextEditingController();
  int _rating = 0;
  bool _favorite = false;

  /// Trava de concorrência: enquanto está true, TODOS os eventos de entrada
  /// (texto, botões e gestos) são ignorados. Evita duplo envio e estados
  /// inconsistentes se o usuário tocar várias vezes durante o processamento.
  bool _submitting = false;

  int get _typedChars => _controller.text.trim().length;
  bool get _textValid => _typedChars >= _minChars;
  bool get _canSubmit => !_submitting && _textValid && _rating > 0;
  bool get _hasContent =>
      _controller.text.isNotEmpty || _rating > 0 || _favorite;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Feedback centralizado: sempre esconde o SnackBar anterior para
  // que as mensagens não formem fila e o usuário veja a mais recente.
  // ------------------------------------------------------------
  void _showMessage(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        action: action,
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ------------------------------------------------------------
  // EVENTO 1: TextField.onChanged
  // ------------------------------------------------------------
  void _onTextChanged(String value) {
    debugPrint('Digitado: "$value" ($_typedChars caracteres válidos)');
    // setState reconstrói a tela: atualiza o contador, a dica
    // e habilita/desabilita o botão "Enviar" em tempo real.
    setState(() {});
  }

  // ------------------------------------------------------------
  // EVENTOS 2, 3 e 4: gestos na área do pôster
  // ------------------------------------------------------------
  void _onPosterTap() {
    if (_submitting) return;
    HapticFeedback.selectionClick();
    // Ciclo 1..5 e volta ao 1: permite corrigir sem precisar de outro botão.
    setState(() => _rating = _rating >= _maxStars ? 1 : _rating + 1);
  }

  void _onPosterDoubleTap() {
    if (_submitting) return;
    HapticFeedback.lightImpact();
    setState(() => _favorite = !_favorite);
    _showMessage(_favorite
        ? '"${widget.movie.title}" adicionado aos favoritos ♥'
        : 'Removido dos favoritos');
  }

  void _onPosterLongPress() {
    if (_submitting || _rating == 0) return;
    HapticFeedback.mediumImpact();
    final previous = _rating;
    setState(() => _rating = 0);
    _showMessage(
      'Nota zerada',
      action: SnackBarAction(
        label: 'DESFAZER',
        onPressed: () => setState(() => _rating = previous),
      ),
    );
  }

  // ------------------------------------------------------------
  // BOTÃO 1: Enviar (onPressed) — só roda se _canSubmit for true.
  // ENCADEAMENTO: valida → AlertDialog → (confirmou) processa →
  // limpa campos → SnackBar → (nota alta) favorita automaticamente.
  // ------------------------------------------------------------
  Future<void> _submit() async {
    if (!_canSubmit) return; // dupla checagem: nunca confie só no "disabled"

    final text = _controller.text.trim();
    final stars = _rating;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar avaliação?'),
        content: Text('${widget.movie.title}  •  ${'★' * stars}\n\n"$text"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed != true) {
      _showMessage('Envio cancelado. Seu texto foi mantido.');
      return;
    }

    // PROCESSAMENTO simulado (futuramente: chamada à API / banco local).
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Evento encadeado 1: limpar o formulário após o envio.
    final autoFavorite = stars >= 4 && !_favorite;
    _controller.clear();
    setState(() {
      _submitting = false;
      _rating = 0;
      if (autoFavorite) _favorite = true;
    });

    // Evento encadeado 2: feedback final (e favorito automático).
    HapticFeedback.heavyImpact();
    _showMessage(autoFavorite
        ? 'Avaliação enviada! Nota alta: filme adicionado aos favoritos ♥'
        : 'Avaliação enviada com sucesso!');
  }

  // ------------------------------------------------------------
  // BOTÃO 2: Limpar — comportamento diferente do botão 1:
  //  - onPressed   : limpa texto e nota, com opção de DESFAZER
  //  - onLongPress : limpa tudo (inclusive favorito), com confirmação
  // ------------------------------------------------------------
  void _clear() {
    if (_submitting || !_hasContent) return;
    final prevText = _controller.text;
    final prevRating = _rating;

    _controller.clear();
    setState(() => _rating = 0);

    _showMessage(
      'Formulário limpo',
      action: SnackBarAction(
        label: 'DESFAZER',
        onPressed: () {
          _controller.text = prevText;
          setState(() => _rating = prevRating);
        },
      ),
    );
  }

  Future<void> _clearAll() async {
    if (_submitting || !_hasContent) return;
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar tudo?'),
        content: const Text('Texto, nota e favorito serão removidos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar tudo'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _controller.clear();
    setState(() {
      _rating = 0;
      _favorite = false;
    });
    _showMessage('Tudo foi limpo');
  }

  // Texto de ajuda dinâmico: explica POR QUE o botão está bloqueado.
  String get _hint {
    if (!_textValid) {
      final missing = _minChars - _typedChars;
      return 'Escreva mais $missing caractere(s) para liberar o envio';
    }
    if (_rating == 0) return 'Toque no pôster para dar uma nota';
    return 'Tudo pronto! Você já pode enviar';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avaliar filme')),
      body: SafeArea(
        // Centraliza e limita a largura em telas grandes (responsivo).
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _posterArea(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    enabled: !_submitting,
                    onChanged: _onTextChanged,
                    maxLength: 200,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Seu comentário',
                      hintText: 'O que você achou do filme?',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _canSubmit ? Icons.check_circle : Icons.info_outline,
                        size: 16,
                        color: _canSubmit
                            ? Colors.greenAccent
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _hint,
                          style: TextStyle(
                            fontSize: 12,
                            color: _canSubmit
                                ? Colors.greenAccent
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: FilledButton.icon(
                          // null = botão desabilitado (condição não satisfeita)
                          onPressed: _canSubmit ? _submit : null,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                          label:
                              Text(_submitting ? 'Enviando...' : 'Enviar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: _submitting || !_hasContent ? null : _clear,
                          onLongPress:
                              _submitting || !_hasContent ? null : _clearAll,
                          icon: const Icon(Icons.cleaning_services_outlined),
                          label: const Text('Limpar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dica: segure "Limpar" para apagar também o favorito.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Área sensível a gestos. InkWell (em vez de GestureDetector) dá o efeito
  /// de ondulação (ripple), um feedback visual imediato do toque.
  Widget _posterArea() {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: _onPosterTap,
        onDoubleTap: _onPosterDoubleTap,
        onLongPress: _onPosterLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  PosterPlaceholder(
                      colors: widget.movie.colors, width: 90, height: 130),
                  Positioned(
                    top: 4,
                    right: 4,
                    // AnimatedSwitcher: transição suave ao favoritar.
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        _favorite ? Icons.favorite : Icons.favorite_border,
                        key: ValueKey(_favorite),
                        color: _favorite ? AppColors.heart : Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 1; i <= _maxStars; i++)
                          Icon(
                            i <= _rating ? Icons.star : Icons.star_border,
                            color: AppColors.yellow,
                            size: 26,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _rating == 0
                          ? 'Sem nota'
                          : 'Sua nota: $_rating/$_maxStars',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Toque: +1 estrela\n'
                      'Duplo toque: favoritar\n'
                      'Segurar: zerar nota',
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
