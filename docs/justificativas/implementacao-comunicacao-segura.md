# Implementação de comunicação segura

## Objetivo e abordagem

A implementação da issue #3 adiciona autenticação JWT, armazenamento seguro do token, consulta protegida de filmes e favoritos persistidos por usuário. O aplicativo Flutter comunica-se exclusivamente por HTTPS com uma API própria em FastAPI + SQLite (`backend/`), que por sua vez consulta o catálogo público Studio Ghibli por HTTPS sem repassar o JWT da conta ao provedor externo.

O serviço `ApiService` concentra as requisições, a exigência de HTTPS e as regras de sessão; `FavoritesProvider` sincroniza os favoritos da conta autenticada e limpa o estado em memória a cada troca ou expiração de sessão; as telas (`LoginScreen`, `RegisterScreen`, `ConsultationScreen` e `MovieDetailsScreen`) conduzem o fluxo do usuário.

Para a análise completa de segurança (HTTPS, `SharedPreferences` vs. `flutter_secure_storage`, pacote `Encrypt` e tratamento de erros), consulte [comunicacao-segura.md](comunicacao-segura.md). Para executar a API HTTPS local e consultar o contrato dos endpoints, veja [backend/README.md](../../backend/README.md).

## Código comentado para conduzir a apresentação

Os blocos abaixo reproduzem trechos reais dos arquivos atuais do projeto com links diretos para as linhas correspondentes.

### 1. Dependências do cliente Flutter

**O que faz:** `provider` gerencia `ApiService` e `FavoritesProvider`, `http` realiza as requisições REST e `flutter_secure_storage` protege o JWT em repouso.

[pubspec.yaml — linhas 9–14](../../pubspec.yaml#L9-L14)

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  http: ^1.6.0
  flutter_secure_storage: ^10.0.0
```

### 2. Iniciar no login e redirecionar globalmente em 401

**O que faz:** `CinePocketApp` inicializa `ApiService` e `FavoritesProvider`, registra o callback global `onSessionExpired` para limpar a pilha de navegação ao receber HTTP 401 em qualquer tela e inicia em `RouteNames.login`.

[lib/main.dart — linhas 24–75](../../lib/main.dart#L24-L75)

```dart
class _CinePocketAppState extends State<CinePocketApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late final ApiService _api = widget.api ?? ApiService();
  late final FavoritesProvider _favorites = FavoritesProvider(_api);

  @override
  void initState() {
    super.initState();
    _api.onSessionExpired = (message) {
      _navigator.currentState?.pushNamedAndRemoveUntil(
          RouteNames.login, (_) => false,
          arguments: message);
    };
  }
  // ...
  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ApiService>.value(value: _api),
          ChangeNotifierProvider<FavoritesProvider>.value(value: _favorites),
        ],
        child: MaterialApp(
          navigatorKey: _navigator,
          title: 'CinePocket',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          initialRoute: RouteNames.login,
          onGenerateInitialRoutes: (_) =>
              [MaterialPageRoute(builder: (_) => const LoginScreen())],
          routes: {
            RouteNames.login: (context) => LoginScreen(
                message: ModalRoute.of(context)?.settings.arguments as String?),
            RouteNames.consultation: (_) => const ConsultationScreen(),
            RouteNames.home: (_) => const ConsultationScreen(),
            RouteNames.details: (context) {
              final movie = ModalRoute.of(context)!.settings.arguments;
              return movie is Movie
                  ? MovieDetailsScreen(movie: movie)
                  : const ConsultationScreen();
            },
          },
        ),
      );
}
```

### 3. Login, restauração de sessão e cadastro

**O que faz:** `LoginScreen` verifica se já existe token no armazenamento seguro para restaurar a sessão; no login manual, valida e-mail e senha, oculta a senha, chama `ApiService.login`, limpa o campo de senha e navega para `RouteNames.consultation` removendo o login da pilha. Também dá acesso à tela `RegisterScreen` (`POST /auth/register`) e à ação de limpar sessão armazenada.

[lib/screens/login_screen.dart — linhas 31–72](../../lib/screens/login_screen.dart#L31-L72)

```dart
  Future<void> _restoreSession() async {
    try {
      final saved = await context.read<ApiService>().hasSession();
      if (!mounted) return;
      if (saved) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(RouteNames.consultation, (_) => false);
      }
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
```

### 4. Armazenamento seguro do token

**O que faz:** `SecureTokenStore` encapsula leitura, gravação e remoção do token via `FlutterSecureStorage`. A interface `TokenStore` permite injetar uma implementação em memória nos testes automatizados.

[lib/services/api_service.dart — linhas 19–35](../../lib/services/api_service.dart#L19-L35)

```dart
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  final FlutterSecureStorage storage;
  SecureTokenStore({this.storage = const FlutterSecureStorage()});
  static const _key = 'cinepocket_access_token';
  @override
  Future<String?> read() => storage.read(key: _key);
  @override
  Future<void> write(String token) => storage.write(key: _key, value: token);
  @override
  Future<void> delete() => storage.delete(key: _key);
}
```

### 5. Exigência de HTTPS e tratamento de rede/timeout

**O que faz:** `API_BASE_URL` tem padrão `https://localhost:8443` (configurável por `--dart-define`). `_endpoint` rejeita qualquer URL que não use `https`, contenha credenciais embutidas ou altere a origem. `_request` desativa redirecionamentos (`followRedirects = false`), impõe timeout de 15 segundos e converte falhas de rede/TLS em mensagens claras de servidor indisponível.

[lib/services/api_service.dart — linhas 92–134](../../lib/services/api_service.dart#L92-L134)

```dart
  Uri _endpoint(String path) {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        !path.startsWith('/') ||
        path.startsWith('//')) {
      throw const ApiFailure('Configure uma API HTTPS válida para continuar.');
    }
    final uri =
        Uri.tryParse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path');
    if (uri == null || uri.origin != base.origin || uri.hasFragment) {
      throw const ApiFailure('Endpoint da API inválido.');
    }
    return uri;
  }

  Future<http.Response> _request(String method, String path,
      {String? token, Map<String, dynamic>? body}) async {
    final request = http.Request(method, _endpoint(path))
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      return await (() async {
        final response = await client.send(request);
        return http.Response.fromStream(response);
      })()
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiFailure('Tempo de conexão esgotado. Tente novamente.');
    } on Exception {
      throw const ApiFailure(
          'Servidor indisponível. Verifique sua conexão e tente novamente.');
    }
  }
```

### 6. Autenticação, extração do JWT e requisições protegidas (401)

**O que faz:** `login` envia JSON para `/auth/login`, identifica credenciais inválidas (`401`/`403`), valida a estrutura compacta do JWT em `access_token` e grava no `TokenStore` (se a gravação falhar, bloqueia a sessão e mantém o usuário no login). `_authorizedRequest` lê o token antes de cada chamada protegida (`/me`, `/movies`, `/favorites`), envia `Authorization: Bearer <token>` e, diante de `401`, executa `logout()`, notifica listeners (limpando favoritos em memória) e dispara `onSessionExpired`.

[lib/services/api_service.dart — linhas 155–227](../../lib/services/api_service.dart#L155-L227)

```dart
  Future<void> login(String email, String password) async {
    final response = await _request('POST', loginPath,
        body: {'email': email, 'password': password});
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ApiFailure('E-mail ou senha inválidos.');
    }
    _checkStatus(response);
    final json = _json(response);
    final token = json is Map<String, dynamic> ? json['access_token'] : null;
    if (token is! String ||
        token.isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$')
            .hasMatch(token)) {
      throw const ApiFailure('A API não retornou um JWT Access Token válido.');
    }
    try {
      await tokens.write(token);
      _blocked = false;
      currentUser = null;
      sessionVersion++;
      notifyListeners();
    } on Exception {
      _blocked = true;
      throw const ApiFailure(
          'Não foi possível salvar a sessão no armazenamento seguro. Tente entrar novamente.');
    }
  }

  Future<http.Response> _authorizedRequest(String method, String path,
      {Map<String, dynamic>? body}) async {
    final version = sessionVersion;
    if (_blocked) throw const SessionExpired();
    String? token;
    try {
      token = await tokens.read();
    } on Exception {
      throw const ApiFailure(
          'Não foi possível ler o armazenamento seguro. Tente novamente.');
    }
    if (token == null || token.isEmpty) {
      onSessionExpired?.call('Sessão ausente. Entre novamente.');
      throw const SessionExpired('Sessão ausente. Entre novamente.');
    }
    if (version != sessionVersion) throw const SessionExpired();
    final response = await _request(method, path, token: token, body: body);
    if (version != sessionVersion) throw const SessionExpired();
    if (response.statusCode == 401) {
      String message = 'Sessão expirada. Entre novamente.';
      try {
        await logout();
      } on ApiFailure {
        message =
            'Sessão expirada. Falha ao remover o token do armazenamento seguro. Entre novamente ou tente limpar a sessão.';
      }
      onSessionExpired?.call(message);
      throw SessionExpired(message);
    }
    _checkStatus(response);
    return response;
  }
```

### 7. Desserialização JSON e exibição de quatro atributos por filme

**O que faz:** `Movie.fromJson` valida os campos obrigatórios (`id`, `title`, `year`, `rating`) e lê os campos adicionais (`director`, `description`, `original_title`, `duration`, `genres`). `ConsultationScreen` carrega identidade (`/me`), filmes (`/movies`) e favoritos (`/favorites`) e exibe **título, ano, nota e direção** em cada item da lista (acima do mínimo de três atributos exigido pela issue).

[lib/models/movie.dart — linhas 25–50](../../lib/models/movie.dart#L25-L50)

```dart
  factory Movie.fromJson(dynamic json) {
    if (json is! Map<String, dynamic> ||
        json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        json['title'] is! String ||
        (json['title'] as String).trim().isEmpty ||
        json['year'] is! int ||
        json['rating'] is! num) {
      throw const FormatException();
    }
    return Movie(
        id: json['id'],
        title: json['title'],
        year: json['year'],
        rating: (json['rating'] as num).toDouble(),
        originalTitle:
            json['original_title'] is String ? json['original_title'] : '',
        director: json['director'] is String ? json['director'] : '',
        description: json['description'] is String ? json['description'] : '',
        duration: json['duration'] is String ? json['duration'] : '',
        genres: json['genres'] is List &&
                (json['genres'] as List).every((g) => g is String)
            ? List<String>.from(json['genres'])
            : const [],
        colors: const [Color(0xFF1F2A44), Color(0xFF8FA6C9)]);
  }
```

[lib/screens/consultation_screen.dart — linhas 184–229](../../lib/screens/consultation_screen.dart#L184-L229)

```dart
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: visible.length,
                              itemBuilder: (_, index) {
                                final movie = visible[index];
                                return ListTile(
                                  title: Text(movie.title),
                                  subtitle: Text(
                                      'Ano: ${movie.year}\nNota: ${movie.rating}\nDireção: ${movie.director}'),
                                  isThreeLine: true,
                                  trailing: IconButton(
                                    tooltip: favorites.isFavorite(movie)
                                        ? 'Remover dos favoritos'
                                        : 'Adicionar aos favoritos',
                                    onPressed: favorites.busy
                                        ? null
                                        : () => _toggle(movie),
                                    icon: Icon(favorites.isFavorite(movie)
                                        ? Icons.favorite
                                        : Icons.favorite_border),
                                  ),
                                  onTap: () => Navigator.of(context).pushNamed(
                                      RouteNames.details,
                                      arguments: movie),
                                );
                              },
                            ))),
```

### 8. API própria FastAPI com validação JWT e isolamento por conta

**O que faz:** O backend em [backend/app.py](../../backend/app.py) persiste contas com hash **Argon2id** e favoritos vinculados à chave composta `(user_id, movie_id)` em SQLite. Toda rota protegida valida assinatura `HS256`, expiração, emissor (`cinepocket-api`), audiência (`cinepocket-app`) e existência do usuário no banco. O cliente nunca envia `user_id` para manipular favoritos (`extra='forbid'`).

[backend/app.py — linhas 161–177](../../backend/app.py#L161-L177)

```python
    def current_user(credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]):
        if credentials is None or credentials.scheme.lower() != 'bearer':
            raise unauthorized()
        try:
            claims = jwt.decode(credentials.credentials, secret, algorithms=['HS256'],
                                issuer='cinepocket-api', audience='cinepocket-app',
                                options={'require': ['sub', 'exp', 'iat', 'iss', 'aud', 'jti']})
            uid = str(UUID(claims['sub']))
        except (jwt.InvalidTokenError, ValueError, TypeError, KeyError) as error:
            raise unauthorized() from error
        with db() as connection:
            row = connection.execute('SELECT id, name, email FROM users WHERE id = ?', (uid,)).fetchone()
        if row is None:
            raise unauthorized()
        return User(**dict(row))
```

### 9. Configurações de plataforma (Android e Apple)

**O que faz:** O manifesto Android declara permissão de internet, bloqueia tráfego HTTP sem criptografia (`usesCleartextTraffic="false"`) e desativa backup automático (`allowBackup="false"`). As configurações de Keychain e rede cliente para Apple estão em [ios/Runner/Runner.entitlements](../../ios/Runner/Runner.entitlements), [macos/Runner/DebugProfile.entitlements](../../macos/Runner/DebugProfile.entitlements) e [macos/Runner/Release.entitlements](../../macos/Runner/Release.entitlements).

[android/app/src/main/AndroidManifest.xml — linhas 1–8](../../android/app/src/main/AndroidManifest.xml#L1-L8)

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:allowBackup="false"
        android:usesCleartextTraffic="false"
        android:label="cinepocket"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
```

## Padrões de projeto adotados

O projeto aplica padrões leves e idiomáticos de Dart/Flutter e FastAPI sem introduzir abstrações desnecessárias:

- **Factory (`Factory Constructor` e `Application Factory`):**
  - `Movie.fromJson` ([lib/models/movie.dart — linhas 25–50](../../lib/models/movie.dart#L25-L50)) e `SessionUser.fromJson` ([lib/services/api_service.dart — linhas 42–52](../../lib/services/api_service.dart#L42-L52)) centralizam a validação estrutural do JSON e a criação segura dos modelos de domínio.
  - `create_app(...)` ([backend/app.py — linhas 112–244](../../backend/app.py#L112-L244)) atua como *Application Factory*, permitindo instanciar a API FastAPI com banco SQLite, segredo JWT, TTL e fonte de catálogo configuráveis para execução local, implantação e testes isolados.
- **Strategy / Injeção de Dependência:**
  - A abstração `TokenStore` ([lib/services/api_service.dart — linhas 19–35](../../lib/services/api_service.dart#L19-L35)) desacopla a regra de sessão do armazenamento concreto (`SecureTokenStore` com `flutter_secure_storage` em execução real e `MemoryTokens` nos testes automatizados). O mesmo vale para `http.Client` (`MockClient` nos testes).
- **Observer (`ChangeNotifier` + `Provider`):**
  - `ApiService` notifica `FavoritesProvider` ([lib/providers/favorites_provider.dart — linhas 11–21](../../lib/providers/favorites_provider.dart#L11-L21)) sempre que `sessionVersion` muda (login, logout ou HTTP 401), garantindo limpeza automática do cache de favoritos da conta anterior.

## Evidências nos testes automatizados

- **35 testes Flutter** (`flutter test`) sem avisos no `flutter analyze`:
  - [test/api_service_test.dart](../../test/api_service_test.dart): login POST JSON, gravação e leitura no `TokenStore`, cabeçalho `Authorization: Bearer`, rejeição de credenciais inválidas, 401 com exclusão do token (inclusive quando a exclusão falha), falhas de leitura/gravação, JSON inválido, falha de rede/servidor indisponível, timeout, códigos HTTP 302/403/500/503 e rejeição de URLs sem HTTPS.
  - [test/auth_flow_test.dart](../../test/auth_flow_test.dart): login → consulta protegida → 401 ao alterar favorito limpa token, dados e pilha de navegação; falha ao gravar token mantém usuário no login.
  - [test/public_api_test.dart](../../test/public_api_test.dart): favoritos com Bearer, limpeza no logout, 401 em mutação de favorito, falha 503 sem corromper estado local e busca autenticada `/movies?q=...`.
  - [test/screens_ux_test.dart](../../test/screens_ux_test.dart): cadastro de conta (sucesso e conflito 409), limpeza de snackbar no login, tela de detalhes com favoritos e botão de limpar busca.
  - [test/widget_test.dart](../../test/widget_test.dart): troca de contas A → B → A garantindo isolamento e restauração dos favoritos.
- **8 testes do backend** (`python -m pytest backend/tests -v`) em [backend/tests/test_api.py](../../backend/tests/test_api.py): cadastro/login, hash Argon2id, isolamento de favoritos entre contas, persistência após reinicialização da API, 401 sem token ou com JWT expirado/adulterado/emissor ou audiência incorretos, rejeição de tentativa de escolher `user_id` e tratamento de indisponibilidade do catálogo externo (503).

## Validação realizada e limitações

- **Validado:** `flutter analyze` (0 avisos), `flutter test` (**35 testes aprovados**), `pytest backend/tests` (**8 testes aprovados**), fluxo Web com API HTTPS local documentado em [docs/entrega/README.md](../../docs/entrega/README.md) e relatório em [docs/entrega/relatorio-seguranca.pdf](../../docs/entrega/relatorio-seguranca.pdf).
- **Limitações registradas:**
  - Os testes automatizados do Flutter utilizam `MockClient` e `MemoryTokens`; o funcionamento do cofre nativo (`Keystore` no Android e `Keychain` no iOS) ainda precisa ser validado em aparelho ou emulador real.
  - A API é didática para desenvolvimento local em HTTPS (`127.0.0.1:8443` com certificado autoassinado) e não inclui refresh token, revogação de JWT no servidor ou recuperação de senha.
