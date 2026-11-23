# CinePocket API

API própria para cumprir o ciclo de autenticação da atividade. Filmes vêm da
Studio Ghibli API; contas e favoritos são persistidos em SQLite.

## Executar em HTTPS local

Na raiz do repositório, com Python 3.12+ e OpenSSL:

```sh
python -m venv backend/.venv
backend/.venv/bin/pip install -r backend/requirements.txt
backend/.venv/bin/python -m backend.run_dev
```

O script gera certificado e chave JWT locais em `backend/.certs/` (ignorados pelo
Git). A chave JWT permanece entre reinicializações; nenhuma senha é pré-definida.
Cadastre duas contas pela tela **Criar conta**. A API escuta somente em loopback.

**Antes de usar o aplicativo, confie no certificado `backend/.certs/cert.pem`
no navegador/dispositivo de desenvolvimento.** Somente abrir uma URL HTTPS não
estabelece confiança num certificado autoassinado. No Android, prefira uma API
com certificado público válido; configurar certificados locais depende da versão
do sistema e da política de confiança do aplicativo. Não há bypass TLS no Flutter.

Para rodar o Flutter Web:

```sh
flutter pub get
flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=https://localhost:8443
```

O servidor permite a origem Web `http://localhost:8080` por padrão. O endereço
HTTP é o servidor local da interface; todas as chamadas REST continuam HTTPS.
O armazenamento seguro Web requer localhost ou HTTPS.

Para emulador Android, localhost do host é normalmente `10.0.2.2`:
`--dart-define=API_BASE_URL=https://10.0.2.2:8443`. Será necessário publicar a API
num endereço acessível ao emulador e configurar certificado confiável. O servidor
local escuta em `127.0.0.1`; para dispositivos físicos, use uma implantação HTTPS
ou adapte o endereço de escuta e o certificado ao IP de desenvolvimento.

## Configuração de implantação

```sh
JWT_SECRET='<segredo aleatório de pelo menos 32 bytes>' \
CORS_ORIGINS='https://app.exemplo.com' \
DATABASE_PATH='/dados/cinepocket.sqlite3' \
JWT_TTL_SECONDS=900 \
backend/.venv/bin/uvicorn backend.app:create_app --factory --host 127.0.0.1 --port 8000
```

Esses valores são do servidor. Não inclua a chave JWT em `--dart-define`, no Git
ou no aplicativo. Gere uma chave aleatória com um gerenciador de segredos ou
`secrets.token_urlsafe(48)`. Em produção, coloque a API atrás de um proxy HTTPS
com certificado público válido e limite de requisições para login/cadastro.
O Uvicorn HTTP acima é apenas o trecho local entre proxy e processo. Caso ele
atravesse rede não confiável, use TLS também nesse trecho. Proteja o banco e
seus backups com permissões e criptografia de disco apropriadas.

Esta implementação é didática: não inclui recuperação/verificação de e-mail,
refresh token, revogação de JWT no servidor, nem controles operacionais completos
de produção. Logout apaga a sessão no cliente; um token copiado continua válido
até expirar. O prazo padrão é 15 minutos. Não há endpoint que permita ao cliente
escolher a validade do JWT.

## Contrato

| Método | Endpoint | Acesso e resposta |
| --- | --- | --- |
| POST | `/auth/register` | Público; `{name,email,password}`; cria conta, não autentica automaticamente |
| POST | `/auth/login` | Público; `{email,password}`; retorna `{access_token,token_type,expires_in}` |
| GET | `/me` | Bearer; identidade do usuário autenticado |
| GET | `/movies?q=texto` | Bearer; filmes com id, título, ano, nota, direção e sinopse |
| GET | `/favorites` | Bearer; apenas favoritos do usuário identificado pelo JWT |
| POST | `/favorites` | Bearer; `{movie_id}`; salva na conta autenticada, idempotente |
| DELETE | `/favorites/{movie_id}` | Bearer; remove somente da conta autenticada |

A API não recebe `user_id` para manipular favoritos. O dono vem de `sub`, após
validar assinatura HS256, expiração, emissor e audiência e confirmar a conta no
banco. Campos extras no cadastro/login/favorito são rejeitados. Senhas usam
Argon2id e SQL usa parâmetros. Nenhuma rota protegida aceita credenciais por URL.
O catálogo externo é acessado em uma origem HTTPS fixa, sem JWT, com timeout e
cache de cinco minutos; sua falha retorna 502/503/504, nunca uma lista fictícia.

## Testes

```sh
backend/.venv/bin/pip install -r backend/requirements-dev.txt
backend/.venv/bin/python -m pytest backend/tests -q
```

Os testes usam catálogo controlado para serem reproduzíveis. Verificam duas
contas, acesso sem token, JWT expirado/adulterado, assinatura, emissor/audiência,
busca, favoritos persistentes após recriar a API e tentativas de escolher outro
dono. Para demonstrar expiração na interface:

```sh
JWT_TTL_SECONDS=60 backend/.venv/bin/python -m backend.run_dev
```

Faça novo login, aguarde mais de um minuto e atualize ou altere um favorito.
