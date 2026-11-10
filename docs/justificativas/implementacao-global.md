# Implementação da gerência de estado

## Abordagem escolhida

Provider + ChangeNotifier. O FavoritesProvider, separado da UI em lib/providers/favorites_provider.dart, é a fonte única dos favoritos da sessão. O ChangeNotifierProvider envolve o aplicativo em lib/main.dart.

## Justificativa da escolha

Provider permite compartilhar o estado com pouca estrutura e sem geração de código, adequado ao tamanho deste aplicativo. Cubit também resolveria o problema, mas introduziria a estrutura e os conceitos do Bloc sem necessidade neste escopo. MobX exigiria stores observáveis e geração de código. Provider foi escolhido pela simplicidade de leitura e manutenção.

## Antes: estado local com setState

Na versão original do PR (commit 181f093817af622b0ddd1f008037cdda6ea35be9), a tela de detalhes guardava bool _favorite e alterava esse valor com setState. Favoritar Duna atualizava o coração e o botão daquela tela, mas o contador da AppBar continuava em 5 e a lista de favoritos continuava fixa. O PR já possuía Provider nos cards da Home e no contador; estas capturas documentam a parte local que ainda precisava ser migrada, conforme a refatoração parcial permitida na atividade.

![Antes: Duna favoritado nos detalhes usando setState](estado-global/antes-setstate.png)

![Antes: contador permanece em 5 após favoritar Duna nos detalhes](estado-global/antes-contador.png)

## Depois: estado compartilhado e reativo

O provider mantém um mapa de filmes, identificado pelo título no catálogo simulado, e expõe count, movies, isFavorite, setFavorite e toggleFavorite. A lista retornada é imutável. As operações adicionam ou removem um filme e chamam notifyListeners somente quando há alteração.

A Home e a AppBar usam Consumer. Meus Favoritos e a tela de detalhes usam context.watch para reconstruir a UI, e context.read nos comandos. Favoritar nos detalhes, dar uma avaliação alta ou limpar tudo modifica o mesmo provider. Também é possível remover um filme diretamente da lista. Ao reabrir os detalhes, o favorito é consultado na fonte compartilhada.

O estado do formulário (texto, nota ainda não enviada e carregamento) permanece local. A refatoração parcial migra os favoritos, compartilhados entre as telas; não é necessário globalizar cada estado efêmero de interação.

![Depois: botão e coração dos detalhes refletem o Provider](estado-global/depois-detalhes.png)

![Depois: ao voltar à Home, o contador passou de 5 para 6](estado-global/depois-contador.png)

![Depois: Duna aparece na lista e o contador da mesma tela mostra 6](estado-global/depois-lista.png)

## Código comentado para conduzir a apresentação

Os blocos abaixo reproduzem os trechos relevantes da implementação. Os links abrem o GitHub com as linhas selecionadas na revisão usada nesta explicação. As reticências entre blocos indicam partes omitidas; cada bloco preserva o código do arquivo.

### 1. Centralizar os favoritos e avisar sobre mudanças

**Ponto principal:** `FavoritesProvider` guarda a coleção e concentra as operações. `movies` devolve uma lista imutável, impedindo que a interface altere a coleção por fora. `setFavorite` evita notificações quando nada mudou; quando adiciona ou remove, `notifyListeners()` avisa os widgets inscritos. `toggleFavorite` reaproveita essa regra.


[lib/providers/favorites_provider.dart — linhas 5–25](https://github.com/GabrielJoao19/CinePocket/blob/cf837221e519c9eb2a2f4c5b62d02379d3c3ba28/lib/providers/favorites_provider.dart#L5-L25)

```dart
class FavoritesProvider extends ChangeNotifier {
  final Map<String, Movie> _movies = {
    for (final movie in favoriteMovies) movie.title: movie,
  };

  int get count => _movies.length;
  List<Movie> get movies => List.unmodifiable(_movies.values);
  bool isFavorite(Movie movie) => _movies.containsKey(movie.title);

  void setFavorite(Movie movie, bool value) {
    if (isFavorite(movie) == value) return;
    if (value) {
      _movies[movie.title] = movie;
    } else {
      _movies.remove(movie.title);
    }
    notifyListeners();
  }

  void toggleFavorite(Movie movie) => setFavorite(movie, !isFavorite(movie));
}
```

### 2. Disponibilizar a mesma instância para todas as telas

**Ponto principal:** o `ChangeNotifierProvider` envolve o aplicativo antes do `MaterialApp` e dos navegadores. Assim, Home, detalhes, contador e favoritos encontram a mesma instância pelo contexto.


[lib/main.dart — linhas 13–20](https://github.com/GabrielJoao19/CinePocket/blob/cf837221e519c9eb2a2f4c5b62d02379d3c3ba28/lib/main.dart#L13-L20)

```dart
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => FavoritesProvider(),
      child: const CinePocketApp(),
    ),
  );
}
```

### 3. Alterar o estado pelos cards da Home

**Ponto principal:** o `Consumer` recebe o provider e reconstrói o botão quando há uma notificação. `isFavorite` define a aparência; `toggleFavorite` altera o estado compartilhado ao tocar no coração. Os blocos abaixo pertencem ao mesmo botão.


[lib/screens/home_screen.dart — linhas 377–386](https://github.com/GabrielJoao19/CinePocket/blob/cf837221e519c9eb2a2f4c5b62d02379d3c3ba28/lib/screens/home_screen.dart#L377-L386)

```dart
child: Consumer<FavoritesProvider>(
  builder: (context, favorites, _) => IconButton(
    tooltip: favorites.isFavorite(movie)
        ? 'Remover dos favoritos'
        : 'Adicionar aos favoritos',
    icon: Icon(
      favorites.isFavorite(movie)
          ? Icons.favorite
          : Icons.favorite_border,
      size: 18,
```


[lib/screens/home_screen.dart — linhas 396–398](https://github.com/GabrielJoao19/CinePocket/blob/cf837221e519c9eb2a2f4c5b62d02379d3c3ba28/lib/screens/home_screen.dart#L396-L398)

```dart
    onPressed: () => favorites.toggleFavorite(movie),
  ),
),
```

### 4. Substituir o favorito local na tela de detalhes

**Ponto principal:** `_favorite` agora é uma consulta ao provider, sem um `bool` local separado. O comando usa `read` para acessar a instância sem criar uma assinatura. A assinatura feita com `watch` no `build` garante a reconstrução da tela e uma nova leitura do favorito após cada mudança.


[lib/screens/movie_details_screen.dart — linhas 35–35](https://github.com/GabrielJoao19/CinePocket/blob/cf837221e519c9eb2a2f4c5b62d02379d3c3ba28/lib/screens/movie_details_screen.dart#L35-L35)

```dart
bool get _favorite => context.read<FavoritesProvider>().isFavorite(movie);
```


[lib/screens/movie_details_screen.dart — linhas 72–78](https://github.com/GabrielJoao19/CinePocket/blob/cf837221e519c9eb2a2f4c5b62d02379d3c3ba28/lib/screens/movie_details_screen.dart#L72-L78)

```dart
void _toggleFavorite() {
  HapticFeedback.lightImpact();
  context.read<FavoritesProvider>().toggleFavorite(movie);
  _showMessage(_favorite
      ? '"${movie.title}" adicionado aos favoritos ♥'
      : 'Removido dos favoritos');
}
```


[lib/screens/movie_details_screen.dart — linhas 237–239](https://github.com/GabrielJoao19/CinePocket/blob/cf837221e519c9eb2a2f4c5b62d02379d3c3ba28/lib/screens/movie_details_screen.dart#L237-L239)

```dart
@override
Widget build(BuildContext context) {
  context.watch<FavoritesProvider>();
```


**Outros caminhos também usam a mesma fonte:** uma avaliação com quatro ou cinco estrelas pode adicionar o filme; a ação “Limpar tudo” remove o filme atual dos favoritos e limpa o formulário. Ela não esvazia a coleção inteira.

### 5. Manter os comandos secundários sincronizados

**Ponto principal:** após o envio da avaliação, `autoFavorite` decide se o filme deve ser adicionado. O `setState` continua cuidando apenas do formulário. Na limpeza, a remoção também passa por `setFavorite`, propagando a mudança às outras telas.


[lib/screens/movie_details_screen.dart — linhas 153–163](https://github.com/GabrielJoao19/CinePocket/blob/cf837221e519c9eb2a2f4c5b62d02379d3c3ba28/lib/screens/movie_details_screen.dart#L153-L163)

```dart
// Eventos encadeados: limpar formulário → feedback → favorito automático.
final autoFavorite = stars >= 4 && !_favorite;
_controller.clear();
setState(() {
  _submitting = false;
  _rating = 0;
});

if (autoFavorite) {
  context.read<FavoritesProvider>().setFavorite(movie, true);
}
```


[lib/screens/movie_details_screen.dart — linhas 215–221](https://github.com/GabrielJoao19/CinePocket/blob/cf837221e519c9eb2a2f4c5b62d02379d3c3ba28/lib/screens/movie_details_screen.dart#L215-L221)

```dart
if (ok != true || !mounted) return;
_controller.clear();
setState(() {
  _rating = 0;
});
context.read<FavoritesProvider>().setFavorite(movie, false);
_showMessage('Tudo foi limpo');
```

### 6. Atualizar o contador da AppBar automaticamente

**Ponto principal:** o `Consumer` lê `count` da mesma coleção. Depois de `notifyListeners()`, o número exibido é recalculado e o selo fica oculto quando a coleção está vazia.


[lib/widgets/common_widgets.dart — linhas 162–168](https://github.com/GabrielJoao19/CinePocket/blob/cf837221e519c9eb2a2f4c5b62d02379d3c3ba28/lib/widgets/common_widgets.dart#L162-L168)

```dart
Consumer<FavoritesProvider>(
  builder: (context, favorites, _) => Badge(
    isLabelVisible: favorites.count > 0,
    label: Text('${favorites.count}'),
    child: const Icon(Icons.favorite_border, color: AppColors.heart),
  ),
),
```

### 7. Construir a lista a partir do estado global

**Ponto principal:** `watch` inscreve a tela nas mudanças. A lista percorre `favorites.movies` e apresenta uma mensagem quando não há favoritos; assim, o conteúdo deixa de ser uma lista fixa.


[lib/screens/favorites_screen.dart — linhas 12–14](https://github.com/GabrielJoao19/CinePocket/blob/cf837221e519c9eb2a2f4c5b62d02379d3c3ba28/lib/screens/favorites_screen.dart#L12-L14)

```dart
@override
Widget build(BuildContext context) {
  final favorites = context.watch<FavoritesProvider>();
```


[lib/screens/favorites_screen.dart — linhas 66–73](https://github.com/GabrielJoao19/CinePocket/blob/cf837221e519c9eb2a2f4c5b62d02379d3c3ba28/lib/screens/favorites_screen.dart#L66-L73)

```dart
if (favorites.count == 0)
  const Padding(
      padding: EdgeInsets.all(24),
      child: Text('Nenhum favorito nesta sessão.')),
for (final m in favorites.movies) ...[
  _favoriteCard(context, m),
  const SizedBox(height: 10),
],
```

### 8. Remover um favorito pela lista

**Ponto principal:** o botão usa `read` para disparar `setFavorite(m, false)`. A notificação faz a tela reconstruir a lista, atualiza o contador e sincroniza o coração nas outras telas.


[lib/screens/favorites_screen.dart — linhas 191–197](https://github.com/GabrielJoao19/CinePocket/blob/cf837221e519c9eb2a2f4c5b62d02379d3c3ba28/lib/screens/favorites_screen.dart#L191-L197)

```dart
IconButton(
    tooltip: 'Remover dos favoritos',
    onPressed: () => context
        .read<FavoritesProvider>()
        .setFavorite(m, false),
    icon: const Icon(Icons.favorite,
        size: 18, color: AppColors.heart)),
```


### Sequência sugerida para demonstrar

1. Mostre a coleção no provider e destaque `notifyListeners()`.
2. Mostre o registro em `main` e explique por que as telas compartilham a instância.
3. Abra os detalhes de Duna e adicione aos favoritos: o comando chama `read` → `toggleFavorite` → `setFavorite` → `notifyListeners`.
4. Volte à Home e mostre o contador atualizado por `Consumer`; abra Meus Favoritos e mostre Duna na lista atualizada por `watch`.
5. Remova Duna pela lista e reabra os detalhes para mostrar o coração sincronizado.

**Frase de apoio:** “A interface dispara comandos no provider. O provider altera a coleção e notifica quem está ouvindo. Cada widget inscrito reconstrói sua apresentação com o mesmo estado.”

## Principal dificuldade

Identificar todos os caminhos que alteravam favoritos: botão dos cards, botão e gesto nos detalhes, avaliação com nota alta e limpeza. Manter uma variável local nos detalhes produziria duas fontes de verdade. A solução foi centralizar as operações no provider e consumir a mesma instância acima dos navegadores das abas.

## Vantagem sobre setState

Uma alteração atualiza os widgets interessados em telas distintas sem passar listas e callbacks pela navegação. A regra de favoritos pode ser exercitada independentemente da apresentação e fica concentrada em uma classe.

## Validação e requisitos

1. Estado separado da UI: FavoritesProvider estende ChangeNotifier.
2. Consumo apropriado: Consumer e context.watch.
3. Reatividade em múltiplos locais: coração/botão, contador e lista de favoritos.
4. Modificação pela UI: favoritar nos cards e detalhes, remover na lista.
5. Separação de responsabilidades: operações de favoritos no provider; widgets apresentam o estado e disparam comandos.

O fluxo foi executado em Flutter Web no Chromium, com janela de 430 x 932, em 7 de novembro de 2026. Primeiro foi capturado o comportamento original do PR; depois, o mesmo fluxo refatorado. As imagens são capturas reais do aplicativo executado.

Testes automatizados: navegação de detalhes e retorno; navegação entre abas e drawer; inclusão de Duna nos detalhes, atualização da lista compartilhada e remoção pela lista. Resultado: 3 testes aprovados e flutter analyze sem problemas. Ambiente: Flutter 3.47.9 e Dart 3.13.7. Comandos: flutter test e flutter analyze.

Os favoritos começam com 5 filmes simulados e duram apenas durante a sessão. Não há persistência em disco ou API. O título identifica o filme neste catálogo simples; uma API real deverá fornecer um ID estável.
