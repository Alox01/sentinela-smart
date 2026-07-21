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
const char* VERSAO_FIRMWARE = "1.10.0";
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

// IP fixo (opcional). Vazio = DHCP, que e o normal. Existe porque em muita
// propriedade o roteador e do provedor e o produtor nao tem acesso para fazer
// reserva de DHCP - sem isto, so restaria reconferir o IP a cada queda de luz.
String ipFixo;
String gatewayFixo;
String mascaraFixa;

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
unsigned long tresBotoesDesdeMs = 0;
unsigned long ultimaAtividadeConfig = 0;

// Prototipos explicitos: o gerador automatico do Arduino as vezes nao monta a
// assinatura certa para funcoes que recebem tipos do ArduinoJson.
void aplicarAjustes(JsonObjectConst entrada, JsonArray aplicadas,
                    JsonArray ignoradas);
void buscarComandosNuvem();
bool estadoDeAlertaMudou();
void carregarConfigPersistida();
void salvarConfigSeNecessario();
void definirTemperaturaAlvo(int novoAlvo);
int margemVigente();
void atualizarEstadoTemperatura();
bool estaSilenciado();
void silenciarPorPrazo();
void reativarAlarme();
long long nowMs();
void iniciarMdns();
void aplicarIpFixoSeConfigurado();
void verificarModoConfig();
void entrarModoConfig();
void handleConfigPagina();
void handleConfigSalvar();

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
    // NTP para timestamp real (fuso nao importa, usamos epoch em ms).
    configTime(0, 0, "pool.ntp.org", "time.google.com");
  } else {
    Serial.println("Sem Wi-Fi - operando em modo local standalone.");
  }
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
  if (!gateway.fromString(gatewayFixo)) {
    // Sem gateway informado, o palpite seguro e o .1 da mesma faixa.
    gateway = IPAddress(ip[0], ip[1], ip[2], 1);
  }
  if (!mascara.fromString(mascaraFixa)) {
    mascara = IPAddress(255, 255, 255, 0);
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
      "<label>Chave de acesso</label><input name=\"token\" value=\"");
  html += escaparHtml(tokenAparelho);
  html += F(
      "\">"
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

  prefs.begin("sentinela", false);
  prefs.putString("wifiSsid", ssid);
  // Senha vazia mantem a atual: assim da para so trocar a chave de acesso sem
  // precisar digitar a senha do Wi-Fi de novo.
  if (senha.length() > 0) prefs.putString("wifiPass", senha);
  prefs.putString("token", token);
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
  // As constantes do topo sao so o valor de fabrica: o que o produtor gravou
  // pelo modo de configuracao tem precedencia.
  wifiSsid = prefs.getString("wifiSsid", WIFI_SSID);
  wifiPass = prefs.getString("wifiPass", WIFI_PASS);
  tokenAparelho = prefs.getString("token", DEVICE_TOKEN);
  ipFixo = prefs.getString("ipFixo", "");
  gatewayFixo = prefs.getString("gateway", "");
  mascaraFixa = prefs.getString("mascara", "");
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
  doc["alarmeAtivo"] = alarmeAtivoAgora();
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

bool riscoIncendioAgora() {
  return leituraOk && temperaturaF > 175;
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
  digitalWrite(BUZZER, LOW);
  buzzerLigadoAgora = false;
}

void reativarAlarme() {
  silencioAteMillis = 0;
  ultimoTempoBuzzer = 0;
}

// Sirene fisica ligada agora? Incendio (nao silenciavel) ou temperatura fora
// (silenciavel). Espelha a logica de atualizarSaidas().
bool alarmeAtivoAgora() {
  bool fogo = alertaLuz || riscoIncendioAgora();
  bool sireneTemp = alertaTemperatura && !estaSilenciado();
  return fogo || sireneTemp;
}

String avisoAtual() {
  if (alertaLuz) return "SENSOR DE LUZ/CHAMA ATIVADO";
  if (riscoIncendioAgora()) return "RISCO DE INCENDIO";
  if (alertaTemperatura) {
    return temperaturaF > temperaturaAlvoF ? "Temperatura Alta" : "Temperatura Baixa";
  }
  if (!leituraOk) return "Sem leitura do sensor";
  return "Estavel";
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
  status["alarmeAtivo"] = alarmeAtivoAgora();
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

void verificarBotoes() {
  // Enquanto os tres estao apertados (ou ja no modo de configuracao), nenhum
  // botao age sozinho: senao a combinacao silenciaria o alarme e mexeria no
  // alvo no caminho.
  if (modoConfig || tresBotoesDesdeMs != 0) return;

  if (botaoFoiPressionado(BOTAO_BUZZER, ultimoBuzzer, estavelBuzzer, debounceBuzzer)) {
    if (alertaTemperatura && !alertaLuz) {
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

  if (alertaLuz) {
    digitalWrite(BUZZER, HIGH);
    buzzerLigadoAgora = true;
    return;
  }

  if (!alertaTemperatura) {
    // Temperatura normalizou: o silencio perde a razao de existir.
    silencioAteMillis = 0;
    buzzerLigadoAgora = false;
    digitalWrite(BUZZER, LOW);
    return;
  }

  if (estaSilenciado()) {
    buzzerLigadoAgora = false;
    digitalWrite(BUZZER, LOW);
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
  // "ConF" no visor: e o unico sinal de que o aparelho virou ponto de acesso,
  // e evita alguem achar que ele travou.
  if (modoConfig) {
    const uint8_t conf[] = {0x39, 0x5C, 0x37, 0x71};  // C o n F
    display.setSegments(conf);
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
