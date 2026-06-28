import 'package:intl/intl.dart';

import '../../../models/historico_leitura_entity.dart';

class RelatorioCsvService {
  const RelatorioCsvService();

  String montarCsv(List<HistoricoLeituraEntity> leituras) {
    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,nome_estufa,ip_estufa,temperatura_f,umidade_percent,temperatura_ajuste_f,umidade_ajuste_percent,aviso,alerta_incendio',
    );

    for (final leitura in leituras) {
      buffer.writeln(
        [
          _csvValue(DateFormat('yyyy-MM-dd HH:mm').format(leitura.timestamp)),
          _csvValue(leitura.nomeEstufa),
          _csvValue(leitura.ipEstufa),
          leitura.temperatura.toStringAsFixed(0),
          leitura.umidade.toStringAsFixed(0),
          leitura.temperaturaMeta.toStringAsFixed(0),
          leitura.umidadeMeta.toStringAsFixed(0),
          _csvValue(leitura.aviso),
          leitura.alertaIncendio ? '1' : '0',
        ].join(','),
      );
    }
    return buffer.toString();
  }

  String nomeArquivo(String nomeEstufa, List<HistoricoLeituraEntity> leituras) {
    final baseNome = _sanitizarFileName(nomeEstufa);
    final inicio = DateFormat('yyyyMMdd').format(leituras.first.timestamp);
    final fim = DateFormat('yyyyMMdd').format(leituras.last.timestamp);
    return '${baseNome}_${inicio}_$fim';
  }

  String _csvValue(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _sanitizarFileName(String nome) {
    final limpo = nome
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return limpo.isEmpty ? 'historico_estufa' : limpo;
  }
}
