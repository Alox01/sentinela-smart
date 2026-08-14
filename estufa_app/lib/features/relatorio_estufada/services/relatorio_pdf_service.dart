import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/ciclo_secagem_entity.dart';
import '../../../models/evento_ciclo_entity.dart';
import '../../../models/historico_leitura_entity.dart';
import '../duracao_estufada.dart';

/// Gera o relatorio da estufada em PDF, legivel e imprimivel para o produtor:
/// resumo, graficos de temperatura e umidade, eventos e a tabela de leituras.
class RelatorioPdfService {
  const RelatorioPdfService();

  Future<Uint8List> gerarPdf({
    required String nomeEstufa,
    required CicloSecagemEntity? ciclo,
    required List<HistoricoLeituraEntity> leituras,
    required List<EventoCicloEntity> eventos,
  }) async {
    final doc = pw.Document();
    final geradoEm = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final horaFmt = DateFormat('dd/MM HH:mm');

    // `inicio` e `fim` sao o periodo das LEITURAS que entraram neste PDF, e o
    // cabecalho mostra isso. A duracao e outra coisa: e da estufada, e vem do
    // ciclo. Sair das leituras encurtava a secagem sempre que faltava leitura na
    // ponta — aparelho desligado, queda de energia —, e o papel e justamente
    // onde o numero errado ganha a discussao.
    final inicio = leituras.first.timestamp;
    final fim = leituras.last.timestamp;
    final duracao = duracaoDaEstufada(
      inicioDoCiclo: ciclo?.inicio,
      fimDoCiclo: ciclo?.fim,
      intervaloDasLeituras: fim.difference(inicio),
    );
    // Mesma conta da tela: EPISODIOS de alarme, e nao leituras gravadas com a
    // sirene ligada. O PDF e o que sai da propriedade — divergir da tela aqui
    // seria dois numeros para a mesma estufada, e o impresso ganharia a
    // discussao por estar no papel.
    final totalAlarmes = eventos
        .where(
          (e) => e.tipo == 'alarme_processo' || e.tipo == 'alerta_incendio',
        )
        .length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 24),
        build: (context) => [
          _cabecalho(nomeEstufa, ciclo, inicio, fim, geradoEm, horaFmt),
          pw.SizedBox(height: 16),
          _resumo(
            duracao: duracao,
            tempInicial: leituras.first.temperaturaMeta,
            tempFinal: leituras.last.temperaturaMeta,
            umidInicial: leituras.first.umidadeMeta,
            umidFinal: leituras.last.umidadeMeta,
            totalAlarmes: totalAlarmes,
          ),
          pw.SizedBox(height: 18),
          _tituloSecao('Eventos da estufada'),
          _tabelaEventos(eventos, horaFmt),
          pw.SizedBox(height: 18),
          _tituloSecao('Leituras registradas'),
          _tabelaLeituras(leituras, horaFmt),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Gerado pelo Sentinela Smart em $geradoEm  -  pagina '
            '${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _cabecalho(
    String nomeEstufa,
    CicloSecagemEntity? ciclo,
    DateTime inicio,
    DateTime fim,
    String geradoEm,
    DateFormat horaFmt,
  ) {
    final periodo = '${horaFmt.format(inicio)}  ate  ${horaFmt.format(fim)}';
    final identificacao = ciclo == null
        ? 'Estufada'
        : 'Estufada #${ciclo.id}'
              '${ciclo.fim == null ? ' (em andamento)' : ''}';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SENTINELA SMART',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        pw.Text(
          'Relatorio da estufada',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        ),
        pw.Divider(color: PdfColors.grey400),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  nomeEstufa,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(identificacao, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Periodo', style: const pw.TextStyle(fontSize: 9)),
                pw.Text(
                  periodo,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _resumo({
    required Duration duracao,
    required double tempInicial,
    required double tempFinal,
    required double umidInicial,
    required double umidFinal,
    required int totalAlarmes,
  }) {
    final horas = duracao.inHours.toString().padLeft(2, '0');
    final minutos = duracao.inMinutes.remainder(60).toString().padLeft(2, '0');

    pw.Widget bloco(String titulo, String valor) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          margin: const pw.EdgeInsets.only(right: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                titulo,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                valor,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Column(
      children: [
        pw.Row(
          children: [
            bloco('DURACAO', '$horas:$minutos h'),
            bloco('TEMP. INICIAL', '${tempInicial.toStringAsFixed(0)} F'),
            bloco('TEMP. FINAL', '${tempFinal.toStringAsFixed(0)} F'),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            bloco('ALARMES', '$totalAlarmes'),
            bloco('UMID. INICIAL', '${umidInicial.toStringAsFixed(0)} %'),
            bloco('UMID. FINAL', '${umidFinal.toStringAsFixed(0)} %'),
          ],
        ),
      ],
    );
  }

  pw.Widget _tituloSecao(String texto) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        texto,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _tabelaEventos(
    List<EventoCicloEntity> eventos,
    DateFormat horaFmt,
  ) {
    if (eventos.isEmpty) {
      return pw.Text(
        'Nenhum evento registrado.',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      );
    }

    final ordenados = [...eventos]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft},
      columnWidths: {
        0: const pw.FixedColumnWidth(70),
        1: const pw.FlexColumnWidth(),
      },
      headers: ['Horario', 'Evento'],
      data: [
        for (final e in ordenados) [horaFmt.format(e.timestamp), e.descricao],
      ],
    );
  }

  pw.Widget _tabelaLeituras(
    List<HistoricoLeituraEntity> leituras,
    DateFormat horaFmt,
  ) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.center,
      headers: [
        'Horario',
        'Temp. (F)',
        'Ajuste',
        'Umid. (%)',
        'Ajuste',
        'Alarme',
      ],
      data: [
        for (final l in leituras)
          [
            horaFmt.format(l.timestamp),
            l.temperatura.toStringAsFixed(0),
            l.temperaturaMeta.toStringAsFixed(0),
            l.umidade.toStringAsFixed(0),
            l.umidadeMeta.toStringAsFixed(0),
            l.alertaIncendio ? 'Sim' : '-',
          ],
      ],
    );
  }
}
