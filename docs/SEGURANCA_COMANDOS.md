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

### Modelo B — **implementado** (firmware 1.24.0, 31/07/2026)

O PIN é sorteado a cada entrada no modo de configuração e ocupa o visor de 4
dígitos enquanto vale. `GET /config/identidade` passa a exigi-lo; o app pede os
4 números e, com eles, recebe a chave longa sem ninguém digitá-la.

O que o PIN fecha: o ponto de acesso do modo de configuração é **aberto**. Sem
ele, qualquer um ao alcance do Wi-Fi naquele momento pediria a identidade e
levaria a chave **sem nunca chegar perto do aparelho**. Com ele, é preciso estar
olhando o visor.

As três proteções que fazem 4 dígitos bastarem, todas no firmware:

- **sorteado por entrada** — um PIN fixo viraria segredo permanente de 4 dígitos;
- **morre em 5 erros** — sem limite, varrer 10 mil combinações leva minutos. O
  visor volta a mostrar `----`, que é o sinal de "saia e entre de novo";
- **vale só no modo de configuração**, que já expira sozinho, e só na rede local.

O Modelo A (etiqueta) fica descartado: era justamente digitar chave longa.

## Limite desta camada

Esta medida evita que uma pessoa envie comandos simples para a estufa sem
conhecer a chave. Ela não substitui HTTPS, controle de usuários, revogação de
tokens nem proteções de rede, que podem ser adicionadas em uma etapa futura.
