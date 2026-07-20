# Seguranca do sistema

Este documento resume as protecoes implementadas, o fluxo de leituras e os riscos que ainda devem ser tratados antes de uma implantacao comercial.

## Modelo de ameaca

O ESP32 opera normalmente na rede Wi-Fi da propriedade. O servidor em nuvem pode ser acessado pela internet. Os principais riscos sao:

- leitura indevida da telemetria;
- envio de ajustes sem autorizacao;
- abuso das rotas publicas;
- vazamento da chave de acesso ou da credencial do banco;
- alteracao ou repeticao de comandos.

## Protecoes implementadas

### API e autenticacao

- As rotas protegidas exigem a chave configurada em `ESTUFA_API_TOKEN`.
- A comparacao da chave usa `crypto.timingSafeEqual`.
- Em producao, o servidor recusa uma chave ausente ou fraca. O modo sem chave exige habilitacao explicita para desenvolvimento.
- O servidor limita cada origem a 180 requisicoes por minuto.
- O corpo JSON e limitado a 64 KB.
- O Helmet adiciona cabecalhos HTTP de seguranca e o cabecalho `X-Powered-By` fica desabilitado.
- Os campos recebidos sao validados e valores fora das faixas permitidas sao rejeitados.

### Banco de dados

- As consultas SQL usam parametros, reduzindo o risco de injecao de SQL.
- A conexao PostgreSQL e sempre cifrada. A **validacao** do certificado exige
  o CA em `DB_SSL_CA`: o pooler do Supabase usa certificado proprio e reprova a
  validacao contra CAs publicas (verificado em teste real — exigir validacao
  sem o CA derrubava toda a persistencia). Sem `DB_SSL_CA`, o servidor cifra
  sem validar e registra um aviso no log.
- Para ativar a validacao completa: painel do Supabase → Settings → Database →
  SSL → baixar o certificado e colar o PEM na variavel `DB_SSL_CA` do Render.
- `DB_SSL=false` desliga o TLS e deve ser usado apenas em ambiente controlado.

### Aplicativo

- A chave e enviada nas requisicoes autenticadas.
- A chave de acesso nao e incluida no backup exportado.
- Backups antigos que ainda contenham chave continuam importaveis, mas a chave nao volta a ser exportada.

### Repositorio e configuracao

- Arquivos `.env` e credenciais locais nao devem ser versionados.
- Segredos devem ser configurados por variaveis de ambiente no servidor.
- Chaves reais nao devem aparecer em documentacao, testes, prints ou commits.

## Fluxo de leituras

O envio ao vivo e a persistencia historica possuem objetivos diferentes:

1. O ESP32 envia uma leitura aproximadamente a cada minuto.
2. O servidor atualiza o estado em memoria imediatamente.
3. O aplicativo consulta esse estado e mostra a leitura mais recente.
4. Uma leitura comum e gravada no banco somente a cada 10 minutos.
5. Leituras importantes sao gravadas imediatamente, mesmo antes dos 10 minutos.

Sao consideradas importantes:

- primeira leitura do aparelho;
- mudanca do estado de alarme;
- alteracao do ajuste de temperatura ou umidade;
- entrada em desvio relevante de temperatura ou umidade.

Se o banco estiver indisponivel, somente as amostras selecionadas para persistencia entram na fila temporaria. Isso evita armazenar milhares de leituras repetitivas sem perder eventos relevantes.

## Por que nao gravar toda leitura

Uma estufada de 10 dias, com uma leitura por minuto, produziria cerca de 14.400 registros comuns. Com amostragem a cada 10 minutos, o volume cai para aproximadamente 1.440 registros, alem dos eventos importantes. A tela continua atualizada porque o estado ao vivo nao depende do intervalo de gravacao historica.

## Riscos restantes

- HTTP local nao cifra o trafego dentro da rede Wi-Fi. Uma rede comprometida ainda pode observar o trafego.
- Uma chave compartilhada entre varios aparelhos aumenta o impacto de um vazamento. O ideal futuro e uma chave por aparelho.
- A fila offline atual e temporaria e pode ser perdida se o processo do servidor reiniciar antes da sincronizacao.
- O ESP32 deve validar certificados ao acessar servicos HTTPS externos.
- A protecao contra repeticao de comandos pode ser fortalecida com identificador unico, validade e confirmacao por aparelho.

## Se uma chave vazar

1. Gere uma nova chave forte.
2. Atualize `ESTUFA_API_TOKEN` no servidor.
3. Atualize a chave cadastrada no aplicativo.
4. Atualize a configuracao dos aparelhos autorizados.
5. Se a credencial do banco tambem tiver vazado, altere a senha no provedor e atualize `DATABASE_URL`.
