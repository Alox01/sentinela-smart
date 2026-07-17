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
    1. Preencha WIFI_SSID, WIFI_PASS e DEVICE_TOKEN abaixo.
    2. O DEVICE_TOKEN deve ser IGUAL a chave de acesso cadastrada no app.
    3. Este firmware ainda NAO foi testado em hardware. Validar quando o
       aparelho chegar (ver o checklist em docs/TESTE_ESP32_REAL.md).
*/

#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <time.h>
#include <DHT.h>
#include <TM1637Display.h>
#include <ArduinoJson.h>

// ===================== CONFIG (preencher) =====================
const char* WIFI_SSID       = "SUA_REDE_WIFI";
const char* WIFI_PASS       = "SUA_SENHA_WIFI";
// Mesma chave usada no app (campo "Chave de acesso") e no ESTUFA_API_TOKEN.
// Deixe "" para liberar comandos sem token (apenas em rede local confiavel).
const char* DEVICE_TOKEN    = "COLE_AQUI_O_MESMO_TOKEN_DO_APP";
// O id do aparelho e gerado do chip (MAC) no setup -> unico por ESP, sem
// precisar configurar nada. Cada aparelho vira o seu na nuvem (status por
// aparelho). Ex.: "ESP32_A1B2C3".
const char* VERSAO_FIRMWARE = "1.0.0";
// URL da nuvem para onde o aparelho empurra as leituras (historico + acesso
// remoto). Deixe "" para nao empurrar. Precisa que o servidor esteja em
// MODO_RECEPTOR para o /status remoto refletir o aparelho real.
const char* CLOUD_URL = "https://estufa-server.onrender.com";
const unsigned long PUSH_INTERVAL_MS = 60000;  // envia uma leitura a cada 1 min
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
bool buzzerSilenciado = false;
bool buzzerLigadoAgora = false;
bool ledControleLigado = false;

float temperaturaF = 0;
float umidade = 0;

bool leituraOk = false;

int temperaturaAlvoF = 76;
int margemF = 8;

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
String idHardware;  // definido no setup a partir do chip (unico por ESP)

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
  Serial.print("ID do aparelho: ");
  Serial.println(idHardware);

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
  server.onNotFound([]() {
    server.send(404, "application/json", "{\"erro\":\"Rota nao encontrada\"}");
  });
  server.begin();

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
  manterWifi();

  if (millis() - ultimoPushNuvem >= PUSH_INTERVAL_MS) {
    ultimoPushNuvem = millis();
    empurrarLeituraNuvem();
  }

  verificarSensorLuz();
  verificarBotoes();
  verificarTempos();

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
  if (strlen(WIFI_SSID) == 0) return;
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASS);

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

// Reconecta em segundo plano sem travar o controle local.
void manterWifi() {
  if (strlen(WIFI_SSID) == 0) return;
  if (WiFi.status() == WL_CONNECTED) return;
  if (millis() - ultimaTentativaWifi < intervaloReconexaoWifi) return;
  ultimaTentativaWifi = millis();
  WiFi.begin(WIFI_SSID, WIFI_PASS);
}

// Empurra a leitura atual para a nuvem (POST /leitura). O servidor em
// MODO_RECEPTOR usa isso para o /status remoto refletir o aparelho real, em vez
// de simular. Bloqueia o loop por ~1-2 s durante o handshake HTTPS; como so roda
// a cada PUSH_INTERVAL_MS, nao atrapalha o controle local.
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

  JsonObject config = doc["config"].to<JsonObject>();
  config["idHardware"] = idHardware;
  config["temperaturaMeta"] = temperaturaAlvoF;
  config["tempTimestamp"] = tempTimestamp;
  config["umidadeMeta"] = umidadeAlvo;
  config["umidTimestamp"] = umidTimestamp;
  config["modoSilencioso"] = buzzerSilenciado;
  config["modoSilenciosoTimestamp"] = modoSilenciosoTimestamp;

  String corpo;
  serializeJson(doc, corpo);

  WiFiClientSecure cliente;
  cliente.setInsecure();  // nao valida certificado (simplifica; ok para o TCC)
  HTTPClient http;
  String url = String(CLOUD_URL) + "/leitura";
  if (!http.begin(cliente, url)) return;
  http.addHeader("Content-Type", "application/json");
  if (strlen(DEVICE_TOKEN) > 0) http.addHeader("X-Device-Token", DEVICE_TOKEN);
  int codigo = http.POST(corpo);
  Serial.print("Push nuvem -> HTTP ");
  Serial.println(codigo);
  http.end();
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
  return leituraOk && temperaturaF > 175.0;
}

// Sirene fisica ligada agora? Incendio (nao silenciavel) ou temperatura fora
// (silenciavel). Espelha a logica de atualizarSaidas().
bool alarmeAtivoAgora() {
  bool fogo = alertaLuz || riscoIncendioAgora();
  bool sireneTemp = alertaTemperatura && !buzzerSilenciado;
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
  String esperado = DEVICE_TOKEN;
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
  config["modoSilencioso"] = buzzerSilenciado;
  config["modoSilenciosoTimestamp"] = modoSilenciosoTimestamp;

  String saida;
  serializeJson(doc, saida);
  server.send(200, "application/json", saida);
}

void handleSimple() {
  JsonDocument doc;
  doc["temperaturaF"] = temperaturaF;
  doc["umidade"] = umidade;
  doc["temperaturaAlvoF"] = temperaturaAlvoF;
  doc["umidadeAlvo"] = umidadeAlvo;
  doc["margemF"] = margemF;
  doc["alertaTemperatura"] = alertaTemperatura;
  doc["alertaLuz"] = alertaLuz;
  doc["mostrandoUmidade"] = mostrandoUmidade;
  doc["modoAjuste"] = modoAjuste;
  doc["buzzerSilenciado"] = buzzerSilenciado;
  doc["ledControleLigado"] = ledControleLigado;
  doc["leituraOk"] = leituraOk;
  doc["ip"] = WiFi.localIP().toString();
  doc["tokenConfigurado"] = (strlen(DEVICE_TOKEN) > 0);
  doc["versaoFirmware"] = VERSAO_FIRMWARE;

  String saida;
  serializeJson(doc, saida);
  server.send(200, "application/json", saida);
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

  // Temperatura (LWW por tempTimestamp).
  if (!entrada["temperaturaMeta"].isNull()) {
    long long ts = entrada["tempTimestamp"].as<long long>();
    if (ts > tempTimestamp) {
      temperaturaAlvoF = (int)round(entrada["temperaturaMeta"].as<float>());
      tempTimestamp = ts;
      atualizarEstadoTemperatura();
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
      buzzerSilenciado = temModo ? entrada["modoSilencioso"].as<bool>() : true;
      modoSilenciosoTimestamp = ts;
      aplicadas.add("modoSilencioso");
    } else {
      ignoradas.add("modoSilencioso");
    }
  }

  resp["sucesso"] = true;
  JsonObject cfg = resp["configAtualizada"].to<JsonObject>();
  cfg["idHardware"] = idHardware;
  cfg["temperaturaMeta"] = temperaturaAlvoF;
  cfg["tempTimestamp"] = tempTimestamp;
  cfg["umidadeMeta"] = umidadeAlvo;
  cfg["umidTimestamp"] = umidTimestamp;
  cfg["modoSilencioso"] = buzzerSilenciado;
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
  if (botaoFoiPressionado(BOTAO_BUZZER, ultimoBuzzer, estavelBuzzer, debounceBuzzer)) {
    if (alertaTemperatura && !alertaLuz) {
      buzzerSilenciado = !buzzerSilenciado;
      // Registra o momento para o LWW: um silenciamento fisico e mais recente
      // que ajustes remotos antigos.
      modoSilenciosoTimestamp = nowMs();
      if (buzzerSilenciado) {
        digitalWrite(BUZZER, LOW);
        buzzerLigadoAgora = false;
        Serial.println("Buzzer silenciado");
      } else {
        ultimoTempoBuzzer = 0;
        Serial.println("Buzzer ativado novamente");
      }
    }
  }

  if (botaoFoiPressionado(BOTAO_VERMELHO, ultimoVermelho, estavelVermelho, debounceVermelho)) {
    if (!modoAjuste) {
      entrarModoAjuste();
    } else {
      temperaturaAlvoF++;
      tempTimestamp = nowMs();  // ajuste fisico participa do LWW
      ultimoTempoAjuste = millis();
      displayAjusteLigado = true;
      ultimoPiscaAjuste = millis();
      atualizarEstadoTemperatura();
      Serial.print("Temperatura desejada: ");
      Serial.println(temperaturaAlvoF);
    }
  }

  if (botaoFoiPressionado(BOTAO_VERDE, ultimoVerde, estavelVerde, debounceVerde)) {
    if (modoAjuste) {
      temperaturaAlvoF--;
      tempTimestamp = nowMs();
      ultimoTempoAjuste = millis();
      displayAjusteLigado = true;
      ultimoPiscaAjuste = millis();
      atualizarEstadoTemperatura();
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
  umidade = leituraUmidade;
  temperaturaF = leituraTemperaturaF;
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

  if (temperaturaF > temperaturaAlvoF + margemF ||
      temperaturaF < temperaturaAlvoF - margemF) {
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
    buzzerSilenciado = false;
    buzzerLigadoAgora = false;
    digitalWrite(BUZZER, LOW);
    return;
  }

  if (buzzerSilenciado) {
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
    display.showNumberDec((int)round(umidade), false);
  } else {
    display.showNumberDec((int)round(temperaturaF), false);
  }
}
