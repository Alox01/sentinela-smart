# -*- coding: utf-8 -*-
"""Diagrama de sequencia: um comando feito sem conexao ate ser aplicado.

Diferenca para o bloco Mermaid de docs/DIAGRAMAS.md: aqui a NUVEM aparece. No
Mermaid a fila volta sempre pela rede local, e nao e o que acontece - na volta
da conexao o aplicativo entrega por onde conseguir, e pela nuvem o comando
ainda espera o controlador buscar. E justamente essa espera que o artigo
declara como limitacao, entao ela precisa estar no desenho.

Gera:  python docs/figuras/sequencia_sync.py
"""
import os

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, FancyArrowPatch

PRETO = '#141414'
CINZA = '#5a5a5a'
PAPEL = '#efefef'

# Desenhado JA NO TAMANHO IMPRESSO: 15,9 cm de largura, que e a mancha de
# texto do artigo. O fontsize abaixo e, portanto, o tamanho real no papel.
LARG_CM = 15.9
LARG_IN = LARG_CM / 2.54
X_MAX, Y_MAX = 164.0, 188.0
fig = plt.figure(figsize=(LARG_IN, LARG_IN * Y_MAX / X_MAX), dpi=400)
ax = fig.add_axes([0, 0, 1, 1])
ax.set_xlim(0, X_MAX)
ax.set_ylim(Y_MAX, 0)
ax.axis('off')

ATORES = [
    (14, 'Produtor'),
    (44, 'Aplicativo'),
    (76, 'Fila local\n(no celular)'),
    (108, 'Nuvem\n(API)'),
    (144, 'Controlador'),
]
X = {nome.split('\n')[0]: x for x, nome in ATORES}
BASE, FIM = 16, 166

for x, nome in ATORES:
    ax.add_patch(FancyBboxPatch((x - 13, 4), 26, 10,
                                boxstyle='round,pad=0,rounding_size=0.8',
                                fc=PAPEL, ec=PRETO, lw=1.4, zorder=5))
    ax.text(x, 9, nome, ha='center', va='center', fontsize=8.0,
            fontweight='bold', color=PRETO, zorder=6, linespacing=1.3)
    ax.plot([x, x], [BASE, FIM], color='#9b9b9b', lw=1.0,
            linestyle=(0, (3, 3)), zorder=1)


def msg(de, para, y, texto, resposta=False, falha=False,
        cor=PRETO):
    x1, x2 = X[de], X[para]
    ax.add_patch(FancyArrowPatch((x1, y), (x2, y), arrowstyle='-|>',
                                 mutation_scale=11, lw=1.3, color=cor,
                                 linestyle=(0, (1, 2)) if falha else
                                 ((0, (4, 2)) if resposta else '-'),
                                 zorder=4, shrinkA=0, shrinkB=0))
    ax.text((x1 + x2) / 2, y - 2.6, texto, ha='center', va='center',
            fontsize=6.6, color=cor, zorder=6, linespacing=1.3)


def nota(x_ini, x_fim, y, texto, cor=PRETO, altura=9):
    ax.add_patch(FancyBboxPatch((x_ini, y), x_fim - x_ini, altura,
                                boxstyle='round,pad=0,rounding_size=0.6',
                                fc=PAPEL, ec=cor, lw=1.0, zorder=5))
    ax.text((x_ini + x_fim) / 2, y + altura / 2, texto, ha='center',
            va='center', fontsize=6.6, color=cor, zorder=6, linespacing=1.4)


def separador(y, texto):
    ax.plot([6, 158], [y, y], color='#c9c9c9', lw=1.0, zorder=2)
    ax.text(82, y, ' ' + texto + ' ', ha='center', va='center', fontsize=6.8,
            color=CINZA, style='italic', zorder=6,
            bbox=dict(boxstyle='round,pad=0.3', fc='white', ec='none'))


# ---------------- sem conexao ----------------
msg('Produtor', 'Aplicativo', 22, 'altera o ajuste\nde temperatura')
msg('Aplicativo', 'Controlador', 29, 'tenta pela rede local')
msg('Controlador', 'Aplicativo', 35.5, 'sem resposta', resposta=True, falha=True)
msg('Aplicativo', 'Nuvem', 42, 'tenta pela nuvem')
msg('Nuvem', 'Aplicativo', 48.5, 'sem internet', resposta=True, falha=True)
msg('Aplicativo', 'Fila local', 55, 'enfileira com\ncarimbo de tempo')
msg('Fila local', 'Aplicativo', 63, 'pendente', resposta=True)
nota(30, 92, 67, 'A tela mostra OFFLINE e a pendência pelo nome:\n'
                 '"Alterar ajuste de temperatura para 65 °F"')

separador(82, 'a conexão volta')

msg('Aplicativo', 'Fila local', 89, 'busca as pendências')
msg('Fila local', 'Aplicativo', 95.5, 'comando + carimbo', resposta=True)

# ---------------- alternativa ----------------
# Os dois caminhos terminam DENTRO do seu ramo. Antes havia um unico
# "estado atualizado" desenhado fora do bloco, do controlador direto para o
# aplicativo - verdade so na rede local. Pela nuvem o controlador nao fala com
# o aplicativo: ele responde a nuvem, e e de la que o aplicativo le.
ax.add_patch(Rectangle((24, 100), 134, 66, fill=False, ec=CINZA, lw=1.0, zorder=3))
ax.add_patch(FancyBboxPatch((24, 100), 12, 5, boxstyle='square,pad=0',
                            fc='#ececec', ec=CINZA, lw=1.0, zorder=4))
ax.text(30, 102.5, 'alt', ha='center', va='center', fontsize=6.6,
        fontweight='bold', color=PRETO, zorder=5)
ax.text(38, 102.5, '[mesma rede]', ha='left', va='center',
        fontsize=6.6, color=CINZA, zorder=5)
msg('Aplicativo', 'Controlador', 109, 'entrega direto,\nem segundos')
msg('Controlador', 'Aplicativo', 116, 'estado atualizado', resposta=True)

ax.plot([24, 158], [121, 121], color=CINZA, lw=1.0, linestyle=(0, (4, 3)), zorder=3)
ax.text(26, 123.5, '[senão, pela nuvem]', ha='left', va='center',
        fontsize=6.6, color=CINZA, zorder=5)
msg('Aplicativo', 'Nuvem', 129, 'guarda o comando')
msg('Controlador', 'Nuvem', 135.5, 'busca comandos\na cada 20 segundos', cor=CINZA)
msg('Nuvem', 'Controlador', 142, 'entrega o comando', resposta=True, cor=CINZA)
msg('Controlador', 'Nuvem', 148.5, 'envia a leitura\ncom o estado novo')
# Pela nuvem o estado chega por CONSULTA, nao por empurrao: o monitor do
# aplicativo tem um Timer.periodic chamando buscarStatus. Sem esta seta, a
# resposta tracejada abaixo nao responderia a chamada nenhuma.
msg('Aplicativo', 'Nuvem', 155, 'consulta o estado')
msg('Nuvem', 'Aplicativo', 161.5, 'estado atualizado', resposta=True)

# ---------------- aplicacao ----------------
nota(92, 162, 170,
     'O controlador aplica Last-Writer-Wins por campo:\n'
     'vence o carimbo mais recente, e um comando\n'
     'antigo não desfaz um ajuste feito depois', altura=12)

destino = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       'sequencia_sync.png')
# pad_inches=0: a margem do savefig e somada FORA da tela da figura, e
# alargaria o PNG alem dos 15,9 cm pretendidos - ao inserir no artigo tudo
# encolheria junto, e a letra nao sairia no tamanho escrito aqui.
fig.savefig(destino, facecolor='white', bbox_inches='tight', pad_inches=0)
print('gerado:', destino)
