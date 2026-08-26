/*
  Teste da placa ilhada — Sentinela Smart

  NAO e o firmware. E um esquete de bancada para conferir a solda antes de
  fechar a caixa: acende cada LED em sequencia, toca a buzina, mostra no
  display e imprime no Serial o estado dos botoes e dos sensores.

  A pinagem e identica a de sentinela_esp32.ino — se algo aqui nao responde,
  o defeito esta na solda, nao no codigo.

  Por que testar com este esquete e nao com o firmware: o firmware so acende
  os LEDs quando a temperatura sai da faixa, e so toca a buzina em alarme.
  Reproduzir isso na bancada e demorado; aqui tudo pisca sozinho.

  Bibliotecas: DHT sensor library (Adafruit), TM1637Display.
  Placa: ESP32 Dev Module.
*/

#include <DHT.h>
#include <TM1637Display.h>

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

int passo = 0;

void setup() {
  Serial.begin(115200);
  delay(500);

  pinMode(SENSOR_LUZ, INPUT);
  pinMode(BOTAO_BUZZER, INPUT_PULLUP);
  pinMode(BOTAO_VERDE, INPUT_PULLUP);
  pinMode(BOTAO_VERMELHO, INPUT_PULLUP);

  pinMode(LED_ALERTA, OUTPUT);
  pinMode(LED_UMIDADE, OUTPUT);
  pinMode(LED_CONTROLE_TEMP, OUTPUT);
  pinMode(BUZZER, OUTPUT);

  dht.begin();
  display.setBrightness(7);

  Serial.println();
  Serial.println("=== TESTE DA PLACA ===");
  Serial.println("LEDs e buzina piscam sozinhos.");
  Serial.println("Aperte cada botao e veja mudar de SOLTO para APERTADO.");
  Serial.println();
}

void loop() {
  // Um LED por vez: se dois acenderem juntos, ha ponte de solda entre eles.
  digitalWrite(LED_ALERTA, passo == 0);
  digitalWrite(LED_UMIDADE, passo == 1);
  digitalWrite(LED_CONTROLE_TEMP, passo == 2);

  // Buzina so no passo 3, e curta: testar solda nao precisa de barulho longo.
  if (passo == 3) {
    digitalWrite(BUZZER, HIGH);
    delay(120);
    digitalWrite(BUZZER, LOW);
  }

  passo = (passo + 1) % 4;

  // Display conta de 0 a 3 junto com o passo: numero parado = CLK ou DIO
  // sem contato; numero embaralhado = os dois trocados.
  display.showNumberDec(passo, true);

  Serial.print("botoes: buzzer=");
  Serial.print(digitalRead(BOTAO_BUZZER) == LOW ? "APERTADO" : "solto");
  Serial.print(" verde=");
  Serial.print(digitalRead(BOTAO_VERDE) == LOW ? "APERTADO" : "solto");
  Serial.print(" vermelho=");
  Serial.print(digitalRead(BOTAO_VERMELHO) == LOW ? "APERTADO" : "solto");

  bool chama = SENSOR_LUZ_ATIVO_LOW ? digitalRead(SENSOR_LUZ) == LOW
                                    : digitalRead(SENSOR_LUZ) == HIGH;
  Serial.print(" | chama=");
  Serial.print(chama ? "DETECTADA" : "nao");

  float umidade = dht.readHumidity();
  float tempC = dht.readTemperature();
  Serial.print(" | DHT22=");
  if (isnan(umidade) || isnan(tempC)) {
    // Sempre nan: falta o resistor de 4,7 kOhm, ou o dado nao chegou ao GPIO 32.
    Serial.println("SEM LEITURA");
  } else {
    Serial.print(tempC * 9.0 / 5.0 + 32.0, 1);
    Serial.print(" F / ");
    Serial.print(umidade, 1);
    Serial.println(" %");
  }

  delay(700);
}
