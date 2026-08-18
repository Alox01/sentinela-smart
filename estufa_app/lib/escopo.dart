/// O que o aplicativo mostra: tudo, ou só o que a proposta do TCC declarou.
///
/// ```
/// flutter build apk --release --dart-define=ESCOPO_TCC=true --dart-define=CLOUD_API_URL=...
/// ```
///
/// ## Por que existe, em vez de um repositório separado
///
/// Havia a ideia de manter um repositório reduzido para a apresentação. Dois
/// repositórios deixam de ser o mesmo sistema: todo defeito precisa ser
/// corrigido duas vezes, e — o que pesa mais — **as evidências de campo foram
/// produzidas por este código**. Os testes de 04 e 05/08, com o que falhou e o
/// que foi corrigido, aconteceram aqui. Um repositório reduzido não teria esse
/// histórico, e a seção de resultados passaria a descrever um sistema que aquele
/// repositório nunca foi.
///
/// Uma marca de build resolve o mesmo problema sem dividir nada: um código, um
/// conjunto de testes, um firmware. Escolhe-se na hora de gerar o APK.
///
/// ## O que sai, e por quê
///
/// **Só o compartilhar acesso por QR Code.** Nenhum dos cinco objetivos
/// declarados fala em delegar controle entre celulares — mas o motivo forte é
/// outro: ele **contradiz a explicação da autenticação**. A regra que se defende
/// é "para comandar, é preciso ter estado na frente do aparelho"; no instante em
/// que existe um QR que atravessa a cidade, ela deixa de valer sem exceção.
///
/// **"Tirar acesso dos outros celulares" FICA.** Ele exige os três botões e o
/// PIN, ou seja, presença física: é a outra metade da mesma regra, e não a
/// contradiz em nada. É também
/// a resposta para "e se o senhor vender o aparelho, ou alguém que não deveria
/// tiver acesso?" — sem ele, a pergunta ficaria sem resposta justamente na
/// versão apresentada.
///
/// Sai também o **agendamento de ajuste** — "às 14h deixe em 120 °F" é automação
/// de curva, e nenhum dos cinco objetivos declarados fala nisso: monitorar,
/// controlar, sincronizar, registrar e alertar. Some o item do menu, a
/// preferência de som do lembrete — um aviso que nunca toca não precisa de
/// interruptor — e o **serviço inteiro no `main.dart`**.
///
/// O serviço ficou de fora por último, e o motivo apareceu em campo: escondido
/// da interface mas ainda rodando, ele avisava "Ajuste não aplicado" na abertura
/// do app, sobre um agendamento antigo. A build apresentada notificando sobre
/// uma função que ela não tem é pior do que ter a função.
///
/// Sai também **a linha de diagnóstico da revogação** — aquela com o código HTTP
/// e a marca da chave. Ela é ferramenta de suporte, e numa apresentação vira
/// ruído técnico embaixo da única ação da tela. Quem depura usa o APK completo.
///
/// E o app deixa de **receber** convite por link: no escopo reduzido ele não
/// gera QR Code, e continuar ouvindo o esquema seria manter aberta uma porta que
/// esta versão não consegue abrir mas aceitaria que abrissem por ela.
///
/// Nada é apagado: no APK de desenvolvimento continua tudo lá.
const bool escopoTcc = bool.fromEnvironment('ESCOPO_TCC');
