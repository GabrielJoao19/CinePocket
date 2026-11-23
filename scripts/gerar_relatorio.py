"""Gera o relatório de duas páginas; executar com requirements-dev.txt."""
from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak

out = Path('docs/entrega/relatorio-seguranca.pdf')
out.parent.mkdir(parents=True, exist_ok=True)
styles = getSampleStyleSheet()
styles['Normal'].fontSize = 10
styles['Normal'].leading = 14
styles['Heading2'].fontSize = 12
styles['Heading2'].spaceBefore = 12
story = []
def title(text): story.append(Paragraph(text, styles['Title']))
def section(heading, text):
    story.append(Paragraph(heading, styles['Heading2']))
    story.append(Paragraph(text, styles['Normal']))

title('CinePocket · Comunicação segura com API REST')
story.append(Paragraph('Relatório técnico da atividade · Flutter, JWT e favoritos por usuário', styles['Normal']))
story.append(Paragraph('Integrantes: João Gabriel · Lukas Sodré', styles['Normal']))
section('Implementação e identidade da conta',
    'O aplicativo comunica-se com uma API própria FastAPI por HTTPS. Cadastro cria uma conta no SQLite, '
    'armazenando somente hash Argon2id da senha. O login envia e-mail/senha em JSON e extrai access_token '
    'da resposta. Após gravar o JWT, abre automaticamente a consulta protegida e recupera o token do cofre '
    'para o cabeçalho Authorization: Bearer. A lista apresenta título, ano, nota e diretor. '
    'O servidor consulta a Studio Ghibli API por HTTPS, sem encaminhar o JWT do usuário.')
section('Por que flutter_secure_storage?',
    'O token Bearer permite agir como o usuário; por isso deve ser protegido em repouso. '
    'flutter_secure_storage usa mecanismos da plataforma, como Keychain em Apple e armazenamento '
    'criptografado com proteção das chaves em Android. A senha não é persistida. Falha de gravação impede '
    'abrir a consulta; falha de leitura impede a chamada protegida. No navegador, o mecanismo depende '
    'da segurança da origem e não elimina riscos de XSS. HTTPS/localhost é obrigatório para o cofre Web.')
section('Quando utilizar SharedPreferences?',
    'É apropriado para tema, idioma, preferências de interface e última pesquisa não sensível. '
    'Não oferece um cofre para segredos; guardar JWT ou senha ali exporia credenciais a extração. '
    'O projeto documenta essa comparação e utiliza exclusivamente flutter_secure_storage para o token. '
    'Não há necessidade de instalar SharedPreferences para demonstrar seu propósito.')
section('Proteção por HTTPS',
    'TLS protege confidencialidade e integridade do tráfego e autentica o servidor por certificado confiável. '
    'Isso protege credenciais, token e JSON até o término da conexão TLS, mas não protege automaticamente '
    'bancos, logs ou dispositivos comprometidos. O cliente só aceita HTTPS e não desativa a validação '
    'de certificados. HTTP permitiria interceptar ou alterar dados; migrar para HTTPS exige certificado '
    'válido, configuração TLS e URLs seguras, sem bypass de certificados. Para desenvolvimento, o '
    'certificado local precisa ser confiado pelo cliente; em produção, usar certificado público válido.')
story.append(PageBreak())
title('Segurança dos dados e validação')
section('Favoritos realmente vinculados ao usuário',
    'A API valida assinatura HS256, expiração, emissor e audiência do JWT. O identificador sub determina '
    'a conta. GET /favorites, POST /favorites e DELETE /favorites/{movie_id} operam somente nessa conta; '
    'o aplicativo não escolhe um user_id. O banco persiste a relação usuário/filme com chave composta. '
    'Logout e HTTP 401 limpam token, identidade, favoritos em memória e navegação. Ao entrar novamente, '
    'a coleção é recuperada do servidor. Trocar para outra conta não reutiliza a coleção anterior.')
section('É necessário usar Encrypt?',
    'Não neste escopo: TLS protege o canal e o cofre protege o JWT local. Uma chave fixa embutida no app '
    'poderia ser extraída e não acrescentaria uma proteção confiável. Uma camada adicional seria útil '
    'para arquivos sensíveis fora do cofre ou conteúdo que precise permanecer cifrado diante de '
    'intermediários, inclusive mensagens que o servidor não deva ler. Seriam necessários protocolo, '
    'criptografia autenticada, chaves por usuário, distribuição, rotação, recuperação e nonces corretos. '
    'Vantagens: proteção do conteúdo além de TLS e menor exposição a intermediários. Desvantagens: '
    'complexidade de chaves, processamento/payload maiores, dificuldade de busca e risco de erros. '
    'Encrypt não substitui HTTPS nem autorização no servidor. JWT assinado não significa JWT criptografado.')
section('Erros, testes e dificuldades',
    'O app trata servidor indisponível, timeout de 15 segundos, credenciais inválidas, token expirado, '
    'JSON inválido e falhas de leitura/gravação/exclusão do cofre. Um favorito só é confirmado localmente '
    'após sucesso no servidor. Os 8 testes do backend verificam isolamento, persistência após reiniciar '
    'a API, hash de senha e rejeição de tokens inválidos. Os 35 testes Flutter cobrem contrato HTTP, '
    'armazenamento, erros, cadastro, detalhes, busca, navegação e troca A → B → A. Análise Flutter e compilação Web passaram. '
    'As dificuldades principais foram relacionar filmes externos a contas próprias, limpar caches na '
    'troca de sessão e configurar certificados locais. Testes usam um cofre substituível; ainda é '
    'necessário validar Keychain/Keystore em Android/iOS. A implementação é didática e não inclui '
    'recuperação de senha, refresh ou revogação de tokens copiados: logout apaga a sessão local.')
section('Referências',
    'FastAPI: fastapi.tiangolo.com/tutorial/security/oauth2-jwt/ · '
    'PyJWT: pyjwt.readthedocs.io/en/latest/api.html · '
    'Pacotes: pub.dev/packages/flutter_secure_storage e pub.dev/packages/shared_preferences · '
    'Catálogo: ghibliapi.vercel.app')

def footer(canvas, doc):
    canvas.setFillColor(colors.grey)
    canvas.setFont('Helvetica', 8)
    canvas.drawRightString(A4[0]-42, 25, f'CinePocket · {doc.page}')
SimpleDocTemplate(str(out), pagesize=A4, rightMargin=42, leftMargin=42,
                  topMargin=35, bottomMargin=40).build(story, onFirstPage=footer, onLaterPages=footer)
print(out)
