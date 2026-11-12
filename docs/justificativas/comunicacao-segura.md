# Comunicação segura — issue #3

## Execução e contrato da API

A issue não informa uma API, credenciais de teste ou esquema JSON. O cliente
implementa o contrato abaixo; a API deve ser fornecida separadamente. Sem
`API_BASE_URL`, o login mostra um erro de configuração e não envia credenciais.
O catálogo antigo continua disponível como demonstração visual, identificado
explicitamente e separado da consulta real.

O Dockerfile fixa Flutter 3.47.9; use essa versão para reproduzir o ambiente
de validação e o lockfile.

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=https://api.seu-dominio.com
```

Também é possível configurar `API_LOGIN_PATH` (padrão `/auth/login`) e
`API_MOVIES_PATH` (padrão `/movies`). Os caminhos devem iniciar com `/`.
Uma base como `https://host/api/v1` preserva o prefixo `/api/v1`.
Essas configurações são públicas; não colocar segredos em `--dart-define`.

### Autenticação

`POST /auth/login`, `Content-Type: application/json`, corpo:

```json
{"email":"usuario@exemplo.com","password":"senha informada no formulário"}
```

Resposta 200 (ou outro 2xx): objeto com `access_token` contendo um JWT assinado
no formato compacto de três segmentos. Exemplo do formato de resposta:

```json
{"access_token":"<header-base64url>.<payload-base64url>.<signature-base64url>"}
```

Esse exemplo é ilustrativo e não é um token utilizável. O backend deve validar
credenciais e emitir/verificar assinatura, expiração, emissor e audiência. O app
verifica apenas a estrutura do token recebido; isso não autentica sua assinatura.
Credenciais inválidas devem retornar 401 (403 no login também é tratado).
Não há refresh token neste escopo: uma sessão expirada exige novo login.

### Consulta protegida

`GET /movies`, `Accept: application/json`, `Authorization: Bearer <token>`.
O token é lido do armazenamento seguro antes da consulta. Resposta 200:

```json
[
  {"title":"Duna: Parte 2","year":2024,"rating":8.8},
  {"title":"Interestelar","year":2014,"rating":8.7}
]
```

`title` deve ser texto não vazio, `year` inteiro e `rating` numérico. A lista
mostra os três atributos, aceita lista vazia e rejeita estrutura incompatível.
O backend deve retornar 401 para token ausente, inválido ou expirado; 403 na
consulta significa acesso negado e não apaga uma sessão válida.

Ao receber 401, o app tenta remover o token, descarta os dados da tela e limpa a
pilha de navegação até o login. Se a remoção falhar, bloqueia a reutilização do
token em memória e informa o erro. O login oferece “Limpar sessão armazenada”
para tentar novamente. Uma nova execução começa sempre no login, sem recuperar
automaticamente tokens que possam ter permanecido após falha de remoção.
Logout segue o mesmo comportamento de exclusão e bloqueio. A senha não é
persistida nem registrada em logs e seu campo é limpo após autenticação.

## Erros e recuperação

| Situação | Comportamento |
| --- | --- |
| Rede indisponível, DNS ou falha TLS | Mensagem de indisponibilidade; permite tentar novamente |
| Resposta demora mais de 15 segundos | Mensagem de timeout, abrangendo envio e leitura da resposta |
| Login 401/403 | E-mail ou senha inválidos, permanece no formulário |
| Consulta 401 | Remove token e retorna automaticamente ao login |
| HTTP 5xx | Mensagem de servidor indisponível |
| Outros códigos não 2xx, inclusive redirects | Erro de requisição, sem interpretar como dados |
| JSON inválido ou formato incompatível | Mensagem de resposta/dados inválidos |
| Leitura segura falha | Não envia GET; oferece nova tentativa |
| Gravação segura falha | Não abre consulta; permite repetir login |
| Exclusão segura falha | Bloqueia sessão local, retorna ao login e permite repetir exclusão |

As operações possuem indicador de progresso e desabilitam botões durante o
processamento para evitar envio duplicado. Respostas e exceções internas não
são mostradas diretamente nem registradas com credenciais.

## HTTPS e proteção em trânsito

HTTPS usa TLS para confidencialidade e integridade do tráfego e autenticação do
servidor por certificado. Protege credenciais, cabeçalhos e JSON entre o cliente
e o ponto onde TLS termina. Não protege dados já descriptografados no servidor,
logs, um dispositivo comprometido ou o conteúdo em repouso.

O cliente só aceita URLs HTTPS e não segue redirecionamentos; portanto não
reenvia credenciais deliberadamente a um destino HTTP. Não há bypass de
certificados. Android bloqueia tráfego cleartext. Na Web, políticas de redirect
e TLS também dependem do navegador; a API deve responder diretamente no endpoint
HTTPS e permitir CORS para a origem do app, POST/GET e cabeçalhos
`Content-Type`/`Authorization` (incluindo preflight OPTIONS).

HTTP permitiria interceptação e alteração das credenciais e do Bearer token,
mesmo numa rede de desenvolvimento. Este projeto não habilita essa exceção.
Para desenvolvimento local, use HTTPS com certificado confiável pelo dispositivo
ou um proxy HTTPS de desenvolvimento. Em produção, configure certificado válido,
TLS atualizado, renovação automática e HTTPS também entre proxy e backend quando
atravessarem uma rede não confiável. Redirecionar HTTP para HTTPS não desfaz o
vazamento de uma primeira requisição enviada sem TLS.

## SharedPreferences versus flutter_secure_storage

SharedPreferences armazena pares simples para preferências: tema, idioma,
configuração da interface e última pesquisa não sensível. Não oferece um cofre
criptográfico para segredos, e sua documentação não garante persistência imediata
de dados críticos. Um token é uma credencial Bearer: quem o obtém pode usá-lo.
Por isso não deve ser salvo em preferências comuns, código-fonte ou logs.

`flutter_secure_storage` usa mecanismos de armazenamento seguro por plataforma,
como Keychain nas plataformas Apple e criptografia com chaves protegidas no
Android. O projeto usa esse pacote exclusivamente para o token; não persiste a
senha. HTTPS cuida do trânsito, e o armazenamento seguro cuida do token em
repouso. Nenhum deles elimina todos os riscos de um dispositivo comprometido.

A configuração Android desabilita backups do app para evitar restauração de
material criptografado sem as chaves correspondentes. iOS/macOS incluem os
entitlements de Keychain; macOS também permite conexões de rede de saída.
Verifique assinatura e provisionamento no Xcode ao executar em dispositivo.
Linux exige as dependências do plugin (`libsecret-1-dev`, `libjsoncpp-dev` no
build e um serviço Secret Service/keyring disponível na sessão). Na Web,
execute em HTTPS ou localhost: o armazenamento depende do navegador e não é
imune a XSS. A origem deve ser confiável e scripts devem ser controlados.

Fontes: [SharedPreferences](https://pub.dev/packages/shared_preferences),
[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage),
[configuração da versão 10](https://pub.dev/packages/flutter_secure_storage/versions/10.0.0).

## Análise do pacote Encrypt

Não adicionamos `encrypt`: para credenciais enviadas à própria API e o token
local, TLS validado e o armazenamento seguro cobrem as necessidades deste
escopo. Criptografar o JSON com uma chave fixa embutida no app não acrescentaria
uma proteção confiável; a chave poderia ser extraída e precisaria ser gerenciada
pelo backend também. JWT assinado não é, por si só, criptografado: suas claims
não devem carregar segredos.

Uma camada adicional seria pertinente para conteúdo que precise permanecer
cifrado após terminar TLS (por exemplo, mensagens entre usuários que o servidor
não deva ler), arquivos sensíveis armazenados fora do cofre, ou campos que
precisem atravessar intermediários sem revelar o conteúdo. Essas situações
exigem um protocolo definido, acordo de chaves, autenticação, rotação, revogação,
nonces únicos e criptografia autenticada. Instalar um pacote sozinho não oferece
criptografia ponta a ponta.

Vantagens: restringir leitura por intermediários e proteger conteúdo fora do
canal TLS. Desvantagens: maior complexidade de chaves e recuperação, custo de
processamento, payload maior, dificuldade de busca no servidor e risco de erros
criptográficos. Caso esse requisito apareça, deve ser projetado e revisado como
um protocolo interoperável com o backend; não se deve substituir HTTPS.

## Verificação

```sh
flutter analyze
flutter test
flutter build web
```

Os testes usam HTTP e armazenamento substituíveis para verificar contrato,
Bearer, sucesso, 401, falhas de leitura/gravação/exclusão, timeout, rede, JSON,
HTTPS obrigatório e navegação. Esses testes não substituem validação do plugin
nativo em dispositivo nem teste integrado com a API real.

Roteiro manual: configurar API compatível; entrar com credenciais válidas;
confirmar título/ano/nota; atualizar a lista; expirar o token no servidor e
atualizar novamente; confirmar retorno ao login e ausência de retorno à lista
pelo botão voltar. Repetir com senha errada, servidor parado, resposta lenta,
JSON malformado, lista vazia e logout. Testar Keychain/Keystore nos dispositivos
alvo e confirmar que não há token em preferências comuns ou logs.
