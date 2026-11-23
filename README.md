# CinePocket

Aplicação Flutter para a atividade de comunicação segura com uma API REST JWT.
Inclui API própria FastAPI/SQLite para contas reais do projeto e favoritos
persistentes separados por usuário. O catálogo vem da Studio Ghibli API.

O Flutter chama somente a API própria: cadastro, login, identidade, filmes,
busca e favoritos. Após login, grava o JWT em `flutter_secure_storage`, recupera
o token para cada requisição protegida e consulta os filmes automaticamente.
HTTP 401 apaga sessão e dados em memória e retorna ao login. Logout também
limpa a coleção local; novo login recupera do servidor apenas os favoritos da conta.

## Executar

Veja [as instruções do servidor HTTPS](backend/README.md), incluindo configuração
de certificado confiável para desenvolvimento local.

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=https://seu-servidor
```

Não existem credenciais públicas pré-configuradas. Use **Criar conta** e cadastre
duas contas para demonstrar o isolamento dos favoritos. A chave de assinatura
JWT existe somente no servidor; não a inclua no aplicativo ou repositório.

## Verificar

```sh
flutter analyze
flutter test
flutter build web
```

Os testes do servidor estão em `backend/tests`; os testes Flutter cobrem Bearer,
cofre, falhas de comunicação, JSON, navegação, busca e troca de contas.

- [Justificativa técnica e comparação de armazenamento](docs/justificativas/comunicacao-segura.md)
- [Contrato da API e teste com duas contas](backend/README.md)

Relatório e evidências da entrega devem acompanhar o código em `docs/entrega/`.
Capturas Web demonstram o fluxo, mas não substituem teste do cofre em Android/iOS.

A interface ativa é a consulta autenticada de filmes, cadastro, detalhes e favoritos.
