# -*- coding: utf-8 -*-
"""DER do banco em nuvem na notacao de Chen, sem os atributos.

Desenhado JA NO TAMANHO IMPRESSO (15,9 cm de largura, a mancha de texto do
artigo). O fontsize aqui e o tamanho real no papel.

Por que sem os atributos: sao seis entidades e cerca de quarenta e cinco
colunas. Impressa com 15,9 cm a figura tem 450 pontos de largura, e so os
rotulos dos atributos somam perto de 2.700 pontos de texto - nao cabem em
nenhum arranjo. A versao anterior cabia porque usava letra de 2,3 pt, ilegivel
no papel. O que cada tabela guarda esta descrito na secao 4.1 do artigo.

Gera:  python docs/figuras/der_chen.py
"""
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Polygon

PRETO = '#141414'
CINZA = '#5a5a5a'

LARG_CM = 15.9
X_MAX, Y_MAX = 78.0, 56.0
FS_ENT, FS_REL, FS_CARD, FS_LEG = 8.0, 7.0, 6.5, 7.0

fig = plt.figure(figsize=(LARG_CM/2.54, (LARG_CM/2.54) * Y_MAX / X_MAX), dpi=400)
ax = fig.add_axes([0, 0, 1, 1])
ax.set_xlim(0, X_MAX); ax.set_ylim(Y_MAX, 0); ax.axis('off')

caixas = []
def entidade(cx, cy, texto, w, h=7.0):
    ax.add_patch(Rectangle((cx-w/2, cy-h/2), w, h, fc='white', ec=PRETO,
                           lw=1.4, zorder=6))
    t = ax.text(cx, cy, texto, ha='center', va='center', fontsize=FS_ENT,
                fontweight='bold', color=PRETO, zorder=7)
    caixas.append((t, w, texto))
    return (cx, cy, w, h)

def losango(cx, cy, texto, w=12, h=7, tracejado=False):
    ax.add_patch(Polygon([(cx, cy-h/2), (cx+w/2, cy), (cx, cy+h/2), (cx-w/2, cy)],
                         closed=True, fc='white', ec=PRETO, lw=1.2, zorder=6,
                         linestyle=(0, (4, 2)) if tracejado else '-'))
    ax.text(cx, cy, texto, ha='center', va='center', fontsize=FS_REL,
            color=PRETO, zorder=7)
    return (cx, cy)

def borda(ent, alvo):
    cx, cy, w, h = ent
    dx, dy = alvo[0]-cx, alvo[1]-cy
    if dx == 0 and dy == 0: return cx, cy
    e = min((w/2)/abs(dx) if dx else 9e9, (h/2)/abs(dy) if dy else 9e9)
    return cx+dx*e, cy+dy*e

def liga(ent, los, card, tracejado=False, desloca=(0, 0)):
    x1, y1 = borda(ent, los); x2, y2 = los
    ax.plot([x1, x2], [y1, y2], color=PRETO, lw=1.0, zorder=4,
            linestyle=(0, (4, 2)) if tracejado else '-')
    ax.text(x1+(x2-x1)*0.26+desloca[0], y1+(y2-y1)*0.26+desloca[1], card,
            ha='center', va='center', fontsize=FS_CARD, color=CINZA, zorder=8,
            bbox=dict(boxstyle='round,pad=0.12', fc='white', ec='none'))

# Estrela: DISPOSITIVOS no centro e as outras cinco em volta, nas diagonais.
# Em linha os losangos nao cabiam entre as caixas e as cardinalidades caiam
# dentro deles.
dispositivos  = entidade(39, 28, 'DISPOSITIVOS', 15)
leituras      = entidade(68, 28, 'LEITURAS', 11)
configuracoes = entidade(11, 9,  'CONFIGURACOES', 16)
push          = entidade(12, 47, 'PUSH_DISPOSITIVOS', 19)
comandos      = entidade(63, 7,  'COMANDOS_SYNC', 16)
pendentes     = entidade(58, 49, 'COMANDOS_PENDENTES', 22)

# Cardinalidade (min,max) ao lado da entidade descrevendo a participacao DELA
# no relacionamento - a convencao do Heuser. Cada par abaixo foi conferido no
# codigo do servidor, nao herdado do desenho anterior:
#
#   Tem      dispositivo pode existir sem configuracao: `salvarConfiguracao` so
#            e chamada `if (dispositivoId && config)`, e a leitura faz
#            `join configuracoes` com `if (!row) return null`.   -> (0,1)
#   Gera     `leituras` acumula varias linhas por aparelho.      -> (0,n)
#   Recebe   `salvarComandoSync` grava com `dispositivo_id` nulo quando o
#            aparelho ainda nao esta cadastrado.                 -> (0,1) no comando
#   Possui   `push_dispositivos` tem chave (token_push, identificador_hardware):
#            varios celulares por aparelho.                      -> (0,n)
#
# As cinco ligacoes sao solidas. A versao anterior tracejava duas delas para
# marcar que ligam pelo identificador do aparelho, sem chave estrangeira
# declarada - informacao correta, mas fisica, e um DER de Chen e conceitual.
#   Aguarda  `comandos_pendentes` tem identificador_hardware como chave
#            primaria: no maximo um pendente por aparelho.       -> (0,1)
gera = losango(55, 28, 'Gera')
liga(dispositivos, gera, '(0,n)'); liga(leituras, gera, '(1,1)')

tem = losango(25, 18, 'Tem')
liga(dispositivos, tem, '(0,1)'); liga(configuracoes, tem, '(1,1)')

recebe = losango(51, 17, 'Recebe')
liga(dispositivos, recebe, '(0,n)'); liga(comandos, recebe, '(0,1)')

# 'Possui', e nao 'Registra': num DER o nome e lido da esquerda para a
# direita, e quem registra o token de notificacao e o celular, nao o
# aparelho. 'Possui' descreve a associacao sem inventar o agente.
possui = losango(25, 38, 'Possui')
liga(dispositivos, possui, '(0,n)')
liga(push, possui, '(1,1)')

aguarda = losango(50, 39, 'Aguarda')
liga(dispositivos, aguarda, '(0,1)')
liga(pendentes, aguarda, '(1,1)')

fig.canvas.draw()
inv = ax.transData.inverted()
for t, w, texto in caixas:
    bb = t.get_window_extent(fig.canvas.get_renderer())
    (x0, _), (x1, _) = inv.transform(((bb.x0, bb.y0), (bb.x1, bb.y1)))
    folga = w - abs(x1-x0)
    print(f'  {texto:<20} caixa {w:4.0f} | texto {abs(x1-x0):5.1f} | folga {folga:4.1f}'
          f'  {"ok" if folga > 1.5 else "APERTADO"}')
print(f'figura: {LARG_CM} x {LARG_CM*Y_MAX/X_MAX:.1f} cm | entidade {FS_ENT} pt')
destino = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'der_chen.png')
# pad_inches=0: a margem do savefig e somada FORA da tela da figura, e
# alargaria o PNG alem dos 15,9 cm pretendidos - ao inserir no artigo tudo
# encolheria junto, e a letra nao sairia no tamanho escrito aqui.
fig.savefig(destino, facecolor='white', bbox_inches='tight', pad_inches=0)
print('gerado:', destino)
