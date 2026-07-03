# Sentinela Smart App

Aplicativo Flutter do Sentinela Smart, usado para monitorar estufas, ajustar temperatura/umidade, acompanhar estufadas e visualizar relatórios.

## Rodar no navegador do computador

```powershell
cd estufa_app
flutter pub get
flutter run -d chrome
```

## Rodar para acessar pelo celular na mesma rede

Use uma porta fixa e exponha o servidor web do Flutter para a rede local:

```powershell
cd estufa_app
flutter run -d chrome --web-hostname 0.0.0.0 --web-port 53312
```

No celular, abra:

```text
http://IP_DO_PC:53312
```

Exemplo:

```text
http://192.168.1.11:53312
```

O servidor da estufa/simulador continua rodando separado na porta `3000`.

## Chave de acesso

Se o servidor ou ESP32 exigir chave de acesso, cadastre a mesma chave no campo `Chave de acesso` da estufa no app.

Também é possível informar uma chave global durante o build ou execução:

```powershell
flutter run -d chrome --dart-define=ESTUFA_API_TOKEN=minha-chave
```

A chave por estufa tem prioridade sobre a chave global.

## Testes úteis

```powershell
flutter analyze
flutter test
```

## Observação

Para testar no celular pelo navegador, o PC e o celular precisam estar na mesma rede Wi-Fi. O endereço do app usa a porta do Flutter (`53312` no exemplo). O endereço da API usa a porta do servidor (`3000`).