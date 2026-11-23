# Evidências da atividade

O material principal para apresentação está em
[apresentacao-comunicacao-segura.md](apresentacao-comunicacao-segura.md), reunindo
explicações diretas, trechos relevantes do código e evidências de execução.
A análise técnica completa está em
[../justificativas/comunicacao-segura.md](../justificativas/comunicacao-segura.md).

O cenário de validação usa contas criadas pela interface e a API própria em
FastAPI + SQLite (`backend/`). O catálogo é consultado no servidor pela Studio
Ghibli API por HTTPS, sem repassar o JWT do usuário.

A captura Web (`01-login-consulta-protegida.png`) demonstra o comportamento da
aplicação; não substitui a comprovação do Keychain/Keystore nativo em aparelho.
Não há exceção TLS no código Flutter — todas as chamadas REST exigem HTTPS.

Validação automatizada realizada:

- **8 testes da API** (`pytest backend/tests -v`): JWT, isolamento entre contas,
  persistência após recriar a API, busca, hash Argon2id e rejeição de tentativas
  de manipular o dono dos favoritos.
- **35 testes Flutter** (`flutter test`): transporte HTTPS, armazenamento seguro,
  timeout, JSON, 401, cadastro, detalhes, favoritos, busca, navegação e troca de
  conta.
- `flutter analyze`: sem problemas.

Verificação ainda necessária no aparelho alvo: cadastro/login, encerramento e
reabertura do app para ler o token do plugin nativo (`Keystore`/`Keychain`),
troca de conta e 401.
