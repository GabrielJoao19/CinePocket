# Comunicação segura do CinePocket

## Arquitetura e vínculo com o usuário

O Flutter usa uma API própria em FastAPI para cadastro, login JWT, identidade,
consulta de filmes e favoritos. A API consulta o catálogo público Studio Ghibli
por HTTPS. O token da conta nunca é encaminhado ao provedor externo. A solução
anterior baseada em DummyJSON foi substituída porque não persistia os favoritos
reais do CinePocket por usuário.

Fluxo:

1. Criar conta (`POST /auth/register`). A API armazena hash Argon2id da senha.
2. Informar e-mail/senha (`POST /auth/login` HTTPS, corpo JSON).
3. Extrair `access_token` e gravá-lo em `flutter_secure_storage`. Se a gravação
   falhar, o usuário permanece no login. A senha não é persistida.
4. Abrir automaticamente a consulta. A API recebe o Bearer lido do armazenamento
   seguro em `/me`, `/movies` e `/favorites`; o aplicativo exibe título, ano,
   nota e direção dos filmes, além da identidade da conta autenticada.
5. Adicionar/remover favorito pelo ID do filme. A API determina o dono pelo
   `sub` do JWT validado; não confia em um `user_id` enviado pelo cliente.
6. Sair ou receber 401 limpa o token, a identidade e os favoritos em memória.
   O 401 de qualquer operação protegida também limpa a navegação até o login.
7. Ao abrir novamente, um token armazenado leva à revalidação no servidor.
   Ao entrar novamente na mesma conta, os favoritos são recarregados do SQLite.

O catálogo de filmes é comum; os favoritos são privados por conta. A API rejeita
consultas protegidas sem token e valida assinatura, algoritmo permitido, prazo,
emissor e audiência. O cliente verifica a estrutura do JWT recebido, mas essa
verificação local não substitui a validação da assinatura no servidor.

## flutter_secure_storage e SharedPreferences

O JWT é uma credencial Bearer: quem o obtém pode apresentar-se como o usuário.
Por isso é gravado somente em `flutter_secure_storage`, que usa mecanismos de
proteção da plataforma (Keychain em Apple e armazenamento criptografado com
proteção das chaves em Android). A leitura ocorre antes de cada chamada protegida.
As dependências e permissões das plataformas já estão no projeto; Android
bloqueia cleartext e desabilita backup do app. Na Web, o mecanismo depende do
navegador, exige HTTPS/localhost e não elimina riscos de XSS. Testes Web não
comprovam o funcionamento do Keychain/Keystore em aparelho.

SharedPreferences é adequado para dados simples não sensíveis: tema, idioma,
preferência de interface e última pesquisa não confidencial. Não é um cofre de
credenciais e não deve conter senha nem JWT. Não é necessário instalar esse
pacote para a atividade: a comparação técnica é documentada, enquanto o token
usa obrigatoriamente o armazenamento seguro.

## HTTPS

TLS protege confidencialidade e integridade dos dados em trânsito e autentica o
servidor por certificado confiável. Protege a senha, o Bearer e o JSON até o
ponto onde TLS termina; não protege automaticamente banco, logs e dados já
abertos no cliente/servidor. JWT assinado não é necessariamente criptografado.

Todas as chamadas REST do app e a consulta externa do backend usam HTTPS.
O Flutter rejeita HTTP e não desativa a validação de certificados. Para teste
local há um inicializador HTTPS; o certificado local precisa ser confiado no
cliente. Para produção, usar certificado público válido e renovação apropriada.
No celular, localhost aponta para o próprio aparelho; configure uma API acessível.

Se o desenvolvimento usasse HTTP, credenciais e tokens poderiam ser capturados
ou alterados por alguém no caminho. Migrar para HTTPS exigiria certificado,
configuração TLS no servidor/proxy e atualização das URLs, sem aceitar
certificados inválidos. Redirecionar uma chamada HTTP não desfaz seu vazamento
inicial. A API pode usar HTTP em loopback atrás de um proxy TLS, mas esse trecho
precisa ser protegido se atravessar rede não confiável.

## Análise do pacote Encrypt

Não é necessário adicionar Encrypt neste escopo: HTTPS protege as requisições e
o cofre protege o JWT em repouso. Não há requisito de manter o catálogo ou os
favoritos cifrados de ponta a ponta após terminarem TLS. Uma chave fixa embutida
no aplicativo seria extraível e não resolveria esse problema.

Uma camada adicional pode fazer sentido para documentos sensíveis armazenados
fora do cofre, conteúdo que deva permanecer cifrado diante de intermediários ou
mensagens que nem o servidor deva ler. Seriam necessários protocolo interoperável,
criptografia autenticada, chaves por usuário, distribuição, rotação, recuperação
e nonces corretos; instalar um pacote não cria essas garantias sozinho.

Vantagens: proteção do conteúdo além do canal TLS e menor exposição a alguns
intermediários. Desvantagens: complexidade de chaves, recuperação difícil, maior
custo de processamento/payload, dificuldade de busca e risco de implementação.
Encrypt não substitui HTTPS, autorização por usuário ou armazenamento seguro.

## Tratamento de erros

| Cenário | Resposta do aplicativo |
| --- | --- |
| Rede, DNS, TLS ou servidor indisponível | Mensagem de indisponibilidade e nova tentativa |
| Timeout de 15 segundos | Mensagem de tempo esgotado |
| Credenciais inválidas | Mantém login com aviso, não salva sessão |
| JWT inválido/expirado, HTTP 401 | Apaga token e dados da conta, retorna ao login |
| JSON inválido ou estrutura incompatível | Mensagem de dados/resposta inválida |
| Falha de leitura segura | Não envia requisição protegida, informa erro |
| Falha de gravação segura | Não abre a consulta, permite repetir login |
| Falha de exclusão segura | Bloqueia reutilização nesta execução e informa erro |
| Falha ao salvar favorito | Não confirma alteração local sem sucesso do servidor |

Se a exclusão do cofre falhar, o app oferece nova tentativa. Um token que tenha
permanecido no disco só será aceito após revalidação no servidor na próxima
execução. Respostas de uma sessão anterior são descartadas após troca de conta.

## Dificuldades e validação

A principal dificuldade foi combinar uma API de filmes pública com autenticação
própria e dados privados por conta. Foi necessário introduzir IDs estáveis de
filmes, persistência relacional e limpeza do cache ao trocar de usuário. Outra
dificuldade foi executar testes com o cofre nativo: testes automatizados usam
uma implementação substituível e devem ser complementados por teste em aparelho.
Certificados locais também precisam de confiança explícita no cliente.

Testar Flutter com `flutter analyze`, `flutter test` e `flutter build web`.
Testar servidor com `python -m pytest backend/tests -q` no ambiente de dependências.
O caso principal é: A favorita um filme; B não o vê e não pode removê-lo de A;
A entra novamente e recupera o filme, inclusive após reiniciar a API.

Para executar, consulte [backend/README.md](../../backend/README.md).
Capturas e relatório ficam em `docs/entrega/`; registre se foram feitas na Web
ou em aparelho. A análise não afirma validação nativa sem executá-la.

Fontes:
- [FastAPI: JWT e hash de senhas](https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/)
- [PyJWT: validação de claims](https://pyjwt.readthedocs.io/en/latest/api.html)
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
- [SharedPreferences](https://pub.dev/packages/shared_preferences)
- [Catálogo Studio Ghibli](https://ghibliapi.vercel.app/)
