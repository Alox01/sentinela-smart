#include <WiFi.h>
#include <WebServer.h>
#include <DHT.h>

const char* ssid = "NOME_DO_SEU_WIFI";
const char* senha = "SENHA_DO_SEU_WIFI";

// Use a mesma chave no cadastro da estufa no app. Deixe vazio para testes sem chave.
const char* chaveAcesso = "";

const char* headerKeys[] = {"Authorization", "X-Device-Token"};
const size_t headerCount = sizeof(headerKeys) / sizeof(char*);

WebServer server(80);

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

const bool COMMON_ANODE = true;

#define SEG_A 18
#define SEG_B 19
#define SEG_C 21
#define SEG_D 22
#define SEG_E 23
#define SEG_F 5
#define SEG_G 16

#define DIG1 17
#define DIG2 2
#define DIG3 15

int segmentos[7] = {SEG_A, SEG_B, SEG_C, SEG_D, SEG_E, SEG_F, SEG_G};
int digitos[3] = {DIG1, DIG2, DIG3};

byte numeros[10][7] = {
  {1,1,1,1,1,1,0},
  {0,1,1,0,0,0,0},
  {1,1,0,1,1,0,1},
  {1,1,1,1,0,0,1},
  {0,1,1,0,0,1,1},
  {1,0,1,1,0,1,1},
  {1,0,1,1,1,1,1},
  {1,1,1,0,0,0,0},
  {1,1,1,1,1,1,1},
  {1,1,1,1,0,1,1}
};

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

void setup() {
  Serial.begin(115200);
  delay(1000);

  dht.begin();

  pinMode(SENSOR_LUZ, INPUT);

  pinMode(BOTAO_BUZZER, INPUT_PULLUP);
  pinMode(BOTAO_VERDE, INPUT_PULLUP);
  pinMode(BOTAO_VERMELHO, INPUT_PULLUP);

  pinMode(LED_ALERTA, OUTPUT);
  pinMode(LED_UMIDADE, OUTPUT);
  pinMode(LED_CONTROLE_TEMP, OUTPUT);
  pinMode(BUZZER, OUTPUT);

  for (int i = 0; i < 7; i++) {
    pinMode(segmentos[i], OUTPUT);
  }

  for (int i = 0; i < 3; i++) {
    pinMode(digitos[i], OUTPUT);
  }

  apagarTudo();

  digitalWrite(LED_ALERTA, LOW);
  digitalWrite(LED_UMIDADE, LOW);
  digitalWrite(LED_CONTROLE_TEMP, LOW);
  digitalWrite(BUZZER, LOW);

  conectarWiFi();

  server.collectHeaders(headerKeys, headerCount);
  server.on("/", HTTP_GET, enviarInicio);
  server.on("/dados", HTTP_GET, enviarDados);
  server.on("/status", HTTP_GET, enviarStatus);
  server.on("/sincronizar", HTTP_OPTIONS, responderOptions);
  server.on("/sincronizar", HTTP_POST, receberSincronizacao);
  server.onNotFound(responderNaoEncontrado);
  server.begin();

  Serial.println("Servidor iniciado");
  Serial.println("Sistema iniciado");
}

void loop() {
  server.handleClient();

  unsigned long agora = millis();

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

void conectarWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, senha);

  Serial.print("Conectando ao Wi-Fi");

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.println("Wi-Fi conectado");
  Serial.print("IP do ESP32: ");
  Serial.println(WiFi.localIP());
}

void enviarCors() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Device-Token");
}

void responderOptions() {
  enviarCors();
  server.send(204, "text/plain", "");
}

bool chaveValida() {
  if (strlen(chaveAcesso) == 0) {
    return true;
  }

  String tokenHeader = server.header("X-Device-Token");
  if (tokenHeader == chaveAcesso) {
    return true;
  }

  String auth = server.header("Authorization");
  String prefixo = "Bearer ";
  if (auth.startsWith(prefixo) && auth.substring(prefixo.length()) == chaveAcesso) {
    return true;
  }

  return false;
}

bool bloquearSeChaveInvalida() {
  if (chaveValida()) {
    return false;
  }

  enviarCors();
  server.send(401, "application/json", "{\"sucesso\":false,\"erro\":\"Chave de acesso invalida.\"}");
  return true;
}

String jsonDadosBasicos() {
  String json = "{";
  json += "\"temperaturaF\":";
  json += String(temperaturaF, 1);
  json += ",";
  json += "\"umidade\":";
  json += String(umidade, 1);
  json += ",";
  json += "\"temperaturaAlvoF\":";
  json += String(temperaturaAlvoF);
  json += ",";
  json += "\"margemF\":";
  json += String(margemF);
  json += ",";
  json += "\"alertaTemperatura\":";
  json += alertaTemperatura ? "true" : "false";
  json += ",";
  json += "\"alertaLuz\":";
  json += alertaLuz ? "true" : "false";
  json += ",";
  json += "\"mostrandoUmidade\":";
  json += mostrandoUmidade ? "true" : "false";
  json += ",";
  json += "\"modoAjuste\":";
  json += modoAjuste ? "true" : "false";
  json += ",";
  json += "\"buzzerSilenciado\":";
  json += buzzerSilenciado ? "true" : "false";
  json += ",";
  json += "\"ledControleLigado\":";
  json += ledControleLigado ? "true" : "false";
  json += ",";
  json += "\"leituraOk\":";
  json += leituraOk ? "true" : "false";
  json += ",";
  json += "\"ip\":\"";
  json += WiFi.localIP().toString();
  json += "\"";
  json += "}";
  return json;
}
String avisoAtual() {
  if (!leituraOk) {
    return "Falha na leitura do sensor";
  }
  if (alertaLuz) {
    return "Alarme de luz acionado";
  }
  if (alertaTemperatura) {
    return "Alarme de temperatura acionado";
  }
  return "Estavel";
}

String corStatusAtual() {
  if (alertaLuz || alertaTemperatura) {
    return "red";
  }
  return "green";
}

int sinalWifiPercentual() {
  long rssi = WiFi.RSSI();
  if (rssi <= -100) return 0;
  if (rssi >= -50) return 100;
  return 2 * (rssi + 100);
}

String jsonStatusApp() {
  String status = "{";
  status += "\"idHardware\":\"ESP32_PROTOTYPE_01\",";
  status += "\"timestampLeitura\":";
  status += String(millis());
  status += ",";
  status += "\"temperaturaAtual\":";
  status += String(temperaturaF, 1);
  status += ",";
  status += "\"umidadeAtual\":";
  status += String(umidade, 1);
  status += ",";
  status += "\"temEnergia\":true,";
  status += "\"temInternet\":";
  status += WiFi.status() == WL_CONNECTED ? "true" : "false";
  status += ",";
  status += "\"sinalWifi\":";
  status += String(sinalWifiPercentual());
  status += ",";
  status += "\"alertaIncendio\":";
  status += alertaLuz ? "true" : "false";
  status += ",";
  status += "\"alarmeAtivo\":";
  status += (alertaLuz || alertaTemperatura) ? "true" : "false";
  status += ",";
  status += "\"perigoChama\":";
  status += alertaLuz ? "true" : "false";
  status += ",";
  status += "\"riscoIncendio\":false,";
  status += "\"ventiladorLigado\":false,";
  status += "\"aquecedorLigado\":";
  status += ledControleLigado ? "true" : "false";
  status += ",";
  status += "\"umidificadorLigado\":false,";
  status += "\"faseAtual\":\"Prototipo\",";
  status += "\"aviso\":\"";
  status += avisoAtual();
  status += "\",";
  status += "\"corStatus\":\"";
  status += corStatusAtual();
  status += "\"";
  status += "}";

  String config = "{";
  config += "\"idHardware\":\"ESP32_PROTOTYPE_01\",";
  config += "\"temperaturaMeta\":";
  config += String(temperaturaAlvoF);
  config += ",";
  config += "\"tempTimestamp\":";
  config += String(millis());
  config += ",";
  config += "\"umidadeMeta\":";
  config += String((int)round(umidade));
  config += ",";
  config += "\"umidTimestamp\":";
  config += String(millis());
  config += ",";
  config += "\"modoSilencioso\":";
  config += buzzerSilenciado ? "true" : "false";
  config += ",";
  config += "\"modoSilenciosoTimestamp\":";
  config += String(millis());
  config += "}";

  String resposta = "{";
  resposta += "\"status\":";
  resposta += status;
  resposta += ",";
  resposta += "\"config\":";
  resposta += config;
  resposta += "}";
  return resposta;
}
void enviarInicio() {
  String html = "";
  html += "<html>";
  html += "<head><meta charset='UTF-8'><title>ESP32</title></head>";
  html += "<body>";
  html += "<h1>ESP32 Online</h1>";
  html += "<p>Acesse /status para o app Sentinela.</p>";
  html += "<p>Acesse /dados para ver o JSON simples do prototipo.</p>";
  html += "</body>";
  html += "</html>";

  enviarCors();
  server.send(200, "text/html", html);
}

void enviarDados() {
  enviarCors();
  server.send(200, "application/json", jsonDadosBasicos());
}

void enviarStatus() {
  enviarCors();
  server.send(200, "application/json", jsonStatusApp());
}

bool extrairNumeroJson(String corpo, String campo, float &valor) {
  String marcador = "\"";
  marcador += campo;
  marcador += "\"";
  int posCampo = corpo.indexOf(marcador);
  if (posCampo < 0) return false;

  int posDoisPontos = corpo.indexOf(':', posCampo);
  if (posDoisPontos < 0) return false;

  int inicio = posDoisPontos + 1;
  while (inicio < corpo.length() && (corpo[inicio] == ' ' || corpo[inicio] == '\"')) {
    inicio++;
  }

  int fim = inicio;
  while (fim < corpo.length()) {
    char c = corpo[fim];
    if (!(c >= '0' && c <= '9') && c != '-' && c != '.') {
      break;
    }
    fim++;
  }

  if (fim <= inicio) return false;
  valor = corpo.substring(inicio, fim).toFloat();
  return true;
}

bool extrairBoolJson(String corpo, String campo, bool &valor) {
  String marcador = "\"";
  marcador += campo;
  marcador += "\"";
  int posCampo = corpo.indexOf(marcador);
  if (posCampo < 0) return false;

  int posDoisPontos = corpo.indexOf(':', posCampo);
  if (posDoisPontos < 0) return false;

  String trecho = corpo.substring(posDoisPontos + 1);
  trecho.trim();
  if (trecho.startsWith("true")) {
    valor = true;
    return true;
  }
  if (trecho.startsWith("false")) {
    valor = false;
    return true;
  }
  return false;
}

void receberSincronizacao() {
  if (bloquearSeChaveInvalida()) {
    return;
  }

  String corpo = server.arg("plain");
  float novoValor = 0;
  bool novoModoSilencioso = false;
  bool alterouTemperatura = false;
  bool alterouModoSilencioso = false;
  bool ignorouUmidade = corpo.indexOf("\"umidadeMeta\"") >= 0;

  if (extrairNumeroJson(corpo, "temperaturaMeta", novoValor)) {
    int novaTemperatura = (int)round(novoValor);
    if (novaTemperatura < 60) novaTemperatura = 60;
    if (novaTemperatura > 200) novaTemperatura = 200;
    temperaturaAlvoF = novaTemperatura;
    atualizarEstadoTemperatura();
    alterouTemperatura = true;
  }

  if (extrairBoolJson(corpo, "modoSilencioso", novoModoSilencioso)) {
    buzzerSilenciado = novoModoSilencioso;
    if (buzzerSilenciado) {
      digitalWrite(BUZZER, LOW);
      buzzerLigadoAgora = false;
    }
    alterouModoSilencioso = true;
  }

  String aplicadas = "[";
  bool primeira = true;
  if (alterouTemperatura) {
    aplicadas += "\"temperaturaMeta\"";
    primeira = false;
  }
  if (alterouModoSilencioso) {
    if (!primeira) aplicadas += ",";
    aplicadas += "\"modoSilencioso\"";
  }
  aplicadas += "]";

  String ignoradas = "[";
  if (ignorouUmidade) {
    ignoradas += "\"umidadeMeta\"";
  }
  ignoradas += "]";

  String resposta = "{";
  resposta += "\"sucesso\":true,";
  resposta += "\"alteracoesAplicadas\":";
  resposta += aplicadas;
  resposta += ",";
  resposta += "\"alteracoesIgnoradas\":";
  resposta += ignoradas;
  resposta += ",";
  resposta += "\"dados\":";
  resposta += jsonStatusApp();
  resposta += "}";

  enviarCors();
  server.send(200, "application/json", resposta);
}

void responderNaoEncontrado() {
  if (server.method() == HTTP_OPTIONS) {
    responderOptions();
    return;
  }

  enviarCors();
  server.send(404, "application/json", "{\"sucesso\":false,\"erro\":\"Rota nao encontrada.\"}");
}

bool botaoFoiPressionado(int pino, bool &ultimoEstado, bool &estadoEstavel, unsigned long &ultimoDebounce) {
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
  apagarTudo();

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
  float leituraTemperaturaF = dht.readTemperature(true);

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

  Serial.print("Alvo: ");
  Serial.print(temperaturaAlvoF);
  Serial.println(" F");

  Serial.print("LED controle D14: ");
  Serial.println(ledControleLigado ? "LIGADO" : "DESLIGADO");
}

void atualizarEstadoTemperatura() {
  if (!leituraOk) {
    alertaTemperatura = false;
    ledControleLigado = false;
    return;
  }

  if (temperaturaF > temperaturaAlvoF + margemF || temperaturaF < temperaturaAlvoF - margemF) {
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
      mostrarNumero3(temperaturaAlvoF);
    } else {
      apagarTudo();
    }

    return;
  }

  if (!leituraOk) {
    mostrarNumero3(0);
    return;
  }

  if (mostrandoUmidade) {
    mostrarNumero3((int)round(umidade));
  } else {
    mostrarNumero3((int)round(temperaturaF));
  }
}

void mostrarNumero3(int numero) {
  if (numero < 0) {
    numero = 0;
  }

  if (numero > 999) {
    numero = 999;
  }

  int centena = (numero / 100) % 10;
  int dezena = (numero / 10) % 10;
  int unidade = numero % 10;

  mostrarDigito(0, centena);
  delay(3);

  mostrarDigito(1, dezena);
  delay(3);

  mostrarDigito(2, unidade);
  delay(3);
}

void mostrarDigito(int posicao, int numero) {
  apagarDigitos();

  for (int i = 0; i < 7; i++) {
    escreverSegmento(segmentos[i], numeros[numero][i]);
  }

  ligarDigito(posicao);
}

void escreverSegmento(int pino, bool ligado) {
  if (COMMON_ANODE) {
    digitalWrite(pino, ligado ? LOW : HIGH);
  } else {
    digitalWrite(pino, ligado ? HIGH : LOW);
  }
}

void ligarDigito(int posicao) {
  if (COMMON_ANODE) {
    digitalWrite(digitos[posicao], HIGH);
  } else {
    digitalWrite(digitos[posicao], LOW);
  }
}

void apagarDigitos() {
  for (int i = 0; i < 3; i++) {
    if (COMMON_ANODE) {
      digitalWrite(digitos[i], LOW);
    } else {
      digitalWrite(digitos[i], HIGH);
    }
  }
}

void apagarTudo() {
  apagarDigitos();

  for (int i = 0; i < 7; i++) {
    if (COMMON_ANODE) {
      digitalWrite(segmentos[i], HIGH);
    } else {
      digitalWrite(segmentos[i], LOW);
    }
  }
}


