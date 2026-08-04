/*
  Sentinela Smart - firmware do ESP32 (controlador local + camada de rede)

  Baseado no controlador standalone (DHT22, botoes, display, LEDs, buzzer),
  mantendo toda a logica local intacta - ela continua funcionando mesmo sem
  Wi-Fi (edge-first). Acrescenta por cima uma camada de rede que fala o contrato
  do app (docs/CONTRATO_API.md):

    GET  /status        -> estado completo (status + config)
    GET  /  e  /dados   -> formato simples compativel com o app
    POST /sincronizar   -> ajustes com token e Last-Write-Wins por campo

  Dependencias (Arduino Library Manager):
    - DHT sensor library (Adafruit)
    - TM1637Display (Avishay Orpaz)
    - ArduinoJson v7+ (Benoit Blanchon)
  Placa: ESP32 (framework Arduino).

  ATENCAO:
    1. WIFI_SSID, WIFI_PASS e DEVICE_TOKEN abaixo sao apenas o valor DE
       FABRICA, usado ate alguem configurar o aparelho.
    2. Depois de gravado, da para trocar rede e chave sem computador:
       segure os TRES botoes por 3 s, conecte na rede "Sentinela-Config" e
       abra o navegador. O que for salvo ali fica na NVS e tem precedencia.
    3. O DEVICE_TOKEN deve ser IGUAL a chave de acesso cadastrada no app.
*/

#include <WiFi.h>
#include <ESPmDNS.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <esp_netif.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <time.h>
#include <DHT.h>
#include <TM1637Display.h>
#include <ArduinoJson.h>
#include <Preferences.h>

// ===================== CONFIG (preencher) =====================
const char* WIFI_SSID       = "SUA_REDE_WIFI";
const char* WIFI_PASS       = "SUA_SENHA_WIFI";
// Mesma chave usada no app (campo "Chave de acesso") e no ESTUFA_API_TOKEN.
// Deixe "" para liberar comandos sem token (apenas em rede local confiavel).
const char* DEVICE_TOKEN    = "COLE_AQUI_O_MESMO_TOKEN_DO_APP";
// O id do aparelho e gerado do chip (MAC) no setup -> unico por ESP, sem
// precisar configurar nada. Cada aparelho vira o seu na nuvem (status por
// aparelho). Ex.: "ESP32_A1B2C3".
// Incrementar a cada mudanca de comportamento: e o unico jeito de saber, pelo
// /status, qual firmware um aparelho em campo esta rodando.
// 1.24.0: PIN de 4 digitos no visor para entregar a chave. O ponto de acesso do
//        modo de configuracao e ABERTO: sem o PIN, quem estivesse ao alcance do
//        wifi naquele momento pediria /config/identidade e levaria a chave sem
//        nunca chegar perto do aparelho. Sorteado a cada entrada, morre depois
//        de 5 erros, e o visor de 4 digitos o mostra inteiro.
// 1.23.0: reporta o proprio `ipLocal` em cada leitura. O nome mDNS era a unica
//        porta local do app; quando ele nao resolve, o endereco guardado vira a
//        segunda. Tambem permite dizer de fora onde o aparelho esta, em vez de
//        mandar procurar no roteador.
// 1.22.0: chave vazia no formulario MANTEM a atual, em vez de apagar. Apagar
//        fazia o boot seguinte gerar uma chave aleatoria desconhecida do app e
//        da nuvem, e o aparelho ficava mudo sem nada explicando. O formulario
//        ja prometia isso; era a gravacao que nao cumpria.
// 1.21.0: guarda o gateway e a mascara que o ROTEADOR entrega no DHCP e usa
//        esses valores quando um IP fixo e configurado sem eles. O produtor
//        nao tem por que saber esses numeros, e adivinhar .1 quebrava redes com
//        o gateway em .254 - local funcionando e nuvem muda, sem nada explicando.
//        Os campos sairam do app; o formulario do aparelho ainda os aceita.
//        O gateway aprendido tambem vai em /config/identidade, para o app
//        deixar o campo de IP fixo quase pronto com a faixa certa.
// 1.20.0: o app le a identidade (id, nome local e CHAVE) de
//        `GET /config/identidade`, que so responde no modo de configuracao -
//        presenca fisica. O formulario HTML deixa de vir com a chave
//        preenchida. Assim o produtor nunca precisa ver nem digitar a chave;
//        sem exibir, a recuperacao passa a ser entrar no modo de configuracao
//        de novo, que e o modelo do adesivo do roteador.
// 1.19.0: reporta `alertaTemperatura` - a CONDICAO de temperatura fora da
//        faixa - separada de `alarmeAtivo`, que diz se a sirene esta tocando.
//        Desligar a sirene do aparelho zerava `alarmeAtivo`, e a nuvem deixava
//        de mandar a notificacao de temperatura para o celular: a sirene da
//        estufa estava mandando no aviso do celular, que tem preferencias
//        proprias.
// 1.18.0: chave de acesso POR APARELHO. Gera uma aleatoria quando nao existe
//        nenhuma (aparelho novo), registra na nuvem por TOFU e oferece "gerar
//        nova chave" no modo de configuracao - presenca fisica -, rotacionando
//        na nuvem com prova de posse da anterior. Aparelho que ja tem chave
//        nunca e trocado sozinho: se o registro falhasse, o produtor perderia
//        o acesso ao que funcionava.
// 1.17.0: o limite de incendio por temperatura passa a acompanhar o ajuste
//        (ajuste > 170 F -> ajuste + 5), como logica.js ja fazia no servidor.
//        Os dois discordavam: com ajuste em 172, o aparelho alarmava aos 175 e
//        a nuvem so aos 177.
// 1.16.0: o silencio cobre so o fogo que JA existia quando o botao foi
//        apertado. Fogo que comeca durante os 10 min cancela o silencio e toca:
//        apertar diz "ja sei DESTE fogo", nao "nao me avise de fogo por 10 min".
//        As duas causas contam separado, e uma que cessa e volta conta como
//        nova. Achado em teste de campo - silenciar e poucos minutos depois
//        acender a chama no sensor nao produzia som nenhum.
// 1.15.0: a temperatura de incendio (>175 F) passa a tocar CONTINUO, como a
//        chama. Ate aqui ela caia no bipe intermitente do alarme comum, apesar
//        de ser tao grave - quem esta na estufa distingue os dois pelo som.
// 1.14.0: o silencio de 10 min passa a valer tambem para FOGO. Quem aperta o
//        botao (ou o do app) ja esta ciente - viu o aviso ou ouviu a sirene - e
//        foi buscar agua ou chamar socorro; a sirene ao lado so atrapalha. Nao
//        e liga/desliga: o prazo vence sozinho e o alarme volta, entao nao da
//        para silenciar e esquecer.
// 1.13.0: segurar SO o botao do buzzer por 3 s liga/desliga a sirene de
//        temperatura deste aparelho, sem celular nem internet. O interruptor do
//        app e global (vale para todas as estufas); desligar uma so e uma
//        decisao tomada na frente dela. Confirma com apitos e LED.
// 1.12.0: o alarme de TEMPERATURA pode ser desligado pelo app (buzzerAtivo,
//        LWW, NVS). Fogo nunca e afetado: sensor de chama e temperatura de
//        incendio (limiteFogoF()) tocam sempre. So a sirene fisica cala - o
//        push segue.
// 1.11.0: ao entrar no modo de configuracao, apita e pisca os 3 LEDs (sinal
//        fisico inconfundivel); visor mostra "----" em vez de tentar "ConF",
//        que um display de 7 segmentos nao escreve legivel.
// 1.10.0: a pagina de configuracao mostra o nome local do aparelho (antes so
//        aparecia no Monitor Serial, que exige um computador com a IDE) e
//        aceita IP fixo, para roteador do provedor onde nao da para reservar.
// 1.9.0: modo de configuracao por ponto de acesso (segurar os 3 botoes por
//        3 s) - Wi-Fi e chave passam a sair da NVS, entao trocar de roteador
//        nao exige mais regravar o firmware com um computador.
// 1.8.0: teto da folga da acomodacao de 20 para 8 F/% - o teto antigo cabia
//        um desvio grande demais dentro do "perdao" de um ajuste.
// 1.7.0: janela de acomodacao de 20 para 5 min - medido na estufa real, que
//        alcanca o alvo novo antes disso; a janela antiga atrasava o alerta.
// 1.6.0: ajustes guardados na memoria nao-volatil - uma queda de energia nao
//        devolve mais o alvo ao padrao no meio de uma estufada.
// 1.5.0: a folga da acomodacao cobre so a distancia que a mudanca criou -
//        aproximar o alvo da temperatura atual nao silencia mais o alarme.
// 1.4.0: acomodacao no proprio aparelho apos mudar o alvo - antes o ESP
//        alarmava na hora ao subir o ajuste, ignorando a acomodacao que so
//        existia no app.
// 1.3.0: envio imediato quando o alarme/incendio comeca ou termina (antes a
//        nuvem so sabia no ciclo de 1 min, e um teste rapido nem chegava).
// 1.2.0: nome local mDNS exclusivo por aparelho, com fallback para o IP.
// 1.1.0: silencio com prazo de 10 min, busca de comandos na nuvem, leituras
//        inteiras, id unico por chip.
const char* VERSAO_FIRMWARE = "1.25.0";
// URL da nuvem: para onde o aparelho empurra as leituras (historico + acesso
// remoto) e de onde ele busca os ajustes feitos pelo app quando o celular esta
// longe da propriedade. Deixe "" para operar so na rede local.
const char* CLOUD_URL = "https://estufa-server.onrender.com";
const unsigned long PUSH_INTERVAL_MS = 60000;  // envia uma leitura a cada 1 min
// Mais frequente que o push: e o tempo que o produtor espera entre mexer no app
// de longe e a estufa obedecer. Nao diminua muito: cada busca e um handshake
// HTTPS que segura o loop por 1-2 s, tempo que falta ao controle local.
const unsigned long COMANDOS_INTERVAL_MS = 20000;
// =============================================================

// ---- Pinos (mapa de referencia) ----
#define DHTPIN 32
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

#define SENSOR_LUZ 35
const bool SENSOR_LUZ_ATIVO_LOW = true;

#define BOTAO_BUZZER 13
#define BOTAO_VERDE 4
#define BOTAO_VERMELHO 33

#define LED_ALERTA 26
#define LED_UMIDADE 27
#define LED_CONTROLE_TEMP 14
#define BUZZER 25

#define DISPLAY_CLK 18
#define DISPLAY_DIO 19
TM1637Display display(DISPLAY_CLK, DISPLAY_DIO);

WebServer server(80);

// ---- Estado local (do controlador original) ----
bool ultimoBuzzer = HIGH;
bool ultimoVerde = HIGH;
bool ultimoVermelho = HIGH;

bool estavelBuzzer = HIGH;
bool estavelVerde = HIGH;
bool estavelVermelho = HIGH;

unsigned long debounceBuzzer = 0;
unsigned long debounceVerde = 0;
unsigned long debounceVermelho = 0;

const unsigned long debounceDelay = 80;

unsigned long ultimoTempoLeitura = 0;
unsigned long tempoInicioUmidade = 0;
unsigned long ultimoTempoAjuste = 0;
unsigned long ultimoPiscaAjuste = 0;
unsigned long ultimoTempoBuzzer = 0;

const unsigned long intervaloLeitura = 2500;
const unsigned long tempoMostrarUmidade = 10000;
const unsigned long tempoSairAjuste = 5000;
const unsigned long intervaloPiscaAjuste = 400;
const unsigned long intervaloBuzzer = 1000;
const unsigned long duracaoBuzzer = 180;

bool displayAjusteLigado = true;
bool mostrandoUmidade = false;
bool modoAjuste = false;

bool alertaLuz = false;
bool alertaTemperatura = false;
bool buzzerLigadoAgora = false;
bool ledControleLigado = false;

// Silencio com prazo, espelhando TEMPO_SILENCIO do servidor (logica.js): o
// alarme volta sozinho depois de 10 min se a temperatura continuar fora. Guarda
// o instante-limite em millis() (nao no relogio NTP) para funcionar mesmo sem
// hora sincronizada. 0 = nao silenciado.
const unsigned long TEMPO_SILENCIO_MS = 10UL * 60UL * 1000UL;
unsigned long silencioAteMillis = 0;

// Que fogo ja estava acontecendo quando o silencio comecou. E so esse que o
// silencio cobre: quem aperta o botao esta dizendo "ja sei DESTE fogo", e nao
// "nao me avise de fogo por 10 minutos". As duas causas andam separadas porque
// sao noticias diferentes - a chama pegou no papel, ou a estufa inteira passou
// do limite de fogo.
bool luzCobertaPeloSilencio = false;
bool tempIncendioCobertaPeloSilencio = false;

// Leituras em numeros inteiros: o display tem 4 digitos e as casas decimais do
// DHT22 nao acrescentam nada util para o produtor.
int temperaturaF = 0;
int umidade = 0;

bool leituraOk = false;

int temperaturaAlvoF = 76;
int margemF = 8;

// Acomodacao apos mudar o alvo: a estufa leva tempo para alcancar o ajuste
// novo, e alarmar nesse caminho seria acusar um problema que o proprio
// produtor causou. A folga acompanha o tamanho da mudanca (mexer 1 grau nao
// pode perdoar um desvio de 20) e vale por um tempo. Espelha a mesma regra do
// app. Incendio NUNCA e afetado: seguranca nao se acomoda.
// 5 min: medido na estufa real, que alcanca um alvo 10-15 F acima em menos que
// isso. Precisa ser igual ao do app e do simulador.
const unsigned long TEMPO_ACOMODACAO_MS = 5UL * 60UL * 1000UL;
const int FOLGA_ACOMODACAO_MAX = 8;
unsigned long acomodacaoAteMillis = 0;
int folgaAcomodacao = 0;

// Ajustes guardados na memoria nao-volatil (NVS): sem isso, uma queda de
// energia devolvia o alvo ao padrao de fabrica no meio de uma estufada - o
// produtor recuperava a luz e a estufa voltava aquecendo para o alvo errado.
// O silencio do alarme NAO e guardado de proposito: apos um reinicio o alarme
// deve voltar a valer.
Preferences prefs;
bool configSuja = false;
unsigned long ultimoSalvamentoConfig = 0;
const unsigned long INTERVALO_SALVAR_CONFIG_MS = 5000;

// ---- Novo: ajuste de umidade e timestamps para o Last-Write-Wins ----
// O hardware nao controla umidade fisicamente (sem umidificador), mas registra
// o ajuste que o app envia para exibir e reportar. Os timestamps sao epoch ms,
// vindos do app; iniciam em 0 para que o primeiro comando sempre venca.
int umidadeAlvo = 90;
long long tempTimestamp = 0;
long long umidTimestamp = 0;
long long modoSilenciosoTimestamp = 0;

// Buzzer do alarme de TEMPERATURA: o produtor pode desliga-lo (ha quem nao
// aguente o bipe durante a estufada). Fogo NUNCA e afetado - o sensor de chama
// e a temperatura de incendio (limiteFogoF()) sempre tocam. So o alarme de temperatura
// comum cala. Persistido em NVS; LWW pelo buzzerTimestamp.
bool buzzerTemperaturaAtivo = true;
long long buzzerTimestamp = 0;

unsigned long ultimaTentativaWifi = 0;
const unsigned long intervaloReconexaoWifi = 15000;
unsigned long ultimoPushNuvem = 0;
// Ultimo estado de emergencia ja enviado, para detectar a borda e empurrar na
// hora em que algo comeca (ou termina), em vez de esperar o ciclo de 1 min.
bool ultimoFogoEnviado = false;
bool ultimoAlarmeEnviado = false;
unsigned long ultimaBuscaComandos = 0;
unsigned long ultimaTentativaMdns = 0;
String idHardware;  // definido no setup a partir do chip (unico por ESP)
String nomeLocal;   // ex.: sentinela-a1b2c3 -> http://sentinela-a1b2c3.local
bool mdnsAtivo = false;
const unsigned long intervaloTentativaMdns = 15000;

// --- Configuracao de rede em tempo de execucao ---
// Wi-Fi e chave saem da NVS; as constantes do topo viram apenas o valor de
// fabrica, usado enquanto ninguem configurou pelo modo de configuracao. Sem
// isto, trocar de roteador exigiria regravar o firmware com um computador.
String wifiSsid;
String wifiPass;
String tokenAparelho;
// Chave anterior, guardada SO enquanto a nuvem nao souber da nova. A rotacao
// precisa provar posse da antiga; sem guardar, gerar chave nova trancaria o
// proprio aparelho fora da nuvem. Apagada assim que a troca e aceita.
String chaveAnterior;
bool chaveRegistradaNaNuvem = false;

// IP fixo (opcional). Vazio = DHCP, que e o normal. Existe porque em muita
// propriedade o roteador e do provedor e o produtor nao tem acesso para fazer
// reserva de DHCP - sem isto, so restaria reconferir o IP a cada queda de luz.
String ipFixo;
String gatewayFixo;
String mascaraFixa;
// Gateway e mascara que o roteador entregou na ultima conexao por DHCP. Servem
// de base quando o produtor fixa um IP sem informar os dois - ele nao tem por
// que saber esses numeros, e o roteador ja os disse ao aparelho.
String gatewayAprendido;
String mascaraAprendida;

// --- Modo de configuracao (ponto de acesso) ---
// Entra segurando os TRES botoes por 3 s: quem nao esta na frente do aparelho
// nao abre a pagina. Sai sozinho depois de um tempo ocioso, para um modo aberto
// por engano nao ficar exposto ate alguem lembrar.
// Responder a QUALQUER consulta de nome com o proprio IP e o que faz o celular
// abrir a pagina sozinho ("conectar-se a rede"), como num Wi-Fi de hotel. Sem
// isto o produtor teria que digitar 192.168.4.1 de cabeca.
DNSServer dnsServer;
const byte PORTA_DNS = 53;
const char* NOME_AP_CONFIG = "Sentinela-Config";
const unsigned long TEMPO_SEGURAR_CONFIG_MS = 3000;
const unsigned long TEMPO_CONFIG_OCIOSO_MS = 5UL * 60UL * 1000UL;
bool modoConfig = false;
// PIN de emparelhamento: 4 digitos sorteados a cada entrada no modo de
// configuracao e mostrados no visor. E o que prova que quem pede a chave esta
// OLHANDO o aparelho - sem ele, o ponto de acesso e aberto e qualquer um ao
// alcance do wifi naquele momento levaria a chave. O visor tem 4 digitos, entao
// o PIN cabe nele inteiro; a chave longa, nao.
//
// 4 digitos bastam porque o PIN e temporario: vale so enquanto o modo de
// configuracao durar (que ja expira sozinho), so na rede local, e morre depois
// de poucos erros. Mesmo racional do pareamento de Bluetooth.
int pinConfig = -1;
int tentativasPin = 0;
const int MAX_TENTATIVAS_PIN = 5;
unsigned long tresBotoesDesdeMs = 0;
unsigned long ultimaAtividadeConfig = 0;

// --- Liga/desliga a sirene de temperatura no proprio aparelho ---
// Segurar SO o botao do buzzer por 3 s alterna `buzzerTemperaturaAtivo`. Existe
// porque o interruptor do app e global (vale para todas as estufas): desligar
// uma so estufa e uma decisao tomada na frente daquele aparelho, e o produtor no
// meio da lavoura pode nao ter celular, sinal, nem internet. Fogo nunca e
// afetado - so a sirene de temperatura cala.
const unsigned long TEMPO_SEGURAR_BUZZER_MS = 3000;
unsigned long buzzerSeguradoDesdeMs = 0;
bool buzzerAlternadoNesteAperto = false;

// Prototipos explicitos: o gerador automatico do Arduino as vezes nao monta a
// assinatura certa para funcoes que recebem tipos do ArduinoJson.
void aplicarAjustes(JsonObjectConst entrada, JsonArray aplicadas,
                    JsonArray ignoradas);
void buscarComandosNuvem();
void sincronizarChaveNuvem();
bool estadoDeAlertaMudou();
void carregarConfigPersistida();
void salvarConfigSeNecessario();
void definirTemperaturaAlvo(int novoAlvo);
int margemVigente();
void atualizarEstadoTemperatura();
bool estaSilenciado();
void silenciarPorPrazo();
void reativarAlarme();
void verificarSegurarBuzzer();
void confirmarAlternanciaBuzzer(bool ligou);
long long nowMs();
void iniciarMdns();
void aplicarIpFixoSeConfigurado();
void verificarModoConfig();
void entrarModoConfig();
void handleConfigPagina();
void handleConfigSalvar();
void guardarRedeAprendida();
void handleConfigIdentidade();

// ============================================================
//  SETUP
// ============================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  // Id unico do aparelho a partir do MAC do chip (6 hex do final).
  uint64_t chipMac = ESP.getEfuseMac();
  char idBuf[16];
  snprintf(idBuf, sizeof(idBuf), "ESP32_%06X", (unsigned)(chipMac & 0xFFFFFF));
  idHardware = idBuf;
  char nomeLocalBuf[24];
  snprintf(nomeLocalBuf, sizeof(nomeLocalBuf), "sentinela-%06x",
           (unsigned)(chipMac & 0xFFFFFF));
  nomeLocal = nomeLocalBuf;
  Serial.print("ID do aparelho: ");
  Serial.println(idHardware);

  carregarConfigPersistida();

  dht.begin();

  pinMode(SENSOR_LUZ, INPUT);
  pinMode(BOTAO_BUZZER, INPUT_PULLUP);
  pinMode(BOTAO_VERDE, INPUT_PULLUP);
  pinMode(BOTAO_VERMELHO, INPUT_PULLUP);

  pinMode(LED_ALERTA, OUTPUT);
  pinMode(LED_UMIDADE, OUTPUT);
  pinMode(LED_CONTROLE_TEMP, OUTPUT);
  pinMode(BUZZER, OUTPUT);

  digitalWrite(LED_ALERTA, LOW);
  digitalWrite(LED_UMIDADE, LOW);
  digitalWrite(LED_CONTROLE_TEMP, LOW);
  digitalWrite(BUZZER, LOW);

  display.setBrightness(7);
  display.clear();

  conectarWifi();

  // Coleta os cabecalhos de autenticacao (o WebServer so guarda os listados).
  const char* cabecalhos[] = {"Authorization", "X-Device-Token", "X-API-Token"};
  server.collectHeaders(cabecalhos, 3);

  server.on("/status", HTTP_GET, handleStatus);
  server.on("/", HTTP_GET, handleSimple);
  server.on("/dados", HTTP_GET, handleSimple);
  server.on("/sincronizar", HTTP_POST, handleSincronizar);
  server.on("/salvar", HTTP_POST, handleConfigSalvar);
  server.on("/config/identidade", HTTP_GET, handleConfigIdentidade);
  server.onNotFound([]() {
    // No ponto de acesso, qualquer endereco cai no formulario: o produtor nao
    // precisa acertar a URL, basta abrir o navegador.
    if (modoConfig) {
      String meuEndereco = WiFi.softAPIP().toString();
      // O celular testa a internet buscando uma URL conhecida e esperando uma
      // resposta especifica. Responder com DESVIO para o aparelho e o sinal que
      // ele entende como "esta rede tem uma pagina para abrir" - e o que faz
      // surgir o aviso de conectar-se a rede. Servir a pagina direto aqui nao
      // aciona esse aviso de forma confiavel.
      if (server.hostHeader() != meuEndereco) {
        server.sendHeader("Location", "http://" + meuEndereco + "/", true);
        server.send(302, "text/plain", "");
        return;
      }
      handleConfigPagina();
      return;
    }
    server.send(404, "application/json", "{\"erro\":\"Rota nao encontrada\"}");
  });
  server.begin();
  iniciarMdns();

  Serial.println("Sistema iniciado");
  Serial.print("Servidor HTTP em: http://");
  Serial.println(WiFi.localIP());
}

// ============================================================
//  LOOP
// ============================================================
void loop() {
  unsigned long agora = millis();

  server.handleClient();
  if (modoConfig) dnsServer.processNextRequest();
  manterWifi();

  // Emergencia nao espera o proximo envio agendado. Sem isto, um incendio so
  // chegaria a nuvem ate um minuto depois - e um teste rapido no sensor de
  // chama comecava e terminava entre dois envios, sem a nuvem ver nada.
  // No modo de configuracao o aparelho e um ponto de acesso, sem saida para a
  // internet: tentar falar com a nuvem so gastaria segundos do loop em
  // conexoes fadadas a falhar.
  if (!modoConfig) {
    if (estadoDeAlertaMudou()) {
      ultimoPushNuvem = millis();
      empurrarLeituraNuvem();
    } else if (millis() - ultimoPushNuvem >= PUSH_INTERVAL_MS) {
      ultimoPushNuvem = millis();
      empurrarLeituraNuvem();
    }

    if (millis() - ultimaBuscaComandos >= COMANDOS_INTERVAL_MS) {
      ultimaBuscaComandos = millis();
      buscarComandosNuvem();
      // Pega carona no mesmo intervalo: nao ha pressa, e a funcao sai na hora
      // quando nao ha nada a registrar.
      sincronizarChaveNuvem();
    }
  }

  verificarSensorLuz();
  verificarModoConfig();
  verificarBotoes();
  verificarTempos();
  salvarConfigSeNecessario();

  if (agora - ultimoTempoLeitura >= intervaloLeitura) {
    ultimoTempoLeitura = agora;
    lerDHT22();
  }

  atualizarSaidas();
  atualizarDisplay();
}

// ============================================================
//  REDE
// ============================================================
void conectarWifi() {
  if (wifiSsid.length() == 0) return;
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  aplicarIpFixoSeConfigurado();
  WiFi.begin(wifiSsid.c_str(), wifiPass.c_str());

  Serial.print("Conectando ao Wi-Fi");
  unsigned long inicio = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - inicio < 15000) {
    delay(300);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Conectado. IP: ");
    Serial.println(WiFi.localIP());
    guardarRedeAprendida();
    // NTP para timestamp real (fuso nao importa, usamos epoch em ms).
    configTime(0, 0, "pool.ntp.org", "time.google.com");
  } else {
    Serial.println("Sem Wi-Fi - operando em modo local standalone.");
  }
}

// Anota o que o roteador entregou, para um IP fixo configurado depois nao
// precisar que o produtor saiba o gateway e a mascara da rede dele. So grava
// quando muda: a NVS tem ciclos de escrita contados, e isto roda a cada conexao.
void guardarRedeAprendida() {
  if (WiFi.status() != WL_CONNECTED) return;
  const String gateway = WiFi.gatewayIP().toString();
  const String mascara = WiFi.subnetMask().toString();
  if (gateway == "0.0.0.0" || mascara == "0.0.0.0") return;
  if (gateway == gatewayAprendido && mascara == mascaraAprendida) return;

  gatewayAprendido = gateway;
  mascaraAprendida = mascara;
  prefs.begin("sentinela", false);
  prefs.putString("gwDhcp", gateway);
  prefs.putString("mascDhcp", mascara);
  prefs.end();
  Serial.print("Rede aprendida - gateway ");
  Serial.print(gateway);
  Serial.print(", mascara ");
  Serial.println(mascara);
}

// Fixa o endereco antes de conectar, quando o produtor configurou um. Se algo
// estiver malformado, cai no DHCP: um IP invalido deixaria o aparelho invisivel
// na rede, que e pior do que um endereco que muda.
void aplicarIpFixoSeConfigurado() {
  if (ipFixo.length() == 0) return;

  IPAddress ip, gateway, mascara;
  if (!ip.fromString(ipFixo)) {
    Serial.println("IP fixo invalido: usando DHCP.");
    return;
  }
  // Ordem de preferencia: o que o produtor informou, depois o que o ROTEADOR
  // ensinou numa conexao DHCP anterior, e so entao o palpite. O que o roteador
  // entregou vale mais que qualquer chute: ha redes com o gateway em .254, e
  // adivinhar .1 nelas deixaria o aparelho sem internet - local funcionando,
  // nuvem muda, sem nada na tela explicando. Como o IP fixo e uma reserva usada
  // depois de o aparelho ja ter entrado na rede, o aprendido quase sempre existe.
  if (!gateway.fromString(gatewayFixo)) {
    if (!gateway.fromString(gatewayAprendido)) {
      gateway = IPAddress(ip[0], ip[1], ip[2], 1);
    }
  }
  if (!mascara.fromString(mascaraFixa)) {
    if (!mascara.fromString(mascaraAprendida)) {
      mascara = IPAddress(255, 255, 255, 0);
    }
  }

  // O gateway tambem responde como DNS na esmagadora maioria das redes
  // domesticas - e o aparelho precisa de DNS para falar com a nuvem.
  if (!WiFi.config(ip, gateway, mascara, gateway)) {
    Serial.println("Falha ao aplicar IP fixo: usando DHCP.");
    return;
  }
  Serial.print("IP fixo: ");
  Serial.println(ipFixo);
}

// Reconecta em segundo plano sem travar o controle local.
void manterWifi() {
  // No modo de configuracao o radio esta servindo o ponto de acesso: tentar
  // reconectar aqui derrubaria a pagina que o produtor esta usando.
  if (modoConfig) return;
  if (wifiSsid.length() == 0) return;
  if (WiFi.status() == WL_CONNECTED) {
    iniciarMdns();
    return;
  }

  if (mdnsAtivo) {
    MDNS.end();
    mdnsAtivo = false;
  }
  if (millis() - ultimaTentativaWifi < intervaloReconexaoWifi) return;
  ultimaTentativaWifi = millis();
  WiFi.begin(WIFI_SSID, WIFI_PASS);
}

// Publica um nome estavel na rede local sem depender do IP entregue pelo
// roteador. O sufixo vem do MAC, portanto duas estufas nao disputam o mesmo
// nome. mDNS e uma conveniencia: o IP continua sendo o caminho alternativo.
void iniciarMdns() {
  if (mdnsAtivo || WiFi.status() != WL_CONNECTED || nomeLocal.length() == 0) {
    return;
  }

  if (ultimaTentativaMdns != 0 &&
      millis() - ultimaTentativaMdns < intervaloTentativaMdns) {
    return;
  }
  ultimaTentativaMdns = millis();

  if (!MDNS.begin(nomeLocal.c_str())) {
    Serial.println("Falha ao iniciar mDNS; use o IP exibido acima.");
    return;
  }

  MDNS.addService("http", "tcp", 80);
  mdnsAtivo = true;
  Serial.print("Nome local: http://");
  Serial.print(nomeLocal);
  Serial.println(".local");
}

// ============================================================
//  MODO DE CONFIGURACAO
// ============================================================

// Vigia a combinacao dos tres botoes e o tempo ocioso do modo aberto.
void verificarModoConfig() {
  if (modoConfig) {
    if (millis() - ultimaAtividadeConfig >= TEMPO_CONFIG_OCIOSO_MS) {
      Serial.println("Modo de configuracao ocioso: reiniciando.");
      delay(200);
      ESP.restart();
    }
    return;
  }

  bool todosPressionados = digitalRead(BOTAO_BUZZER) == LOW &&
                           digitalRead(BOTAO_VERDE) == LOW &&
                           digitalRead(BOTAO_VERMELHO) == LOW;
  if (!todosPressionados) {
    tresBotoesDesdeMs = 0;
    return;
  }

  if (tresBotoesDesdeMs == 0) {
    tresBotoesDesdeMs = millis();
    return;
  }
  if (millis() - tresBotoesDesdeMs >= TEMPO_SEGURAR_CONFIG_MS) {
    entrarModoConfig();
  }
}

void entrarModoConfig() {
  modoConfig = true;
  tresBotoesDesdeMs = 0;
  ultimaAtividadeConfig = millis();

  // Confirmacao fisica de que entrou no modo: um apito curto e um pisca dos
  // tres LEDs juntos. O visor de 7 segmentos nao mostra texto legivel, entao o
  // sinal do produtor e este - inconfundivel e sem depender de olhar o display.
  //
  // Toca DE PROPOSITO mesmo com a sirene de temperatura desligada, e isso nao e
  // descuido: o interruptor e sobre o ALARME, nao sobre todo som do aparelho.
  // Isto e resposta a uma acao que o produtor acabou de fazer, com ele na frente
  // segurando os botoes. Calar aqui deixaria segurar os 3 botoes sem retorno
  // nenhum, e a instrucao da tela ("segure ate apitar") viraria mentira.
  // PIN novo a cada entrada: um PIN fixo viraria segredo permanente de 4
  // digitos, que e fraco. Sorteado por entrada, ele so vale para esta sessao.
  pinConfig = (int)(esp_random() % 10000);
  tentativasPin = 0;

  digitalWrite(LED_ALERTA, HIGH);
  digitalWrite(LED_UMIDADE, HIGH);
  digitalWrite(LED_CONTROLE_TEMP, HIGH);
  digitalWrite(BUZZER, HIGH);
  delay(250);
  digitalWrite(BUZZER, LOW);
  digitalWrite(LED_ALERTA, LOW);
  digitalWrite(LED_UMIDADE, LOW);
  digitalWrite(LED_CONTROLE_TEMP, LOW);

  // Apertar tres botoes quase nunca e simultaneo: o primeiro a fechar contato
  // pode ter entrado no modo de ajuste e mexido no alvo. Descarta essas
  // alteracoes acidentais recarregando o que esta gravado.
  modoAjuste = false;
  configSuja = false;
  prefs.begin("sentinela", true);
  temperaturaAlvoF = prefs.getInt("tempAlvo", temperaturaAlvoF);
  umidadeAlvo = prefs.getInt("umidAlvo", umidadeAlvo);
  prefs.end();

  if (mdnsAtivo) {
    MDNS.end();
    mdnsAtivo = false;
  }

  WiFi.disconnect(true);
  WiFi.mode(WIFI_AP);
  WiFi.softAP(NOME_AP_CONFIG);

  // Anuncia o proprio aparelho como servidor DNS na entrega do endereco. Sem
  // isto alguns Android consultam o DNS que ja tinham e nunca percebem o
  // portal - o celular conecta, mas nada abre sozinho.
  esp_netif_t* rede = esp_netif_get_handle_from_ifkey("WIFI_AP_DEF");
  if (rede != nullptr) {
    esp_netif_dns_info_t dns;
    dns.ip.type = ESP_IPADDR_TYPE_V4;
    dns.ip.u_addr.ip4.addr = (uint32_t)WiFi.softAPIP();
    uint8_t oferecerDns = 1;
    esp_netif_dhcps_stop(rede);
    esp_netif_set_dns_info(rede, ESP_NETIF_DNS_MAIN, &dns);
    esp_netif_dhcps_option(rede, ESP_NETIF_OP_SET,
                           ESP_NETIF_DOMAIN_NAME_SERVER, &oferecerDns,
                           sizeof(oferecerDns));
    esp_netif_dhcps_start(rede);
  }

  dnsServer.start(PORTA_DNS, "*", WiFi.softAPIP());

  Serial.print("Modo de configuracao. Rede: ");
  Serial.print(NOME_AP_CONFIG);
  Serial.print(" -> http://");
  Serial.println(WiFi.softAPIP());
}

// Evita que um SSID com aspas quebre o HTML do formulario.
String escaparHtml(const String& texto) {
  String saida;
  saida.reserve(texto.length() + 8);
  for (unsigned int i = 0; i < texto.length(); i++) {
    char c = texto.charAt(i);
    if (c == '&') saida += "&amp;";
    else if (c == '<') saida += "&lt;";
    else if (c == '>') saida += "&gt;";
    else if (c == '"') saida += "&quot;";
    else saida += c;
  }
  return saida;
}

void handleConfigPagina() {
  ultimaAtividadeConfig = millis();

  // A senha nao volta preenchida: quem abre a pagina nao precisa ve-la, e
  // deixa-la no HTML seria entregar a senha do Wi-Fi a quem estiver na rede.
  String html = F(
      "<!doctype html><html lang=\"pt-br\"><head><meta charset=\"utf-8\">"
      "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
      "<title>Sentinela Smart</title><style>"
      "body{font-family:sans-serif;background:#0e1012;color:#fff;margin:0;"
      "padding:24px}h1{font-size:20px}label{display:block;margin:14px 0 4px;"
      "font-size:14px;color:#bbb}input{width:100%;padding:10px;border-radius:8px;"
      "border:1px solid #333;background:#1c1c1e;color:#fff;font-size:16px;"
      "box-sizing:border-box}button{margin-top:20px;width:100%;padding:12px;"
      "border:0;border-radius:8px;background:#2e7d32;color:#fff;font-size:16px}"
      "p.aviso{color:#888;font-size:12px;margin-top:18px}"
      ".nome{background:#1c1c1e;border:1px solid #2e7d32;border-radius:8px;"
      "padding:12px;margin-bottom:8px}.nome b{font-size:17px;color:#7bd88f;"
      "word-break:break-all}.nome span{font-size:12px;color:#888}"
      "details{margin-top:14px}summary{color:#bbb;font-size:14px;cursor:pointer}"
      "</style></head><body><h1>Configurar aparelho</h1>"
      // O nome vem primeiro e destacado: e o dado que o produtor precisa levar
      // para o app, e ate agora so aparecia no Monitor Serial - ou seja, so
      // para quem tivesse um computador com a IDE do Arduino.
      "<div class=\"nome\"><span>Cadastre este endere&ccedil;o no app:</span>"
      "<br><b>");
  html += escaparHtml(nomeLocal + ".local");
  html += F(
      "</b></div>"
      "<form method=\"POST\" action=\"/salvar\">"
      "<label>Rede Wi-Fi</label><input name=\"ssid\" value=\"");
  html += escaparHtml(wifiSsid);
  html += F(
      "\" required><label>Senha do Wi-Fi</label>"
      "<input name=\"senha\" type=\"password\" placeholder=\"(deixe vazio para "
      "manter a atual)\">"
      // Vazio aqui quer dizer "mantenha a que voce tem", que nao serve para
      // mudar para uma rede SEM senha: a antiga ficaria gravada e o aparelho
      // nao conectaria. Esta caixa e a unica forma de pedir senha nenhuma.
      "<label style=\"font-weight:normal\"><input type=\"checkbox\" "
      "name=\"semsenha\" value=\"1\"> Rede sem senha</label>"
      "<label>Chave de acesso</label>"
      "<input name=\"token\" placeholder=\"(deixe vazio para manter a atual)\">"
      "<label style=\"font-weight:normal\"><input type=\"checkbox\" "
      "name=\"novachave\" value=\"1\"> Gerar uma chave nova</label>"
      "<p class=\"aviso\">Marque so ao trocar de dono ou se a chave vazou. A "
      "chave nova aparece na tela seguinte e precisa ser atualizada no app.</p>"
      "<details><summary>Endere&ccedil;o fixo (opcional)</summary>"
      "<p class=\"aviso\">Use quando n&atilde;o der para reservar o IP no "
      "roteador. Deixe vazio para o roteador escolher.</p>"
      "<label>IP fixo</label><input name=\"ip\" placeholder=\"192.168.1.220\" "
      "value=\"");
  html += escaparHtml(ipFixo);
  html += F(
      "\"><label>Gateway</label><input name=\"gateway\" "
      "placeholder=\"192.168.1.1\" value=\"");
  html += escaparHtml(gatewayFixo);
  html += F(
      "\"><label>M&aacute;scara</label><input name=\"mascara\" "
      "placeholder=\"255.255.255.0\" value=\"");
  html += escaparHtml(mascaraFixa);
  html += F(
      "\"></details>"
      "<button type=\"submit\">Salvar e reiniciar</button></form>"
      "<p class=\"aviso\">O aparelho reinicia e volta ao normal. "
      "O alarme continua funcionando durante a configura&ccedil;&atilde;o.</p>"
      "</body></html>");

  server.send(200, "text/html; charset=utf-8", html);
}

// Entrega ao app a identidade do aparelho, incluindo a CHAVE. So responde no
// modo de configuracao, e essa restricao e a seguranca inteira: entrar nele
// exige segurar os tres botoes, ou seja, estar na frente do aparelho, e ele sai
// sozinho por inatividade. Em operacao normal a rota nao existe - `/status` diz
// apenas se ha chave, nunca qual.
//
// Serve para o produtor nunca precisar ver nem digitar a chave: o app le daqui e
// guarda. Uso unico foi considerado e descartado - se o app fechasse ou o
// celular caisse da rede do aparelho no meio, a chave se perderia e o produtor
// ficaria preso. Presenca fisica mais o prazo do modo de configuracao dao a
// mesma protecao sem a fragilidade.
void handleConfigIdentidade() {
  if (!modoConfig) {
    server.send(404, "application/json", "{\"erro\":\"fora do modo de configuracao\"}");
    return;
  }
  ultimaAtividadeConfig = millis();

  // Estar na rede do aparelho nao basta: o ponto de acesso e aberto. Sem o PIN
  // do visor, quem estiver ao alcance do wifi levaria a chave sem nunca chegar
  // perto do aparelho.
  if (pinConfig < 0) {
    server.send(403, "application/json",
                "{\"erro\":\"pin bloqueado\",\"detalhe\":\"Saia e entre de novo no modo de configuracao.\"}");
    return;
  }
  const int pinRecebido = server.hasArg("pin") ? server.arg("pin").toInt() : -1;
  if (pinRecebido != pinConfig) {
    tentativasPin++;
    // Poucos erros e o PIN morre: 4 digitos so sao seguros com limite de
    // tentativas, senao da para varrer os 10 mil em minutos.
    if (tentativasPin >= MAX_TENTATIVAS_PIN) pinConfig = -1;
    server.send(403, "application/json",
                String("{\"erro\":\"pin invalido\",\"restantes\":")
                    + (pinConfig < 0 ? 0 : (MAX_TENTATIVAS_PIN - tentativasPin))
                    + "}");
    return;
  }
  tentativasPin = 0;

  JsonDocument doc;
  doc["idHardware"] = idHardware;
  doc["nomeLocal"] = nomeLocal;
  doc["chave"] = tokenAparelho;
  doc["versaoFirmware"] = VERSAO_FIRMWARE;
  // Gateway aprendido do roteador. O app usa a faixa dele para ja deixar o
  // campo de IP fixo quase pronto: no modo de configuracao o celular esta na
  // rede do APARELHO (192.168.4.x) e nao tem como descobrir a faixa da casa
  // sozinho - mas o aparelho ja esteve la e anotou.
  doc["gatewayAprendido"] = gatewayAprendido;
  String corpo;
  serializeJson(doc, corpo);
  server.send(200, "application/json", corpo);
}

void handleConfigSalvar() {
  ultimaAtividadeConfig = millis();

  String ssid = server.arg("ssid");
  String senha = server.arg("senha");
  String token = server.arg("token");
  ssid.trim();
  token.trim();

  if (ssid.length() == 0) {
    server.send(400, "text/html; charset=utf-8",
                "<p>Informe a rede Wi-Fi.</p><a href=\"/\">Voltar</a>");
    return;
  }

  String ip = server.arg("ip");
  String gateway = server.arg("gateway");
  String mascara = server.arg("mascara");
  ip.trim();
  gateway.trim();
  mascara.trim();

  // IP preenchido mas invalido e pior do que nao ter nenhum: o aparelho sumiria
  // da rede. Recusa antes de gravar, para o erro aparecer com o produtor ainda
  // na frente do formulario.
  IPAddress conferencia;
  if (ip.length() > 0 && !conferencia.fromString(ip)) {
    server.send(400, "text/html; charset=utf-8",
                "<p>IP fixo invalido. Use o formato 192.168.1.220.</p>"
                "<a href=\"/\">Voltar</a>");
    return;
  }

  // Chave nova pedida no formulario: guarda a anterior para poder PROVAR posse
  // na rotacao com a nuvem. Sem isso a nuvem ficaria com a antiga para sempre e
  // o aparelho sem como corrigir, porque a rotacao exige a chave que ela tem.
  const bool gerarNova = server.arg("novachave") == "1";
  String chaveSubstituida;
  if (gerarNova) {
    chaveSubstituida = tokenAparelho;
    token = gerarChaveAleatoria();
  }

  prefs.begin("sentinela", false);
  prefs.putString("wifiSsid", ssid);
  // Senha vazia mantem a atual: assim da para so trocar a chave de acesso sem
  // precisar digitar a senha do Wi-Fi de novo. Isso nao consegue exprimir "esta
  // rede nao tem senha" — a antiga ficaria gravada, o aparelho tentaria entrar
  // com ela numa rede aberta e nao conectaria, sem nada dizendo por que. Daí a
  // marca explicita: quem quer rede aberta pede rede aberta.
  //
  // Ausente = comportamento de antes, entao app e formulario velhos continuam
  // valendo.
  const bool redeAberta = server.arg("semsenha") == "1";
  if (redeAberta) prefs.putString("wifiPass", "");
  else if (senha.length() > 0) prefs.putString("wifiPass", senha);
  // Chave vazia MANTEM a atual, como a senha do Wi-Fi logo acima - e como o
  // proprio formulario sempre prometeu. Gravar vazio apagava a chave, e o boot
  // seguinte gerava uma aleatoria que nem o app nem a nuvem conheciam: o
  // aparelho ficava na rede, funcionando, e trancado para fora de tudo. Desde a
  // v1.20.0 o app manda vazio de proposito (ele ja leu a chave do aparelho),
  // entao salvar pelo app derrubava o aparelho.
  if (token.length() > 0) prefs.putString("token", token);
  if (gerarNova) {
    prefs.putString("chaveAnt", chaveSubstituida);
    prefs.putBool("chaveReg", false);
    chaveAnterior = chaveSubstituida;
    chaveRegistradaNaNuvem = false;
  }
  prefs.putString("ipFixo", ip);
  prefs.putString("gateway", gateway);
  prefs.putString("mascara", mascara);
  prefs.end();

  Serial.print("Configuracao gravada. Rede: ");
  Serial.println(ssid);

  // Repete o endereco aqui tambem: o ponto de acesso vai sumir no reinicio, e
  // esta e a ultima tela em que o produtor pode anotar o nome.
  String confirmacao = F(
      "<!doctype html><meta charset=\"utf-8\">"
      "<body style=\"font-family:sans-serif;background:#0e1012;color:#fff;"
      "padding:24px\"><h1>Salvo</h1>"
      "<p>O aparelho esta reiniciando e vai conectar na rede nova.</p>"
      "<p>Cadastre este endereco no app:<br><b style=\"font-size:18px;"
      "color:#7bd88f\">");
  confirmacao += escaparHtml(nomeLocal + ".local");
  if (gerarNova) {
    // Ultima tela em que a chave nova aparece. Depois do reinicio ela volta a
    // ser segredo: em operacao normal /status so diz se existe chave, nunca qual.
    confirmacao += F(
        "</b></p><p>Chave nova (anote e atualize no app):<br>"
        "<b style=\"font-size:18px;color:#7bd88f\">");
    confirmacao += escaparHtml(token);
  }
  confirmacao += F("</b></p>");
  if (ip.length() > 0) {
    confirmacao += F("<p>Ou o endereco fixo: <b>");
    confirmacao += escaparHtml(ip);
    confirmacao += F("</b></p>");
  }
  confirmacao += F("</body>");

  server.send(200, "text/html; charset=utf-8", confirmacao);

  delay(1500);  // deixa a resposta sair antes de reiniciar
  ESP.restart();
}

// Troca o alvo por um caminho so, abrindo a janela de acomodacao proporcional
// ao tamanho da mudanca. Todo lugar que mexe no ajuste passa por aqui.
void definirTemperaturaAlvo(int novoAlvo) {
  int delta = novoAlvo - temperaturaAlvoF;
  if (delta == 0) return;

  // A folga cobre so a distancia que a mudanca CRIOU. Aproximar o alvo da
  // temperatura atual nao gera folga nenhuma: a estufa nao precisa percorrer
  // nada, entao um desvio que ja existia continua sendo alarme.
  int desvioAntes = abs(temperaturaF - temperaturaAlvoF);
  int desvioDepois = abs(temperaturaF - novoAlvo);
  int folga = leituraOk ? (desvioDepois - desvioAntes) : 0;
  if (folga < 0) folga = 0;
  if (folga > FOLGA_ACOMODACAO_MAX) folga = FOLGA_ACOMODACAO_MAX;
  // Ajustes seguidos: vale a maior folga enquanto a janela estiver aberta.
  bool janelaAberta = acomodacaoAteMillis != 0 &&
                      (long)(millis() - acomodacaoAteMillis) < 0;
  folgaAcomodacao = (janelaAberta && folgaAcomodacao > folga) ? folgaAcomodacao : folga;
  acomodacaoAteMillis = millis() + TEMPO_ACOMODACAO_MS;
  if (acomodacaoAteMillis == 0) acomodacaoAteMillis = 1;

  temperaturaAlvoF = novoAlvo;
  configSuja = true;
  atualizarEstadoTemperatura();
}

// Margem valendo agora: a normal mais a folga da acomodacao, se a janela
// ainda estiver aberta.
int margemVigente() {
  if (acomodacaoAteMillis == 0) return margemF;
  if ((long)(millis() - acomodacaoAteMillis) >= 0) {
    acomodacaoAteMillis = 0;  // venceu
    folgaAcomodacao = 0;
    return margemF;
  }
  return margemF + folgaAcomodacao;
}

// Le os ajustes gravados na NVS. Sem valor gravado, mantem o padrao do codigo.
void carregarConfigPersistida() {
  prefs.begin("sentinela", true);  // somente leitura
  temperaturaAlvoF = prefs.getInt("tempAlvo", temperaturaAlvoF);
  umidadeAlvo = prefs.getInt("umidAlvo", umidadeAlvo);
  // Os timestamps voltam junto para o Last-Write-Wins continuar valendo depois
  // de um reinicio: sem eles um comando antigo poderia vencer o ajuste atual.
  tempTimestamp = prefs.getLong64("tempTs", 0);
  umidTimestamp = prefs.getLong64("umidTs", 0);
  buzzerTemperaturaAtivo = prefs.getBool("buzzerAtivo", true);
  buzzerTimestamp = prefs.getLong64("buzzerTs", 0);
  // As constantes do topo sao so o valor de fabrica: o que o produtor gravou
  // pelo modo de configuracao tem precedencia.
  wifiSsid = prefs.getString("wifiSsid", WIFI_SSID);
  wifiPass = prefs.getString("wifiPass", WIFI_PASS);
  tokenAparelho = prefs.getString("token", DEVICE_TOKEN);
  chaveAnterior = prefs.getString("chaveAnt", "");
  chaveRegistradaNaNuvem = prefs.getBool("chaveReg", false);
  // Gera chave propria SO quando nao existe nenhuma - aparelho novo, ou com a
  // constante do topo ainda no valor de fabrica. Aparelho que ja tem chave NUNCA
  // e trocado sozinho: a troca automatica deixaria app e nuvem sem a chave nova
  // se o registro falhasse, e o produtor perderia o acesso ao que funcionava.
  // Trocar e sempre ato deliberado, no modo de configuracao.
  if (tokenAparelho.length() == 0
      || tokenAparelho == "COLE_AQUI_O_MESMO_TOKEN_DO_APP") {
    tokenAparelho = gerarChaveAleatoria();
    prefs.putString("token", tokenAparelho);
    prefs.putBool("chaveReg", false);
    chaveRegistradaNaNuvem = false;
    Serial.println("Chave de acesso gerada (primeira vez).");
  }
  ipFixo = prefs.getString("ipFixo", "");
  gatewayFixo = prefs.getString("gateway", "");
  mascaraFixa = prefs.getString("mascara", "");
  gatewayAprendido = prefs.getString("gwDhcp", "");
  mascaraAprendida = prefs.getString("mascDhcp", "");
  prefs.end();

  Serial.print("Wi-Fi configurado: ");
  Serial.println(wifiSsid.length() > 0 ? wifiSsid : String("(nenhum)"));

  Serial.print("Ajustes recuperados: ");
  Serial.print(temperaturaAlvoF);
  Serial.print(" F / ");
  Serial.print(umidadeAlvo);
  Serial.println(" %");
}

// Grava no maximo a cada INTERVALO_SALVAR_CONFIG_MS. Segurar o botao gera um
// ajuste por toque, e a NVS tem numero limitado de escritas - juntar as
// mudancas numa so evita gastar a flash a toa.
void salvarConfigSeNecessario() {
  if (!configSuja) return;
  if (millis() - ultimoSalvamentoConfig < INTERVALO_SALVAR_CONFIG_MS) return;
  if (modoAjuste) return;  // espera o produtor terminar de ajustar

  prefs.begin("sentinela", false);
  prefs.putInt("tempAlvo", temperaturaAlvoF);
  prefs.putInt("umidAlvo", umidadeAlvo);
  prefs.putLong64("tempTs", tempTimestamp);
  prefs.putLong64("umidTs", umidTimestamp);
  prefs.putBool("buzzerAtivo", buzzerTemperaturaAtivo);
  prefs.putLong64("buzzerTs", buzzerTimestamp);
  prefs.end();

  configSuja = false;
  ultimoSalvamentoConfig = millis();
  Serial.println("Ajustes salvos na memoria");
}

// Houve mudanca no que a nuvem precisa saber com urgencia? Detecta a BORDA:
// so devolve true na transicao, para uma emergencia em curso nao virar um
// envio a cada volta do loop.
bool estadoDeAlertaMudou() {
  bool fogo = alertaLuz || riscoIncendioAgora();
  bool alarme = alarmeAtivoAgora();

  bool mudou = (fogo != ultimoFogoEnviado) || (alarme != ultimoAlarmeEnviado);
  ultimoFogoEnviado = fogo;
  ultimoAlarmeEnviado = alarme;
  return mudou;
}

// Empurra a leitura atual para a nuvem (POST /leitura), que guarda o estado ao
// vivo por aparelho para o /status remoto refletir este ESP em vez do simulador.
// Bloqueia o loop por ~1-2 s durante o handshake HTTPS; como so roda a cada
// PUSH_INTERVAL_MS, nao atrapalha o controle local.
void empurrarLeituraNuvem() {
  if (strlen(CLOUD_URL) == 0) return;
  if (WiFi.status() != WL_CONNECTED) return;

  JsonDocument doc;
  doc["idHardware"] = idHardware;
  doc["timestampLeitura"] = nowMs();
  doc["temperaturaAtual"] = temperaturaF;
  doc["umidadeAtual"] = umidade;
  doc["temEnergia"] = true;
  doc["temInternet"] = true;
  doc["sinalWifi"] = wifiSinalPercent();
  // Endereco do aparelho na rede local. Vai junto porque, ate aqui, o nome mDNS
  // era a UNICA porta local do app - e quando ele falha (sufixo, roteador ou
  // celular que nao resolve .local) nao sobrava nada, com a nuvem funcionando
  // escondendo o problema. Com o endereco guardado, o app ganha uma segunda
  // porta e da para dizer de fora onde o aparelho esta.
  doc["ipLocal"] = WiFi.localIP().toString();
  doc["alarmeAtivo"] = alarmeAtivoAgora();
  // A CONDICAO de temperatura fora da faixa, separada de `alarmeAtivo` (que diz
  // se a sirene esta tocando agora). Os dois divergem quando o produtor desliga
  // a sirene deste aparelho ou pede os 10 min de silencio - e o aviso no celular
  // nao pode depender disso: ele tem tela de preferencias propria, e desligar a
  // sirene da estufa e um pedido sobre o barulho ali, nao sobre ser avisado.
  doc["alertaTemperatura"] = alertaTemperatura;
  doc["alertaIncendio"] = (alertaLuz || riscoIncendioAgora());
  doc["perigoChama"] = alertaLuz;
  doc["riscoIncendio"] = riscoIncendioAgora();
  doc["aquecedorLigado"] = ledControleLigado;
  doc["ventiladorLigado"] = false;
  doc["umidificadorLigado"] = false;
  doc["faseAtual"] = fasePorAlvo(temperaturaAlvoF);
  doc["aviso"] = avisoAtual();
  doc["corStatus"] = corStatusAtual();
  doc["fonte"] = "hardware";
  // Vai junto da leitura para dar para saber, pela nuvem, qual firmware cada
  // aparelho em campo esta rodando - sem isso so olhando o Serial no local.
  doc["versaoFirmware"] = VERSAO_FIRMWARE;

  JsonObject config = doc["config"].to<JsonObject>();
  config["idHardware"] = idHardware;
  config["temperaturaMeta"] = temperaturaAlvoF;
  config["tempTimestamp"] = tempTimestamp;
  config["umidadeMeta"] = umidadeAlvo;
  config["umidTimestamp"] = umidTimestamp;
  config["modoSilencioso"] = estaSilenciado();
  config["modoSilenciosoTimestamp"] = modoSilenciosoTimestamp;
  config["buzzerAtivo"] = buzzerTemperaturaAtivo;
  config["buzzerTimestamp"] = buzzerTimestamp;

  String corpo;
  serializeJson(doc, corpo);

  WiFiClientSecure cliente;
  cliente.setInsecure();  // nao valida certificado (simplifica; ok para o TCC)
  HTTPClient http;
  String url = String(CLOUD_URL) + "/leitura";
  if (!http.begin(cliente, url)) return;
  http.addHeader("Content-Type", "application/json");
  if (tokenAparelho.length() > 0) {
    http.addHeader("X-Device-Token", tokenAparelho);
  }
  int codigo = http.POST(corpo);
  Serial.print("Push nuvem -> HTTP ");
  Serial.println(codigo);
  http.end();
}

// Conta a propria chave para a nuvem, para ela deixar de depender da chave
// global. Registro simples enquanto o aparelho nunca teve chave la (TOFU);
// rotacao quando ha uma anterior guardada, porque ai a nuvem tem outra e so
// aceita a troca de quem provar posse da antiga.
//
// Roda de vez em quando, nao uma vez so: a primeira tentativa pode cair com a
// nuvem hibernada ou a internet fora, e nesse caso a chave nova nao pode ficar
// valendo apenas aqui.
void sincronizarChaveNuvem() {
  if (strlen(CLOUD_URL) == 0) return;
  if (WiFi.status() != WL_CONNECTED) return;
  if (chaveRegistradaNaNuvem && chaveAnterior.length() == 0) return;
  if (tokenAparelho.length() == 0) return;
  // Mesma regra do resto: emergencia manda, e o handshake HTTPS trava o loop.
  if (alertaLuz || riscoIncendioAgora()) return;

  const bool rotacionando = chaveAnterior.length() > 0;

  JsonDocument doc;
  doc["idHardware"] = idHardware;
  if (rotacionando) {
    doc["chaveAtual"] = chaveAnterior;
    doc["chaveNova"] = tokenAparelho;
  } else {
    doc["chave"] = tokenAparelho;
  }
  String corpo;
  serializeJson(doc, corpo);

  WiFiClientSecure cliente;
  cliente.setInsecure();
  HTTPClient http;
  String url = String(CLOUD_URL)
               + (rotacionando ? "/aparelhos/chave/rotacionar" : "/aparelhos/chave");
  if (!http.begin(cliente, url)) return;
  http.addHeader("Content-Type", "application/json");
  // Autentica com a credencial que a nuvem AINDA conhece: a anterior durante uma
  // rotacao, a atual quando e o primeiro registro.
  http.addHeader("X-Device-Token", rotacionando ? chaveAnterior : tokenAparelho);
  int codigo = http.POST(corpo);
  http.end();

  Serial.print("Chave -> nuvem HTTP ");
  Serial.println(codigo);

  if (codigo == 200) {
    chaveRegistradaNaNuvem = true;
    chaveAnterior = "";
    prefs.begin("sentinela", false);
    prefs.putBool("chaveReg", true);
    prefs.remove("chaveAnt");
    prefs.end();
    Serial.println("Chave registrada na nuvem.");
    return;
  }

  // 409: a nuvem ja tem chave para este aparelho e nao e esta. Sem a anterior
  // guardada nao ha como provar posse, entao insistir nao resolve - so o modo de
  // configuracao (presenca fisica) desfaz isso. Para de tentar para nao ficar
  // batendo na nuvem a cada ciclo.
  if (codigo == 409) {
    chaveRegistradaNaNuvem = true;
    prefs.begin("sentinela", false);
    prefs.putBool("chaveReg", true);
    prefs.end();
    Serial.println("A nuvem ja tem outra chave para este aparelho.");
  }
}

// Busca na nuvem um ajuste feito pelo app quando o celular estava longe da
// propriedade. O aparelho nao e alcancavel de fora (fica atras do roteador do
// produtor), entao quem procura e ele. O servidor entrega o comando uma vez; o
// POST /leitura seguinte ja leva a config nova e serve de confirmacao. Se algo
// se perder, o app reenvia pela fila de pendencias que ele ja mantem.
void buscarComandosNuvem() {
  if (strlen(CLOUD_URL) == 0) return;
  if (WiFi.status() != WL_CONNECTED) return;
  // Emergencia manda: o handshake HTTPS trava o loop por 1-2 s, e durante um
  // incendio esse tempo faz falta para a sirene e os botoes. A nuvem espera.
  if (alertaLuz || riscoIncendioAgora()) return;

  WiFiClientSecure cliente;
  cliente.setInsecure();
  HTTPClient http;
  String url = String(CLOUD_URL) + "/comandos?idHardware=" + idHardware;
  if (!http.begin(cliente, url)) return;
  if (tokenAparelho.length() > 0) {
    http.addHeader("X-Device-Token", tokenAparelho);
  }

  int codigo = http.GET();
  if (codigo != 200) {
    http.end();
    return;
  }

  JsonDocument resposta;
  DeserializationError erro = deserializeJson(resposta, http.getString());
  http.end();
  if (erro) return;

  JsonObjectConst comando = resposta["comando"].as<JsonObjectConst>();
  if (comando.isNull()) return;  // nada esperando por este aparelho

  JsonDocument descartavel;
  JsonArray aplicadas = descartavel["a"].to<JsonArray>();
  JsonArray ignoradas = descartavel["i"].to<JsonArray>();
  aplicarAjustes(comando, aplicadas, ignoradas);
  if (aplicadas.size() == 0) return;

  // Confirma na hora, em vez de esperar o proximo push: e a leitura empurrada
  // que avisa a nuvem que o comando foi obedecido, e ate ela chegar o app fica
  // mostrando "aguardando o aparelho".
  ultimoPushNuvem = millis() - PUSH_INTERVAL_MS;

  Serial.print("Comando da nuvem aplicado. Campos: ");
  Serial.println(aplicadas.size());
}

// epoch em milissegundos quando o NTP sincronizou; senao, fallback para millis().
long long nowMs() {
  time_t agora = time(nullptr);
  if (agora > 1700000000) {  // relogio plausivel (apos ~2023)
    return (long long)agora * 1000LL;
  }
  return (long long)millis();
}

int wifiSinalPercent() {
  if (WiFi.status() != WL_CONNECTED) return 0;
  long rssi = WiFi.RSSI();
  if (rssi <= -100) return 0;
  if (rssi >= -50) return 100;
  return (int)(2 * (rssi + 100));
}

const char* fasePorAlvo(int alvo) {
  if (alvo <= 100) return "1. Amarelacao";
  if (alvo <= 110) return "2. Murchamento";
  if (alvo <= 120) return "3. Fixacao da Cor";
  if (alvo <= 135) return "4. Secagem da Folha";
  if (alvo <= 150) return "5. Secagem do Talo";
  if (alvo <= 165) return "6. ALERTA: ajuste acima do recomendado";
  return "CRITICO: ajuste muito elevado";
}

// Limite de incendio por temperatura. Espelha limiteFogo de logica.js: o
// aparelho e a nuvem precisam concordar sobre o que e fogo, e ate a v1.16.0 nao
// concordavam - o firmware usava 175 fixo enquanto o servidor ja acompanhava o
// ajuste. Com ajuste em 172, um alarmava aos 175 e o outro so aos 177.
//
// Acompanhar o ajuste importa porque a folga entre a maxima de trabalho
// (165 F) e o limite e de so 10 F, e o sensor fica no ar mais quente da estufa.
// Quem pede um ajuste alto de proposito nao deveria receber alarme de incendio
// por ter conseguido o que pediu.
int limiteFogoF() {
  return temperaturaAlvoF > 170 ? temperaturaAlvoF + 5 : 175;
}

// Chave aleatoria de 32 hex (128 bits). Aleatoria e por aparelho e melhor que
// escolhida pelo produtor por dois motivos: nao repete entre aparelhos e nao e
// adivinhavel. `esp_random()` usa o gerador de hardware.
String gerarChaveAleatoria() {
  const char* hex = "0123456789abcdef";
  String chave;
  chave.reserve(32);
  for (int i = 0; i < 32; i++) chave += hex[esp_random() & 0x0F];
  return chave;
}

bool riscoIncendioAgora() {
  return leituraOk && temperaturaF > limiteFogoF();
}

// O silencio expirou? Comparacao com sinal para sobreviver ao rollover do
// millis() (~49 dias): negativo significa que o limite ainda esta no futuro.
bool estaSilenciado() {
  if (silencioAteMillis == 0) return false;
  if ((long)(millis() - silencioAteMillis) >= 0) {
    silencioAteMillis = 0;  // prazo vencido: volta a apitar
    return false;
  }
  return true;
}

// Silenciar e sempre "por 10 minutos a partir de agora" - nunca um liga/desliga.
// Apertar o botao de novo apenas reinicia o prazo, em vez de fazer a sirene
// voltar na hora, que era o comportamento antigo.
void silenciarPorPrazo() {
  silencioAteMillis = millis() + TEMPO_SILENCIO_MS;
  if (silencioAteMillis == 0) silencioAteMillis = 1;  // 0 e "nao silenciado"
  // Fotografa o fogo deste instante: e dele que o produtor esta ciente.
  luzCobertaPeloSilencio = alertaLuz;
  tempIncendioCobertaPeloSilencio = riscoIncendioAgora();
  digitalWrite(BUZZER, LOW);
  buzzerLigadoAgora = false;
}

// Rodada a cada ciclo enquanto o silencio vale. Responde se apareceu fogo que o
// silencio NAO cobre, e ao mesmo tempo descobre as causas que cessaram - uma
// chama que apaga e volta e fogo novo, e ninguem esta ciente dela ainda.
bool fogoNovoDuranteSilencio() {
  bool luzAgora = alertaLuz;
  bool tempAgora = riscoIncendioAgora();
  bool novo = (luzAgora && !luzCobertaPeloSilencio)
              || (tempAgora && !tempIncendioCobertaPeloSilencio);
  if (!luzAgora) luzCobertaPeloSilencio = false;
  if (!tempAgora) tempIncendioCobertaPeloSilencio = false;
  return novo;
}

void reativarAlarme() {
  silencioAteMillis = 0;
  ultimoTempoBuzzer = 0;
}

// Sirene fisica ligada agora? Incendio (nao silenciavel) ou temperatura fora
// (silenciavel). Espelha a logica de atualizarSaidas().
bool alarmeAtivoAgora() {
  if (!alertaLuz && !alertaTemperatura) return false;
  // O silencio de 10 min cobre todos os alarmes, inclusive o fogo que ja estava
  // acontecendo quando o botao foi apertado. Fogo novo cancela o silencio em
  // atualizarSaidas(), entao aqui basta consultar.
  if (estaSilenciado()) return false;
  // Buzzer de temperatura desligado cala so o alarme comum.
  if (!alertaLuz && !buzzerTemperaturaAtivo && !riscoIncendioAgora()) {
    return false;
  }
  return true;
}

// Textos que o produtor le (aparecem no app e no corpo do push), entao vao
// acentuados. O JSON e UTF-8; o visor de 7 segmentos nao mostra texto de
// qualquer forma, entao nao ha motivo para escrever sem acento.
String avisoAtual() {
  if (alertaLuz) return "Sensor de chama ativado";
  if (riscoIncendioAgora()) return "Risco de incêndio";
  if (alertaTemperatura) {
    return temperaturaF > temperaturaAlvoF ? "Temperatura alta" : "Temperatura baixa";
  }
  if (!leituraOk) return "Sem leitura do sensor";
  return "Estável";
}

String corStatusAtual() {
  if (alertaLuz || riscoIncendioAgora()) return "red";
  if (alertaTemperatura) return temperaturaF > temperaturaAlvoF ? "orange" : "purple";
  return "green";
}

bool tokenValido() {
  String esperado = tokenAparelho;
  if (esperado.length() == 0) return true;  // sem token = liberado

  String recebido = "";
  if (server.hasHeader("Authorization")) {
    String h = server.header("Authorization");
    if (h.startsWith("Bearer ")) recebido = h.substring(7);
  }
  if (recebido.length() == 0 && server.hasHeader("X-Device-Token")) {
    recebido = server.header("X-Device-Token");
  }
  if (recebido.length() == 0 && server.hasHeader("X-API-Token")) {
    recebido = server.header("X-API-Token");
  }
  recebido.trim();
  return recebido == esperado;
}

// ============================================================
//  HANDLERS HTTP (contrato do app)
// ============================================================
void handleStatus() {
  JsonDocument doc;

  JsonObject status = doc["status"].to<JsonObject>();
  status["idHardware"] = idHardware;
  status["timestampLeitura"] = nowMs();
  status["temperaturaAtual"] = temperaturaF;
  status["umidadeAtual"] = umidade;
  status["temEnergia"] = true;  // sem sensor de tensao ainda
  status["temInternet"] = (WiFi.status() == WL_CONNECTED);
  status["sinalWifi"] = wifiSinalPercent();
  status["ipLocal"] = WiFi.localIP().toString();  // ver empurrarLeituraNuvem()
  status["alarmeAtivo"] = alarmeAtivoAgora();
  status["alertaTemperatura"] = alertaTemperatura;  // ver comentario em empurrarLeituraNuvem()
  status["alertaIncendio"] = (alertaLuz || riscoIncendioAgora());
  status["perigoChama"] = alertaLuz;
  status["riscoIncendio"] = riscoIncendioAgora();
  status["aquecedorLigado"] = ledControleLigado;
  status["ventiladorLigado"] = false;  // sem rele de ventilador
  status["umidificadorLigado"] = false;
  status["faseAtual"] = fasePorAlvo(temperaturaAlvoF);
  status["aviso"] = avisoAtual();
  status["corStatus"] = corStatusAtual();

  JsonObject config = doc["config"].to<JsonObject>();
  config["idHardware"] = idHardware;
  config["temperaturaMeta"] = temperaturaAlvoF;
  config["tempTimestamp"] = tempTimestamp;
  config["umidadeMeta"] = umidadeAlvo;
  config["umidTimestamp"] = umidTimestamp;
  config["modoSilencioso"] = estaSilenciado();
  config["modoSilenciosoTimestamp"] = modoSilenciosoTimestamp;
  config["buzzerAtivo"] = buzzerTemperaturaAtivo;
  config["buzzerTimestamp"] = buzzerTimestamp;

  String saida;
  serializeJson(doc, saida);
  server.send(200, "application/json", saida);
}

void handleSimple() {
  // No ponto de acesso a raiz e o formulario, nao o JSON: quem abre o navegador
  // ali esta configurando o aparelho, nao consultando leitura.
  // So a raiz vira formulario: `/dados` segue devolvendo JSON mesmo aqui, e e
  // por ele que o app descobre o nome local para mostrar ao produtor.
  if (modoConfig && server.uri() == "/") {
    handleConfigPagina();
    return;
  }

  JsonDocument doc;
  doc["temperaturaF"] = temperaturaF;
  doc["umidade"] = umidade;
  doc["temperaturaAlvoF"] = temperaturaAlvoF;
  doc["umidadeAlvo"] = umidadeAlvo;
  doc["margemF"] = margemVigente();
  doc["alertaTemperatura"] = alertaTemperatura;
  doc["alertaLuz"] = alertaLuz;
  doc["mostrandoUmidade"] = mostrandoUmidade;
  doc["modoAjuste"] = modoAjuste;
  doc["buzzerSilenciado"] = estaSilenciado();
  doc["ledControleLigado"] = ledControleLigado;
  doc["leituraOk"] = leituraOk;
  doc["ip"] = WiFi.localIP().toString();
  doc["nomeLocal"] = nomeLocal + ".local";
  doc["tokenConfigurado"] = (tokenAparelho.length() > 0);
  doc["versaoFirmware"] = VERSAO_FIRMWARE;

  String saida;
  serializeJson(doc, saida);
  server.send(200, "application/json", saida);
}

// Aplica ajustes com Last-Write-Wins por campo. Vale tanto para o comando que
// chega direto do app na rede local (POST /sincronizar) quanto para o que o
// aparelho busca na nuvem: e a mesma regra, entao e o mesmo caminho.
void aplicarAjustes(JsonObjectConst entrada, JsonArray aplicadas,
                    JsonArray ignoradas) {
  // Temperatura (LWW por tempTimestamp).
  if (!entrada["temperaturaMeta"].isNull()) {
    long long ts = entrada["tempTimestamp"].as<long long>();
    if (ts > tempTimestamp) {
      definirTemperaturaAlvo((int)round(entrada["temperaturaMeta"].as<float>()));
      tempTimestamp = ts;
      aplicadas.add("temperaturaMeta");
    } else {
      ignoradas.add("temperaturaMeta");
    }
  }

  // Umidade (LWW por umidTimestamp). Registrada, nao atuada fisicamente.
  if (!entrada["umidadeMeta"].isNull()) {
    long long ts = entrada["umidTimestamp"].as<long long>();
    if (ts > umidTimestamp) {
      umidadeAlvo = (int)round(entrada["umidadeMeta"].as<float>());
      umidTimestamp = ts;
      configSuja = true;
      aplicadas.add("umidadeMeta");
    } else {
      ignoradas.add("umidadeMeta");
    }
  }

  // Silenciar (aceita modoSilencioso ou o formato antigo {"comando":"silenciar"}).
  bool temModo = !entrada["modoSilencioso"].isNull();
  bool ehComandoSilenciar =
      entrada["comando"].is<const char*>() &&
      String((const char*)entrada["comando"]) == "silenciar";
  if (temModo || ehComandoSilenciar) {
    long long ts = entrada["modoSilenciosoTimestamp"].isNull()
                       ? nowMs()
                       : entrada["modoSilenciosoTimestamp"].as<long long>();
    if (ts > modoSilenciosoTimestamp) {
      bool silenciar = temModo ? entrada["modoSilencioso"].as<bool>() : true;
      if (silenciar) {
        silenciarPorPrazo();
      } else {
        reativarAlarme();
      }
      modoSilenciosoTimestamp = ts;
      aplicadas.add("modoSilencioso");
    } else {
      ignoradas.add("modoSilencioso");
    }
  }

  // Liga/desliga o buzzer do alarme de temperatura (LWW por buzzerTimestamp).
  // Fogo nao passa por aqui - continua tocando sempre (ver atualizarSaidas).
  if (!entrada["buzzerAtivo"].isNull()) {
    long long ts = entrada["buzzerTimestamp"].isNull()
                       ? nowMs()
                       : entrada["buzzerTimestamp"].as<long long>();
    if (ts > buzzerTimestamp) {
      buzzerTemperaturaAtivo = entrada["buzzerAtivo"].as<bool>();
      buzzerTimestamp = ts;
      configSuja = true;
      aplicadas.add("buzzerAtivo");
    } else {
      ignoradas.add("buzzerAtivo");
    }
  }
}

void handleSincronizar() {
  if (!tokenValido()) {
    server.send(401, "application/json",
                "{\"sucesso\":false,\"erro\":\"Nao autorizado\"}");
    return;
  }

  if (!server.hasArg("plain")) {
    server.send(400, "application/json",
                "{\"sucesso\":false,\"erro\":\"Payload invalido\"}");
    return;
  }

  JsonDocument entrada;
  DeserializationError erro = deserializeJson(entrada, server.arg("plain"));
  if (erro) {
    server.send(400, "application/json",
                "{\"sucesso\":false,\"erro\":\"JSON invalido\"}");
    return;
  }

  JsonDocument resp;
  JsonArray aplicadas = resp["alteracoesAplicadas"].to<JsonArray>();
  JsonArray ignoradas = resp["alteracoesIgnoradas"].to<JsonArray>();

  aplicarAjustes(entrada.as<JsonObjectConst>(), aplicadas, ignoradas);

  resp["sucesso"] = true;
  JsonObject cfg = resp["configAtualizada"].to<JsonObject>();
  cfg["idHardware"] = idHardware;
  cfg["temperaturaMeta"] = temperaturaAlvoF;
  cfg["tempTimestamp"] = tempTimestamp;
  cfg["umidadeMeta"] = umidadeAlvo;
  cfg["umidTimestamp"] = umidTimestamp;
  cfg["modoSilencioso"] = estaSilenciado();
  cfg["modoSilenciosoTimestamp"] = modoSilenciosoTimestamp;
  cfg["buzzerAtivo"] = buzzerTemperaturaAtivo;
  cfg["buzzerTimestamp"] = buzzerTimestamp;

  String saida;
  serializeJson(resp, saida);
  server.send(200, "application/json", saida);
}

// ============================================================
//  CONTROLE LOCAL (preservado do firmware original)
// ============================================================
bool botaoFoiPressionado(int pino, bool &ultimoEstado, bool &estadoEstavel,
                         unsigned long &ultimoDebounce) {
  bool leituraAtual = digitalRead(pino);
  bool pressionado = false;

  if (leituraAtual != ultimoEstado) {
    ultimoDebounce = millis();
  }

  if ((millis() - ultimoDebounce) > debounceDelay) {
    if (leituraAtual != estadoEstavel) {
      estadoEstavel = leituraAtual;
      if (estadoEstavel == LOW) {
        pressionado = true;
      }
    }
  }

  ultimoEstado = leituraAtual;
  return pressionado;
}

// Segurar SO o botao do buzzer por 3 s liga/desliga a sirene de temperatura
// deste aparelho. Exige os outros dois soltos: com os tres apertados quem manda
// e o modo de configuracao.
//
// O aperto CURTO ja disparou no instante em que o botao desceu (silencia por 10
// min, e so quando ha alarme tocando). Nao ha conflito: os dois apontam para o
// mesmo lado - calar. Segurar leva mais longe, tornando o silencio permanente.
void verificarSegurarBuzzer() {
  bool soBuzzerPressionado = digitalRead(BOTAO_BUZZER) == LOW &&
                             digitalRead(BOTAO_VERDE) == HIGH &&
                             digitalRead(BOTAO_VERMELHO) == HIGH;

  if (!soBuzzerPressionado) {
    buzzerSeguradoDesdeMs = 0;
    buzzerAlternadoNesteAperto = false;
    return;
  }

  // Uma alternancia por aperto: sem isto, continuar segurando ficaria ligando e
  // desligando a cada passagem do loop.
  if (buzzerAlternadoNesteAperto) return;

  if (buzzerSeguradoDesdeMs == 0) {
    buzzerSeguradoDesdeMs = millis();
    return;
  }
  if (millis() - buzzerSeguradoDesdeMs < TEMPO_SEGURAR_BUZZER_MS) return;

  buzzerAlternadoNesteAperto = true;
  buzzerTemperaturaAtivo = !buzzerTemperaturaAtivo;
  // Participa do LWW como qualquer ajuste: um toque fisico e mais recente que
  // um comando remoto antigo, e o app reflete a mudanca na proxima leitura.
  buzzerTimestamp = nowMs();
  configSuja = true;

  // Religar deve religar de verdade: se havia um silencio de 10 min correndo,
  // ele perderia o sentido logo apos o produtor pedir a sirene de volta.
  if (buzzerTemperaturaAtivo) reativarAlarme();

  confirmarAlternanciaBuzzer(buzzerTemperaturaAtivo);
  Serial.print("Sirene de temperatura ");
  Serial.println(buzzerTemperaturaAtivo ? "LIGADA (botao)" : "DESLIGADA (botao)");
}

// Confirmacao fisica, sem depender do visor: dois apitos curtos quando liga, um
// longo quando desliga. Como a confirmacao do modo de configuracao, ignora o
// interruptor de proposito - inclusive ao DESLIGAR, porque o apito e o aviso de
// que o pedido foi entendido. Sem ele, desligar seria indistinguivel de o
// aparelho nao ter percebido o toque.
void confirmarAlternanciaBuzzer(bool ligou) {
  if (ligou) {
    for (int i = 0; i < 2; i++) {
      digitalWrite(LED_ALERTA, HIGH);
      digitalWrite(BUZZER, HIGH);
      delay(120);
      digitalWrite(BUZZER, LOW);
      digitalWrite(LED_ALERTA, LOW);
      delay(120);
    }
  } else {
    digitalWrite(LED_ALERTA, HIGH);
    digitalWrite(BUZZER, HIGH);
    delay(500);
    digitalWrite(BUZZER, LOW);
    digitalWrite(LED_ALERTA, LOW);
  }
}

void verificarBotoes() {
  // Enquanto os tres estao apertados (ou ja no modo de configuracao), nenhum
  // botao age sozinho: senao a combinacao silenciaria o alarme e mexeria no
  // alvo no caminho.
  if (modoConfig || tresBotoesDesdeMs != 0) return;

  verificarSegurarBuzzer();

  if (botaoFoiPressionado(BOTAO_BUZZER, ultimoBuzzer, estavelBuzzer, debounceBuzzer)) {
    // Vale para qualquer alarme, inclusive fogo: quem aperta ja esta ciente.
    if (alertaTemperatura || alertaLuz) {
      // Mesmo comportamento do botao do app: silencia por 10 min. Apertar de
      // novo reinicia o prazo em vez de religar a sirene na hora.
      silenciarPorPrazo();
      // Registra o momento para o LWW: um silenciamento fisico e mais recente
      // que ajustes remotos antigos.
      modoSilenciosoTimestamp = nowMs();
      Serial.println("Buzzer silenciado por 10 min");
    }
  }

  if (botaoFoiPressionado(BOTAO_VERMELHO, ultimoVermelho, estavelVermelho, debounceVermelho)) {
    if (!modoAjuste) {
      entrarModoAjuste();
    } else {
      definirTemperaturaAlvo(temperaturaAlvoF + 1);
      tempTimestamp = nowMs();  // ajuste fisico participa do LWW
      ultimoTempoAjuste = millis();
      displayAjusteLigado = true;
      ultimoPiscaAjuste = millis();
      Serial.print("Temperatura desejada: ");
      Serial.println(temperaturaAlvoF);
    }
  }

  if (botaoFoiPressionado(BOTAO_VERDE, ultimoVerde, estavelVerde, debounceVerde)) {
    if (modoAjuste) {
      definirTemperaturaAlvo(temperaturaAlvoF - 1);
      tempTimestamp = nowMs();
      ultimoTempoAjuste = millis();
      displayAjusteLigado = true;
      ultimoPiscaAjuste = millis();
      Serial.print("Temperatura desejada: ");
      Serial.println(temperaturaAlvoF);
    } else {
      mostrandoUmidade = !mostrandoUmidade;
      if (mostrandoUmidade) {
        tempoInicioUmidade = millis();
        Serial.println("Mostrando umidade");
      } else {
        Serial.println("Mostrando temperatura");
      }
    }
  }
}

void entrarModoAjuste() {
  modoAjuste = true;
  mostrandoUmidade = false;
  ultimoTempoAjuste = millis();
  ultimoPiscaAjuste = millis();
  displayAjusteLigado = true;
  Serial.println("Modo ajuste ativado");
}

void sairModoAjuste() {
  modoAjuste = false;
  mostrandoUmidade = false;
  display.clear();
  Serial.println("Modo ajuste encerrado");
}

void verificarTempos() {
  if (!modoAjuste && mostrandoUmidade) {
    if (millis() - tempoInicioUmidade >= tempoMostrarUmidade) {
      mostrandoUmidade = false;
      Serial.println("Voltando para temperatura");
    }
  }
  if (modoAjuste) {
    if (millis() - ultimoTempoAjuste >= tempoSairAjuste) {
      sairModoAjuste();
    }
  }
}

void verificarSensorLuz() {
  int leituraLuz = digitalRead(SENSOR_LUZ);
  if (SENSOR_LUZ_ATIVO_LOW) {
    alertaLuz = leituraLuz == LOW;
  } else {
    alertaLuz = leituraLuz == HIGH;
  }
}

void lerDHT22() {
  float leituraUmidade = dht.readHumidity();
  float leituraTemperaturaF = dht.readTemperature(true);  // true = Fahrenheit

  if (isnan(leituraUmidade) || isnan(leituraTemperaturaF)) {
    leituraOk = false;
    alertaTemperatura = false;
    Serial.println("Erro ao ler DHT22");
    return;
  }

  leituraOk = true;
  umidade = (int)round(leituraUmidade);
  temperaturaF = (int)round(leituraTemperaturaF);
  atualizarEstadoTemperatura();

  Serial.print("Temperatura: ");
  Serial.print(temperaturaF);
  Serial.println(" F");
  Serial.print("Umidade: ");
  Serial.print(umidade);
  Serial.println(" %");
}

void atualizarEstadoTemperatura() {
  if (!leituraOk) {
    alertaTemperatura = false;
    ledControleLigado = false;
    return;
  }

  int margem = margemVigente();
  if (temperaturaF > temperaturaAlvoF + margem ||
      temperaturaF < temperaturaAlvoF - margem) {
    alertaTemperatura = true;
  } else {
    alertaTemperatura = false;
  }

  if (temperaturaF <= temperaturaAlvoF - 2) {
    ledControleLigado = true;
  }
  if (temperaturaF >= temperaturaAlvoF + 2) {
    ledControleLigado = false;
  }
}

void atualizarSaidas() {
  bool existeAlerta = alertaLuz || alertaTemperatura;

  digitalWrite(LED_ALERTA, existeAlerta ? HIGH : LOW);
  digitalWrite(LED_CONTROLE_TEMP, ledControleLigado ? HIGH : LOW);

  if (!modoAjuste && mostrandoUmidade) {
    digitalWrite(LED_UMIDADE, HIGH);
  } else {
    digitalWrite(LED_UMIDADE, LOW);
  }

  if (!existeAlerta) {
    // Nada a alarmar: o silencio perde a razao de existir.
    silencioAteMillis = 0;
    buzzerLigadoAgora = false;
    digitalWrite(BUZZER, LOW);
    return;
  }

  // Buzzer de temperatura desligado pelo produtor: cala o alarme COMUM, mas
  // fogo (chama ou temperatura de incendio) ainda toca - desligar o buzzer nunca esconde
  // incendio.
  if (!alertaLuz && !buzzerTemperaturaAtivo && !riscoIncendioAgora()) {
    buzzerLigadoAgora = false;
    digitalWrite(BUZZER, LOW);
    return;
  }

  // Silencio de 10 min vale tambem para o fogo. Quem apertou o botao ja esta
  // ciente - viu no app ou ouviu a sirene - e provavelmente foi buscar agua ou
  // chamar socorro; a sirene gritando ao lado so atrapalha. Nao e um
  // liga/desliga: o prazo vence sozinho e o alarme volta, entao nao da para
  // silenciar e esquecer.
  if (estaSilenciado()) {
    // ...mas so o fogo que ja estava aqui quando o botao foi apertado. Fogo
    // novo derruba o silencio inteiro: e informacao que o produtor ainda nao
    // tem, e e justamente para isso que a sirene existe. Se ele quiser silencio
    // de novo, aperta de novo - e ai passa a estar ciente deste tambem.
    if (fogoNovoDuranteSilencio()) {
      reativarAlarme();
    } else {
      buzzerLigadoAgora = false;
      digitalWrite(BUZZER, LOW);
      return;
    }
  }

  // Fogo toca CONTINUO - as duas causas: chama no sensor e temperatura de
  // incendio. O alarme comum de temperatura toca intermitente, e essa diferenca
  // e o que distingue "va ver a lenha" de "corra" para quem esta na estufa e nao
  // tem o celular na mao. Ate a 1.14.0 so a chama era continua: a temperatura
  // de incendio caia no mesmo bipe do alarme comum, apesar de ser tao grave.
  if (alertaLuz || riscoIncendioAgora()) {
    digitalWrite(BUZZER, HIGH);
    buzzerLigadoAgora = true;
    return;
  }

  controlarBuzzerIntermitente();
}

void controlarBuzzerIntermitente() {
  unsigned long agora = millis();

  if (!buzzerLigadoAgora && agora - ultimoTempoBuzzer >= intervaloBuzzer) {
    digitalWrite(BUZZER, HIGH);
    buzzerLigadoAgora = true;
    ultimoTempoBuzzer = agora;
  }

  if (buzzerLigadoAgora && agora - ultimoTempoBuzzer >= duracaoBuzzer) {
    digitalWrite(BUZZER, LOW);
    buzzerLigadoAgora = false;
  }
}

void atualizarDisplay() {
  // No modo de configuracao o visor mostra "----": um estado claramente
  // diferente de uma leitura, sem tentar escrever letras (o display de 7
  // segmentos nao mostra texto legivel). A confirmacao de entrada e o
  // apito + LEDs em entrarModoConfig(); isto so evita achar que travou.
  if (modoConfig) {
    // O PIN ocupa o visor enquanto vale. Os tracos voltam quando ele morre por
    // excesso de erros: um estado visivelmente diferente, que diz "saia e entre
    // de novo no modo de configuracao".
    if (pinConfig >= 0) {
      display.showNumberDec(pinConfig, true);  // true = zeros a esquerda
    } else {
      const uint8_t tracos[] = {0x40, 0x40, 0x40, 0x40};  // - - - -
      display.setSegments(tracos);
    }
    return;
  }

  if (modoAjuste) {
    if (millis() - ultimoPiscaAjuste >= intervaloPiscaAjuste) {
      ultimoPiscaAjuste = millis();
      displayAjusteLigado = !displayAjusteLigado;
    }
    if (displayAjusteLigado) {
      display.showNumberDec(temperaturaAlvoF, false);
    } else {
      display.clear();
    }
    return;
  }

  if (!leituraOk) {
    display.showNumberDec(0, false);
    return;
  }

  if (mostrandoUmidade) {
    display.showNumberDec(umidade, false);
  } else {
    display.showNumberDec((int)round(temperaturaF), false);
  }
}
