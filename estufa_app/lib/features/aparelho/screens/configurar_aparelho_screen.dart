import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../services/api_service.dart';
import '../prefixo_da_rede.dart';

/// Configura a rede e o acesso ao aparelho pelo aplicativo.
///
/// A chave é gerada pelo controlador e obtida pela rota de identidade. Versões
/// antigas do firmware devem ser configuradas pelo portal em `192.168.4.1`.
enum UsoDaConfiguracao {
  /// Estufa nova: leva endereco e chave para o formulario de cadastro.
  cadastro,

  /// Estufa ja cadastrada: se a chave mudou, a guardada no app ficou velha e os
  /// comandos passariam a ser recusados. Oferece atualizar.
  atualizacao,

  /// Autoriza outro celular por presença física e PIN, sem alterar a rede.
  apenasAcesso,

  /// Revoga acessos anteriores pela geração de uma nova chave no aparelho.
  revogacao,
}

class ConfigurarAparelhoScreen extends StatefulWidget {
  /// Nulo quando a tela e aberta solta: nada e oferecido no fim.
  final UsoDaConfiguracao? uso;

  const ConfigurarAparelhoScreen({super.key, this.uso});

  @override
  State<ConfigurarAparelhoScreen> createState() =>
      _ConfigurarAparelhoScreenState();
}

/// O que a configuracao acabou de definir, para o cadastro nao pedir de novo.
/// A chave sai daqui em memoria, direto para o formulario - nao e persistida
/// nem exibida em lugar nenhum pelo caminho.
class DadosAparelhoConfigurado {
  final String? endereco;
  final String? chave;

  /// Identificador do aparelho, lido dele mesmo. Vai junto para a estufa nascer
  /// ja sabendo de qual aparelho e - sem isto ela ficava "SEM ID" ate conseguir
  /// uma primeira conexao local, e ate la nao lia nada pela nuvem.
  final String? idHardware;

  const DadosAparelhoConfigurado({this.endereco, this.chave, this.idHardware});
}

class _ConfigurarAparelhoScreenState extends State<ConfigurarAparelhoScreen> {
  // Endereco fixo do ponto de acesso do ESP32 (padrao do softAP).
  static const String _enderecoAparelho = 'http://192.168.4.1';

  final _rede = TextEditingController();
  final _senha = TextEditingController();

  /// Chave lida do proprio aparelho. Nunca exibida: existe so para seguir ao
  /// cadastro. Nula quando o firmware e anterior a 1.20.0.
  String? _chaveDoAparelho;
  String? _idDoAparelho;

  /// Faixa da rede da casa (ex.: "192.168.0."), aprendida pelo aparelho.
  String? _prefixoDaRede;

  /// Gateway da ultima rede em que o aparelho entrou. So vale para ela — ver
  /// `prefixo_da_rede.dart`.
  String? _gatewayAprendido;
  final _pin = TextEditingController();

  /// PINs recusados nesta sessão, usados para evitar novas tentativas inválidas.
  final Set<String> _pinsQueFalharam = {};

  /// PIN associado à mensagem de erro exibida.
  String? _pinDoErro;
  String? _pinTentado;
  String? _erroPin;

  /// Informa o que será alterado em cada modo de configuração.
  Widget _cartaoPegarAcesso() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pronto para usar neste celular',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Este celular vai passar a comandar o aparelho também.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          SizedBox(height: 8),
          // Este modo não reinicia o aparelho; a saída exige manter o botão por 2 s.
          Text(
            'Depois de tocar o botão abaixo, o aparelho continua no modo de '
            'configuração: segure qualquer botão por 2 segundos para ele voltar '
            'ao normal (ou espere 5 minutos).',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// As 5 tentativas acabaram. O aparelho reinicia e sai do modo de
  /// configuracao, entao nao ha mais nada a fazer nesta tela sem voltar ate ele.
  bool _pinBloqueado = false;

  /// Indica firmware sem suporte à rota de identidade.
  bool _firmwareSemIdentidade = false;

  /// O aparelho se apresentou e entregou a chave. So entao ha o que preencher:
  /// o endereco, a chave e a faixa da rede vem dele. Firmware antigo NAO conta —
  /// ele nao entrega chave, e esta tela nao tem mais como obtê-la.
  bool get _aparelhoRespondeu => _chaveDoAparelho != null;
  Timer? _tentativas;
  bool _senhaVisivel = false;
  bool _conferindo = false;
  bool? _alcancou;
  final _ip = TextEditingController();

  bool _enviando = false;
  String? _erro;
  bool _concluido = false;

  /// Mantém o resultado disponível após o retorno da tela de sucesso.
  bool _jaGravou = false;
  // Nome local do aparelho (ex.: sentinela-a1b2c3.local). E o endereco que o
  // produtor cadastra na estufa, e ate a versao 1.10 do firmware ele so
  // aparecia no Monitor Serial - inutil para quem nao tem a IDE do Arduino.
  String? _nomeLocal;

  /// Rede atual, reenviada durante a revogação para preservar a configuração.
  String? _ssidDoAparelho;

  bool get _revogando => widget.uso == UsoDaConfiguracao.revogacao;

  /// So pegar a chave: nada e gravado no aparelho.
  bool get _apenasAcesso => widget.uso == UsoDaConfiguracao.apenasAcesso;

  /// A revogacao aconteceu no aparelho, mas o app nao recebeu a chave nova.
  /// Firmware antigo. Os comandos deste celular tambem param — e preciso dizer.
  bool _revogouSemChave = false;

  Map<String, dynamic>? _lerJson(String corpo) {
    try {
      final decodificado = jsonDecode(corpo);
      return decodificado is Map<String, dynamic> ? decodificado : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    // Repete a consulta enquanto o celular ainda está entrando na rede do aparelho.
    unawaited(_lerNomeDoAparelho());
    _tentativas = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_concluido || _chaveDoAparelho != null) return;
      unawaited(_lerNomeDoAparelho());
    });
    _rede.addListener(_aoTrocarDeRede);
  }

  /// Reutiliza a faixa aprendida somente quando a rede doméstica não mudou.
  bool get _prefixoAindaVale =>
      prefixoOferecido(
        gatewayAprendido: _gatewayAprendido,
        ssidDoAparelho: _ssidDoAparelho,
        ssidDigitado: _rede.text,
      ) !=
      null;

  /// Recolhe o prefixo pre-preenchido quando o produtor digita outra rede, e o
  /// reoferece se ele voltar para a de origem.
  void _aoTrocarDeRede() {
    final prefixo = _prefixoDaRede;
    if (prefixo == null) return;

    final vale = _prefixoAindaVale;
    final texto = _ip.text.trim();
    // So mexe no campo enquanto ele for o palpite intocado: numero completado a
    // mao e decisao do produtor, e apagar seria desfazer o trabalho dele.
    if (!vale && texto == prefixo) {
      setState(_ip.clear);
      return;
    }
    if (vale && texto.isEmpty) {
      setState(() {
        _ip.text = prefixo;
        _ip.selection = TextSelection.collapsed(offset: _ip.text.length);
      });
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tentativas?.cancel();
    _pin.dispose();
    _rede.dispose();
    _senha.dispose();
    _ip.dispose();
    super.dispose();
  }

  /// Silencioso de proposito: se o celular ainda nao estiver na rede do
  /// aparelho, o formulario continua utilizavel e o erro aparece so quando ele
  /// tentar salvar, que e quando importa.
  Future<void> _lerNomeDoAparelho() async {
    try {
      final resposta = await http
          .get(Uri.parse('$_enderecoAparelho/dados'))
          .timeout(const Duration(seconds: 5));
      if (mounted && resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);
        final nome = dados is Map ? dados['nomeLocal']?.toString() : null;
        if (nome != null && nome.isNotEmpty) {
          setState(() => _nomeLocal = ApiService.completarNomeMdns(nome));
        }
      }
    } catch (_) {
      // Sem rede do aparelho ainda: nada a mostrar, e nada a avisar.
    }
    // Fora do try de proposito: as duas leituras sao independentes, e a do nome
    // falhando nao pode impedir a da identidade - que e a que traz a chave.
    await _lerIdentidadeDoAparelho();
  }

  /// Obtém a identidade e a chave do aparelho enquanto ele está em configuração.
  ///
  /// [pedidoDoProdutor] distingue uma ação manual da repetição automática.
  Future<void> _lerIdentidadeDoAparelho({bool pedidoDoProdutor = false}) async {
    final pin = _pin.text.trim();
    // Sem os 4 digitos nao ha o que pedir: o aparelho recusa, e insistir so
    // gastaria as tentativas dele.
    if (pin.length != 4) return;
    // Bloqueado: o aparelho reiniciou e nao esta mais ouvindo. Insistir so
    // produziria "nao achei o aparelho", que manda conferir a coisa errada.
    if (_pinBloqueado) return;
    // Não reenvia PINs recusados durante as consultas automáticas.
    if (_pinsQueFalharam.contains(pin)) {
      // So responde a quem apertou. Vindo do relogio, fica calado: a contagem
      // de tentativas ja esta na tela e e ela que interessa.
      // E o mesmo PIN que acabou de falhar? A mensagem na tela ja e sobre ele, e
      // ela diz quantas tentativas sobraram - informacao melhor. So avisa quando
      // o produtor volta a um PIN errado ANTERIOR, que e quando ele nao tem como
      // saber que ja tentou aquele.
      if (pedidoDoProdutor && mounted && pin != _pinDoErro) {
        setState(() {
          _erroPin = 'Este PIN já falhou. Confira o número no visor.';
          _pinDoErro = pin;
        });
      }
      return;
    }
    if (pin == _pinTentado) return;
    _pinTentado = pin;
    try {
      final resposta = await http
          .get(Uri.parse('$_enderecoAparelho/config/identidade?pin=$pin'))
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (resposta.statusCode == 403) {
        final corpo = jsonDecode(resposta.body);
        final restantes = corpo is Map ? corpo['restantes'] : null;
        setState(() {
          _pinsQueFalharam.add(pin);
          _pinDoErro = pin;
          // Bloqueado nao e "errei de novo": o aparelho sai do modo de
          // configuracao e some da rede, entao continuar digitando ali nao leva
          // a lugar nenhum. Vira estado proprio, com cartao proprio - so a
          // legenda embaixo do campo passava batido, e o produtor ficava
          // tentando contra um aparelho que ja tinha ido embora.
          _pinBloqueado = restantes == 0;
          // "restam N" e nao "(N tentativas)": entre parenteses lia como
          // quantas ja foram gastas, que e o contrario.
          _erroPin = restantes == 0
              ? 'PIN bloqueado.'
              : restantes is int
              ? 'PIN não confere. Confira o número no visor do aparelho — '
                    'restam $restantes ${restantes == 1 ? 'tentativa' : 'tentativas'}.'
              : 'PIN não confere. Confira o número no visor do aparelho.';
        });
        return;
      }
      if (resposta.statusCode != 200) {
        _marcarFirmwareAntigoSePreciso();
        return;
      }
      // Deu certo: o teclado sai de cena. Ficar aberto sobre uma tela que ja
      // seguiu adiante faz parecer que ainda falta digitar algo.
      FocusManager.instance.primaryFocus?.unfocus();
      if (_erroPin != null) setState(() => _erroPin = null);
      final dados = jsonDecode(resposta.body);
      if (dados is! Map) return;
      final chave = dados['chave']?.toString();
      final nome = dados['nomeLocal']?.toString();
      final id = dados['idHardware']?.toString();
      final gateway = dados['gatewayAprendido']?.toString();
      final ssid = dados['wifiSsid']?.toString();
      if (chave == null || chave.isEmpty) return;
      setState(() {
        _chaveDoAparelho = chave;
        if (id != null && id.isNotEmpty) _idDoAparelho = id;
        if (nome != null && nome.isNotEmpty) {
          _nomeLocal = ApiService.completarNomeMdns(nome);
        }
        if (ssid != null && ssid.isNotEmpty) _ssidDoAparelho = ssid;
        _gatewayAprendido = gateway;
        _prefixoDaRede = _prefixoDe(gateway);
        // Deixa o campo quase pronto: falta so o ultimo numero. O celular esta
        // na rede do aparelho agora e nao teria como descobrir a faixa da casa;
        // quem sabe e o aparelho, que ja esteve nela.
        //
        // So quando a rede digitada e a mesma de onde ele aprendeu: em outra
        // rede esse prefixo e um numero de outro lugar. Enquanto nada foi
        // digitado o campo fica vazio, e `_aoTrocarDeRede` oferece o prefixo
        // assim que o nome bater.
        if (_prefixoDaRede != null &&
            _prefixoAindaVale &&
            _ip.text.trim().isEmpty) {
          _ip.text = _prefixoDaRede!;
          _ip.selection = TextSelection.collapsed(offset: _ip.text.length);
        }
      });
    } catch (_) {
      // Falhas de rede não consomem uma tentativa de PIN no aparelho.
      _pinTentado = null;
      _marcarFirmwareAntigoSePreciso();
    }
  }

  /// Identifica firmware incompatível após confirmar a comunicação com o aparelho.
  void _marcarFirmwareAntigoSePreciso() {
    if (!mounted || _nomeLocal == null || _erroPin != null) return;
    if (_firmwareSemIdentidade) return;
    setState(() => _firmwareSemIdentidade = true);
  }

  /// Verifica o endereço após o retorno do aparelho à rede doméstica.
  ///
  /// A primeira falha solicita confirmação; uma nova tentativa permite continuar.
  Future<void> _confirmarEUsar() async {
    // Na revogação, devolve a nova chave sem exigir uma sonda de alcance.
    if (_alcancou == null && !_revogando && !_apenasAcesso) {
      await _conferirAlcance();
      if (!mounted || _alcancou == false) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      DadosAparelhoConfigurado(
        endereco: _nomeLocal,
        chave: _chaveDoAparelho,
        idHardware: _idDoAparelho,
      ),
    );
  }

  Future<void> _conferirAlcance() async {
    final nome = _nomeLocal;
    if (nome == null || nome.isEmpty) return;
    setState(() {
      _conferindo = true;
      _alcancou = null;
    });
    var ok = false;
    for (final porta in const ['3000', '80']) {
      try {
        final resposta = await http
            .get(Uri.parse('http://$nome:$porta/status'))
            .timeout(const Duration(seconds: 5));
        if (resposta.statusCode == 200) {
          ok = true;
          break;
        }
      } catch (_) {
        // Tenta a proxima porta.
      }
    }
    if (!mounted) return;
    setState(() {
      _conferindo = false;
      _alcancou = ok;
    });
  }

  /// "192.168.0.1" -> "192.168.0.". Nulo quando nao parece um IPv4.
  static String? _prefixoDe(String? ip) => prefixoDe(ip);

  /// O campo pre-preenchido vale como vazio ate ganhar o ultimo numero: mandar
  /// so a faixa seria um endereco invalido, e o aparelho cairia no DHCP sem o
  /// produtor entender por que.
  String get _ipFixoInformado {
    final texto = _ip.text.trim();
    if (texto.isEmpty || texto.endsWith('.')) return '';
    return texto;
  }

  /// Confirma explicitamente o uso de uma rede sem senha.
  Future<bool> _confirmarRedeSemSenha() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'A rede não tem senha?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Você deixou a senha em branco, então o aparelho vai entrar na rede '
          '"${_rede.text.trim()}" sem senha nenhuma. '
          'Se a rede tiver senha, ele não vai conseguir conectar e a estufa '
          'vai ficar sem sinal.',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar e digitar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('É aberta, salvar'),
          ),
        ],
      ),
    );
    return confirmou ?? false;
  }

  Future<void> _salvar() async {
    // Na revogacao a rede nao e digitada: e a mesma em que o aparelho ja esta,
    // reenviada igual. So a chave muda.
    final rede = _revogando ? (_ssidDoAparelho ?? '') : _rede.text.trim();
    if (rede.isEmpty) {
      setState(() {
        _erro = _revogando
            ? 'O aparelho não informou em qual rede está. Saia e entre de novo '
                  'no modo de configuração.'
            : 'Informe o nome da rede Wi-Fi.';
      });
      return;
    }
    // Senha em branco agora significa "esta rede nao tem senha", e o aparelho
    // grava vazio DE PROPOSITO (semsenha=1). Numa rede com senha isso o deixa
    // sem conseguir entrar - ele some da nuvem e a estufa fica SEM SINAL, sem
    // nada na tela ligando uma coisa a outra. Ja aconteceu, no primeiro dia em
    // que a marca existiu. Entao pergunta antes, uma vez.
    // A pergunta da rede aberta so faz sentido para quem esta escolhendo a rede.
    // Na revogacao a senha vai vazia de proposito, o que MANTEM a atual.
    if (!_revogando && _senha.text.isEmpty && !await _confirmarRedeSemSenha()) {
      return;
    }
    // Senha vazia é aceita somente após a confirmação de rede aberta.

    setState(() {
      _enviando = true;
      _erro = null;
    });

    try {
      final resposta = await http
          .post(
            Uri.parse('$_enderecoAparelho/salvar'),
            // O aparelho le os campos com server.arg(), que espera formulario.
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              // O aparelho passou a exigir o PIN tambem para GRAVAR, e nao so
              // para entregar a chave. E o mesmo numero que ja esta digitado na
              // tela: quem chegou ate aqui ja acertou uma vez.
              'pin': _pin.text.trim(),
              'ssid': rede,
              // A rotacao, e o pedido para o aparelho responder em JSON com a
              // chave nova. Ele reinicia logo depois de gravar: nao ha segunda
              // chance de ler, e sem isto trocar a chave exigiria voltar ate a
              // estufa e refazer tudo.
              if (_revogando) ...{'novachave': '1', 'formato': 'json'},
              'senha': _senha.text,
              // Campo vazio quer dizer rede aberta, e e o que a legenda promete
              // — mas para o aparelho vazio sempre significou "mantenha a senha
              // que voce ja tem". Numa rede sem senha ele guardaria a antiga e
              // nao conectaria. Esta marca (firmware 1.25.0) diz a diferenca; em
              // firmware anterior ela e ignorada e o caso raro volta a falhar.
              // Rede aberta so quando o produtor escolheu a rede. Na revogacao
              // vazio quer dizer "mantenha a senha que voce tem".
              if (!_revogando && _senha.text.isEmpty) 'semsenha': '1',
              // Sempre vazio: desde a 1.22.0 isso mantem a chave que o aparelho
              // ja tem. Nao ha mais de onde vir outra — quem a gera e ele.
              'token': '',
              'ip': _ipFixoInformado,
              // Vazios de proposito: desde a 1.21.0 o aparelho usa o gateway e
              // a mascara que o roteador entregou a ele. Sao numeros que o
              // produtor nao tem por que saber, e o aparelho ja sabe.
              'gateway': '',
              'mascara': '',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
        // A chave nova vem AQUI, na resposta da gravacao, e em lugar nenhum
        // depois: o aparelho reinicia em seguida e sai do modo de configuracao.
        // Perde-la aqui significaria mandar o produtor de volta ate a estufa.
        String? chaveNova;
        if (_revogando) {
          final corpo = _lerJson(resposta.body);
          chaveNova = corpo?['chaveNova']?.toString();
        }
        setState(() {
          if (chaveNova != null && chaveNova.isNotEmpty) {
            _chaveDoAparelho = chaveNova;
          }
          _concluido = true;
          _jaGravou = true;
          // O aparelho nao devolveu a chave: e firmware anterior a esta rota.
          // Rotacionou de verdade — a chave velha ja nao vale —, mas o app ficou
          // sem a nova, e dizer "pronto" seria mentira.
          _revogouSemChave =
              _revogando && (chaveNova == null || chaveNova.isEmpty);
        });
      } else {
        setState(
          () => _erro = 'O aparelho recusou (código ${resposta.statusCode}).',
        );
      }
    } catch (_) {
      if (!mounted) return;
      // A causa quase sempre e a mesma: o celular nao esta na rede do aparelho.
      setState(
        () => _erro =
            'Não encontrei o aparelho. Confirme que o celular está conectado '
            'na rede "Sentinela-Config" e que o aparelho está no modo de '
            'configuração.',
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // O "voltar" da tela de sucesso saia da configuracao inteira e jogava o
    // produtor no cadastro de estufa, com tudo o que ele fez perdido — e ele
    // esta parado nessa tela de proposito, esperando o celular voltar para o
    // Wi-Fi de casa, que e quando a mao encosta no botao errado. Agora ele
    // recua um passo, para o formulario; sair de vez e o segundo toque.
    return PopScope(
      canPop: !_concluido,
      onPopInvokedWithResult: (saiu, resultado) {
        if (!saiu && mounted) setState(() => _concluido = false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0E1012),
        appBar: AppBar(
          backgroundColor: const Color(0xFF17191D),
          foregroundColor: Colors.white,
          title: Text(
            _revogando
                ? 'Tirar acesso'
                : _apenasAcesso
                ? 'Pegar acesso'
                : widget.uso == UsoDaConfiguracao.atualizacao
                // Vindo do menu da estufa, o aparelho ja esta configurado: o que
                // se faz aqui e trocar o que ja existe.
                ? 'Reconfigurar aparelho'
                : 'Configurar aparelho',
          ),
        ),
        body: SafeArea(child: _concluido ? _sucesso() : _formulario()),
      ),
    );
  }

  Widget _sucesso() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.check_circle_outline,
              color: Colors.greenAccent,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              // "Acesso trocado" descrevia o mecanismo e nao dizia de quem. O
              // produtor escolheu "Tirar acesso dos outros celulares"; o titulo
              // do fim responde isso, com as mesmas palavras.
              _revogando
                  ? 'Os outros celulares perderam o acesso'
                  : 'Configuração enviada',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _revogando
                  ? (_revogouSemChave
                        // Rotacionou no aparelho e o app ficou sem a chave nova:
                        // este celular perdeu o acesso junto com os outros. Dizer
                        // "pronto" aqui seria mentira, e a descoberta viria depois,
                        // como comando recusado sem explicacao.
                        ? 'O aparelho trocou a chave, mas não devolveu a nova '
                              '(programa antigo). ESTE celular também perdeu o '
                              'acesso: refaça "Conectar o aparelho ao Wi-Fi" '
                              'para recuperá-lo.'
                        // Mesma frase da tela anterior, palavra por palavra: o
                        // produtor acabou de ler aquilo, e reescrever a mesma
                        // ideia com outras palavras faz procurar a diferenca.
                        // Devolver o acesso e ir ate o aparelho: nao ha
                        // compartilhamento por QR Code nesta versao.
                        : 'Este celular continua com acesso — para devolver '
                              'para outro celular, ele vai até o aparelho e '
                              'usa "pegar acesso" no app. O comando pela '
                              'internet volta quando o aparelho reconectar.')
                  : 'O aparelho está reiniciando e vai entrar na rede nova. '
                        'A rede "Sentinela-Config" vai sumir — reconecte o '
                        'celular no Wi-Fi da propriedade.',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        ),
        // O cartao do endereco so aparece quando NAO ha para onde levar os
        // dados: aberta solta, ele e o unico resultado da tela. Vindo do
        // cadastro ou da atualizacao, o endereco segue sozinho e mostra-lo aqui
        // e uma terceira coisa competindo com a acao obvia.
        if (widget.uso == null) ...[_cartaoNome(), const SizedBox(height: 8)],
        // Fecha o circulo: o endereco que o produtor acabou de ver vai sozinho
        // para o cadastro, em vez de ele ter de decorar ou copiar a mao. A
        // chave tambem, porque ele a definiu nesta mesma tela.
        if (widget.uso != null && _nomeLocal != null) ...[
          // A conferencia deixou de ser um botao proprio. Como um botao, ela so
          // funcionava DEPOIS de o produtor sair do app e trocar de Wi-Fi -
          // apertado no momento natural, falhava sempre, e um botao que falha
          // na hora obvia ensina a desconfiar do app. Agora ela acontece dentro
          // da acao principal, que e quando importa: se o aparelho nao
          // responder, o produtor decide seguir ou esperar.
          if (_alcancou == false) ...[
            const Text(
              'Ainda não respondeu. Se o celular já voltou para o Wi-Fi de '
              'sempre, espere alguns segundos — o aparelho pode estar '
              'reiniciando.',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: _conferindo ? null : _confirmarEUsar,
            icon: _conferindo
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    widget.uso == UsoDaConfiguracao.cadastro
                        ? Icons.playlist_add_rounded
                        : Icons.sync_rounded,
                    size: 18,
                  ),
            label: Text(
              _conferindo
                  ? 'Procurando o aparelho...'
                  : widget.uso == UsoDaConfiguracao.cadastro
                  ? 'Usar estes dados no cadastro'
                  : _revogando
                  ? 'Guardar a chave nova'
                  : 'Atualizar esta estufa',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          // O nome so resolve com os dois na mesma rede. Como o botao acima
          // confere antes de seguir, o aviso passa a ser sobre a ORDEM: trocar
          // de Wi-Fi primeiro, apertar depois.
          const Text(
            'Reconecte o celular no Wi-Fi da propriedade antes de continuar — '
            'o endereço só responde quando os dois estão na mesma rede.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
        // Nao ha "Voltar" aqui, e nao deve voltar a haver. Ele saia da
        // configuracao inteira e jogava fora TUDO: o PIN, a rede, a senha, o
        // endereco que o aparelho acabou de entregar. E o pior e que refazer nao
        // e digitar de novo - e ir ate a estufa, segurar o verde e o vermelho,
        // reconectar o celular no "Sentinela-Config" e recomecar. Um botao
        // discreto, ao lado do que continua o processo, custava isso.
        //
        // Sair continua possivel pelo "voltar" do sistema, que recua para o
        // formulario em vez de descartar (ver o PopScope em build).
      ],
    );
  }

  /// Endereço que o produtor precisa levar para o cadastro da estufa. Fica
  /// visível aqui porque não há outro lugar: o visor tem 4 dígitos e o Monitor
  /// Serial exige um computador com a IDE do Arduino.
  /// Diz se a tela ESTA falando com o aparelho agora. Sem isso, "ainda nao
  /// conectei na rede dele" e indistinguivel de "esta tela nao funciona": os
  /// campos aparecem vazios e o da chave reaparece, e nada explica por que. Como
  /// a leitura se repete sozinha, este aviso vira o retorno de que faltava so a
  /// rede.
  Widget _cartaoEstadoDaConversa() {
    // Firmware antigo tem cartao proprio, logo abaixo: aqui ele nao e "achei"
    // (nao da para configurar) nem "nao achei" (o aparelho respondeu).
    if (_firmwareSemIdentidade) return const SizedBox.shrink();
    if (_pinBloqueado) return _cartaoPinBloqueado();
    final achou = _chaveDoAparelho != null;
    // Antes de qualquer tentativa o app NAO tentou nada, e dizer "nao achei"
    // ali e falso — chegou a convencer duas vezes de que o Wi-Fi do aparelho
    // estava quebrado quando o processo nem tinha comecado.
    final aindaNaoTentou = !achou && _pinTentado == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            (achou
                    ? Colors.greenAccent
                    : aindaNaoTentou
                    ? Colors.white
                    : Colors.orangeAccent)
                .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            achou
                ? Icons.link_rounded
                : aindaNaoTentou
                ? Icons.hourglass_empty_rounded
                : Icons.link_off_rounded,
            color: achou
                ? Colors.greenAccent
                : aindaNaoTentou
                ? Colors.white54
                : Colors.orangeAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              achou
                  ? (_revogando || _apenasAcesso
                        // Sem campo nenhum abaixo: o botao ja diz o que fazer.
                        // O cartao so confirma que o aparelho esta do outro lado.
                        ? 'Falando com o aparelho.'
                        : 'Falando com o aparelho. Pode preencher a rede de '
                              'casa abaixo.')
                  : aindaNaoTentou
                  ? (_revogando
                        // Nada "se completa" aqui: nao ha campo abaixo, so o
                        // botao — que fica desligado ate o PIN valer.
                        ? 'Esperando o PIN. Digite os 4 números do visor para '
                              'liberar a troca.'
                        : _apenasAcesso
                        ? 'Esperando o PIN. Digite os 4 números do visor para '
                              'pegar o acesso.'
                        : 'Esperando o PIN. Assim que você digitar os 4 '
                              'números, o resto desta tela se completa.')
                  // Duas falhas diferentes, e a diferenca decide o que fazer.
                  // Se o aparelho NUNCA respondeu (`_nomeLocal` vazio), o
                  // celular nao esta na rede dele — culpar o PIN manda conferir
                  // o numero certo, que e o caminho mais longo ate a causa.
                  : _nomeLocal == null
                  ? 'Não estou alcançando o aparelho. Confira no Wi-Fi do '
                        'celular se você está na rede "Sentinela-Config" — o PIN '
                        'só vale depois disso.'
                  : 'Não achei o aparelho com esse PIN. Confira o número no '
                        'visor do aparelho.',
              style: TextStyle(
                color: achou
                    ? Colors.greenAccent
                    : aindaNaoTentou
                    ? Colors.white60
                    : Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// As 5 tentativas acabaram.
  ///
  /// Precisa ser cartao, e nao a legenda embaixo do campo: o aparelho REINICIA
  /// e sai do modo de configuracao, entao o produtor podia ficar digitando
  /// contra algo que ja tinha ido embora. E a tela nao pode cair no "nao achei o
  /// aparelho com esse PIN", que manda conferir o numero e a rede — os dois
  /// estao certos; o que acabou foram as tentativas.
  Widget _cartaoPinBloqueado() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.25)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_clock_outlined,
                color: Colors.orangeAccent,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '5 tentativas erradas',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'O aparelho bloqueou o PIN e saiu do modo de configuração — o visor '
            'voltou ao normal e a rede "Sentinela-Config" sumiu.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          SizedBox(height: 10),
          Text(
            'Vá até o aparelho, segure o botão verde e o vermelho juntos por '
            '3 s de novo e refaça. O visor mostra um PIN novo.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// A unica saida honesta para um aparelho anterior a 1.20.0: ele nao serve a
  /// rota de identidade, nao tem chave propria para entregar, e gravar nele a
  /// partir daqui mandaria um token vazio que as versoes anteriores a 1.22.0
  /// escrevem por cima — o aparelho sortearia uma chave nova e sumiria da nuvem
  /// sem nada na tela dizendo por que. Entao esta tela nao o configura. Diz o
  /// que ele e e aponta o caminho que continua funcionando: a pagina do proprio
  /// aparelho, no navegador.
  /// O que a revogacao mostra no lugar dos campos de Wi-Fi.
  ///
  /// Ela nao pede nada alem do PIN — a rede e a senha nao mudam. Entao o espaco
  /// vai para dizer o que vai acontecer, que e a unica decisao aqui.
  Widget _cartaoConfirmarRevogacao() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O que vai acontecer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Todos os outros celulares perdem o controle. Este continua '
            'com acesso — para devolver para outro celular, ele vai até o '
            'aparelho e usa "pegar acesso" no app. O Wi-Fi do aparelho não '
            'muda.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          SizedBox(height: 10),
          Text(
            'As estufadas e relatórios não somem — o que muda é só quem pode '
            'comandar.',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _cartaoFirmwareAntigo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.25)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                color: Colors.orangeAccent,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Este aparelho está com um programa antigo',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Ele respondeu, mas é de uma versão anterior ao PIN e não consegue '
            'se apresentar ao app. Configurar por aqui deixaria o aparelho sem '
            'chave e ele sumiria da nuvem.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          SizedBox(height: 10),
          Text(
            'Com o celular ainda na rede "Sentinela-Config", abra o navegador '
            'em 192.168.4.1 e configure por lá. Depois disso, atualize o '
            'programa do aparelho para usar esta tela.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _cartaoNome() {
    final nome = _nomeLocal;
    if (nome == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Endereço deste aparelho',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  nome,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copiar',
                icon: const Icon(Icons.copy_rounded, color: Colors.white54),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: nome));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Endereço copiado')),
                  );
                },
              ),
            ],
          ),
          // A instrucao de cadastrar a mao so vale quando a tela foi aberta
          // solta: vinda do cadastro ou da atualizacao, o endereco segue sozinho
          // e mandar digitar seria pedir um trabalho que o app ja fez. O cartao
          // fica nos dois casos porque, alem do endereco, ele e a confirmacao de
          // que o celular esta MESMO na rede do aparelho - se o nome aparece, a
          // conversa funciona.
          // Nao se fala mais em roteador nem em IP aqui. Aquela frase existia
          // para justificar por que o endereco e um NOME e nao um numero — uma
          // decisao que o produtor nunca teve de tomar, porque ele nunca digitou
          // numero nenhum: o app preenche sozinho. Era resposta para uma
          // pergunta que ele nao faz, no meio de uma tela em que ele esta
          // tentando fazer outra coisa.
          //
          // No lugar, cada modo diz o que aquele cartao significa ALI.
          Text(
            widget.uso == null
                ? 'Cadastre este endereço no app. É o nome deste aparelho na '
                      'rede, e ele não muda.'
                : _revogando
                ? 'É este o aparelho cuja chave vai ser trocada.'
                : _apenasAcesso
                ? 'É este o aparelho que este celular vai passar a comandar.'
                : 'Vai junto para o cadastro — você não precisa digitar.',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _formulario() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _cartaoNome(),
        // As instrucoes descrevem o que fazer ATE o aparelho responder. Depois
        // que ele respondeu, todas ja foram cumpridas — deixa-las na tela e
        // pedir de novo o que acabou de ser feito, e empurra para baixo o que
        // interessa agora.
        if (!_aparelhoRespondeu)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              // "Antes de preencher" nao serve a quem nao vai preencher nada.
              '${_revogando
                  ? "Antes de trocar a chave"
                  : _apenasAcesso
                  ? "Para pegar o acesso"
                  : "Antes de preencher"}:'
              '\n\n'
              '1. No aparelho, segure o botão verde e o vermelho juntos por 3 '
              'segundos, até apitar e os LEDs piscarem.\n'
              '2. No Wi-Fi do celular, conecte na rede "Sentinela-Config".\n'
              '3. O Android avisa que a rede não tem internet — aceite continuar '
              'conectado.\n'
              '4. Digite abaixo os 4 números que aparecem no visor do aparelho.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        const SizedBox(height: 12),
        // O aviso vem DEPOIS das instrucoes, e nao antes: no topo ele era a
        // primeira coisa lida e anunciava falha antes de o produtor ter feito
        // qualquer passo — chegou a convencer duas vezes de que o Wi-Fi do
        // aparelho estava quebrado quando nada tinha sido tentado ainda.
        _cartaoEstadoDaConversa(),
        // Caminho de volta ao resultado. Sem isto, recuar da tela de sucesso
        // seria uma porta de mao unica: o aparelho ja reiniciou e saiu do modo
        // de configuracao, entao gravar de novo nao funciona e o endereco que
        // ele mostrou nao teria como reaparecer.
        if (_jaGravou) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => setState(() => _concluido = true),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Voltar para o endereço do aparelho'),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        // Os 4 digitos do visor. E o unico numero que o produtor digita em todo
        // o processo, e e ele que troca a chave longa por presenca fisica.
        // Some com o campo quando o PIN esta bloqueado: nao ha aparelho do
        // outro lado, e um campo digitavel convida a tentar de novo.
        if (_chaveDoAparelho == null &&
            !_firmwareSemIdentidade &&
            !_pinBloqueado) ...[
          _campo(
            controlador: _pin,
            rotulo: 'PIN do visor (4 números)',
            // "no modo de configuracao" e verdade, mas e vocabulario do sistema
            // — e soa estranho numa tela chamada "Pegar acesso", que diz que
            // nada e configurado. Dizer QUANDO eles aparecem, na acao que a
            // pessoa acabou de fazer, serve aos tres usos desta tela.
            dica:
                _erroPin ??
                'Aparecem no visor depois que você segura o verde e o vermelho',
            numerico: true,
            // Confirma em vez de disparar sozinho no 4o digito: a busca comecava
            // com o teclado ainda aberto por cima, sem nada dizendo que ja tinha
            // comecado. Aqui quem decide a hora e o produtor.
            aoConfirmar: () {
              FocusManager.instance.primaryFocus?.unfocus();
              unawaited(_lerIdentidadeDoAparelho(pedidoDoProdutor: true));
            },
          ),
        ],
        // Nada abaixo do PIN antes de o aparelho responder. Os campos apareciam
        // desde a abertura, o da chave sumia depois do PIN e o do IP fixo so
        // entao vinha preenchido — a tela mudava sozinha e parecia defeito. Agora
        // ela tem duas fases claras: pedir o PIN, e so entao preencher.
        if (_firmwareSemIdentidade)
          _cartaoFirmwareAntigo()
        else if (_aparelhoRespondeu && _apenasAcesso) ...[
          // Nada a preencher e nada a gravar: o aparelho ja esta configurado, e
          // este celular so quer a chave. O botao leva os dados ao cadastro.
          _cartaoPegarAcesso(),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _confirmarEUsar,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Pegar acesso'),
            ),
          ),
        ] else if (_aparelhoRespondeu && _revogando) ...[
          // Revogacao nao pergunta rede nem senha: elas nao mudam. O aparelho
          // devolveu a rede atual na identidade, e ela e reenviada igual.
          _cartaoConfirmarRevogacao(),
        ] else if (_aparelhoRespondeu) ...[
          _campo(
            controlador: _rede,
            rotulo: 'Rede Wi-Fi da propriedade',
            dica: 'Nome exato, com maiúsculas e minúsculas',
          ),
          _campo(
            controlador: _senha,
            rotulo: 'Senha do Wi-Fi',
            dica:
                'Informe a senha do Wi-Fi. Se a rede não tiver senha, não '
                'preencha nada.',
            senha: !_senhaVisivel,
            // Senha de Wi-Fi rural costuma ser longa e cheia de numero: digitar as
            // cegas e errar, e o erro so aparece la na frente, quando o aparelho
            // nao conecta e nao ha como saber por que.
            acao: IconButton(
              icon: Icon(
                _senhaVisivel
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white38,
                size: 20,
              ),
              onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
            ),
          ),
          // Nao ha campo de chave, nem aviso sobre ela. O texto que ficava aqui
          // tranquilizava sobre um problema que o produtor nao tem: ele nunca
          // soube que existe chave, e dizer "voce nao precisa digitar" so
          // levanta a pergunta de por que precisaria. Ver o comentario da
          // classe para por que o campo nao volta.
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Endereço fixo (opcional)',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              subtitle: const Text(
                'Fixa o endereço do aparelho nesta rede',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
              iconColor: Colors.white54,
              collapsedIconColor: Colors.white54,
              childrenPadding: const EdgeInsets.only(top: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _prefixoDaRede != null && _prefixoAindaVale
                        ? 'O aparelho passa a usar este endereço sempre que '
                              'ligar, e ele só vale nesta rede. Serve para você '
                              'ter um endereço para digitar caso o nome acima '
                              'não funcione. A faixa já veio preenchida — '
                              'complete só o último número, entre 200 e 250. '
                              'Vazio deixa o roteador escolher, que é o normal.'
                        : 'O aparelho passa a usar este endereço sempre que '
                              'ligar, e ele só vale nesta rede. Se for '
                              'preencher, os TRÊS primeiros números têm de ser '
                              'os desta rede — veja no Wi-Fi do celular, nos '
                              'detalhes da rede conectada. Se lá aparecer '
                              '192.168.0.15, use 192.168.0.220.',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
                _campo(
                  controlador: _ip,
                  rotulo: 'IP fixo',
                  dica: 'Últimos números altos, de 200 a 250, evitam conflito',
                ),
              ],
            ),
          ),
        ],
        if (_erro != null) ...[
          const SizedBox(height: 16),
          Text(
            _erro!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
        // Nada de botao de salvar quando o modo e so pegar acesso: nao ha o que
        // gravar, e o botao proprio ja esta logo acima.
        if (!_firmwareSemIdentidade && !_apenasAcesso) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              // Desligado ate o aparelho responder: sem ele nao ha onde gravar, e
              // um botao que so produz erro convida a apertar de novo.
              onPressed: (_enviando || !_aparelhoRespondeu) ? null : _salvar,
              // Sem cor propria: estilo padrao do tema, o mesmo do botao "Iniciar"
              // da estufada (lilas, texto em caixa normal). So o padding maior,
              // por ser um botao de largura total.
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _enviando
                    ? 'Salvando...'
                    : _revogando
                    ? 'Trocar a chave agora'
                    : 'Salvar no aparelho',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'O aparelho reinicia sozinho depois de salvar. O alarme continua '
            'funcionando durante todo o processo.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _campo({
    required TextEditingController controlador,
    required String rotulo,
    required String dica,
    bool senha = false,
    bool numerico = false,
    Widget? acao,
    VoidCallback? aoConfirmar,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controlador,
        obscureText: senha,
        keyboardType: numerico ? TextInputType.number : null,
        maxLength: numerico ? 4 : null,
        textInputAction: aoConfirmar != null ? TextInputAction.done : null,
        onSubmitted: aoConfirmar == null ? null : (_) => aoConfirmar(),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: rotulo,
          labelStyle: const TextStyle(color: Colors.white54),
          helperText: dica,
          helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
          // O padrao e UMA linha, e a legenda mais longa (a da senha) vinha
          // cortada no fim - justo a parte que diz o que fazer numa rede sem
          // senha. Legenda que so cabe pela metade nao e legenda.
          helperMaxLines: 3,
          suffixIcon: acao,
          // Sem esta folga o rotulo flutuante encosta no texto digitado: o
          // Material desenha os dois dentro da mesma caixa preenchida, e sem
          // borda visivel para separar eles parecem uma coisa so.
          contentPadding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
          filled: true,
          fillColor: const Color(0xFF1C1C1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
