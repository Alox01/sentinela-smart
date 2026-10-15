# Melhorias de codigo — 15/10/2026

Registro das correcoes feitas depois da revisao geral de hardware, firmware,
aplicativo e servidor. O objetivo deste arquivo e separar o que foi realmente
alterado do que continua sendo limitacao conhecida.

## Implementado

### 1. Chaves de producao mais fortes

- O servidor passou a exigir no minimo **16 caracteres** em
  `ESTUFA_API_TOKEN`; antes aceitava 8.
- A recomendacao operacional e uma chave com **32 bytes aleatorios**, e nao uma
  senha inventada por uma pessoa.
- Os exemplos, a mensagem de inicializacao e os testes foram atualizados.
- Desenvolvimento sem chave continua possivel somente com a decisao explicita
  `PERMITIR_SEM_TOKEN=true`.

Impacto de implantacao: uma instalacao que ainda use token com 8 a 15
caracteres precisa rotaciona-lo antes do proximo deploy.

### 2. TLS estrito e verificavel no PostgreSQL

- Foi criada a opcao `DB_SSL_REQUIRE_VALIDATION=true`.
- Com ela ligada, `DB_SSL_CA` passa a ser obrigatorio e o servidor se recusa a
  iniciar sem validar o certificado do banco.
- O `render.yaml` ativa o modo estrito e declara `DB_SSL_CA` como segredo.
- O `docker-compose.yml` e o `.env.example` agora expõem as mesmas opcoes.
- Foram adicionados testes para falha sem CA e sucesso com CA multiline.

Isso evita que uma configuracao de producao pareca segura por usar TLS, mas
aceite qualquer certificado.

### 3. Identificador de requisicao

- Toda resposta da API agora inclui `X-Request-Id` gerado pelo servidor.
- Respostas 4xx entram em log `info`, 5xx em `erro` e sucessos apenas em
  `debug`.
- O registro contem somente id, metodo, rota, status e duracao. Corpo,
  credenciais e telemetria nao sao gravados.
- Testes verificam tanto a classificacao quanto a ausencia de segredo no log.

Isso permite relacionar uma falha vista no app ao evento exato no servidor sem
transformar os logs em um novo vazamento de dados.

### 4. Documentacao alinhada ao codigo

- Contagens atuais: **234 testes no servidor** e **210 no aplicativo**.
- Documentos de seguranca e demonstracao agora declaram o limite correto de
  token e o modo TLS estrito.

### 5. Dependencias do servidor sem alertas conhecidos

- `npm audit --omit=dev` encontrou 12 vulnerabilidades transitivas: 1 critica,
  4 altas e 7 moderadas.
- `npm audit fix` atualizou apenas a arvore/lockfile, sem mudar a API do projeto.
- Depois da atualizacao, `npm audit` retornou **0 vulnerabilidades** e os 234
  testes do servidor continuaram passando.

### 6. Estado de conexao coerente no aplicativo

- A comunicacao real mais recente passou a ser registrada como evidencia do
  caminho que esta funcionando (local ou nuvem).
- O teste de alcance nao pode mais declarar um caminho indisponivel quando uma
  leitura ou um comando real acabou de responder por ele. Essa evidencia vale
  por 15 segundos, cobrindo falhas isoladas de mDNS e novas conexoes Android
  sem esconder uma queda verdadeira por muito tempo.
- Ao abrir os detalhes, o app mostra o ultimo resultado sem deixar a janela
  vazia, mas imediatamente faz uma verificacao nova; o cache antigo nao fica
  parado por ate dois minutos na tela.
- O resultado de alcance agora e observavel e compartilhado: se uma leitura,
  comando ou sonda o atualizar enquanto a janela estiver aberta, as linhas da
  janela mudam junto, sem precisar fecha-la e abri-la de novo.
- Os textos agora distinguem `Conexao usada agora` de `Caminhos disponiveis`.
  LOCAL/NUVEM informa por onde a leitura atual chegou; as duas linhas abaixo
  informam quais alternativas responderam ao diagnostico.
- Foi adicionado um teste de regressao para o caso observado em campo: comando
  LOCAL bem-sucedido seguido por uma falha passageira apenas na sonda.
- Em telas estreitas, foi acrescentada separacao fixa entre o rotulo `Conexao
  usada agora` e o valor, eliminando o texto visualmente grudado em `LOCAL`.
- Quando existe uma leitura real, o caminho comprovado aparece imediatamente;
  a verificacao que continua em segundo plano fica identificada como
  `Verificando outras conexoes`, pois esta conferindo a alternativa e nao
  redescobrindo o modo que ja esta funcionando.
- Um teste de widget em largura de 360 px confirma a separacao minima de 12 px
  e a ausencia de erro de layout.
- No diagnostico, `Local` passou a ser exibido como `Aparelho local` e `Nuvem`
  como `Servidor na nuvem`. Assim, servidor acessivel com ESP desligado nao
  parece significar que o aparelho esta disponivel remotamente: o estado geral
  continua corretamente em `SEM SINAL` quando a telemetria esta antiga.

### 7. APK de validacao gerado

- Em 15/10/2026 as 19:17 foi gerado o APK release atualizado por arquitetura,
  ja com a correcao de layout e do indicador de verificacao, com
  `CLOUD_API_URL=https://estufa-server.onrender.com`.
- Para o aparelho Android atual, o artefato indicado e
  `estufa_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- SHA-256 do APK ARM64:
  `A94A8361C11171254F559932CF0A87BFC6B54F8E4210A47FF7DF28C5F797AF4E`.

### 8. Builds TCC e completo separados

- Em 15/10/2026 as 19:16 foi gerada a versao de apresentacao com
  `ESCOPO_TCC=true`, preservando todas as correcoes de conexao e layout.
- A versao TCC foi preservada no projeto como
  `estufa_app/build/app/outputs/flutter-apk/app-TCC-arm64-v8a-release.apk` e
  copiada para `C:/Users/Apole/Downloads/EstufaSmart-TCC-arm64.apk`.
- SHA-256 da versao TCC:
  `B35B49ED82BCB6A5AC51C8D7FEFFA215EE137ECB7D7A7EFB1516F1F71340F491`.
- Em seguida, o build completo foi restaurado e copiado para
  `C:/Users/Apole/Downloads/EstufaSmart-Completo-arm64.apk`.
- SHA-256 da versao completa:
  `A94A8361C11171254F559932CF0A87BFC6B54F8E4210A47FF7DF28C5F797AF4E`.

## Verificado e mantido como esta

### Versao do firmware

`VERSAO_FIRMWARE = "1.0"` nao foi alterada. O comentario do proprio firmware
define que esse numero representa o binario fisicamente gravado e so deve mudar
quando o produtor fizer uma nova gravacao. Alterar apenas no Git faria o app
afirmar uma versao que ainda nao existe no aparelho.

### HTTPS do ESP32

`WiFiClientSecure::setInsecure()` continua presente. Colocar uma CA sem resolver
sincronizacao confiavel de relogio pode impedir toda comunicacao depois de uma
queda longa de energia. A correcao segura exige CA confiavel, relogio robusto e
teste no aparelho; nunca deve existir fallback automatico para modo inseguro.

### HTTP local no Android

`usesCleartextTraffic=true` continua necessario porque o app fala diretamente
com IPs DHCP do ESP32 em HTTP. Uma lista de dominios nao cobre IPs privados
dinamicos. A protecao atual e a chave por aparelho; migrar o canal local para
HTTPS exige provisionar identidade/certificado no ESP32.

### Arquivos grandes do app e servidor

Nao houve divisao mecanica de telas ou de `db.js`. Esses arquivos concentram
fluxos que ja foram corrigidos em campo; uma divisao ampla sem objetivo
funcional aumentaria o risco antes da banca. A proxima extracao deve ser feita
por comportamento, com teste antes e depois, começando por provisionamento e
resolucao de conexao.

## Ainda depende de operacao ou hardware

1. Baixar o CA do Supabase e preencher `DB_SSL_CA` no Render.
2. Rotacionar qualquer token global com menos de 16 caracteres.
3. Gravar uma nova versao do firmware somente quando o produtor decidir e
   repetir os testes de campo correspondentes.
4. Validar iOS em aparelho Apple real.
5. Concluir a matriz de evidencias em `PLANO_POS_TESTES.md`.
6. Projetar validacao TLS do ESP32 e testar recuperacao após queda de energia.
