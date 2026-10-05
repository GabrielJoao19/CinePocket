import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/movie.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

/// Tela de detalhes do filme, com a avaliação INTERATIVA embutida.
///
/// Ciclo de eventos (AÇÃO → PROCESSAMENTO → FEEDBACK) usado aqui:
///  - Banner ............. onDoubleTap  → favorita (coração animado)
///  - Botão Favoritos .... onPressed    → alterna favorito (mesmo estado do banner)
///  - Estrelas (InkWell) . onTap / onLongPress → +1 estrela / zerar nota
///  - TextField .......... onChanged    → valida tamanho mínimo em tempo real
///  - Botão Enviar ....... onPressed    → só com condição satisfeita
///  - Botão Limpar ....... onPressed / onLongPress → limpar / limpar tudo
///  - Feedback ........... SnackBar e AlertDialog
class MovieDetailsScreen extends StatefulWidget {
  final Movie movie;
  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  static const int _minChars = 10;
  static const int _maxStars = 5;

  Movie get movie => widget.movie;

  final _controller = TextEditingController();
  int _rating = 0;
  bool _favorite = false;

  /// Trava de concorrência: enquanto true, TODOS os eventos de entrada
  /// (texto, botões e gestos da avaliação) são ignorados. Evita duplo envio
  /// e estados inconsistentes se o usuário tocar várias vezes durante o
  /// processamento.
  bool _submitting = false;

  int get _typedChars => _controller.text.trim().length;
  bool get _textValid => _typedChars >= _minChars;
  bool get _canSubmit => !_submitting && _textValid && _rating > 0;
  bool get _hasContent => _controller.text.isNotEmpty || _rating > 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Feedback centralizado: esconde o SnackBar anterior para que as
  // mensagens não formem fila e o usuário veja sempre a mais recente.
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
  // FAVORITO: acionado pelo duplo toque no banner OU pelo botão.
  // Dois eventos diferentes, um único estado (_favorite).
  // ------------------------------------------------------------
  void _toggleFavorite() {
    HapticFeedback.lightImpact();
    setState(() => _favorite = !_favorite);
    _showMessage(_favorite
        ? '"${movie.title}" adicionado aos favoritos ♥'
        : 'Removido dos favoritos');
  }

  // ------------------------------------------------------------
  // GESTOS nas estrelas (InkWell): onTap e onLongPress
  // ------------------------------------------------------------
  void _onStarsTap() {
    if (_submitting) return;
    HapticFeedback.selectionClick();
    // Ciclo 1..5 e volta ao 1: permite corrigir sem outro botão.
    setState(() => _rating = _rating >= _maxStars ? 1 : _rating + 1);
  }

  void _onStarsLongPress() {
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
  // TextField.onChanged
  // ------------------------------------------------------------
  void _onTextChanged(String value) {
    debugPrint('Digitado: "$value" ($_typedChars caracteres válidos)');
    // setState atualiza contador, dica e habilita/desabilita "Enviar".
    setState(() {});
  }

  // ------------------------------------------------------------
  // BOTÃO ENVIAR (onPressed) — só roda se _canSubmit for true.
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
        content: Text('${movie.title}  •  ${'★' * stars}\n\n"$text"'),
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

    // PROCESSAMENTO simulado (futuramente: API / banco local).
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Eventos encadeados: limpar formulário → feedback → favorito automático.
    final autoFavorite = stars >= 4 && !_favorite;
    _controller.clear();
    setState(() {
      _submitting = false;
      _rating = 0;
      if (autoFavorite) _favorite = true;
    });

    HapticFeedback.heavyImpact();
    _showMessage(autoFavorite
        ? 'Avaliação enviada! Nota alta: filme adicionado aos favoritos ♥'
        : 'Avaliação enviada com sucesso!');
  }

  // ------------------------------------------------------------
  // BOTÃO LIMPAR — comportamento diferente do Enviar:
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
      'Avaliação limpa',
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
    if (_submitting || !(_hasContent || _favorite)) return;
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

  // Texto de ajuda dinâmico: explica POR QUE o envio está bloqueado.
  String get _hint {
    if (!_textValid) {
      final missing = _minChars - _typedChars;
      return 'Escreva mais $missing caractere(s) para liberar o envio';
    }
    if (_rating == 0) return 'Toque nas estrelas para dar uma nota';
    return 'Tudo pronto! Você já pode enviar';
  }

  // ============================================================
  // UI
  // ============================================================
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
                _reviewCard(),
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
    // Duplo toque em qualquer parte do banner favorita o filme.
    return GestureDetector(
      onDoubleTap: _toggleFavorite,
      child: SizedBox(
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
            // Indicador animado do estado de favorito.
            Positioned(
              left: 16,
              bottom: 10,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black54,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _favorite ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(_favorite),
                    color: _favorite ? AppColors.heart : Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
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

  /// Nota geral do público (informativa).
  Widget _ratingCard() {
    return _card(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.star, color: AppColors.yellow, size: 26),
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
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  /// Botão de favoritos: alterna o mesmo estado do duplo toque no banner.
  Widget _primaryButton() {
    return FilledButton.icon(
      onPressed: _toggleFavorite,
      icon: Icon(_favorite ? Icons.favorite : Icons.favorite_border, size: 18),
      label: Text(_favorite ? 'Nos Favoritos' : 'Adicionar aos Favoritos'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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

  // ------------------------------------------------------------
  // CARD "SUA AVALIAÇÃO": estrelas (gestos) + TextField + botões
  // ------------------------------------------------------------
  Widget _reviewCard() {
    final ready = _canSubmit;
    final hintColor = ready ? Colors.greenAccent : AppColors.textSecondary;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeaderInline('Sua Avaliação'),
          const SizedBox(height: 12),

          // Área de gestos: InkWell dá o ripple (feedback visual imediato).
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _onStarsTap,
            onLongPress: _onStarsLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  for (var i = 1; i <= _maxStars; i++)
                    Icon(
                      i <= _rating ? Icons.star : Icons.star_border,
                      color: AppColors.yellow,
                      size: 30,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _rating == 0
                              ? 'Sem nota'
                              : 'Sua nota: $_rating/$_maxStars',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const Text(
                          'Toque: +1 • Segure: zerar',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _controller,
            enabled: !_submitting,
            onChanged: _onTextChanged,
            maxLength: 200,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Seu comentário',
              hintText: 'O que você achou do filme?',
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(ready ? Icons.check_circle : Icons.info_outline,
                  size: 16, color: hintColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_hint,
                    style: TextStyle(fontSize: 12, color: hintColor)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  // null = botão desabilitado (condição não satisfeita)
                  onPressed: ready ? _submit : null,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: Text(_submitting ? 'Enviando...' : 'Enviar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _submitting || !_hasContent ? null : _clear,
                  onLongPress: _submitting || !(_hasContent || _favorite)
                      ? null
                      : _clearAll,
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: const Text('Limpar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Dicas: duplo toque no banner favorita • segure "Limpar" para apagar tudo.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
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
