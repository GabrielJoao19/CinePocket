# Implementação da gerência de estado

## 1. Abordagem escolhida

Para refatorar o aplicativo CinePocket, foi escolhido o uso de **Provider + ChangeNotifier**.

Foi criado o `FavoritesProvider`, responsável por guardar os filmes favoritos e informar quando essa lista é alterada. Esse provider é disponibilizado para todo o aplicativo por meio do `ChangeNotifierProvider`, configurado no `main.dart`.

## 2. Justificativa da escolha

O Provider + ChangeNotifier foi escolhido por ser uma solução simples de aprender e fácil de acompanhar durante a leitura do código. A lógica dos favoritos fica reunida em uma classe, enquanto os widgets apenas consultam os dados e reagem às mudanças.

Essa opção também foi mais adequada ao tamanho e ao objetivo do CinePocket. Em comparação com o Cubit/Bloc, ela exige menos estrutura inicial e menos conceitos para começar. Em comparação com o MobX, não depende de ferramentas complexas nem de geradores de código. Assim, foi possível organizar o estado usando recursos que já fazem parte do próprio código Dart e do Flutter, com uma implementação mais direta.

## 3. Principal dificuldade encontrada

A principal dificuldade foi entender onde colocar o `ChangeNotifierProvider` e como fazer os widgets encontrarem o `FavoritesProvider`. Ele precisava ficar em um ponto acima das telas que usam os favoritos. Por isso, foi colocado no `main.dart`, envolvendo o `CinePocketApp`.

Também foi necessário aprender a usar o `Consumer` para atualizar somente as partes da tela que dependem dessa informação. Por exemplo, o botão de favorito no card do filme usa o `Consumer` para mudar o ícone e a cor quando o filme é adicionado ou removido.

## 4. Principal vantagem sobre o `setState`

A principal vantagem foi não precisar passar a lista de favoritos de uma tela ou widget para outro manualmente. Antes, usando apenas `setState`, seria necessário encontrar uma forma de levar essa informação entre os componentes que precisam dela.

Agora, o `FavoritesProvider` funciona como um ponto compartilhado. Quando o usuário toca no botão de favorito, o provider altera a lista e chama `notifyListeners()`. Os widgets que usam o `Consumer` percebem essa mudança e se atualizam automaticamente.

Na prática, isso permite que o botão do filme e a `AppBar` conversem com o mesmo estado: o botão muda para indicar que o filme foi favoritado, e o contador de favoritos da `AppBar` é atualizado sem que seja necessário conectar esses widgets manualmente.

## 5. Como a implementação atende aos requisitos

### 5.1 Estado compartilhado separado da UI

O estado dos favoritos foi colocado na classe `FavoritesProvider`, em [lib/providers/favorites_provider.dart](../../lib/providers/favorites_provider.dart#L6). Essa classe não desenha telas. Ela apenas mantém os títulos favoritos e oferece operações para consultar e alterar esse estado:

```dart
class FavoritesProvider extends ChangeNotifier {
	final Set<String> _favoriteTitles = ...;

	int get count => _favoriteTitles.length;

	bool isFavorite(Movie movie) => _favoriteTitles.contains(movie.title);
}
```

Essa separação é importante porque a regra dos favoritos não fica presa a um card específico. Qualquer widget que tenha acesso ao provider pode consultar a quantidade de favoritos ou verificar se um filme está marcado.

### 5.2 Provider disponibilizado para a aplicação

Em [lib/main.dart](../../lib/main.dart#L12-L18), o `ChangeNotifierProvider` envolve o `CinePocketApp`:

```dart
runApp(
	ChangeNotifierProvider(
		create: (_) => FavoritesProvider(),
		child: const CinePocketApp(),
	),
);
```

O provider foi colocado nesse nível porque a `AppBar` e os cards de filmes precisam acessar o mesmo objeto. Assim, eles leem a mesma fonte de dados, em vez de cada parte da interface possuir uma cópia diferente da lista.

### 5.3 UI consumindo o estado com `Consumer`

O aplicativo usa o mecanismo apropriado do Provider: `Consumer<FavoritesProvider>`. No botão de favorito do card, em [lib/screens/home_screen.dart](../../lib/screens/home_screen.dart#L371-L397), o `Consumer` lê o provider e escolhe o ícone, a cor e a mensagem do botão:

```dart
Consumer<FavoritesProvider>(
	builder: (context, favorites, _) => IconButton(
		tooltip: favorites.isFavorite(movie)
				? 'Remover dos favoritos'
				: 'Adicionar aos favoritos',
		icon: Icon(
			favorites.isFavorite(movie)
					? Icons.favorite
					: Icons.favorite_border,
		),
	),
)
```

No `Consumer`, o parâmetro `favorites` representa o estado compartilhado. Quando esse estado muda, somente a parte da interface envolvida pelo `Consumer` precisa ser reconstruída.

### 5.4 Dois locais reagindo à mesma mudança

Há pelo menos dois locais da UI que reagem à alteração dos favoritos:

1. O botão de favorito em [lib/screens/home_screen.dart](../../lib/screens/home_screen.dart#L371-L397) muda entre `favorite` e `favorite_border` e também altera a cor.
2. O contador da `AppBar`, em [lib/widgets/common_widgets.dart](../../lib/widgets/common_widgets.dart#L159-L166), usa `favorites.count` para exibir a quantidade atual no `Badge`.

Quando um filme é favoritado, os dois locais recebem a atualização do mesmo provider. Isso demonstra que o estado está realmente compartilhado: o card mostra a nova situação do filme e a `AppBar` atualiza a quantidade sem receber dados por parâmetros.

### 5.5 Estado alterado a partir da UI

O usuário modifica o estado ao tocar no botão do card. O callback chama o método do provider, em vez de alterar diretamente uma variável dentro do widget:

```dart
onPressed: () => favorites.toggleFavorite(movie),
```

Esse método, em [lib/providers/favorites_provider.dart](../../lib/providers/favorites_provider.dart#L12-L20), adiciona ou remove o filme e depois chama `notifyListeners()`:

```dart
void toggleFavorite(Movie movie) {
	if (isFavorite(movie)) {
		_favoriteTitles.remove(movie.title);
	} else {
		_favoriteTitles.add(movie.title);
	}
	notifyListeners();
}
```

O `notifyListeners()` avisa aos `Consumer`s que o estado mudou. Com isso, a ação começa na UI, a regra é executada no provider e os elementos interessados são atualizados automaticamente.

### 5.6 Separação de responsabilidades e código limpo

A implementação mantém responsabilidades bem definidas:

- `FavoritesProvider`: guarda os dados, verifica se um filme é favorito e altera a coleção.
- `PopularCard`: apresenta o filme e dispara a ação quando o usuário toca no botão.
- `CineAppBar`: apresenta a quantidade de favoritos.
- `ChangeNotifierProvider`: disponibiliza o estado para a árvore de widgets.
- `Consumer`: conecta cada parte da UI ao estado que ela precisa observar.

Esse desenho remove a lógica de estado dos widgets. Os widgets não precisam conhecer como os favoritos são armazenados; eles apenas solicitam a informação necessária e chamam a operação apropriada. Isso facilita a manutenção e permite trocar a forma de persistência no futuro sem reescrever toda a interface.
