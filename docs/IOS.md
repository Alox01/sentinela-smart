# iOS — o que falta para o app rodar num iPhone

Escrito em 04/08/2026, quando o iOS virou alvo declarado junto com o Android.

**Nada aqui foi executado.** Não há Mac neste projeto, então o que está no
repositório é configuração escrita à mão e conferida por leitura. Trate como
ponto de partida verificado, não como "funciona".

## O que já está feito no repositório

| Item | Onde | Por que importa |
|---|---|---|
| Permissão de rede local | `ios/Runner/Info.plist` → `NSLocalNetworkUsageDescription` | **A mais importante.** Sem ela o iOS 14+ bloqueia a rede local inteira: `sentinela-xxxxxx.local` não resolve e nem o IP direto responde. O app continua funcionando pela nuvem, e a metade edge-first morre em silêncio |
| Serviço Bonjour | `Info.plist` → `NSBonjourServices` = `_http._tcp` | O iOS só procura o que está declarado. É o serviço que o firmware anuncia |
| Esquema do convite | `Info.plist` → `CFBundleURLTypes` = `sentinela` | A câmera do iPhone lê `sentinela://convite?c=...`. Sem isto o QR não abre nada — e o convite escrito foi removido, então compartilhar ficaria **sem nenhum caminho** |
| Push em segundo plano | `Info.plist` → `UIBackgroundModes` = `remote-notification` | Alarme com o app fechado |
| Identificador | `project.pbxproj` → `br.com.sentinelasmart.estufa` | Era `com.example.estufaApp`. A Apple **recusa** `com.example.*`, e o id agora é o mesmo do Android |
| Nome exibido | `Info.plist` → `Sentinela Smart` | Era "Estufa App" |

**Nenhuma dessas faltas dá erro de compilação.** O app compilaria, instalaria,
abriria — e simplesmente não acharia o aparelho nem receberia convite, sem nada
na tela dizendo por quê. Foi por isso que foram feitas agora, com o assunto
fresco, em vez de na primeira tentativa de build.

## O que ainda falta, e só pode ser feito com um Mac

1. **`GoogleService-Info.plist`** — console do Firebase, projeto que já existe
   (o do Android), botão "adicionar app iOS" com o identificador acima. O arquivo
   vai em `ios/Runner/` **e precisa ser adicionado ao alvo Runner pelo Xcode** —
   copiar para a pasta não basta, o Xcode não o inclui sozinho. Está no
   `.gitignore`, como o `google-services.json`.
2. **Certificado APNs** — push no iOS não passa direto pelo FCM. É preciso subir
   a chave APNs (`.p8`) da conta de desenvolvedor no console do Firebase, senão
   a notificação nunca chega, sem erro visível.
3. **`pod install`** — o `Podfile` nem existe ainda; o Flutter o gera no primeiro
   `flutter build ios`. Só roda em macOS.
4. **Assinatura.** Para instalar num iPhone de verdade:
   - **Apple ID grátis** — dá para instalar pelo Xcode no seu próprio aparelho,
     mas o app **expira em 7 dias** e precisa ser reinstalado. Serve para provar
     que funciona, não para deixar com alguém.
   - **Conta paga (US$ 99/ano)** — validade de 1 ano e TestFlight, que é como se
     manda para o celular de outra pessoa sem cabo.

## Sobre "máquina virtual de macOS"

Funciona tecnicamente e **viola o contrato de licença da Apple**, que só permite
macOS em hardware Apple. Além disso costuma quebrar exatamente na parte que
interessa: Xcode, simulador e assinatura de código são os primeiros a falhar numa
VM, e o erro raramente diz que a causa é essa. É decisão de quem faz — mas, para
um TCC com prazo, é o caminho com mais chance de consumir dias e não entregar
APP nenhum.

Alternativas legítimas, se o objetivo é só **gerar e instalar**:

- **Codemagic** — CI com macOS, tem plano gratuito, feito para Flutter. É o
  caminho mais curto: conecta o repositório e ele compila.
- **GitHub Actions** com `runs-on: macos-latest` — grátis para repositório
  público, e o repositório já está no GitHub.
- **MacinCloud / MacStadium** — aluguel de Mac por hora ou por mês.

Nos três casos, **instalar no iPhone ainda exige assinatura** (item 4). Compilar
é o problema fácil; assinar é o que custa.

## Ordem sugerida, se for encarar

1. Firebase iOS + `GoogleService-Info.plist` (dá para fazer do Windows, é web).
2. Codemagic compilando o projeto — prova que o código é portável.
3. Só então decidir sobre conta paga, que é a única parte que custa dinheiro.

**Para o TCC:** o honesto é escrever que a arquitetura é multiplataforma e que o
iOS está previsto e configurado, **sem afirmar que foi testado**. A banca pode
perguntar; a resposta "está configurado, faltou o hardware Apple para validar" é
melhor que uma afirmação que não se sustenta.
