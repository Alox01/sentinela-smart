import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../services/api_service.dart';

/// Configura a rede e a chave do aparelho pelo app, sem digitar endereco.
///
/// O aparelho tambem serve a mesma pagina em `192.168.4.1`, e o portal cativo
/// tenta abri-la sozinha — mas quem decide isso e o Android, e nao ha garantia.
/// Esta tela e o caminho que sempre funciona: o produtor ja tem o app, e um
/// toque no menu basta.
/// De onde a configuracao foi aberta. Muda o que a tela de sucesso oferece
/// depois, porque o produtor esta em situacoes diferentes em cada caso.
enum UsoDaConfiguracao {
  /// Estufa nova: leva endereco e chave para o formulario de cadastro.
  cadastro,

  /// Estufa ja cadastrada: se a chave mudou, a guardada no app ficou velha e os
  /// comandos passariam a ser recusados. Oferece atualizar.
  atualizacao,
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

  const DadosAparelhoConfigurado({
    this.endereco,
    this.chave,
    this.idHardware,
  });
}

class _ConfigurarAparelhoScreenState extends State<ConfigurarAparelhoScreen> {
  // Endereco fixo do ponto de acesso do ESP32 (padrao do softAP).
  static const String _enderecoAparelho = 'http://192.168.4.1';

  final _rede = TextEditingController();
  final _senha = TextEditingController();
  final _chave = TextEditingController();
  /// Chave lida do proprio aparelho. Nunca exibida: existe so para seguir ao
  /// cadastro. Nula quando o firmware e anterior a 1.20.0.
  String? _chaveDoAparelho;
  String? _idDoAparelho;
  /// Faixa da rede da casa (ex.: "192.168.0."), aprendida pelo aparelho.
  String? _prefixoDaRede;
  final _pin = TextEditingController();
  /// Ultimo PIN enviado, para a repeticao automatica nao gastar as tentativas.
  String? _pinTentado;
  String? _erroPin;
  Timer? _tentativas;
  bool _senhaVisivel = false;
  bool _conferindo = false;
  bool? _alcancou;
  final _ip = TextEditingController();

  bool _enviando = false;
  String? _erro;
  bool _concluido = false;
  // Nome local do aparelho (ex.: sentinela-a1b2c3.local). E o endereco que o
  // produtor cadastra na estufa, e ate a versao 1.10 do firmware ele so
  // aparecia no Monitor Serial - inutil para quem nao tem a IDE do Arduino.
  String? _nomeLocal;

  @override
  void initState() {
    super.initState();
    // Insiste enquanto nao conhecer o aparelho. A tela manda conectar na rede
    // dele DEPOIS de abrir, entao uma leitura unica no init falha justamente na
    // ordem que a propria instrucao ensina - e nada tentava de novo: ficava sem
    // nome, sem id e sem a chave, e o formulario voltava a pedir a chave a mao.
    unawaited(_lerNomeDoAparelho());
    _tentativas = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_concluido || _chaveDoAparelho != null) return;
      unawaited(_lerNomeDoAparelho());
    });
  }

  @override
  void dispose() {
    _tentativas?.cancel();
    _pin.dispose();
    _rede.dispose();
    _senha.dispose();
    _chave.dispose();
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

  /// Le a chave do proprio aparelho, para o produtor nunca precisar ve-la nem
  /// digita-la. Ela fica so aqui em memoria e segue direto para o cadastro.
  ///
  /// A rota so responde no modo de configuracao — estar na frente do aparelho é
  /// o que autoriza. Firmware anterior a 1.20.0 não a serve: nesse caso o campo
  /// da chave continua aparecendo, para o aparelho antigo não ficar sem caminho.
  Future<void> _lerIdentidadeDoAparelho() async {
    final pin = _pin.text.trim();
    // Sem os 4 digitos nao ha o que pedir: o aparelho recusa, e insistir so
    // gastaria as tentativas dele.
    if (pin.length != 4) return;
    // E nunca reenviar um PIN que ja falhou. A leitura se repete a cada 3 s, e
    // sem isto um PIN errado consumiria as 5 tentativas do aparelho em 15
    // segundos - o proprio app bloquearia o emparelhamento.
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
          _erroPin = restantes == 0
              ? 'PIN bloqueado. Saia e entre de novo no modo de configuração '
                    'no aparelho.'
              : 'PIN não confere. Confira o número no visor do aparelho'
                    '${restantes is int ? ' ($restantes tentativas)' : ''}.';
        });
        return;
      }
      if (resposta.statusCode != 200) return;
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
      if (chave == null || chave.isEmpty) return;
      setState(() {
        _chaveDoAparelho = chave;
        if (id != null && id.isNotEmpty) _idDoAparelho = id;
        if (nome != null && nome.isNotEmpty) {
          _nomeLocal = ApiService.completarNomeMdns(nome);
        }
        _prefixoDaRede = _prefixoDe(gateway);
        // Deixa o campo quase pronto: falta so o ultimo numero. O celular esta
        // na rede do aparelho agora e nao teria como descobrir a faixa da casa;
        // quem sabe e o aparelho, que ja esteve nela.
        if (_prefixoDaRede != null && _ip.text.trim().isEmpty) {
          _ip.text = _prefixoDaRede!;
          _ip.selection = TextSelection.collapsed(offset: _ip.text.length);
        }
      });
    } catch (_) {
      // Firmware antigo ou fora do modo de configuracao: segue pelo campo.
    }
  }

  /// Confere se o aparelho voltou a ser alcancavel pelo nome, agora que os dois
  /// deviam estar na rede de casa. Sem isto o produtor podia terminar com uma
  /// estufa cadastrada num endereco que nunca responde — o mDNS falha em parte
  /// dos celulares e roteadores, e o erro so apareceria muito depois.
  /// Confere o alcance e so entao devolve os dados. Na primeira tentativa que
  /// falha, avisa e deixa o produtor decidir: apertar de novo segue assim
  /// mesmo. Nao barra o cadastro - o aparelho pode so estar demorando a
  /// reiniciar, e travar o fluxo seria pior do que uma estufa a conferir depois.
  Future<void> _confirmarEUsar() async {
    if (_alcancou == null) {
      await _conferirAlcance();
      if (!mounted || _alcancou == false) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      DadosAparelhoConfigurado(
        endereco: _nomeLocal,
        chave: _chaveDoAparelho
            ?? (_chave.text.trim().isEmpty ? null : _chave.text.trim()),
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
  static String? _prefixoDe(String? ip) {
    if (ip == null) return null;
    final partes = ip.split('.');
    if (partes.length != 4) return null;
    if (partes.any((p) => int.tryParse(p) == null)) return null;
    return '${partes.take(3).join('.')}.';
  }

  /// O campo pre-preenchido vale como vazio ate ganhar o ultimo numero: mandar
  /// so a faixa seria um endereco invalido, e o aparelho cairia no DHCP sem o
  /// produtor entender por que.
  String get _ipFixoInformado {
    final texto = _ip.text.trim();
    if (texto.isEmpty || texto.endsWith('.')) return '';
    return texto;
  }

  Future<void> _salvar() async {
    final rede = _rede.text.trim();
    if (rede.isEmpty) {
      setState(() => _erro = 'Informe o nome da rede Wi-Fi.');
      return;
    }



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
              'ssid': rede,
              'senha': _senha.text,
              // Vazio mantem a atual no aparelho. So manda algo quando o
              // produtor digitou — caso do firmware antigo, sem chave propria.
              'token': _chaveDoAparelho != null ? '' : _chave.text.trim(),
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
        setState(() => _concluido = true);
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
    return Scaffold(
      backgroundColor: const Color(0xFF0E1012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17191D),
        foregroundColor: Colors.white,
        title: const Text('Configurar aparelho'),
      ),
      body: SafeArea(child: _concluido ? _sucesso() : _formulario()),
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
            const Text(
              'Configuração enviada',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'O aparelho está reiniciando e vai entrar na rede nova. '
              'A rede "Sentinela-Config" vai sumir — reconecte o celular no '
              'Wi-Fi de sempre.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
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
            'Reconecte o celular no Wi-Fi de sempre antes de continuar — '
            'o endereço só responde quando os dois estão na mesma rede.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Voltar'),
        ),
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
    final achou = _chaveDoAparelho != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (achou ? Colors.greenAccent : Colors.orangeAccent).withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            achou ? Icons.link_rounded : Icons.link_off_rounded,
            color: achou ? Colors.greenAccent : Colors.orangeAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              achou
                  ? 'Falando com o aparelho. A chave dele vem junto — você não '
                        'precisa digitar nada.'
                  : 'Ainda não achei o aparelho. Siga os 3 passos abaixo e '
                        'digite os 4 números que aparecem no visor dele.',
              style: TextStyle(
                color: achou ? Colors.greenAccent : Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
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
          Text(
            widget.uso == null
                ? 'Cadastre no campo de endereço da estufa. Ele continua '
                      'valendo mesmo que o roteador troque o IP.'
                : 'Vai junto para o cadastro. Ele continua valendo mesmo que '
                      'o roteador troque o IP.',
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
        _cartaoEstadoDaConversa(),
        _cartaoNome(),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: const Text(
            'Antes de preencher:\n\n'
            '1. No aparelho, segure os três botões por 3 segundos, até apitar e '
            'os LEDs piscarem.\n'
            '2. No Wi-Fi do celular, conecte na rede "Sentinela-Config".\n'
            '3. O Android avisa que a rede não tem internet — aceite continuar '
            'conectado.\n'
            '4. Digite abaixo os 4 números que aparecem no visor do aparelho.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ),
        const SizedBox(height: 20),
        // Os 4 digitos do visor. E o unico numero que o produtor digita em todo
        // o processo, e e ele que troca a chave longa por presenca fisica.
        if (_chaveDoAparelho == null) ...[
          _campo(
            controlador: _pin,
            rotulo: 'PIN do visor (4 números)',
            dica: _erroPin ?? 'Aparecem no visor do aparelho no modo de '
                'configuração',
            numerico: true,
            // Confirma em vez de disparar sozinho no 4o digito: a busca comecava
            // com o teclado ainda aberto por cima, sem nada dizendo que ja tinha
            // comecado. Aqui quem decide a hora e o produtor.
            aoConfirmar: () {
              FocusManager.instance.primaryFocus?.unfocus();
              unawaited(_lerIdentidadeDoAparelho());
            },
          ),
        ],
        _campo(
          controlador: _rede,
          rotulo: 'Rede Wi-Fi da propriedade',
          dica: 'Nome exato, com maiúsculas e minúsculas',
        ),
        _campo(
          controlador: _senha,
          rotulo: 'Senha do Wi-Fi',
          dica: 'Deixe vazio para manter a senha atual',
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
        // O campo so aparece para aparelho sem chave propria (firmware anterior
        // a 1.20.0). Com chave propria o produtor nunca precisa ve-la nem
        // digita-la: o app le do aparelho e leva ao cadastro.
        if (_chaveDoAparelho == null)
          _campo(
            controlador: _chave,
            rotulo: 'Chave de acesso',
            dica: 'A mesma cadastrada na estufa, aqui no app',
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.white38, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A chave deste aparelho vai junto para o cadastro. '
                    'Você não precisa vê-la nem digitá-la.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'Endereço fixo (opcional)',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            subtitle: const Text(
              'Quando não dá para reservar o IP no roteador',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
            iconColor: Colors.white54,
            collapsedIconColor: Colors.white54,
            childrenPadding: const EdgeInsets.only(top: 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _prefixoDaRede != null
                      ? 'Reserva, para quando o nome acima não funcionar no '
                            'seu celular ou roteador. A faixa da sua rede já '
                            'veio preenchida — complete só o último número, '
                            'entre 200 e 250. Vazio deixa o roteador escolher.'
                      : 'Reserva, para quando o nome acima não funcionar no '
                            'seu celular ou roteador. Deixe vazio para o '
                            'roteador escolher. Os TRÊS primeiros números têm '
                            'de ser os da sua rede — veja no Wi-Fi do celular, '
                            'nos detalhes da rede conectada. Se lá aparecer '
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
        if (_erro != null) ...[
          const SizedBox(height: 16),
          Text(
            _erro!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _enviando ? null : _salvar,
            // Sem cor propria: estilo padrao do tema, o mesmo do botao "Iniciar"
            // da estufada (lilas, texto em caixa normal). So o padding maior,
            // por ser um botao de largura total.
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_enviando ? 'Salvando...' : 'Salvar no aparelho'),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'O aparelho reinicia sozinho depois de salvar. O alarme continua '
          'funcionando durante todo o processo.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
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
