# Segurança dos comandos da estufa

Esta camada protege os comandos que alteram o funcionamento da estufa, como
mudança de ajuste de temperatura, mudança de ajuste de umidade e silenciamento
de alarme.

## Regra atual

- `GET /status` continua liberado para leitura do estado da estufa.
- `GET /` e `GET /dados` continuam liberados para leitura no formato simples compatível com ESP32.
- `POST /sincronizar` exige token quando o servidor estiver configurado com
  `ESTUFA_API_TOKEN`.
- `POST /leitura` (ingestão de telemetria do hardware) exige token quando
  configurado.
- `POST /debug/botao-fisico` também exige token quando configurado.

O servidor **exige um `ESTUFA_API_TOKEN` forte** (>= 8 caracteres, não trivial —
a checagem está em `token_policy.js`) para iniciar. Sem um token válido, ele
**recusa o boot**, evitando que a API suba aberta por engano. Para testes locais
sem token, defina explicitamente `PERMITIR_SEM_TOKEN=true` — aí o servidor sobe
sem proteção e avisa no log (usar só em desenvolvimento).

No aplicativo, a chave pode ser configurada no cadastro/edição da estufa. Assim
cada aparelho pode ter uma chave própria. Se a chave da estufa ficar vazia, o
app usa o token global informado por `--dart-define=ESTUFA_API_TOKEN=...`, caso
ele exista.

## Como o token é enviado

O aplicativo envia o token nos cabeçalhos:

```http
Authorization: Bearer <token>
X-Device-Token: <token>
```

O servidor aceita os dois formatos. O cabeçalho `X-Device-Token` foi mantido
para facilitar a futura integração com o ESP32.

## Como testar localmente

No servidor:

```powershell
$env:ESTUFA_API_TOKEN="minha-chave-de-teste"
node server.js
```

Também existe o arquivo `estufa_server/.env.example` como modelo das variáveis
necessárias. O arquivo `.env` real deve ficar somente no computador de teste ou
no ambiente do servidor. Ao iniciar com `node server.js`, o servidor carrega
automaticamente `estufa_server/.env` quando esse arquivo existir.

No aplicativo Flutter:

```powershell
flutter run -d chrome --dart-define=ESTUFA_API_TOKEN=minha-chave-de-teste
```

Ou cadastre a estufa no app e preencha o campo
`Chave de acesso` com a mesma chave usada no servidor/ESP32.

Se o token do aplicativo estiver diferente do token do servidor, os comandos de
controle retornam `401 Não autorizado`.

## Provisionamento e recuperação do token (ESP32 — planejado)

Ponto de usabilidade: o usuário-alvo é um produtor rural, não um técnico. Ele
**não deve inventar nem decorar** o token — a segurança forte é responsabilidade
de quem instala e do servidor na nuvem, não da rotina dele. O produtor apenas
**emparelha** o app com o aparelho, e precisa conseguir se recuperar caso perca a
chave. Como o visor típico do aparelho é de 4 dígitos (7 segmentos, feito para
mostrar temperatura), ele não exibe token nem QR. Dois modelos resolvem isso:

### Modelo A — token fixo em etiqueta (mais simples)

O aparelho tem um token permanente de fábrica, impresso num adesivo/cartão que o
acompanha (como a senha embaixo de um roteador). O produtor lê e digita uma vez
no app. Perdeu? Lê o adesivo de novo. O "reset" limpa a configuração, mas **não**
troca o token (ele é a identidade do aparelho). O visor não participa.

### Modelo B — PIN de 4 dígitos no visor (recomendado)

Aproveita o visor de 4 dígitos que o aparelho já tem, usando-o como **PIN de
emparelhamento** (não como token):

1. O produtor aperta um botão → o aparelho entra em modo de emparelhamento e
   mostra um **PIN de 4 dígitos** no visor.
2. No app, ele digita esses 4 números.
3. O app conecta ao aparelho pela rede local e os dois **trocam o token forte
   automaticamente** — o token longo nunca é visto nem digitado pelo produtor.
4. Perdeu o token? Aperta o botão → novo PIN no visor → digita → reemparelhado.

O produtor lida só com 4 dígitos, e o token real continua forte porque é gerado
pela máquina e trocado sozinho.

**Por que 4 dígitos são seguros aqui:** o PIN é apenas um segredo temporário de
emparelhamento, protegido como no pareamento de Bluetooth/TV:

- vale só numa **janela curta** (ex.: 2 min após apertar o botão);
- **limite de tentativas** (bloqueia após poucos erros);
- só funciona na **rede local**.

### Modelo B — **implementado** (31/07/2026)

O PIN é sorteado a cada entrada no modo de configuração e ocupa o visor de 4
dígitos enquanto vale. `GET /config/identidade` passa a exigi-lo; o app pede os
4 números e, com eles, recebe a chave longa sem ninguém digitá-la.

O que o PIN fecha: o ponto de acesso do modo de configuração é **aberto**. Sem
ele, qualquer um ao alcance do Wi-Fi naquele momento pediria a identidade e
levaria a chave **sem nunca chegar perto do aparelho**. Com ele, é preciso estar
olhando o visor.

**Corrigido em 05/08/2026: `POST /salvar` também exige o PIN.** Ele ficou de fora
quando o PIN nasceu, e o buraco era maior que o que o PIN fechou: `/salvar`
**grava** rede, endereço e chave — quem estivesse ao alcance do Wi-Fi durante os
5 minutos podia trocar a chave do aparelho e ficar com ele. O raciocínio ("o
ponto de acesso é aberto, estar nele não prova nada") sempre valeu para as duas
rotas; só uma tinha sido protegida. A conferência virou uma função só,
`pinDoVisorConfere()`, usada pelas duas — separadas, elas voltariam a divergir. O
formulário do navegador ganhou o campo do PIN, e o app manda o número que já está
digitado na tela.

As três proteções que fazem 4 dígitos bastarem, todas no firmware:

- **sorteado por entrada** — um PIN fixo viraria segredo permanente de 4 dígitos;
- **morre em 5 erros** — sem limite, varrer 10 mil combinações leva minutos. O
  visor volta a mostrar `----`, que é o sinal de "saia e entre de novo";
- **vale só no modo de configuração**, que já expira sozinho, e só na rede local.

O Modelo A (etiqueta) fica descartado: era justamente digitar chave longa.

## Revogar acesso pelo app — **implementado** (05/08/2026)

Desenho escrito antes de existir, e construído no mesmo dia. O formulário do
navegador do aparelho (`192.168.4.1` → "Chave de acesso (avançado)" → "Gerar uma
chave nova") continua valendo como caminho de recuperação e manutenção.

No app: menu da estufa → **"Tirar acesso dos outros celulares"**, ao lado de
"Compartilhar acesso" — é o contrário dele, e é ali que se procura depois de ter
compartilhado com quem não devia.

### O problema que isto resolve

Não é a rotação faltar — ela existe. É **ninguém conseguir achá-la** no dia em
que precisar. Está escondida atrás de um `<details>` num formulário que o
produtor nunca abre, e o app não menciona em lugar nenhum. Se um QR vazar, o
caminho existe e é invisível.

### O fluxo

1. No menu da estufa: **"Tirar acesso dos outros celulares"**. (Esse é o texto da
   tela. "Revogação de acesso" fica para a documentação — não é o vocabulário de
   quem usa.)
2. Aviso antes de qualquer coisa: **todos os celulares que receberam o QR antigo
   perdem o controle**, e vão precisar de um QR novo. E, explicitamente: **as
   estufadas e os relatórios continuam** — só a credencial muda. "Revogar acesso"
   soa como perder dados.
3. Pede para colocar o aparelho no modo de configuração (3 botões, 3 s) e
   conectar o celular na rede `Sentinela-Config`.
4. Pede o **PIN do visor**, como o fluxo de configuração já faz. O app **nunca**
   preenche o PIN: a presença física é o que impede alguém só com o aplicativo de
   expulsar os outros celulares.
5. O app consulta `GET /config/identidade` e recebe também o **`wifiSsid`**.
6. O app manda `POST /salvar` com: o mesmo SSID, **senha vazia** (mantém a
   atual), `novachave=1` e o PIN.
7. O aparelho gera a chave nova, grava, **devolve a chave nova na resposta** e
   reinicia.
8. O app substitui a chave guardada e oferece o QR novo.

### As duas mudanças no firmware

Foram só estas duas:

- **`GET /config/identidade` devolve `wifiSsid`.** Sem ele o app não tem
  como reenviar a mesma rede, e `POST /salvar` recusa SSID vazio.
- **`POST /salvar` devolve a chave nova** quando recebe `formato=json` — o
  formulário do navegador não manda essa marca, então continua recebendo a página
  HTML de sempre. É a peça que faz
  o passo 8 existir: o aparelho **reinicia** logo depois de gravar
  (`ESP.restart()`), então o app não tem uma segunda chance de ler. Sem isso, o
  produtor teria de segurar os três botões de novo e digitar um PIN novo — duas
  idas ao aparelho para uma operação só. O aparelho já mostra essa chave na tela
  de confirmação do navegador; falta devolvê-la também em JSON.

**O que NÃO precisa ser feito, porque já existe:** guardar a chave anterior para
provar posse na rotação com a nuvem. Está no firmware (`chaveAnt` na NVS,
`chaveAnterior` em memória, usada por `sincronizarChaveNuvem`), e o servidor já
serve `POST /aparelhos/chave/rotacionar`.

### Consistência eventual, e por que não dá para prometer mais

Houve a ideia de garantir que "uma falha de internet não deixe app, nuvem e
aparelho com chaves diferentes". **Isso não é alcançável**, e tentar seria
desenhar contra a realidade: o aparelho troca a chave **localmente**, e a
configuração acontece justamente quando ele ainda não está na rede de casa.
Sempre existirá uma janela com aparelho e app na chave nova e a nuvem na antiga.

O que se garante:

| | Quando |
|---|---|
| **Aparelho e celular** | juntos, na mesma resposta do `/salvar` — nunca divergem |
| **Controle local** | volta na hora |
| **Nuvem** | quando o aparelho recuperar internet, por repetição automática |
| **Controle remoto** | indisponível até lá |

E o app **precisa dizer isso**, senão parece defeito:

> Acesso local atualizado. O acesso pela internet volta assim que o aparelho
> conectar.

### Firmware antigo: o app avisa em vez de mentir

Aparelho que não devolve a chave nova (programa anterior a esta rota) **rotaciona
mesmo assim** — a chave velha deixa de valer. Nesse caso **este celular perde o
acesso junto com os outros**, e a tela diz isso, mandando refazer "Conectar o
aparelho ao Wi-Fi" para recuperá-lo. Dizer "pronto" ali seria mentira, e a
descoberta viria depois, como comando recusado sem explicação.

### Ainda por testar em campo

Gravar o firmware, e então: revogar, confirmar que **este** celular continua
comandando, confirmar que um segundo celular com o QR antigo **não** comanda mais,
compartilhar um QR novo e confirmar que ele volta a comandar.

## Troca de dono (venda do aparelho)

Escrito em 05/08/2026. O caminho **existe hoje** — é o de sempre mais um passo —,
mas nunca tinha sido descrito, e é um caso que a banca pergunta.

### O procedimento

1. O novo dono tem o aparelho na mão, então tem tudo o que o sistema exige:
   segura os 3 botões, conecta no `Sentinela-Config`, lê o PIN do visor e faz
   **"Conectar o aparelho ao Wi-Fi"** pelo app. A estufa nasce cadastrada.
2. **Em seguida, "Tirar acesso dos outros celulares".** É este passo que fecha a
   venda: a chave gira, e o app do vendedor para de comandar — local e remoto.

**Nesta ordem, e não o contrário.** O vendedor revogando antes de entregar não
resolve: o novo dono leria a chave nova do aparelho do mesmo jeito, e o vendedor
teria uma janela com ela em mãos. Quem revoga tem de ser quem fica.

### Por que o passo 2 não é opcional

Configurar **não** tira o acesso de ninguém — a chave não muda. O app do vendedor
continua com ela, e a nuvem continua aceitando. Ele não alcança pela rede local,
porque está longe, mas **comanda pela internet**: mexe na temperatura de uma
estufa que não é mais dele.

### O que a revogação NÃO resolve

Duas coisas ficam para trás, e nenhuma tem conserto pelo lado de quem compra:

- **O vendedor continua recebendo notificações.** A inscrição de push é por
  celular e por `idHardware`, guardada na nuvem, e só sai quando ele **apagar a
  estufa do app dele** (`EstufasRepository.remover` chama
  `PushNotificationService.removerEstufa`). Revogar tira o controle, não os
  avisos: ele segue sendo acordado às 3h por uma estufa que vendeu. Depende da
  boa vontade dele.
- **O histórico é do aparelho, não do dono.** As leituras na nuvem são por
  `idHardware`, então o novo dono passa a ver as estufadas do anterior, e o
  anterior mantém no celular o que já baixou. Para temperatura de estufa isso é
  inofensivo — mas **não se pode afirmar que "os dados vão junto com o dono"**,
  porque não vão.

## Limite desta camada

Esta medida evita que uma pessoa envie comandos simples para a estufa sem
conhecer a chave. Ela não substitui HTTPS, controle de usuários, revogação de
tokens nem proteções de rede, que podem ser adicionadas em uma etapa futura.

## Compartilhar acesso entre celulares (31/07/2026)

Vários celulares sempre puderam comandar a mesma estufa — a chave é do
**aparelho**, não do celular — e o push já é por celular, com preferências
próprias. O que faltava era o segundo celular **receber** a chave.

A outra via seria entrar no modo de configuração, que derruba o aparelho do ar
enquanto dura. No meio de uma estufada, pedir que alguém vá até lá e interrompa o
monitoramento para instalar o app é caro e desnecessário: quem já pode comandar
pode delegar. É a família, não um estranho.

O menu da estufa mostra um **QR** com o convite. A câmera comum do outro celular
o lê e oferece abrir o Sentinela com a estufa preenchida.

**O convite escrito foi removido (04/08/2026).** Ele era mandado pelo
compartilhamento do sistema e colado no outro celular em "Nova Estufa" → "Colar
convite". Decisão do produtor: convite mandado por mensagem **fica gravado na
conversa, com a chave dentro, para sempre**, e apagar do próprio celular não
apaga do outro nem do backup dele. O preço está declarado — **compartilhar passou
a exigir estar junto**, e não há rede de segurança se a câmera do outro celular
não reconhecer o código.

Decisões:

- **Base64, e não texto cru.** Não esconde de ninguém — o objetivo é o convite
  chegar **inteiro**. Chave solta no meio de uma mensagem convida o aplicativo
  do caminho a "arrumar" espaços e quebras de linha, e ela chega diferente.
- **Marca de versão.** Convite de formato desconhecido é **recusado**, não
  interpretado pela metade: meio cadastro é pior que nenhum.
- **Acha o convite no meio da conversa**, porque é assim que ele chega — colado
  junto com o "oi pai, entra aí".
- ~~**O aviso viaja no texto**~~ — valia enquanto havia texto. Com só o QR, o
  aviso é da tela de quem compartilha, e ele encolheu para a única coisa que o
  produtor decide: *compartilhe só com quem você confia, porque quem tiver esta
  estufa no app comanda o aparelho de qualquer lugar*. Explicar que existe uma
  chave, e que ela viaja no convite, era explicar a máquina para justificar a
  regra.

**Limitação declarada:** com chave por aparelho não há como revogar **um**
celular. Gerar chave nova tranca todos, e todos reemparelham. Revogar
individualmente exigiria uma chave por celular, com o aparelho guardando várias
— grande, e para uma família não paga.
