# Implementação de comunicação segura

## Objetivo e abordagem

A implementação da issue #3 adiciona autenticação JWT, armazenamento seguro do token e consulta de filmes em uma API REST protegida. O serviço `ApiService` concentra as requisições e as regras da sessão; as telas recebem os dados, apresentam o resultado e conduzem a navegação.

Antes, o login era demonstrativo e o catálogo usava dados simulados. Agora, o aplicativo inicia no login e abre a consulta da API após a autenticação. O catálogo anterior continua acessível como demonstração visual.

**Limite da implementação:** a issue não informa uma API nem credenciais. O app depende de um servidor HTTPS compatível, configurado por `API_BASE_URL`. O [contrato da API e a análise de segurança](comunicacao-segura.md) descrevem os formatos e a configuração. Os testes usam respostas simuladas: não comprovam integração com um servidor real nem o funcionamento do armazenamento nativo em dispositivo.

## Código comentado para conduzir a apresentação

Os blocos reproduzem trechos dos arquivos do projeto; os comentários explicativos foram adicionados a esta documentação para facilitar a apresentação. Cada link aponta para o arquivo correspondente e as linhas indicadas. Alguns blocos são recortes de métodos maiores. Os testes referenciados são evidências automatizadas, sem capturas de tela ou alegação de execução em uma API real.

### 1. Adicionar as dependências

**O que faz:** `http` fornece o cliente para as requisições e `flutter_secure_storage` oferece armazenamento seguro para o token.

[pubspec.yaml — linhas 9–14](../../pubspec.yaml#L9-L14)

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  # Cliente para comunicação com a API.
  http: ^1.6.0
  flutter_secure_storage: ^10.0.0
```

### 2. Iniciar no login e disponibilizar o serviço

**O que faz:** `Provider<ApiService>` disponibiliza o serviço às telas. A rota inicial abre `LoginScreen`; a rota de consulta é registrada no aplicativo.

[lib/main.dart — linhas 30–48](../../lib/main.dart#L30-L48)

```dart
  @override
  Widget build(BuildContext context) {
    // Compartilha o serviço de API entre as telas.
    return Provider<ApiService>(
        create: (_) => api ?? ApiService(),
        dispose: (_, service) => service.close(),
        child: MaterialApp(
          title: 'CinePocket',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          // Rota inicial da aplicação
          initialRoute: RouteNames.login,
          onGenerateInitialRoutes: (_) =>
              [MaterialPageRoute(builder: (_) => const LoginScreen())],
          // 1. Mapeamento centralizado de rotas no MaterialApp
          routes: {
            RouteNames.login: (context) => LoginScreen(
                message: ModalRoute.of(context)?.settings.arguments as String?),
            RouteNames.consultation: (_) => const ConsultationScreen(),
            RouteNames.home: (context) => const MainShell(),
```

### 3. Receber e validar as credenciais

**O que faz:** O formulário coleta e-mail e senha, valida os campos e oculta a senha. Enquanto há uma operação em andamento, os campos ficam desabilitados.

[lib/screens/login_screen.dart — linhas 84–109](../../lib/screens/login_screen.dart#L84-L109)

```dart
                    // Recebe o e-mail e valida o formato antes do envio.
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
```

### 4. Autenticar e abrir a consulta

**O que faz:** O formulário chama `login` no serviço. Após o sucesso, limpa o campo de senha e abre a consulta, removendo a tela anterior da pilha. Caso ocorra erro, apresenta a mensagem.

[lib/screens/login_screen.dart — linhas 28–47](../../lib/screens/login_screen.dart#L28-L47)

```dart
  Future<void> _login() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Envia as credenciais e aguarda a gravação segura do token.
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

### 5. Configurar a API e exigir HTTPS

**O que faz:** `API_BASE_URL`, `API_LOGIN_PATH` e `API_MOVIES_PATH` configuram o servidor e os endpoints. A validação rejeita URLs sem HTTPS, caminhos inválidos e URL com credenciais embutidas.

[lib/services/api_service.dart — linhas 64–94](../../lib/services/api_service.dart#L64-L94)

```dart
  ApiService({
    http.Client? client,
    TokenStore? tokens,
    this.baseUrl = const String.fromEnvironment('API_BASE_URL'),
    this.loginPath = const String.fromEnvironment('API_LOGIN_PATH',
        defaultValue: '/auth/login'),
    this.moviesPath = const String.fromEnvironment('API_MOVIES_PATH',
        defaultValue: '/movies'),
    this.timeout = const Duration(seconds: 15),
  })  : client = client ?? http.Client(),
        tokens = tokens ?? SecureTokenStore();

  Uri _endpoint(String path) {
    // Rejeita configurações inválidas ou que não usem HTTPS.
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
```

### 6. Enviar requisições e tratar falhas de conexão

**O que faz:** A requisição aceita JSON, envia corpo JSON quando necessário e inclui o cabeçalho Bearer quando recebe um token. Redirecionamentos estão desativados; timeout e falhas de conexão recebem mensagens próprias.

[lib/services/api_service.dart — linhas 96–118](../../lib/services/api_service.dart#L96-L118)

```dart
  Future<http.Response> _request(String method, String path,
      {String? token, Map<String, String>? body}) async {
    // Monta a requisição e impede redirecionamentos automáticos.
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

### 7. Extrair e armazenar o JWT

**O que faz:** O login envia as credenciais via POST, identifica credenciais inválidas, interpreta o JSON e verifica o formato compacto do token antes de gravá-lo. A verificação de formato não valida a assinatura; essa validação é responsabilidade do servidor.

[lib/services/api_service.dart — linhas 139–162](../../lib/services/api_service.dart#L139-L162)

```dart
  Future<void> login(String email, String password) async {
    // Envia e-mail e senha para o endpoint de autenticação.
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
    } on Exception {
      _blocked = true;
      throw const ApiFailure(
          'Não foi possível salvar a sessão no armazenamento seguro. Tente entrar novamente.');
    }
  }
```

### 8. Usar o armazenamento seguro

**O que faz:** `SecureTokenStore` implementa leitura, gravação e remoção do token com `FlutterSecureStorage`. A interface `TokenStore` também permite substituir o armazenamento nos testes.

[lib/services/api_service.dart — linhas 17–33](../../lib/services/api_service.dart#L17-L33)

```dart
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

// Implementa as operações do token com armazenamento seguro.
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

### 9. Consultar a API e tratar token expirado

**O que faz:** O serviço lê o token antes do GET. Ao receber 401, tenta apagá-lo e sinaliza sessão expirada. Se a exclusão falhar, a mensagem informa o problema e `logout()` bloqueia novas consultas com o token durante o processo atual.

[lib/services/api_service.dart — linhas 164–193](../../lib/services/api_service.dart#L164-L193)

```dart
  // Bloqueia a sessão antes de tentar apagar o token.
  Future<void> logout() async {
    _blocked = true;
    try {
      await tokens.delete();
    } on Exception {
      throw const ApiFailure(
          'Não foi possível remover a sessão do armazenamento seguro. Tente novamente.');
    }
  }

  Future<List<ProtectedMovie>> fetchMovies() async {
    if (_blocked) throw const SessionExpired();
    String? token;
    try {
      token = await tokens.read();
    } on Exception {
      throw const ApiFailure(
          'Não foi possível ler o armazenamento seguro. Tente novamente.');
    }
    if (token == null || token.isEmpty) throw const SessionExpired();
    final response = await _request('GET', moviesPath, token: token);
    if (response.statusCode == 401) {
      try {
        await logout();
      } on ApiFailure {
        throw const SessionExpired(
            'Sessão expirada. Falha ao remover o token do armazenamento seguro. Entre novamente ou tente limpar a sessão.');
      }
      throw const SessionExpired();
    }
```

### 10. Interpretar os dados recebidos

**O que faz:** `ProtectedMovie.fromJson` valida título, ano e nota. A consulta exige uma lista e converte cada objeto; uma estrutura incompatível gera uma mensagem de erro.

[lib/services/api_service.dart — linhas 35–52](../../lib/services/api_service.dart#L35-L52)

```dart
class ProtectedMovie {
  final String title;
  final int year;
  final double rating;
  const ProtectedMovie(this.title, this.year, this.rating);

  // Valida os três atributos antes de construir o filme.
  factory ProtectedMovie.fromJson(dynamic json) {
    if (json is! Map<String, dynamic> ||
        json['title'] is! String ||
        (json['title'] as String).trim().isEmpty ||
        json['year'] is! int ||
        json['rating'] is! num) {
      throw const FormatException('Invalid movie');
    }
    return ProtectedMovie(
        json['title'], json['year'], (json['rating'] as num).toDouble());
  }
}
```

### 11. Converter a lista JSON

**O que faz:** Após verificar o status, o serviço interpreta a resposta como uma lista de filmes e informa quando a estrutura não corresponde ao contrato.

[lib/services/api_service.dart — linhas 194–202](../../lib/services/api_service.dart#L194-L202)

```dart
    _checkStatus(response);
    // Converte o JSON recebido em objetos de filme.
    final json = _json(response);
    try {
      if (json is! List) throw const FormatException('Expected list');
      return json.map(ProtectedMovie.fromJson).toList();
    } on FormatException {
      throw const ApiFailure('A API retornou dados de filmes inválidos.');
    }
  }
```

### 12. Atualizar a interface e retornar ao login

**O que faz:** A tela consulta a API ao iniciar. Ela apresenta erros comuns na própria tela e, ao receber `SessionExpired`, navega para o login removendo a pilha anterior.

[lib/screens/consultation_screen.dart — linhas 17–45](../../lib/screens/consultation_screen.dart#L17-L45)

```dart
  @override
  void initState() {
    super.initState();
    // Carrega os filmes assim que a tela é criada.
    _load();
  }

  void _login(String? message) {
    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        RouteNames.login, (_) => false,
        arguments: message);
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
      _movies = [];
    });
    try {
      final movies = await context.read<ApiService>().fetchMovies();
      if (mounted) setState(() => _movies = movies);
    } on SessionExpired catch (error) {
      if (mounted) _login(error.message);
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
```

### 13. Apresentar três atributos por filme

**O que faz:** A lista mostra título, ano e nota. A tela também oferece atualização e informa quando o resultado está vazio.

[lib/screens/consultation_screen.dart — linhas 84–97](../../lib/screens/consultation_screen.dart#L84-L97)

```dart
                : _movies.isEmpty
                    ? const Center(child: Text('Nenhum filme encontrado.'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _movies.length,
                            itemBuilder: (_, index) {
                              final movie = _movies[index];
                              // Mostra título, ano e nota de cada filme.
                              return ListTile(
                                  title: Text(movie.title),
                                  subtitle: Text('Ano: ${movie.year}'),
                                  trailing: Text('Nota: ${movie.rating}'));
                            })),
```

### 14. Remover a sessão no logout

**O que faz:** A ação de sair tenta excluir o token e volta ao login. Se a exclusão falhar, encaminha a mensagem de erro ao formulário.

[lib/screens/consultation_screen.dart — linhas 47–56](../../lib/screens/consultation_screen.dart#L47-L56)

```dart
  Future<void> _logout() async {
    setState(() => _busy = true);
    String? message;
    try {
      // Solicita a exclusão do token no armazenamento seguro.
      await context.read<ApiService>().logout();
    } on ApiFailure catch (error) {
      message = error.message;
    }
    if (mounted) _login(message);
  }
```

### 15. Configurar acesso à rede no Android

**O que faz:** O manifesto declara permissão de internet, desabilita tráfego HTTP sem criptografia e desativa backup do aplicativo para evitar restaurar dados protegidos sem as respectivas chaves.

[android/app/src/main/AndroidManifest.xml — linhas 1–8](../../android/app/src/main/AndroidManifest.xml#L1-L8)

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permite acesso à rede para consultar a API. -->
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:allowBackup="false"
        android:usesCleartextTraffic="false"
        android:label="cinepocket"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
```

As configurações de Keychain para plataformas Apple estão em [ios/Runner/Runner.entitlements](../../ios/Runner/Runner.entitlements), [macos/Runner/DebugProfile.entitlements](../../macos/Runner/DebugProfile.entitlements) e [macos/Runner/Release.entitlements](../../macos/Runner/Release.entitlements). O projeto iOS associa o arquivo de entitlements às configurações de build em [ios/Runner.xcodeproj/project.pbxproj](../../ios/Runner.xcodeproj/project.pbxproj).

## Evidências nos testes automatizados

Os testes usam `MockClient` e `MemoryTokens`: o primeiro simula a API, e o segundo simula leitura, gravação e exclusão. Eles verificam a lógica do cliente sem acessar a rede ou o armazenamento nativo.

### 16. Evidência do POST, armazenamento e GET com Bearer

**O que faz:** O teste verifica o corpo do login, a gravação do JWT, o cabeçalho Authorization e os três atributos retornados.

[test/api_service_test.dart — linhas 42–64](../../test/api_service_test.dart#L42-L64)

```dart
  test('login POST JSON saves JWT; GET reads storage and sends Bearer',
      () async {
    // Simula a API e confere os dados enviados pelo aplicativo.
    final api = service((request) async {
      expect(request.followRedirects, isFalse);
      if (request.method == 'POST') {
        expect(request.url.path, '/auth/login');
        expect(jsonDecode(request.body),
            {'email': 'user@example.test', 'password': 'secret'});
        expect(request.headers['Content-Type'], 'application/json');
        return http.Response(jsonEncode({'access_token': testToken}), 200);
      }
      expect(request.method, 'GET');
      expect(request.url.path, '/movies');
      expect(request.headers['Authorization'], 'Bearer $testToken');
      return http.Response('[{"title":"Filme","year":2026,"rating":8.5}]', 200);
    });
    await api.login('user@example.test', 'secret');
    expect(store.value, testToken);
    final movies = await api.fetchMovies();
    expect(movies.single.title, 'Filme');
    expect(movies.single.year, 2026);
    expect(movies.single.rating, 8.5);
  });
```

### 17. Evidência do retorno ao login após 401

**O que faz:** O teste de interface preenche o formulário, verifica a lista e seus três atributos, simula a expiração e confirma a exclusão do token, o retorno ao login e a remoção da tela anterior.

[test/auth_flow_test.dart — linhas 28–47](../../test/auth_flow_test.dart#L28-L47)

```dart
    await tester.pumpWidget(CinePocketApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).first, 'user@example.test');
    await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Cinema'), findsOneWidget);
    expect(find.text('Ano: 2026'), findsOneWidget);
    expect(find.text('Nota: 9.0'), findsOneWidget);
    // Simula a expiração e confirma o retorno seguro ao login.
    expired = true;
    await tester.tap(find.byTooltip('Atualizar'));
    await tester.pumpAndSettle();
    expect(store.value, isNull);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Sessão expirada. Entre novamente.'), findsOneWidget);
    expect(find.text('Cinema'), findsNothing);
    expect(Navigator.of(tester.element(find.text('Entrar'))).canPop(), isFalse);
  });
```

Outras evidências estão em [test/api_service_test.dart](../../test/api_service_test.dart): credenciais inválidas, falhas de leitura/gravação/exclusão, token ausente, JSON inválido, falha de rede, timeout, códigos HTTP e rejeição de URL insegura. [test/auth_flow_test.dart](../../test/auth_flow_test.dart) também verifica que uma falha ao gravar o token mantém o usuário no login.

## Proteção e decisões

- **HTTPS:** protege os dados em trânsito entre o cliente e o ponto de terminação TLS. O app exige HTTPS na [validação da URL](../../lib/services/api_service.dart#L76-L94).
- **SharedPreferences:** adequado para preferências não sensíveis, como tema e idioma. Não é um cofre para tokens ou credenciais. O token usa [flutter_secure_storage](../../lib/services/api_service.dart#L23-L33).
- **Encrypt:** não foi adicionado. TLS e armazenamento seguro atendem ao escopo implementado; uma camada adicional pode fazer sentido para conteúdo que deva permanecer cifrado mesmo depois da terminação TLS, desde que exista um protocolo de gerenciamento de chaves. A análise completa está em [comunicacao-segura.md](comunicacao-segura.md#análise-do-pacote-encrypt).

## Sequência sugerida para demonstrar

1. Configure uma API HTTPS que siga o [contrato documentado](comunicacao-segura.md#execução-e-contrato-da-api).
2. Mostre a tela de login e explique a validação dos campos e a chamada a `ApiService.login`.
3. Mostre a resposta do servidor sendo interpretada e o token sendo salvo em armazenamento seguro.
4. Após entrar, mostre a lista e identifique título, ano e nota. Explique a leitura do token e o cabeçalho Bearer no GET.
5. Invalide o token no servidor e atualize a lista. Mostre a mensagem de sessão expirada e o retorno automático ao login.
6. Apresente os testes de contrato e de navegação como evidências automatizadas.

## Validação realizada e limitações

Na implementação anterior foram executados `flutter analyze`, `flutter test` e `flutter build web` com Flutter 3.47.9 em Docker. A análise terminou sem avisos, os **29 testes passaram** e o build web foi concluído. O build emitiu um aviso relacionado à fonte Cupertino; ele não impediu a compilação.

Essas evidências cobrem o cliente e a interface com dependências simuladas. A execução completa ainda exige uma API HTTPS compatível e credenciais; a integração com o servidor real e o Keychain/Keystore em dispositivo não foram validados.
