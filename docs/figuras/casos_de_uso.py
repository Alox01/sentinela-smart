# Diagrama de casos de uso da plataforma (aplicativo + API em nuvem).
#
# Desenhado aqui, e nao no mermaid.live como os outros, porque o Mermaid nao
# tem diagrama de casos de uso: o que se faz la e um fluxograma disfarcado, com
# retangulos no lugar das elipses. Este sai no formato que a banca espera.
#
# A figura e desenhada JA NO TAMANHO IMPRESSO (15,9 cm de largura, que e a
# mancha de texto do artigo com margens de 3 e 2 cm). Isso importa: matplotlib
# mede fontsize em pontos sobre o tamanho da FIGURA, entao desenhar grande e
# reduzir na pagina encolhe a letra junto. Na versao anterior a figura tinha
# 11 polegadas e era impressa com 6,3 - os 8,2 pt viravam 4,9 pt no papel, e o
# diagrama saia ilegivel. Aqui o numero do fontsize e o tamanho real.
#
# Gera:  python docs/figuras/casos_de_uso.py
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse, FancyBboxPatch, Circle

PRETO = '#141414'
CINZA = '#5a5a5a'

LARG_CM = 15.9
LARG_IN = LARG_CM / 2.54
X_MAX, Y_MAX = 110.0, 104.0
W_ELIPSE = 48.0
H_ELIPSE = 9.0
PASSO = 10.0

FS_CASO, FS_ATOR, FS_TITULO, FS_LEGENDA = 8.0, 9.0, 9.5, 7.0

fig = plt.figure(figsize=(LARG_IN, LARG_IN * Y_MAX / X_MAX), dpi=400)
ax = fig.add_axes([0, 0, 1, 1])
ax.set_xlim(0, X_MAX); ax.set_ylim(Y_MAX, 0); ax.axis('off')

ESQ, DIR = 55 - W_ELIPSE/2 - 3, 55 + W_ELIPSE/2 + 3
ax.add_patch(FancyBboxPatch((ESQ, 6), DIR - ESQ, Y_MAX - 12,
                            boxstyle='round,pad=0,rounding_size=1.5',
                            fc='white', ec=PRETO, lw=1.6, zorder=1))
ax.text(55, 11, 'Plataforma Sentinela\n(aplicativo móvel + API em nuvem)',
        ha='center', va='center', fontsize=FS_TITULO, fontweight='bold',
        color=PRETO, linespacing=1.4, zorder=3)

def ator(x, y, nome, legenda=''):
    ax.add_patch(Circle((x, y - 6), 1.7, fill=False, ec=PRETO, lw=1.4, zorder=3))
    ax.plot([x, x], [y - 4.3, y + 1], color=PRETO, lw=1.4, zorder=3)
    ax.plot([x - 3, x + 3], [y - 2.5, y - 2.5], color=PRETO, lw=1.4, zorder=3)
    ax.plot([x, x - 2.6], [y + 1, y + 5], color=PRETO, lw=1.4, zorder=3)
    ax.plot([x, x + 2.6], [y + 1, y + 5], color=PRETO, lw=1.4, zorder=3)
    ax.text(x, y + 8.5, nome, ha='center', va='center', fontsize=FS_ATOR,
            fontweight='bold', color=PRETO, zorder=3, linespacing=1.3)
    if legenda:
        ax.text(x, y + 13, legenda, ha='center', va='center', fontsize=FS_LEGENDA,
                color=CINZA, zorder=3, linespacing=1.3)

textos = []
def caso(x, y, texto):
    ax.add_patch(Ellipse((x, y), W_ELIPSE, H_ELIPSE, fc='white', ec=PRETO,
                         lw=1.2, zorder=2))
    t = ax.text(x, y, texto, ha='center', va='center', fontsize=FS_CASO,
                color=PRETO, zorder=3, linespacing=1.25)
    textos.append((t, x, y))

CASOS = ['Cadastrar e parear a estufa',
         'Acompanhar temperatura\ne umidade',
         'Ajustar os alvos de\ntemperatura e umidade',
         'Receber alertas de temperatura\ne de incêndio',
         'Receber aviso de\nfalta de comunicação',
         'Silenciar o alarme',
         'Iniciar e encerrar\numa estufada',
         'Consultar e exportar\no relatório do ciclo']
y0 = 21.0   # abaixo do titulo da fronteira, que fica em y=11
ys = [y0 + i*PASSO for i in range(len(CASOS))]
for y, texto in zip(ys, CASOS):
    caso(55, y, texto)

meio = (ys[0] + ys[-1]) / 2
Y_CTRL, Y_PUSH = meio - 9, ys[-1] - 4
ator(10, meio, 'Produtor')
ator(100, Y_CTRL, 'Controlador', 'da estufa\n(projeto complementar)')
ator(100, Y_PUSH, 'Serviço de\nnotificações', 'Firebase Cloud\nMessaging')

for y in ys:
    ax.plot([14, 55 - W_ELIPSE/2 + 0.5], [meio, y], color=CINZA, lw=1.0, zorder=1)
# O controlador participa do pareamento, das leituras, do ajuste, do alarme de
# temperatura/chama e do silenciar. NAO participa do aviso de falta de
# comunicacao - esse aviso nasce do silencio dele, quem o detecta e a nuvem -,
# nem da estufada ou do relatorio, que o firmware desconhece.
IDX_CONTROLADOR = (0, 1, 2, 3, 5)
IDX_NOTIFICACAO = (3, 4)
for i in IDX_CONTROLADOR:
    ax.plot([55 + W_ELIPSE/2 - 0.5, 96], [ys[i], Y_CTRL], color=CINZA, lw=1.0, zorder=1)
for i in IDX_NOTIFICACAO:
    ax.plot([55 + W_ELIPSE/2 - 0.5, 96], [ys[i], Y_PUSH], color=CINZA, lw=1.0, zorder=1)

destino = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'casos_de_uso.png')
# pad_inches=0: a margem do savefig e somada FORA da tela da figura, e
# alargaria o PNG alem dos 15,9 cm pretendidos - ao inserir no artigo tudo
# encolheria junto, e a letra nao sairia no tamanho escrito aqui.
fig.savefig(destino, facecolor='white', bbox_inches='tight', pad_inches=0)
print('gerado:', destino)
