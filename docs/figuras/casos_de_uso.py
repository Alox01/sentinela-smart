# Diagrama de casos de uso da plataforma (aplicativo + API em nuvem).
#
# Desenhado aqui, e nao no mermaid.live como os outros, porque o Mermaid nao
# tem diagrama de casos de uso: o que se faz la e um fluxograma disfarcado, com
# retangulos no lugar das elipses. Este sai no formato que a banca espera.
#
# Gera:  python docs/figuras/casos_de_uso.py
import os

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse, FancyBboxPatch, Circle

PRETO = '#141414'
CINZA = '#5a5a5a'
MOSTARDA = '#8a6d00'
PAPEL = '#f1efe9'

fig = plt.figure(figsize=(11, 8.2), dpi=200)
ax = fig.add_axes([0, 0, 1, 1])
ax.set_xlim(0, 110)
ax.set_ylim(82, 0)
ax.axis('off')

# ---- fronteira do sistema ----
ax.add_patch(FancyBboxPatch((28, 6), 54, 72,
                            boxstyle='round,pad=0,rounding_size=1.5',
                            fc='white', ec=PRETO, lw=1.6, zorder=1))
ax.text(55, 10, 'Plataforma Sentinela\n(aplicativo móvel + API em nuvem)',
        ha='center', va='center', fontsize=10, fontweight='bold', color=PRETO,
        linespacing=1.4, zorder=3)


def ator(x, y, nome, legenda=''):
    """Boneco de palito da UML."""
    ax.add_patch(Circle((x, y - 6), 1.7, fill=False, ec=PRETO, lw=1.4,
                        zorder=3))
    ax.plot([x, x], [y - 4.3, y + 1], color=PRETO, lw=1.4, zorder=3)
    ax.plot([x - 3, x + 3], [y - 2.5, y - 2.5], color=PRETO, lw=1.4, zorder=3)
    ax.plot([x, x - 2.6], [y + 1, y + 5], color=PRETO, lw=1.4, zorder=3)
    ax.plot([x, x + 2.6], [y + 1, y + 5], color=PRETO, lw=1.4, zorder=3)
    ax.text(x, y + 8, nome, ha='center', va='center', fontsize=9.5,
            fontweight='bold', color=PRETO, zorder=3)
    if legenda:
        ax.text(x, y + 11.5, legenda, ha='center', va='center', fontsize=7,
                color=CINZA, zorder=3, linespacing=1.3)


def caso(x, y, texto, w=40, h=7.4):
    ax.add_patch(Ellipse((x, y), w, h, fc='white', ec=PRETO, lw=1.2, zorder=2))
    ax.text(x, y, texto, ha='center', va='center', fontsize=8.2, color=PRETO,
            zorder=3, linespacing=1.25)


def liga(x1, y1, x2, y2, tracejado=False):
    ax.plot([x1, x2], [y1, y2], color=CINZA, lw=1.0, zorder=1,
            linestyle=(0, (4, 2)) if tracejado else '-')


CASOS = [
    (16, 'Cadastrar e parear a estufa'),
    (25, 'Acompanhar temperatura\ne umidade'),
    (34, 'Ajustar os alvos de\ntemperatura e umidade'),
    (43, 'Receber alertas de temperatura,\nde incêndio e de falta de comunicação'),
    (52, 'Silenciar o alarme'),
    (61, 'Iniciar e encerrar\numa estufada'),
    (70, 'Consultar e exportar\no relatório do ciclo'),
]

for y, texto in CASOS:
    caso(55, y, texto)

# ---- atores ----
ator(10, 38, 'Produtor')
ator(100, 34, 'Controlador', 'da estufa\n(projeto complementar)')
ator(100, 66, 'Serviço de\nnotificações', 'Firebase Cloud\nMessaging')

for y, _ in CASOS:
    liga(14, 38, 35.5, y)

# O controlador participa de tudo que depende do aparelho: ele se identifica
# no pareamento, fornece as leituras, aplica os alvos, decide o alarme e cala
# a sirene. Nao participa da estufada nem do relatorio - o firmware nao tem
# conceito de ciclo e nao guarda historico nenhum.
for y in (16, 25, 34, 43, 52):
    liga(74.5, y, 96, 34)
# O servico de notificacao entrega o aviso quando o aplicativo esta fechado.
liga(74.5, 43, 96, 66)

destino = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       'casos_de_uso.png')
fig.savefig(destino, facecolor='white', bbox_inches='tight', pad_inches=0.2)
print('gerado:', destino)
