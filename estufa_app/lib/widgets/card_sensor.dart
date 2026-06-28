import 'package:flutter/material.dart';

class CardSensor extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final Color cor;
  final double? valorFontSize;

  const CardSensor({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icone,
    required this.cor,
    this.valorFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tamanhoTela = MediaQuery.sizeOf(context);
        final telaEstreita = tamanhoTela.width < 430;
        final telaBaixa = tamanhoTela.height < 500;
        final compacto = telaBaixa && constraints.maxHeight < 160;
        final tituloFontSize = telaEstreita || compacto ? 10.5 : 12.0;
        final iconeSize = telaEstreita || compacto ? 14.0 : 16.0;
        final paddingVertical = compacto ? 12.0 : 18.0;
        final headerHeight = 42.0;
        final spacingAfterTitle = compacto ? 4.0 : 10.0;
        final valueHeight = compacto ? 54.0 : 72.0;
        final valueFontSize = compacto ? 42.0 : (valorFontSize ?? 50.0);

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: paddingVertical,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cor.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: headerHeight,
                child: Center(
                  child: telaEstreita || compacto
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icone, color: cor, size: iconeSize),
                            const SizedBox(height: 4),
                            Text(
                              titulo,
                              maxLines: 2,
                              overflow: TextOverflow.visible,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cor,
                                fontSize: tituloFontSize,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                height: 1.05,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icone, color: cor, size: iconeSize),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                titulo,
                                maxLines: 2,
                                overflow: TextOverflow.visible,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: cor,
                                  fontSize: tituloFontSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: spacingAfterTitle),
              SizedBox(
                height: valueHeight,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      valor,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
