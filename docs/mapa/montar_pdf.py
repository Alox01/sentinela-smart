# Junta as quatro paginas num PDF so, dentro do projeto.
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages

import mapa1
import mapa2
import mapa3
import mapa4

# Sai um nível: o PDF mora em docs/, o código que o desenha em docs/mapa/.
DESTINO = os.path.join(os.path.dirname(AQUI), 'MAPA_DE_MONTAGEM.pdf')

# A3 deitado: cabe a fiacao inteira numa folha so, e ainda imprime legivel em A4.
TAMANHO = (16.54, 11.69)

with PdfPages(DESTINO) as pdf:
    meta = pdf.infodict()
    meta['Title'] = 'Sentinela Smart — mapa de montagem'
    meta['Subject'] = ('Parte elétrica, placa perfurada, protoboard e tabela '
                       'de ligações')
    meta['Keywords'] = 'ESP32, contator, relé, DS18B20, DHT22, TM1637'

    for pagina in (mapa1, mapa2, mapa3, mapa4):
        fig = plt.figure(figsize=TAMANHO, dpi=200)
        pagina.desenhar(fig)
        pdf.savefig(fig, facecolor='white')
        plt.close(fig)

print('gerado:', DESTINO)
