# Sentinela ESP32 prototype

Firmware de teste para ligar o prototipo ESP32 ao app Sentinela sem usar o simulador Node.js.

## Como usar

1. Abra `esp32/sentinela_esp32/sentinela_esp32.ino` na Arduino IDE.
2. Selecione a placa `ESP32 Dev Module`.
3. Instale a biblioteca `DHT sensor library`, se ainda nao estiver instalada.
4. Ajuste no topo do arquivo:

```cpp
const char* ssid = "NOME_DO_SEU_WIFI";
const char* senha = "SENHA_DO_SEU_WIFI";
const char* chaveAcesso = "123456";
```

5. Grave o codigo no ESP32.
6. Abra o monitor serial e copie o IP exibido pelo ESP32.
7. No app, cadastre a estufa com:

```text
IP ou endereco: 192.168.1.50:80
Chave de acesso: 123456
```

Troque `192.168.1.50` pelo IP real mostrado no monitor serial.

## Rotas expostas

- `GET /dados`: JSON simples do prototipo.
- `GET /status`: JSON no formato esperado pelo app Sentinela.
- `POST /sincronizar`: recebe comandos do app.

## Observacoes

- O ESP32 controla somente o ajuste de temperatura, porque o prototipo atual nao tem atuador de umidade.
- Quando o app enviar `umidadeMeta`, o ESP32 aceita a requisicao, mas ignora esse campo.
- A rota `/status` fica publica para facilitar monitoramento local. A rota `/sincronizar` exige a chave de acesso quando `chaveAcesso` estiver preenchida.
- Para voltar ao simulador, use outra branch do projeto ou cadastre a estufa apontando para o IP do computador na porta `3000`.
