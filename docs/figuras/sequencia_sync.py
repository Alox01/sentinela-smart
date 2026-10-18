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
MOSTARDA = '#8a6d00'
PAPEL = '#f1efe9'

fig = plt.figure(figsize=(14.5, 12.6), dpi=200)
ax = fig.add_axes([0, 0, 1, 1])
ax.set_xlim(0, 164)
ax.set_ylim(172, 0)
ax.axis('off')

ATORES = [
    (14, 'Produtor'),
    (44, 'Aplicativo'),
    (76, 'Fila local\n(banco do celular)'),
    (108, 'Nuvem\n(API)'),
    (144, 'Controlador'),
]
X = {nome.split('\n')[0]: x for x, nome in ATORES}
BASE, FIM = 16, 166

for x, nome in ATORES:
    ax.add_patch(FancyBboxPatch((x - 13, 4), 26, 10,
                                boxstyle='round,pad=0,rounding_size=0.8',
                                fc=PAPEL, ec=PRETO, lw=1.4, zorder=5))
    ax.text(x, 9, nome, ha='center', va='center', fontsize=8.2,
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
            fontsize=7.2, color=cor, zorder=6, linespacing=1.3)


def nota(x_ini, x_fim, y, texto, cor=PRETO, altura=9):
    ax.add_patch(FancyBboxPatch((x_ini, y), x_fim - x_ini, altura,
                                boxstyle='round,pad=0,rounding_size=0.6',
                                fc=PAPEL, ec=cor, lw=1.0, zorder=5))
    ax.text((x_ini + x_fim) / 2, y + altura / 2, texto, ha='center',
            va='center', fontsize=7.0, color=cor, zorder=6, linespacing=1.4)


def separador(y, texto):
    ax.plot([6, 158], [y, y], color='#c9c9c9', lw=1.0, zorder=2)
    ax.text(82, y, ' ' + texto + ' ', ha='center', va='center', fontsize=7.4,
            color=CINZA, style='italic', zorder=6,
            bbox=dict(boxstyle='round,pad=0.3', fc='white', ec='none'))


# ---------------- sem conexao ----------------
msg('Produtor', 'Aplicativo', 22, 'altera o ajuste de temperatura')
msg('Aplicativo', 'Controlador', 30, 'tenta pela rede local')
msg('Controlador', 'Aplicativo', 37, 'sem resposta', resposta=True, falha=True)
msg('Aplicativo', 'Nuvem', 44, 'tenta pela nuvem')
msg('Nuvem', 'Aplicativo', 51, 'sem internet', resposta=True, falha=True)
msg('Aplicativo', 'Fila local', 58, 'enfileira o comando com\no carimbo de tempo')
msg('Fila local', 'Aplicativo', 68, 'pendente', resposta=True)
nota(30, 92, 72, 'A tela mostra OFFLINE e a pendência pelo nome:\n'
                 '"Alterar ajuste de temperatura para 70 °F"')

separador(88, 'a conexão volta')

msg('Aplicativo', 'Fila local', 96, 'busca as pendências')
msg('Fila local', 'Aplicativo', 103, 'comando + carimbo', resposta=True)

# ---------------- alternativa ----------------
ax.add_patch(Rectangle((24, 108), 134, 34, fill=False, ec=CINZA, lw=1.0,
                       zorder=3))
ax.add_patch(FancyBboxPatch((24, 108), 12, 5,
                            boxstyle='square,pad=0', fc='#ececec', ec=CINZA,
                            lw=1.0, zorder=4))
ax.text(30, 110.5, 'alt', ha='center', va='center', fontsize=7,
        fontweight='bold', color=PRETO, zorder=5)
ax.text(38, 110.5, '[o aparelho está na mesma rede]', ha='left', va='center',
        fontsize=7, color=CINZA, zorder=5)
msg('Aplicativo', 'Controlador', 118, 'entrega direto, em segundos')

ax.plot([24, 158], [122, 122], color=CINZA, lw=1.0,
        linestyle=(0, (4, 3)), zorder=3)
ax.text(26, 124.5, '[senão, pela nuvem]', ha='left', va='center',
        fontsize=7, color=CINZA, zorder=5)
msg('Aplicativo', 'Nuvem', 130, 'guarda o comando')
msg('Controlador', 'Nuvem', 136,
    'busca comandos a cada 20 s\n(é daqui que vem a espera declarada)',
    cor=CINZA)

# ---------------- aplicacao ----------------
nota(112, 160, 146,
     'O controlador aplica Last-Write-Wins por campo: vence o\n'
     'carimbo mais recente, e um comando antigo nao desfaz\n'
     'um ajuste feito depois', altura=12)
msg('Controlador', 'Aplicativo', 164, 'estado atualizado', resposta=True)

destino = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       'sequencia_sync.png')
fig.savefig(destino, facecolor='white', bbox_inches='tight', pad_inches=0.25)
print('gerado:', destino)
