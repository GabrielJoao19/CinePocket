# Evidências da atividade

O relatório `relatorio-seguranca.pdf` tem duas páginas. O texto técnico completo
está em `../justificativas/comunicacao-segura.md` e pode ser ajustado para incluir
os nomes dos integrantes antes de enviar ao Moodle.

O cenário de validação usa duas contas fictícias criadas pela interface e a API
própria. O catálogo é consultado no servidor pela Studio Ghibli API. A senha das
contas de captura é gerada para o teste e não é entregue como credencial fixa.

As capturas Web demonstram o comportamento da aplicação; não são comprovação do
Keychain/Keystore nativo. O navegador automatizado usa perfil isolado e uma
exceção apenas de teste para o certificado HTTPS autoassinado local. Não há
exceção TLS no código Flutter. Para uso normal, confie no certificado local ou
configure uma API com certificado público válido. Todas as chamadas REST usam HTTPS.

Validação automatizada realizada:

- 8 testes da API: JWT, isolamento entre contas, persistência após recriar API,
  busca, hash de senha e tentativas de manipular o dono dos favoritos.
- 35 testes Flutter: transporte, armazenamento, timeout, JSON, 401, cadastro,
  detalhes, favoritos, busca, navegação e troca de conta.
- `flutter analyze`: sem problemas; `flutter build web`: concluído.
- A compilação Web emite aviso sobre fonte Cupertino. Não impede a compilação.
- A versão instalada do Starlette emite aviso de depreciação do TestClient com
  httpx nos testes do servidor; os 8 testes passaram.

Verificação ainda necessária no aparelho alvo: cadastro/login, encerramento e
reabertura do app para ler o token do plugin nativo, troca de conta e 401. Essa
validação não foi executada em Android/iOS neste ambiente.
