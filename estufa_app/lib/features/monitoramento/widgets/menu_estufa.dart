import 'dart:async';

import 'package:flutter/material.dart';

import '../../notificacoes/models/preferencias_notificacao.dart';
import '../../notificacoes/services/preferencias_notificacao_service.dart';
import '../../notificacoes/services/push_notification_service.dart';
import '../../notificacoes/services/silenciamento_estufas.dart';
import 'itens_menu_estufa.dart';

/// A casca do menu (gaveta) da tela de monitoramento, com todos os seus itens.
///
/// ## Por que dois objetos em vez de treze parâmetros
///
/// O menu lia 5 valores da tela, chamava 3 métodos dela e ainda gerenciava
/// estufadas. Extraí-lo item a item dava um construtor com ~13 posições soltas,
/// onde trocar dois `String?` de lugar compila e só quebra em campo.
///
/// A saída escolhida foi **agrupar**: [DadosMenuEstufa] é o que o menu desenha,
/// [AcoesMenuEstufa] é o que ele pede de volta à tela. Sobram duas posições, e a
/// própria assinatura passa a dizer onde está o acoplamento — três callbacks, e
/// nenhum a mais.
///
/// A alternativa era deixar na tela os itens que mexem em estado e passá-los
/// prontos como `Widget`. Foi descartada por dois motivos:
///
/// 1. Os itens da gaveta ficariam divididos entre dois arquivos, e ninguém
///    lendo um deles veria o menu inteiro. O risco desta extração é justamente
///    **sumir um item sem ninguém notar** — a forma que esconde isso é a pior
///    das duas.
/// 2. O caso tido como claro (silenciar avisos) não mexe em estado da tela: ele
///    lê os *singletons* [SilenciamentoEstufas] e
///    [PreferenciasNotificacaoService] e chama um serviço, sem tocar em nenhum
///    campo do `State` nem chamar `setState`. Pelo mesmo motivo veio junto
///    "Apagar estufadas": também é função apenas dos valores acima.
///
/// O que ficou na tela ficou porque depende mesmo dela: os detalhes da conexão
/// (leem pendências e o `ApiService`), a reconfiguração do aparelho (grava a
/// estufa e volta para a lista) e o reinício de ajustes (abre diálogo e agenda
/// o envio com *debounce*).
class MenuEstufa extends StatelessWidget {
  final DadosMenuEstufa dados;
  final AcoesMenuEstufa acoes;

  const MenuEstufa({super.key, required this.dados, required this.acoes});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF17191D),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // Nome primeiro, rotulo embaixo — mesma ordem da barra do
                // monitoramento. O nome e o contexto (de qual estufa sao as
                // acoes); com "ACOES" em cima parecia que o nome pertencia a
                // uma secao chamada Acoes.
                children: [
                  Text(
                    dados.nomeEstufa,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'AÇÕES',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            const TituloMenu('CONEXÃO'),
            ListTile(
              leading: const Icon(
                Icons.info_outline_rounded,
                color: Colors.white70,
              ),
              title: const Text(
                'Detalhes da conexão',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(context).pop();
                acoes.aoAbrirDetalhesConexao();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.settings_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                // "Re-" porque aqui o aparelho JA esta configurado e
                // reportando: a primeira vez tem lugar proprio, no "Adicionar
                // estufa". E o prefixo avisa que se vai mexer no que funciona —
                // quem entrou por engano le a palavra e pensa duas vezes.
                'Reconfigurar aparelho',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                // A chave saiu: nao ha mais campo para ela em tela nenhuma do
                // app, e o aparelho a gera sozinho. Wi-Fi e endereco e o que
                // sobrou de verdade aqui.
                'Trocar o Wi-Fi ou o endereço na rede',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                acoes.aoConfigurarAparelho();
              },
            ),
            // Quem alcanca este aparelho, e como. Compartilhar e tirar acesso
            // moravam em AVISOS — posicao herdada da tela antiga, preservada
            // sem discussao quando a gaveta foi extraida. Nao e assunto de
            // aviso: os dois decidem QUEM COMANDA a estufa, que e do que esta
            // secao trata. E ficam juntos porque um desfaz o outro.
            // A outra metade de "so comanda quem esteve na frente do
            // aparelho": presenca fisica para dar o acesso ("pegar acesso", com
            // o PIN do visor) e presenca fisica para tirar. E a resposta para
            // "e se o senhor vender o aparelho?" — sem ela, a pergunta fica sem
            // resposta.
            //
            // Em CONEXAO, junto de "Reconfigurar aparelho": os dois decidem
            // quem comanda a estufa, o que nao e assunto de aviso. Ate agora a
            // revogacao existia so no formulario do navegador do aparelho,
            // atras de "avancado" — o caminho existia e era invisivel.
            ListTile(
              leading: const Icon(
                Icons.person_remove_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                'Tirar acesso dos outros celulares',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                // Sem o compartilhamento por QR Code na tela, citar o QR Code
                // aqui e falar de uma coisa que nao existe. O que sobra e o que
                // sempre foi verdade nos dois escopos: todo celular que tinha
                // acesso perde, independente de como o conseguiu.
                'Gera uma chave nova no aparelho. Todos os outros '
                    'celulares perdem o controle',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                acoes.aoTirarAcessoDosOutros();
              },
            ),
            // Secao propria: silenciar aviso nao e assunto de conexao, e ficava
            // solto no fim daquela lista.
            const Divider(color: Colors.white12, height: 1),
            const TituloMenu('AVISOS'),
            _ItemSilenciarAvisos(
              idHardware: dados.idHardware,
              tokenAcesso: dados.tokenAcesso,
            ),
            ItemVigilancia(
              vigiada: dados.vigiada,
              semIdHardware: (dados.idHardware?.trim() ?? '').isEmpty,
            ),
            ItemSireneDoAparelho(ativa: dados.buzzerAparelhoAtivo),
            // A secao ACOES RAPIDAS saiu desta versao: agendar ajuste,
            // reiniciar ajustes e apagar estufadas. O agendamento nao esta
            // em nenhum dos cinco objetivos; reiniciar ajustes e atalho para
            // o + e o - da tela principal; e apagar estufadas ja existe na
            // propria tela de relatorios, na lixeira da barra. Nenhuma
            // capacidade se perde - uma porta a menos, so.
          ],
        ),
      ),
    );
  }
}

/// O que o menu desenha. Só valores — nada aqui chama de volta a tela.
class DadosMenuEstufa {
  final int idEstufa;
  final String nomeEstufa;
  final String ipEstufa;
  final String? tokenAcesso;

  /// Já resolvido pela tela (`widget.idHardware ?? api.idHardware`): o menu não
  /// conhece o `ApiService`, e a estufa pode ter sido cadastrada sem o id, que
  /// só aparece depois da primeira conversa na rede local.
  final String? idHardware;

  /// Ajustes em vigor, que a tela de agendamento usa como ponto de partida.
  final double temperaturaAjuste;
  final double umidadeAjuste;

  /// Estado da sirene como o aparelho reporta. `null` = ainda não informou.
  final bool? buzzerAparelhoAtivo;

  /// Se este celular está inscrito para os avisos desta estufa. `null` = ainda
  /// conferindo. Vem pronto da tela em vez de ser lido aqui do
  /// [PushNotificationService] só para a leitura acontecer no mesmo instante
  /// que acontecia antes da extração — a gaveta constrói o corpo quando abre,
  /// não quando a tela desenha.
  final bool? vigiada;

  /// Os valores para os quais "Reiniciar ajustes" volta o aparelho. Ficaram na
  /// tela, que é quem manda o comando; aqui só aparecem na legenda do item.
  final double temperaturaNovaEstufada;
  final double umidadeNovaEstufada;

  const DadosMenuEstufa({
    required this.idEstufa,
    required this.nomeEstufa,
    required this.ipEstufa,
    required this.tokenAcesso,
    required this.idHardware,
    required this.temperaturaAjuste,
    required this.umidadeAjuste,
    required this.buzzerAparelhoAtivo,
    required this.vigiada,
    required this.temperaturaNovaEstufada,
    required this.umidadeNovaEstufada,
  });
}

/// O que o menu pede de volta à tela — e só o que ela realmente precisa fazer.
class AcoesMenuEstufa {
  /// Abre o diálogo de detalhes: depende do `ApiService` e das pendências.
  final VoidCallback aoAbrirDetalhesConexao;

  /// Reconfigura o aparelho e grava a estufa com o endereço/chave novos.
  final VoidCallback aoConfigurarAparelho;

  /// Troca a chave do aparelho: os celulares que receberam o QR antigo perdem
  /// o controle, e este continua.
  final VoidCallback aoTirarAcessoDosOutros;

  /// Confirma e devolve temperatura e umidade aos valores de nova estufada.
  final VoidCallback aoReiniciarAjustes;

  const AcoesMenuEstufa({
    required this.aoAbrirDetalhesConexao,
    required this.aoConfigurarAparelho,
    required this.aoTirarAcessoDosOutros,
    required this.aoReiniciarAjustes,
  });
}

/// Silenciar os avisos do app SO desta estufa (fogo e sem comunicacao nunca
/// calam). Escopo por aparelho, diferente das preferencias globais da home.
class _ItemSilenciarAvisos extends StatelessWidget {
  final String? idHardware;
  final String? tokenAcesso;

  const _ItemSilenciarAvisos({
    required this.idHardware,
    required this.tokenAcesso,
  });

  @override
  Widget build(BuildContext context) {
    final idHw = idHardware;
    return AnimatedBuilder(
      // Escuta tambem as preferencias globais: elas mandam no que este
      // interruptor pode prometer, entao a legenda tem que acompanhar.
      animation: Listenable.merge([
        SilenciamentoEstufas.instance,
        PreferenciasNotificacaoService.instance,
      ]),
      builder: (context, _) {
        final silenciada = SilenciamentoEstufas.instance.silenciada(idHw);
        return SwitchListTile(
          // Icone e interruptor acompanham o TITULO, nao o centro do item. A
          // legenda muda de tamanho conforme as configuracoes gerais, e sem
          // isto o sino afundava justamente nos casos de texto mais longo.
          isThreeLine: true,
          secondary: Icon(
            silenciada
                ? Icons.notifications_off_outlined
                : Icons.notifications_active_outlined,
            color: Colors.white70,
          ),
          // Curto como os vizinhos: o cabecalho do menu ja diz de qual estufa
          // sao estas acoes, e a secao acima ja diz que sao avisos.
          title: const Text(
            'Silenciar avisos',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            idHw == null
                ? 'Conecte o aparelho uma vez para poder silenciar.'
                : _legenda(),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          value: silenciada,
          onChanged: idHw == null ? null : (v) => unawaited(_silenciar(idHw, v)),
        );
      },
    );
  }

  /// A promessa de que incendio e sem comunicacao continuam avisando so vale se
  /// eles estiverem ligados nas configuracoes gerais - o silenciamento por
  /// estufa nunca LIGA um aviso que o produtor desligou no global, so desliga os
  /// demais. Quando o global ja desligou um deles, a legenda diz isso em vez de
  /// prometer um aviso que nao vira.
  String _legenda() {
    final prefs = PreferenciasNotificacaoService.instance.preferencias;
    // Os dois avisos de risco de fogo (chama no sensor e temperatura acima do
    // limite) contam como um so aqui: a legenda diz o que o produtor precisa
    // saber - se sobra algum aviso de fogo -, sem virar uma lista.
    final fogo =
        prefs.opcao(EventoNotificacao.incendio).notificar ||
        prefs.opcao(EventoNotificacao.temperaturaMuitoAlta).notificar;
    final semComunicacao = prefs
        .opcao(EventoNotificacao.semComunicacao)
        .notificar;

    if (fogo && semComunicacao) {
      return 'Incêndio e sem comunicação continuam avisando.';
    }
    if (!fogo && !semComunicacao) return 'Nada será avisado.';
    return fogo
        ? 'Só incêndio continua avisando.'
        : 'Só sem comunicação continua avisando.';
  }

  Future<void> _silenciar(String idHardware, bool silenciar) async {
    await SilenciamentoEstufas.instance.definir(idHardware, silenciar);
    // Reenvia as preferencias deste aparelho: o servidor passa a suprimir (ou
    // liberar) os avisos nao-criticos so desta estufa.
    await PushNotificationService.instance.atualizarPreferenciasDispositivo(
      idHardware: idHardware,
      tokenAcesso: tokenAcesso,
    );
  }
}

