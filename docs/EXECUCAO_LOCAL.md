# Execução local para demonstração

Este guia resume como rodar o Sentinela Smart em ambiente local para testar no PC ou no celular.

## Peças do sistema

- App Flutter: interface usada pelo produtor.
- Servidor local: API HTTP e simulador da estufa.
- Banco PostgreSQL/Supabase: opcional durante testes locais.
- ESP32 real: opcional, quando o protótipo físico estiver disponível.

## Rodar o servidor com Docker

Na raiz do projeto:

```powershell
docker compose up --build
```

Com chave de acesso:

```powershell
$env:ESTUFA_API_TOKEN="teste-local-forte-aleatorio"
docker compose up --build
```

Com banco e chave:

```powershell
$env:ESTUFA_API_TOKEN="teste-local-forte-aleatorio"
$env:DATABASE_URL="postgresql://usuario:senha@host:5432/postgres"
docker compose up --build
```

Teste no PC:

```text
http://localhost:3000/status
```

Teste no celular, usando o IP do PC:

```text
http://192.168.1.11:3000/status
```

Se aparecer JSON, o servidor esta acessivel.

## Rodar o app no celular

Conecte o aparelho por USB ou depuração sem fio. Em outro terminal:

```powershell
cd estufa_app
flutter devices
flutter run -d ID_DO_APARELHO --dart-define=CLOUD_API_URL=https://estufa-server.onrender.com
```

O app não possui versão web. A porta `3000` continua sendo a API/JSON do
simulador local. A página `192.168.4.1` é servida pelo próprio ESP32 e configura
o aparelho; ela não é a versão web do app.

## Cadastrar a estufa no app

Para usar o simulador local:

```text
Nome: Estufa Principal
IP ou endereço: 192.168.1.11:3000
Chave de acesso: mesma chave do ESTUFA_API_TOKEN, se existir
```

Para usar o ESP32 real atual:

```text
Nome: ESP32
IP ou endereço: 192.168.1.21
Chave de acesso: deixar vazio enquanto o firmware nao tiver chave
```

## Como explicar no vídeo

1. O app Flutter roda no celular.
2. O servidor local roda no PC e simula o aparelho físico.
3. O app faz requisições HTTP para buscar temperatura, umidade e estado da estufa.
4. Quando o produtor altera um ajuste, o app envia um comando HTTP para o servidor ou ESP32.
5. A chave de acesso protege os comandos de controle.
6. O banco é opcional no teste local, mas será usado para guardar histórico e relatórios.
7. Quando o ESP32 real estiver pronto, ele responderá JSON parecido com o simulador, reduzindo mudanças no app.

## Problemas comuns

- Abrir `http://IP_DO_PC:3000/status` mostra JSON. Isso é esperado: é a API, não o app.
- Se o simulador não responder no celular, confirme que PC e celular estão na
  mesma rede Wi-Fi e que a porta `3000` está liberada no firewall.
- Se comandos falharem com chave inválida, confira se a chave cadastrada no app é igual ao `ESTUFA_API_TOKEN`.
- Se usar Docker, reinicie com `docker compose up --build` depois de alterar variáveis de ambiente.
