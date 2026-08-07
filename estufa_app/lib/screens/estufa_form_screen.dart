import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/aparelho/screens/configurar_aparelho_screen.dart';
import '../features/home/models/convite_estufa.dart';
import '../features/home/models/modelo_estufa.dart';
import '../features/home/services/atualizacao_estufa.dart';
import '../features/home/services/estufas_repository.dart';
import '../services/isar_service.dart';

/// O que o formulario fez, para quem o abriu poder anunciar a coisa certa.
///
/// Um convite de aparelho ja cadastrado entra por "Adicionar estufa" e termina
/// em atualizacao. Sem isto a home diria "Estufa cadastrada" depois de uma
/// atualizacao — contaria outra historia, e nenhuma estufa teria nascido.
enum ResultadoFormEstufa { cadastrada, atualizada }

class EstufaFormScreen extends StatefulWidget {
  final ModeloEstufa? estufa;

  /// Convite ja lido, para o formulario nascer preenchido.
  ///
  /// E o caminho do QR: quem aponta a camera nao passa por "Colar convite" —
  /// cai direto aqui, com os campos prontos. Mesmo destino, mesma tela e mesmo
  /// preenchimento do caminho de texto; muda so quem entrega o convite.
  final ConviteEstufa? convite;

  /// Injetavel pela mesma razao das outras costuras deste app: quem decide se
  /// uma chave e sobrescrita mora aqui, e com o banco de verdade no meio isso
  /// nunca seria conferido por teste nenhum.
  final EstufasRepository? repositorio;

  const EstufaFormScreen({
    super.key,
    this.estufa,
    this.convite,
    this.repositorio,
  });

  @override
  State<EstufaFormScreen> createState() => _EstufaFormScreenState();
}

class _EstufaFormScreenState extends State<EstufaFormScreen> {
  static const int _limiteNomeEstufa = 24;

  late final EstufasRepository _repository =
      widget.repositorio ?? EstufasRepository(IsarService.instance);

  /// Chave e endereco vieram de um convite, e nao da mao de quem digita.
  ///
  /// E o que separa "tenho autoridade para sobrescrever a chave desta estufa" de
  /// "isto e palpite": o convite vem de alguem que TEM a chave nova. Digitado a
  /// mao, a recusa de sempre continua valendo.
  bool _veioDeConvite = false;
  late final TextEditingController _nomeController;
  late final TextEditingController _ipController;
  late final TextEditingController _chaveController;
  late final TextEditingController _idHardwareController;

  bool _salvando = false;

  bool get _editando => widget.estufa != null;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.estufa?.nome ?? '');
    _ipController = TextEditingController(text: widget.estufa?.ip ?? '');
    _chaveController = TextEditingController(
      text: widget.estufa?.tokenAcesso ?? '',
    );
    _idHardwareController = TextEditingController(
      text: widget.estufa?.idHardware ?? '',
    );

    final convite = widget.convite;
    // Sem `setState`: ainda nao houve `build`, e os controladores acabaram de
    // nascer. O primeiro desenho ja sai preenchido.
    if (convite != null) _aplicarConvite(convite);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _ipController.dispose();
    _chaveController.dispose();
    _idHardwareController.dispose();
    super.dispose();
  }

  /// Outra estufa que ja e ESTE aparelho, ou que ja usa este endereco.
  ///
  /// Duas perguntas, porque uma so nao basta. O endereco e texto: o mesmo
  /// aparelho pode estar cadastrado como `192.168.0.50` num celular e como
  /// `sentinela-215788.local` noutro, e comparar texto nao acusa. O convite por
  /// QR tornou isso comum, porque o segundo celular recebe o endereco tal como o
  /// primeiro escreveu. Ja o `idHardware` e identidade de verdade — vem do MAC
  /// do chip e nao muda.
  ///
  /// A propria estufa em edicao nao conta.
  Future<({ModeloEstufa estufa, bool mesmoAparelho})?> _conflitoDeCadastro(
    String ip,
    String? idHardware,
  ) async {
    final estufas = await _repository.listar();
    final id = idHardware?.trim();
    for (final outra in estufas) {
      if (_editando && outra.id == widget.estufa!.id) continue;
      final outroId = outra.idHardware?.trim();
      if (id != null &&
          id.isNotEmpty &&
          outroId != null &&
          outroId.isNotEmpty &&
          outroId == id) {
        return (estufa: outra, mesmoAparelho: true);
      }
      if (outra.ip.trim().toLowerCase() == ip.toLowerCase()) {
        return (estufa: outra, mesmoAparelho: false);
      }
    }
    return null;
  }

  /// Oferece atualizar a estufa que ja existe, em vez de recusar o convite.
  ///
  /// **Nunca grava sozinho.** Sobrescrever a chave com uma errada tira o acesso
  /// do produtor ate ele ir fisicamente ate o aparelho, e nada na tela ligaria
  /// uma coisa a outra depois. Por isso a confirmacao diz QUAL estufa muda, O
  /// QUE muda, e o custo de aceitar por engano.
  Future<void> _oferecerAtualizacao(
    ModeloEstufa existente,
    String ip,
    String? chave,
    String? idHardware,
  ) async {
    final mudanca = AtualizacaoDeEstufa.entre(
      id: existente.id,
      nome: existente.nome,
      enderecoAtual: existente.ip,
      chaveAtual: existente.tokenAcesso,
      idHardwareAtual: existente.idHardware,
      enderecoNovo: ip,
      chaveNova: chave,
      idHardwareNovo: idHardware,
    );

    // Convite igual ao que ja esta gravado. Pedir confirmacao sobre coisa
    // nenhuma ensina a aceitar sem ler.
    if (mudanca == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não há o que atualizar: "${existente.nome}" já está com esta '
            'chave e este endereço.',
          ),
        ),
      );
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          // O nome, e nao "esta estufa": com duas cadastradas, sem ele nao ha
          // como saber em qual se esta prestes a mexer.
          'Atualizar "${existente.nome}"?',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          'Este convite traz ${mudanca.oQueMuda} deste aparelho.\n\n'
          'Se a chave estiver errada, a estufa para de responder até alguém ir '
          'até ele e configurar de novo.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            // Diz o que vai acontecer, nao "OK": quem le precisa poder recusar
            // sabendo o que estava prestes a ser gravado.
            child: Text('Atualizar ${mudanca.oQueMuda}'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _salvando = true);
    try {
      await mudanca.aplicar(_repository);
      if (!mounted) return;
      Navigator.of(context).pop(ResultadoFormEstufa.atualizada);
    } catch (erro, pilha) {
      if (!mounted) return;
      _mostrarFalha('Não foi possível atualizar a estufa.', erro, pilha);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _salvar() async {
    final nome = _nomeController.text.trim();
    final ip = _ipController.text.trim();
    final chaveTexto = _chaveController.text.trim();
    final chave = chaveTexto.isEmpty ? null : chaveTexto;
    final idHardwareTexto = _idHardwareController.text.trim();
    final idHardware = idHardwareTexto.isEmpty ? null : idHardwareTexto;

    if (nome.isEmpty || ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome e o endereço da estufa.')),
      );
      return;
    }

    if (!_enderecoValido(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Endereço inválido. Use algo como 192.168.1.9 ou 192.168.1.9:80.',
          ),
        ),
      );
      return;
    }

    // Duas estufas no mesmo endereco e a raiz de uma familia de confusoes: o
    // app aprende o id do aparelho a partir de quem atende no endereco, entao
    // enderecos repetidos fazem duas estufas virarem a mesma - e uma passa a
    // exibir a leitura da outra sem nada na tela sugerir isso. Barrar aqui e a
    // unica forma de impedir na origem.
    final conflito = await _conflitoDeCadastro(ip, idHardware);
    if (conflito != null) {
      if (!mounted) return;
      // Mesmo aparelho + convite = a chave girou la e alguem que a tem esta
      // passando adiante. Ai cabe ATUALIZAR, nao recusar: recusar era um beco
      // sem saida, porque nao havia outro caminho para a chave nova entrar.
      //
      // Digitado a mao, nao. Chave e endereco datilografados sao palpite, e nao
      // ha autoridade nenhuma para sobrescrever a chave de uma estufa que
      // funciona.
      if (conflito.mesmoAparelho && _veioDeConvite) {
        await _oferecerAtualizacao(conflito.estufa, ip, chave, idHardware);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // Mensagens diferentes porque os consertos sao diferentes: endereco
          // repetido se resolve trocando o endereco; aparelho repetido nao se
          // resolve — a estufa ja esta ai, com outro nome.
          content: Text(
            conflito.mesmoAparelho
                ? 'Este aparelho já está cadastrado como '
                      '"${conflito.estufa.nome}". Cadastrar de novo criaria '
                      'duas estufas mostrando o mesmo aparelho.'
                : 'A estufa "${conflito.estufa.nome}" já usa este endereço. '
                      'Duas estufas no mesmo endereço passam a mostrar os dados '
                      'do mesmo aparelho.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _salvando = true);

    try {
      if (_editando) {
        await _repository.atualizar(
          id: widget.estufa!.id,
          nome: nome,
          ip: ip,
          tokenAcesso: chave,
          idHardware: idHardware,
        );
      } else {
        await _repository.salvar(
          nome: nome,
          ip: ip,
          tokenAcesso: chave,
          idHardware: idHardware,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(
        _editando
            ? ResultadoFormEstufa.atualizada
            : ResultadoFormEstufa.cadastrada,
      );
    } catch (erro, pilha) {
      if (!mounted) return;
      _mostrarFalha('Não foi possível salvar a estufa.', erro, pilha);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Mostra a falha ao produtor E guarda a causa ao alcance de quem conserta.
  ///
  /// Antes o `catch` descartava a exceção e dizia só "não foi possível". Quando
  /// isso aconteceu de verdade, não havia o que investigar: nem no aparelho, nem
  /// no `logcat` — a causa tinha sido jogada fora dentro do próprio app. Um dia
  /// inteiro de depuração começou com essa linha faltando.
  ///
  /// A mensagem curta continua sendo o que o produtor lê. O detalhe fica atrás
  /// de "Detalhes", selecionável para poder ser copiado e mandado.
  void _mostrarFalha(String mensagem, Object erro, StackTrace pilha) {
    debugPrint('SENTINELA falha: $erro\n$pilha');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Detalhes',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              title: const Text(
                'O que deu errado',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: SelectableText(
                  '$erro\n\n$pilha',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Validacao leve do endereco: aceita IP, nome de host (inclusive mDNS como
  // "sentinela.local"), com ou sem "http://" e com porta opcional. Rejeita so o
  // que e claramente invalido (espacos, caracteres estranhos, porta fora da
  // faixa). O ApiService ainda normaliza, entao isso e so um aviso amigavel.
  bool _enderecoValido(String enderecoBruto) {
    var valor = enderecoBruto.trim();
    if (valor.isEmpty) return false;

    valor = valor.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    valor = valor.split('/').first; // ignora caminho apos o host
    if (valor.isEmpty || valor.contains(' ')) return false;

    final partes = valor.split(':');
    if (partes.length > 2) return false; // mais de um ":"

    final host = partes[0];
    if (!RegExp(r'^[a-zA-Z0-9.\-]+$').hasMatch(host)) return false;

    if (partes.length == 2) {
      final porta = int.tryParse(partes[1]);
      if (porta == null || porta < 1 || porta > 65535) return false;
    }
    return true;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0E1012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17191D),
        foregroundColor: Colors.white,
        title: Text(_editando ? 'Editar estufa' : 'Adicionar estufa'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _editando ? 'Editar estufa' : 'Adicionar estufa',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Só ao adicionar, não ao editar: é aqui que
                    // o iniciante chega na primeira vez. O aparelho novo ainda
                    // não está na rede, então antes de preencher o endereço
                    // abaixo ele configura o Wi-Fi do aparelho por aqui. Não dá
                    // para embutir num formulário só: configurar exige o celular
                    // na rede do aparelho (Sentinela-Config), e cadastrar exige
                    // o celular na rede da casa — redes diferentes, duas etapas.
                    if (!_editando) ...[
                      _buildAtalhoConfigurar(),
                      const SizedBox(height: 12),
                      // O segundo celular da casa: o aparelho ja esta na rede e
                      // configurado, e ele so precisa da chave. Sem este atalho
                      // o caminho existia, mas passava pelo formulario de
                      // configuracao inteiro — redigitando a rede e a senha do
                      // Wi-Fi para gravar por cima de algo que ja estava bom.
                      _buildAtalhoPegarAcesso(),
                      const SizedBox(height: 12),
                      // O segundo caminho para a mesma estufa: quem ja tem
                      // acesso delega, sem tocar no aparelho.
                      _buildAtalhoSimulador(),
                      const SizedBox(height: 22),
                    ],
                    _buildEntradaFlutter(),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _salvando
                              ? null
                              // Sem resultado, e nao `false`: a rota devolve
                              // ResultadoFormEstufa, e um bool aqui explodia na
                              // conversao DEPOIS de a rota ja estar marcada como
                              // fechada — a tela ficava presa, o voltar sumia, e
                              // todo pop seguinte falhava com "No element".
                              // Cancelar nao produziu resultado nenhum, entao o
                              // valor certo e a ausencia dele.
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        // Sem cor propria: usa o estilo padrao do tema, o mesmo
                        // do botao "Iniciar" da estufada (lilas, texto em caixa
                        // normal), para os botoes de acao nao destoarem.
                        FilledButton(
                          onPressed: _salvando ? null : _salvar,
                          child: Text(_salvando ? 'Salvando...' : 'Salvar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Abre a primeira configuracao e traz de volta o que ela definiu. Sem isto o
  /// produtor via o endereco numa tela e tinha de digita-lo na outra, de
  /// memoria — um nome como `sentinela-215788.local` erra facil.
  Future<void> _abrirConfiguracaoAparelho({
    UsoDaConfiguracao uso = UsoDaConfiguracao.cadastro,
  }) async {
    final dados = await Navigator.of(context).push<DadosAparelhoConfigurado>(
      MaterialPageRoute(
        builder: (_) => ConfigurarAparelhoScreen(uso: uso),
      ),
    );
    if (dados == null || !mounted) return;
    setState(() {
      if (dados.endereco != null) _ipController.text = dados.endereco!;
      if (dados.chave != null) _chaveController.text = dados.chave!;
      if (dados.idHardware != null) {
        _idHardwareController.text = dados.idHardware!;
      }
    });
  }


  /// Derrama o convite nos campos. Vale para os dois caminhos — o texto colado
  /// e o QR lido pela camera —, para nao existir a chance de um deles preencher
  /// um campo a menos que o outro.
  void _aplicarConvite(ConviteEstufa convite) {
    // Os dois caminhos do convite passam por aqui — o QR e o "Colar convite" —,
    // entao a marca de origem fica num lugar so. Se cada um marcasse por conta,
    // um deles acabaria oferecendo atualizar e o outro recusando, na mesma
    // situacao: a assimetria que ja aconteceu neste caminho antes.
    _veioDeConvite = true;
    // O nome e sugestao: cada um chama a estufa como quiser, e o app ja
    // respeita isso nas notificacoes.
    if (_nomeController.text.trim().isEmpty) {
      _nomeController.text = convite.nome;
    }
    _ipController.text = convite.endereco;
    if (convite.chave != null) _chaveController.text = convite.chave!;
    if (convite.idHardware != null) {
      _idHardwareController.text = convite.idHardware!;
    }
  }

  /// O simulador nao tem aparelho, e por isso nao tem como ensinar o proprio id.
  ///
  /// Era o unico motivo de o campo de id existir na vista normal: sem ele, quem
  /// perdesse a estufa do simulador nao teria como cadastra-la de novo. Um botao
  /// que preenche resolve o caso real sem cobrar do produtor decorar
  /// `ESP32_REALISTIC_V2`.
  Widget _buildAtalhoSimulador() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _usarSimulador,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(
          children: [
            Icon(Icons.science_outlined, color: Colors.white54, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Usar a estufa de demonstração',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Estufa de demonstração, sem aparelho nenhum. Serve '
                    'somente para apresentar o app.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 22),
          ],
        ),
      ),
    );
  }

  void _usarSimulador() {
    setState(() {
      if (_nomeController.text.trim().isEmpty) {
        _nomeController.text = 'Simulador';
      }
      // Endereco que nao resolve em rede nenhuma, de proposito: esta estufa vive
      // so na nuvem, e o app cai para NUVEM sozinho quando o local falha. O que
      // faz ela funcionar e o id, nao o endereco.
      _ipController.text = 'simulador';
      _idHardwareController.text = 'ESP32_REALISTIC_V2';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pronto. Toque em Salvar.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildAtalhoPegarAcesso() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => unawaited(
        _abrirConfiguracaoAparelho(uso: UsoDaConfiguracao.apenasAcesso),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.key_outlined,
              color: Colors.white54,
              size: 22,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aparelho já configurado: pegar acesso',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Para outro celular da casa. Vá até o aparelho, digite o PIN '
                    'do visor e ele passa a comandar. Nada muda no aparelho.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildAtalhoConfigurar() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => unawaited(_abrirConfiguracaoAparelho()),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            // Mesma engrenagem do "Configurar aparelho" no menu da estufa: e a
            // mesma tela, entao tem que ser o mesmo simbolo.
            const Icon(
              Icons.settings_outlined,
              color: Colors.white54,
              size: 22,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conectar o aparelho ao Wi-Fi',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Configure o Wi-Fi antes de adicionar a estufa. '
                    'O aparelho vai preencher o endereço abaixo.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntradaFlutter() {
    return Column(
      children: [
        _buildNomeField(),
        const SizedBox(height: 18),
        _buildIpField(),
        // Nem chave nem id aparecem aqui, e nao ha secao avancada escondendo os
        // dois. Nenhum e assunto de quem cadastra, e os tres caminhos de entrada
        // preenchem os dois sozinhos: o modo de configuracao le do aparelho, o
        // convite traz de quem ja tem, e o simulador nao precisa de chave.
        //
        // Campo visivel convida a preencher, e valor inventado faz o aparelho
        // recusar comando depois — longe desta tela, sem ligacao aparente.
        //
        // O id continua VISIVEL, so nao aqui: aparece nos detalhes da conexao da
        // estufa, que e onde se pergunta "de quem sao estes numeros?".
      ],
    );
  }





  Widget _buildNomeField() {
    return TextField(
      controller: _nomeController,
      textInputAction: TextInputAction.next,
      maxLength: _limiteNomeEstufa,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Nome (ex: Estufa 01)',
        helperText: 'Use até 24 caracteres.',
        helperStyle: TextStyle(color: Colors.white38),
        counterStyle: TextStyle(color: Colors.white38),
        labelStyle: TextStyle(color: Colors.white54),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
      ),
    );
  }

  Widget _buildIpField() {
    return TextField(
      controller: _ipController,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.url,
      textCapitalization: TextCapitalization.none,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'IP ou endereço',
        hintText: 'Ex: 192.168.1.11',
        hintStyle: TextStyle(color: Colors.white30),
        labelStyle: TextStyle(color: Colors.white54),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
      ),
    );
  }

}
