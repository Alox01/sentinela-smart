# Sentinela Smart — retomada do TCC

> **Atualizado em 11/09/2026.** Este arquivo foi feito para ser colado ou anexado
> num chat novo, **sem acesso ao repositório**. Ele se sustenta sozinho. Quando
> houver um computador por perto, os detalhes estão nos arquivos citados em
> `docs/`.
>
> Substitui o `HANDOFF.md` como ponto de partida — aquele parou em 04/08 e não
> sabe da montagem do aparelho nem das mudanças de firmware de setembro.

---

## 1. O que é o projeto

**Sentinela Smart** é um sistema de IoT para **estufas de secagem de fumo**. Três
partes:

- **Aparelho** — ESP32 numa placa soldada, na estufa. Mede temperatura, umidade e
  chama; mostra num visor; tem botões, LEDs e sirene. **Decide sozinho, sem
  internet.**
- **Nuvem** — servidor Node.js/Express no Render (plano gratuito), banco
  PostgreSQL no Supabase. Guarda histórico, repassa comandos remotos, dispara
  notificações.
- **App** — Flutter, Android. Conversa com o aparelho **direto pela rede local**
  quando pode, e pela nuvem quando não pode.

**A ideia central é "edge-first":** o aparelho é a fonte da verdade e funciona
sozinho. A nuvem acrescenta histórico, acesso de longe e aviso no celular — mas se
ela cair, a estufa continua protegida.

**Os cinco objetivos declarados na proposta:** monitorar, controlar, sincronizar,
registrar e alertar. "Controlar" aqui é **o produtor mudar o ajuste, inclusive de
longe** — não é o aparelho acionar equipamento.

**Repositório:** `github.com/Alox01/sentinela-smart` (público). Branch de trabalho
e de deploy: `test/http-local-device` — o Render publica a partir dela. A `main`
fica no mesmo ponto.

---

## 2. Regras que não podem ser quebradas

**Git**
- Commits **em inglês**, no imperativo, explicando o *porquê*.
- **Nenhuma menção a IA** — nem Claude, nem Codex — em commit, branch ou texto
  versionado. **Sem a linha `Co-Authored-By`**, mesmo que alguma ferramenta peça.
  O histórico é público e é do TCC.
- **Nunca `git add .`** — o Flutter gera arquivos que não entram em commit.
  Adicionar caminho por caminho.
- Segredos **nunca** no repositório: `.env`, `google-services.json`, credencial do
  Firebase.

**Domínio — coisas que parecem erro e não são**
- **Temperatura em Fahrenheit de propósito.** O produtor pensa em °F. Nunca
  converter para Celsius.
- **Umidade nunca dispara alarme.** Só temperatura e fogo. Numa estufa de secagem,
  a umidade ficar bem abaixo do ajuste é o objetivo do processo.
- **A versão do firmware não sobe sozinha.** Está em `1.0` desde 04/08. Só muda
  quando o produtor pedir.
- **Durante o ajuste no aparelho, nenhum aviso sai para a nuvem — nem fogo.** A
  sirene local toca na hora; o aviso para o celular espera o ajuste acabar, com
  teto de 30 s. Decisão do produtor (11/09). Ver seção 4.

**Build do app** — o `--dart-define` é obrigatório, senão toda estufa aparece
OFFLINE:

```
flutter build apk --release --split-per-abi --dart-define=CLOUD_API_URL=https://estufa-server.onrender.com
```

**APK da apresentação** — acrescentar `--dart-define=ESCOPO_TCC=true`. Ele esconde o
que está fora dos cinco objetivos: compartilhar por QR Code, agendamento de ajuste
e a seção "Ações rápidas" do menu.

---

## 3. Onde o projeto está hoje

### Aparelho (hardware)

**Saiu do protoboard.** Placa perfurada 9×15 cm, soldada entre 26/08 e 01/09.

- **Conferida com multímetro em 01/09:** nenhum curto, as 22 ligações presentes,
  resistores medidos (3 × 220 Ω e 1 × 4,64 kΩ).
- **Todos os grupos funcionando em 09/09**, com o firmware real: visor, sirene,
  os três botões, dois LEDs, DHT22, DS18B20 e sensor de chama.
- Está numa **caixa provisória de papelão forrada com EVA**. Serve para bancada e
  demonstração; **não serve para deixar dias na estufa** (papelão absorve
  umidade e cede).

**Sensores**
- **Temperatura: DS18B20** (sonda selada, 5 m de cabo), no `GPIO 23`. Trocou de
  sensor em 09/09 — antes vinha do DHT22.
- **Umidade: DHT22**, no `GPIO 32`. Agora só entrega umidade.
- **Chama:** o que está ligado hoje **é um sensor de luz, não de chama** — o
  firmware inclusive chama o pino de `SENSOR_LUZ`. Detecta qualquer claridade.
  **Os três sensores de chama de verdade já chegaram e não foram trocados.** A
  troca é de três parafusos, no `GPIO 35`.

**Painel:** o LED de "controle de temperatura" foi **retirado de propósito**
(09/09). A via dele no borne ficou reservada para o relé da ventoinha.

**Três ligações frouxas no mesmo dia (09/09).** Duas eram juntas de solda feitas
em cima de outra junta; a terceira, fio de sonda multifilar mal preso num borne de
parafuso. **Antes de fechar qualquer caixa: puxar cada fio de leve.**

### Firmware

Compila em **87% da memória flash e 15% da RAM** (núcleo esp32 3.2.0). Precisa das
bibliotecas `OneWire` e `DallasTemperature`, já instaladas no computador.

**⚠️ Gravar a versão mais recente antes de qualquer teste.** O último commit do
firmware é `5280a1e`.

**O que mudou em setembro**, e por quê:

| Mudança | Motivo |
|---|---|
| Temperatura passou para o DS18B20 | os dois sensores ficam em pontos diferentes da estufa |
| Os dois sensores falham separados | antes, umidade quebrada derrubava o alarme de temperatura junto |
| Sem temperatura, o comando de aquecimento desliga | aparelho "cego" não pode manter a ventoinha ligada |
| Ajuste de umidade no aparelho | os botões mexem no alvo **do que o visor mostra** |
| Segurar o botão repete o passo | antes era um toque por grau; agora, um passo a cada 400 ms |
| Grava 1,5 s depois da última mudança | antes, queda de energia logo depois do ajuste o perdia |
| Nuvem espera enquanto se ajusta | o envio bloqueia o laço e parava o botão no meio do gesto |
| Prazo em toda conversa com a nuvem | o aperto de mão TLS esperava até **120 s**; agora 4 s |
| Motivo do último reinício no boot e no `/dados` | separa "travou" de "reiniciou" |
| Alertas esperam o fim do ajuste, com teto de 30 s | pedido do produtor; o teto cobre botão preso |

### App e servidor

Sem mudanças em setembro. Funcionando.

---

## 4. Problema conhecido: o aparelho engasga

**Sintoma (visto em 10/09):** às vezes os botões não respondem por alguns segundos
e o visor apaga e volta. Comandos e sensores funcionam; só a resposta local some e
volta.

**Causa confirmada no código:** o envio para a nuvem é **bloqueante** — enquanto
ele acontece, o aparelho não lê botão, não atualiza o visor e não responde ao app
pela rede local. Isso acontece a cada 20 s (busca de comandos) e a cada 60 s
(envio de leitura).

**O que já foi feito:**
- O **pior caso caiu de 120 s para uns 7 s**, com prazo em todas as conexões.
- Durante o ajuste, a nuvem **espera** — o botão não trava mais no meio.

**O que ainda não foi resolvido:** com o servidor acordado, cada envio ainda leva
**1 a 2 s**, que é o cálculo do TLS no próprio ESP32. O conserto estrutural é
**mover a rede para um núcleo separado do processador** (tarefa do FreeRTOS no
núcleo 0). Isso exige proteger as variáveis compartilhadas entre as duas tarefas,
senão o travamento vira corrupção de dado — pior. **Decidido: depois da banca.**

**Dúvida em aberto:** visor *apagando* não combina com travamento — travado, ele
congela no último número. Visor apagando é sinal de **reinício**. Para saber qual
dos dois, abrir no navegador do celular:

```
http://<ip-do-aparelho>/dados
```

- **`ligadoHaSegundos`** menor que o tempo que você está ali = reiniciou.
- **`motivoReinicio`** diz o porquê:
  - `QUEDA DE TENSAO` → **alimentação** (cabo, fonte, pico da sirene somado ao
    Wi-Fi). Não é código.
  - `TRAVOU: cao de guarda` ou `TRAVOU: excecao` → é o firmware.

**Para o TCC isso é material bom**, não defeito a esconder: limitação achada em
campo, causa confirmada no código, mitigação aplicada, solução estrutural
proposta. Ver seção 6.

---

## 5. O que falta fazer — em ordem

### A. Testes (agora)

**Este fim de semana, em outra casa:**

1. **Gravar o firmware `5280a1e` antes de ir.**
2. **Teste do IP fixo — o mais importante.** É o único conserto ainda não
   provado, e é o que falhou na frente do professor na faculdade.
   - **NÃO apagar o IP fixo antes.** O aparelho está com `192.168.1.200`. Numa
     casa cuja rede use outra faixa (`192.168.0.x`, `10.0.0.x`), esse número não
     pertence àquela rede.
   - O firmware deveria **ignorar** o IP fixo quando ele não cabe na rede, e
     pegar o que o roteador der.
   - **Conectou com outro IP** → o conserto funciona. Anotar o IP, fotografar o
     visor, anotar a data.
   - **Sumiu do ar** → o conserto não pegou.
3. **Se o visor apagar**, ler o `/dados` (seção 4) e anotar os dois campos.

**Depois:**

4. **Deixar ligado um dia inteiro** sem mexer. Defeito intermitente só aparece
   assim.
5. **Caminho da nuvem:** aparelho ligado, app fechado por horas, depois abrir o
   relatório. As horas em que o app esteve fechado têm que aparecer.
6. **Teste de transporte:** carregar a caixa até outro cômodo, pôr na mesa,
   conferir se tudo responde. Encontra a junta frouxa antes da banca.
7. **Trocar o sensor de luz pelo de chama.** Testar com isqueiro a 20 cm (tem
   que dar "detectada") e com uma lâmpada acesa perto (tem que **ignorar**).

### B. Matriz de evidências — o que vira a seção de resultados

Regra: **implementado não é validado.** Resultado ausente declarado vale mais que
resultado inventado.

| # | O que provar | Situação |
|---|---|---|
| 1 | Operação local com a internet desligada | **em aberto** |
| 2 | Comandos offline e sincronização ao reconectar | **em aberto** |
| 3 | Acesso remoto, de fora da propriedade | **em aberto** |
| 4 | Pareamento e revogação com dois celulares | ✅ 05/08/2026 |
| 5 | Alertas com o app aberto e fechado | ✅ 25/07 e 13/08/2026 |
| 6 | Uma estufada completa: relatório, eventos, gráfico, PDF e CSV | **em aberto** |
| 7 | Registro de cada teste com data, resultado, prints e limitação | **em aberto** |

**Roteiro rápido para o #1 e o #2** (uns 60 segundos, com o app):
Menu → "Detalhes da conexão" → confirmar modo **LOCAL** e **Pendências: 0** →
desligar o Wi-Fi e os dados do celular → mudar o ajuste → **Pendências: 1** →
religar o Wi-Fi → tocar em **Sincronizar** → **Pendências: 0** → conferir no visor
que o ajuste mudou. Print de cada passo.

**Evidência nova de setembro, que pode entrar:** placa conferida com multímetro
(01/09); todos os grupos funcionando na placa soldada (09/09); troca do sensor de
temperatura (09/09).

**Decidido sobre a troca de sensor:** as evidências colhidas com o DHT22 são usadas
como estão, e **atualizadas na entrega de outubro**.

### C. Compras

**Para fechar o aparelho:**
- Chave de fenda pequena ou jogo de precisão (se ainda não tiver)
- Caixa IP65 ou IP67 com **medida interna mínima de 300 × 150 × 100 mm** — o
  tamanho foi decidido pensando no relé e no contator que entram depois
- 4 espaçadores sextavados de **nylon M3 × 10 mm**, com parafusos
- Abraçadeiras de nylon; broca escalonada até 13,5 mm (para os prensa-cabos)
- Verniz **Implastec ISOTEC** + álcool isopropílico **99,8%** (não o de farmácia) —
  **por último**, com a placa testada

**Para os cabos longos dos sensores:**
- Resistor **2,2 kΩ** — só se o DHT22 falhar a 5 m; não trocar antes
- Resistor **4,7 kΩ** extra — pull-up do sensor de chama. **Obrigatório:** sem ele,
  cabo rompido faz o aparelho gritar incêndio falso

**Alimentação:** não comprar fonte de parede. Na bancada, USB do computador; na
estufa, um carregador de celular com cabo USB cortado.

### D. Depois da banca

- **Rede no núcleo separado** (o conserto estrutural da seção 4)
- **Acionamento da ventoinha** — tudo decidido, nada construído:
  - Motor medido na plaqueta: **WEG 1/8 cv, 220 V, 0,86 A**
  - Relé de 1 canal com optoacoplador **acionando um contator** (bobina 220 V). O
    relé daria conta sozinho; o contator entra porque a ventoinha liga muitas
    vezes e o relé gastaria em uma ou duas safras
  - **Uma caixa só**, com divisória entre a parte de 220 V e a placa (decisão de
    mercado: todo aparelho do ramo é assim)
  - Fonte interna de **5 W** (não 3 W), fusível **2 A retardado**, tomada com terra
  - Em qualquer falha — boot, travamento, reinício — **a ventoinha fica desligada**
- Verniz e caixa definitiva

---

## 6. Para escrever o TCC

**Onde está o texto:** o artigo está num `.docx` fora do repositório.
`ARTIGO_TCC_OUTLINE.md` tem o esqueleto seção por seção, com as fontes de cada
fato. `ARTIGO_CONTINUACAO.md` tem texto pronto para Resultados, Conclusão, Resumo
e Abstract.

**⚠️ Conferir antes de entregar:** o texto de continuação diz que o hardware real
*"poderá substituir o simulador"*. Isso foi escrito quando só havia o simulador.
**Hoje o aparelho físico existe, está soldado e foi testado** — o texto precisa
dizer isso.

**Como escrever cada resultado:** três frases — **o que foi feito**, **o que
aconteceu**, **o que ficou de fora**. A terceira é a que dá credibilidade;
resultado sem limitação declarada é o primeiro que a banca questiona.

**Formulações exatas que valem copiar:**
- **iOS:** "previsto e configurado, não validado por falta de hardware Apple".
  Não dizer "compatível porque é Flutter" — sem as permissões de rede local o iOS
  bloqueia o mDNS, e a parte edge-first deixa de existir.
- **Simulador:** "reproduz o mesmo contrato de comunicação e o comportamento
  lógico do ESP32, não toda a física de uma estufa real".

**Limitação pronta para a seção de conclusão — o engasgo do aparelho:**
- *Feito:* o envio à nuvem é síncrono e bloqueia o laço de controle local; foi
  identificado em teste de campo (10/09), com a causa confirmada no código.
- *Aconteceu:* o pior caso chegava a 120 s, por herdar o prazo padrão do aperto
  de mão TLS; com prazos explícitos caiu para cerca de 7 s, e o tráfego de rotina
  passou a esperar enquanto o produtor ajusta.
- *Ficou de fora:* o bloqueio de rotina de 1 a 2 s permanece; a solução
  estrutural (rede em tarefa separada, no outro núcleo do processador) fica como
  trabalho futuro, porque exige sincronizar o estado entre as tarefas.

**Outras limitações honestas:** a notificação push depende da nuvem e do Firebase;
queda simultânea de luz e internet não é 100% distinguível sem hardware dedicado;
validação em campo ainda inicial.

**Trabalhos futuros:** acionamento da ventoinha (seção 5D), rede em núcleo
separado, bateria com sensor de tensão, caixa definitiva IP65.

---

## 7. Onde está cada coisa no repositório

| Arquivo | O que tem |
|---|---|
| `docs/CONVENCOES.md` | regras de commit, comandos de build, fatos de domínio |
| `docs/AUDITORIA.md` | **fila de trabalho** — item D3 é o engasgo |
| `docs/PLANO_POS_TESTES.md` | a matriz de evidências completa |
| `docs/MONTAGEM_DEFINITIVA.md` | o aparelho: mapa da placa, conferência, compras, acionamento |
| `docs/ARTIGO_TCC_OUTLINE.md` | esqueleto do artigo, com fontes |
| `docs/ARTIGO_CONTINUACAO.md` | texto pronto de Resultados, Conclusão, Resumo |
| `docs/DEMO.md` | roteiro da demonstração |
| `docs/CONTRATO_API.md` | o que o aparelho publica em `/dados` e `/status` |
| `firmware/sentinela_esp32/` | o firmware |
| `firmware/teste_placa/` | esquete de teste de bancada |

**Compilar o firmware** (o `arduino-cli` vem dentro da IDE do Arduino, não está no
PATH):

```
"%LOCALAPPDATA%\Programs\Arduino IDE\resources\app\lib\backend\resources\arduino-cli.exe" compile --fqbn esp32:esp32:esp32 firmware/sentinela_esp32
```

Saudável: ~87% do flash. Salto grande = alguma biblioteca entrou sem querer.

---

## 8. Decisões que ainda dependem do produtor

- **A sirene também deveria esperar o fim do ajuste?** Hoje ela toca na hora; só o
  aviso para o celular espera. Fazer a sirene esperar é decisão maior, porque ela
  é o sinal de segurança principal.
- **A ventoinha empurra o ar quente da fornalha, ou existe para resfriar?** O
  firmware liga o comando quando a temperatura **cai** — lógica de aquecedor. Se a
  ventoinha for para resfriar, o sentido é o inverso. **Decidir antes de ligar o
  relé.**
- **Três commits antigos têm a linha `Co-Authored-By`.** Decisão do produtor e do
  orientador sobre o que fazer com eles.
