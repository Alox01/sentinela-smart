/// Quanto a leitura pode se afastar do ajuste antes de contar como desvio.
///
/// Espelha o `margemF` do firmware (**8**). Quem decide alarme e o aparelho; o
/// app nao emite um segundo parecer — ele so precisa desenhar a mesma fronteira.
///
/// Estava em **5**, fixo em dois lugares do grafico, e a diferenca aparecia na
/// tela: um desvio de 6 ou 7 pintava o ponto de vermelho e forcava a bolinha,
/// como se fosse problema, sendo que a sirene nunca tocou e nunca tocaria. O
/// grafico acusava o que o aparelho considerava normal.
///
/// Vale para temperatura e umidade, acima e abaixo do ajuste.
const double margemAjuste = 8;
