# Roadmap pre-APK

Este documento guarda o plano de trabalho antes de gerar uma versao APK de teste do Sentinela Smart.

## Objetivo atual

Chegar em uma versao estavel para demonstracao no celular, usando o simulador e tambem permitindo teste local com ESP32 via HTTP.

## Ordem de trabalho

### 1. Congelar a base atual

- Manter a branch atual como ponto seguro para testes com HTTP local.
- Evitar refatoracao grande antes do primeiro APK.
- Fazer commits pequenos e com nomes claros em ingles.

### 2. Revisao leve antes do APK

Verificar e corrigir somente problemas de baixo risco:

- Textos do app em portugues: acentos, termos e consistencia entre "ajuste", "estufa", "estufada" e "relatorio".
- Mensagens de erro para o produtor: simples, curtas e sem termos tecnicos desnecessarios.
- Codigo morto ou logs temporarios.
- Arquivos muito repetidos que possam ser limpos sem alterar comportamento.
- Validacoes de entrada: nome da estufa, IP/endereco, chave de acesso e limites de temperatura/umidade.
- Tratamento offline: nao travar tela quando servidor, simulador ou ESP32 estiver indisponivel.

### 3. Testes antes do APK

Guia de execução local e demonstração: docs/EXECUCAO_LOCAL.md.

Executar:

- `flutter analyze`
- `flutter test`
- `npm test` em `estufa_server`

Testar manualmente:

- Cadastro, edicao e remocao de estufas.
- Chave de acesso correta, incorreta e vazia.
- Leitura pelo simulador.
- Leitura pelo ESP32 local.
- Ajuste de temperatura e umidade.
- Inicio e fim de estufada.
- Relatorios, eventos e graficos.
- App em retrato e paisagem no celular.
- Offline e reconexao.

### 4. Gerar APK de teste

Depois da revisao leve:

- Gerar APK debug ou release de teste.
- Instalar no celular.
- Repetir os testes manuais principais.

### 5. Melhorias futuras

> Atualizado jul/2026. Vários itens que estavam aqui já foram entregues.

**Já feito** (saiu do "futuro"):

- Integracao completa com nuvem (deploy Render + Supabase, autenticado).
- Controle remoto fora da rede local (caixa de comandos nuvem→aparelho).
- mDNS (`sentinela-XXXXXX.local`) e id unico por aparelho.
- Retencao automatica de dados na nuvem.
- Refatoracao de arquivos grandes (split native/web do Isar; store de leitura).

**Ainda futuro:**

- **Notificacoes push (FCM)** — proximo item, ver `NOTIFICACOES_PUSH.md`.
- MQTT como opcao remota (hoje o transporte e HTTP).
- HTTPS no aparelho local / validacao de certificado no ESP.
- Modo de configuracao Wi-Fi por AP (`Sentinela-Config`).
- Controle de atuadores (ventoinha/rele) e agendamento — depende de hardware.
- Build de producao assinado para distribuicao (Play Store).

## Proximos blocos do projeto

### 1. App para APK de teste

Finalizar a revisao leve do app, gerar um APK de teste e validar no celular.

### 2. Simulador como ESP32 virtual

Deixar o simulador e o servidor o mais proximos possivel do comportamento do ESP32 real:

- mesmas rotas principais;
- JSON parecido com o do aparelho;
- leitura de temperatura e umidade;
- envio de ajustes;
- chave de acesso opcional para testes;
- comportamento offline/online parecido com o aparelho real.

Assim, quando o ESP32 fisico estiver disponivel, a adaptacao do firmware deve exigir poucas mudancas no app.

O modo "ESP32 virtual" (push HTTP via `POST /leitura`, com buffer offline
proprio) ja esta implementado. Detalhes e topologia: `docs/ESP32_VIRTUAL.md`.

### 3. Banco de dados

O banco deve guardar apenas informacoes uteis para relatorio, auditoria e sincronizacao. Evitar salvar leitura a cada segundo sem necessidade.

Detalhamento tecnico: `docs/PLANO_BANCO_DADOS.md`.

Itens planejados:

- Estufas cadastradas: nome, endereco/IP, modo de conexao, ultimo status conhecido e datas basicas.
- Estufadas: inicio, fim, status, ajustes iniciais e ajustes finais de temperatura/umidade.
- Leituras importantes: leituras periodicas em intervalo maior, por exemplo a cada 10 minutos, e leituras extras quando houver alarme, oscilacao ou mudanca de ajuste.
- Eventos da estufada: inicio, fim, ajuste alterado, alarme acionado, alarme normalizado, queda de conexao, reconexao e falha de leitura.
- Comandos pendentes: comandos criados quando app e aparelho nao estiverem sincronizados, usando a regra de que o ultimo comando valido vence.

O objetivo do banco nao e gravar tudo o tempo todo, mas manter um historico suficiente para explicar a estufada e gerar relatorio.

### 4. Servidor

Revisar o servidor para virar a ponte oficial da arquitetura:

- rotas organizadas;
- validacoes de payload;
- seguranca por chave de acesso;
- Docker;
- arquivo `.env.example`;
- documentacao de execucao;
- preparo para nuvem gratuita ou de baixo custo.
### 5. Configuracao de rede do ESP32

O ESP32 deve ter mais de uma forma de ser encontrado na rede local, porque em ambiente rural pode haver queda de energia, troca de roteador ou falta de acesso administrativo ao roteador.

Detalhamento tecnico: `docs/CONFIGURACAO_ESP32.md`.

Estratégia planejada:

- Preferencial: usar DHCP com reserva de IP no roteador, quando o produtor ou tecnico tiver acesso. Assim o roteador entrega sempre o mesmo IP para o MAC do ESP32 e evita conflito com outros aparelhos.
- Alternativa: se nao houver acesso ao roteador, permitir IP fixo alto configurado no proprio ESP32, por exemplo no final da faixa da rede, reduzindo a chance de conflito com dispositivos comuns.
- Facilitador: tentar anunciar um nome local por mDNS, como `sentinela.local`, para diminuir dependencia do numero do IP quando a rede suportar.
- Recuperacao: manter um modo de configuracao em que o ESP32 cria uma rede propria, como `Sentinela-Config`, permitindo ver IP atual, trocar Wi-Fi e alterar a chave de acesso sem reenviar codigo para o aparelho.

Essa abordagem evita depender de uma unica forma de conexao e combina com a proposta hibrida do projeto.
### 6. Frequencia de comunicacao e armazenamento

A comunicacao deve equilibrar resposta rapida no app com baixo consumo de rede, bateria e banco de dados.

Regras planejadas:

- App em primeiro plano na tela da estufa: consultar o aparelho com mais frequencia, por exemplo a cada 1 ou 2 segundos, para o produtor ver os dados quase em tempo real.
- App em primeiro plano na home: consultar de forma mais leve, por exemplo a cada 5 ou 10 segundos, apenas para atualizar estado online/offline e ultimos valores.
- App em segundo plano: evitar consulta constante. Preferir notificacoes via servidor/nuvem quando houver infraestrutura remota, ou polling bem espacado quando necessario.
- ESP32 para servidor/nuvem: enviar leitura periodica durante estufada, por exemplo a cada 10 minutos.
- ESP32 por evento: enviar imediatamente quando houver alerta, oscilacao relevante, falha de sensor, ajuste fisico, inicio/fim de estufada, queda ou retorno de conexao.
- Heartbeat: opcionalmente enviar um sinal leve de vida a cada 1 ou 2 minutos, sem gravar como leitura de relatorio.
- Banco de dados: salvar somente leituras relevantes para historico e relatorio, nao toda atualizacao visual exibida no app.

Separacao importante:

- Atualizacao da tela pode ser frequente.
- Armazenamento historico deve ser economico.
- Alertas criticos devem ser imediatos.
## Decisao tecnica atual

Para o TCC, a arquitetura segue hibrida:

- Local: app conversa direto com o ESP32 por HTTP na mesma rede Wi-Fi.
- Simulacao: app conversa com `estufa_server` para desenvolvimento e demonstracao.
- Nuvem: continua planejada para historico, sincronizacao e acesso remoto futuro.

## Cuidado principal

Como o app ja esta funcional, qualquer limpeza deve preservar comportamento. A prioridade agora e estabilidade para demonstracao, nao reescrever tudo.



