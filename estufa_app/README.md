# Sentinela Smart App

Aplicativo Flutter para Android e iOS, usado para monitorar estufas, ajustar
temperatura e umidade, acompanhar estufadas e visualizar relatórios.

O projeto não possui versão web. A página aberta em `192.168.4.1` pertence ao
firmware do ESP32 e continua sendo usada para configurar o aparelho.

## Executar no celular

Liste os aparelhos conectados e execute no destino desejado:

```powershell
flutter devices
flutter run -d ID_DO_APARELHO --dart-define=CLOUD_API_URL=https://estufa-server.onrender.com
```

## Testes

```powershell
flutter analyze
flutter test
```

## Gerar APK

```powershell
flutter build apk --release --split-per-abi --dart-define=CLOUD_API_URL=https://estufa-server.onrender.com
```

Nesta branch não existe `ESCOPO_TCC`: ela já *é* a versão de apresentação, e sai
um APK só. Ver [`../docs/VERSAO_TCC.md`](../docs/VERSAO_TCC.md).
