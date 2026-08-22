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
- **Nao existe mais exportar/importar backup** (removido em 04/08/2026, decisao
  do produtor). Ele gerava um JSON com o banco local inteiro e abria o
  compartilhamento do Android — e-mail, WhatsApp, Drive.
- **As duas linhas que estavam aqui eram falsas.** Diziam que a chave de acesso
  nao ia no backup; ela ia, no campo `chave` de cada estufa. Quem lesse este
  documento acharia que estava protegido. O aviso do proprio compartilhamento
  ("Contem as chaves de acesso") era o que dizia a verdade.
- O que o backup guardava tem outro caminho: o historico esta na nuvem, e uma
  estufa se recadastra lendo o aparelho no modo de configuracao.

### Limitacoes aceitas conscientemente (05/08/2026)

Nao sao esquecimento. Foram avaliadas, e a decisao foi **declarar em vez de
corrigir agora** — corrigir traria risco maior do que o que evita, as vesperas da
apresentacao.

**1. O aparelho nao valida o certificado da nuvem** (`cliente.setInsecure()` no
firmware). A conexao e criptografada, mas o ESP32 nao confere quem esta do outro
lado: alguem no caminho de rede poderia se passar pela nuvem.

Por que fica assim por ora: validar exige uma CA fixada e **relogio certo**. O
ESP pega hora por NTP, que precisa de internet — numa queda longa ele volta com
o relogio errado e a validacao falha, deixando o aparelho **mudo mesmo com
internet de volta**. E cair para `setInsecure()` quando falha anularia a
protecao. O ataque exige alguem no caminho entre a estufa e a Render, na roca; o
risco introduzido e a estufa parar de avisar de incendio numa madrugada.

Solucao correta, para quando houver: conjunto de CAs confiaveis, sincronia de
relogio robusta, e **nunca** voltar automaticamente ao modo inseguro.

**2. A chave global (`ESTUFA_API_TOKEN`) ainda autoriza comandos** para aparelho
que ainda nao registrou a sua. Esta marcado como transitorio em `auth.js`.

Por que nao sai agora: **nao e mudanca de codigo** — o suporte ja existe
(`exigirChaveDoAparelho`). E mudanca operacional: todo aparelho em campo precisa
ter registrado a chave propria ANTES, senao vira tijolo na hora em que a global
deixar de valer. O caminho e conferir no banco quais `idHardware` ja tem chave e
so entao virar.

**3. Nao ha registro de auditoria** — quem mandou o que, quando, e se o aparelho
obedeceu. E a que mais renderia no TCC, por ser resultado alem de seguranca, mas
e funcionalidade nova.

### Banco fechado para a API REST (RLS)

O Supabase publica o schema `public` por uma **API REST propria**, que aceita a
chave `anon`. Sem *Row Level Security*, quem tiver essa chave le e **escreve**
nas tabelas por fora do servidor — e portanto por fora de toda a autenticacao
deste projeto.

O que doi nao e o cadastro de push. E **`comandos_pendentes` e
`comandos_agendados`**: sao a caixa de comandos que o aparelho busca e obedece.
Escrever ali seria comandar a estufa **sem chave, sem PIN e sem estar na frente
do aparelho** — furando a regra central do trabalho.

**RLS ligado em todas as sete tabelas, sem politica nenhuma, de proposito.**
Ligar sem criar policy fecha a API REST por completo, e o servidor nao sente: ele
conecta como `postgres` pelo pooler, e o superusuario ignora RLS. Politica so
faria sentido se um dia o app falasse direto com o Supabase, o que nao acontece —
o app so conhece o servidor.

*Como apareceu:* o Advisor do Supabase apontou tres tabelas sem RLS em
21/08/2026. As quatro do `database/schema.sql` ja estavam protegidas; as tres
descobertas — `push_dispositivos`, `comandos_pendentes` e `comandos_agendados` —
sao criadas em **tempo de execucao** pelo `db.js`, nasceram depois do arquivo de
schema e por isso escaparam da revisao. As tres foram acrescentadas ao
`schema.sql`, junto com os `alter table ... enable row level security`, para uma
implantacao nova ja subir fechada.

*Verificado antes:* nem a chave `anon` nem a URL do projeto aparecem no
repositorio publico. Mas a chave `anon` do Supabase **e feita para ser publica**
em uso normal — depender de ninguem te-la visto nao e protecao, e um print do
painel bastaria.

### Repositorio e configuracao

- Arquivos `.env` e credenciais locais nao devem ser versionados.
- Segredos devem ser configurados por variaveis de ambiente no servidor.
- Chaves reais nao devem aparecer em documentacao, testes, prints ou commits.
- **Print do painel do Supabase tambem vaza**: a pagina de API Keys mostra a
  chave `anon` inteira.

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
