# -*- coding: utf-8 -*-
"""DER do banco em nuvem na notacao de Chen (retangulo, losango, atributo).

E o mesmo conteudo de der_nuvem.py, que desenha o estilo de tabelas. Este aqui
e o formato que a banca costuma esperar: entidade em retangulo, relacionamento
em losango, atributo em bolinha ligada por linha, chave primaria em bolinha
cheia, e cardinalidade em (minimo, maximo) nas pontas.

Gera:  python docs/figuras/der_chen.py
"""
import math
import os

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Polygon, Circle

PRETO = '#111111'
CINZA = '#555555'
LARANJA = '#8a6d00'

fig = plt.figure(figsize=(19, 13.2), dpi=170)
ax = fig.add_axes([0, 0, 1, 1])
ax.set_xlim(-18, 240)
ax.set_ylim(162, -16)
ax.axis('off')


def entidade(cx, cy, texto, w=30, h=11):
    ax.add_patch(Rectangle((cx - w / 2, cy - h / 2), w, h, fc='white',
                           ec=PRETO, lw=1.5, zorder=6))
    ax.text(cx, cy, texto, ha='center', va='center', fontsize=8.6,
            fontweight='bold', color=PRETO, zorder=7)
    return (cx, cy, w, h)


def losango(cx, cy, texto, w=22, h=11, tracejado=False):
    ax.add_patch(Polygon([(cx, cy - h / 2), (cx + w / 2, cy),
                          (cx, cy + h / 2), (cx - w / 2, cy)], closed=True,
                         fc='white', ec=LARANJA if tracejado else PRETO,
                         lw=1.3, zorder=6,
                         linestyle=(0, (4, 2)) if tracejado else '-'))
    ax.text(cx, cy, texto, ha='center', va='center', fontsize=7.4,
            color=LARANJA if tracejado else PRETO, zorder=7)
    return (cx, cy)


def borda(ent, alvo):
    """Ponto na borda do retangulo na direcao de alvo."""
    cx, cy, w, h = ent
    dx, dy = alvo[0] - cx, alvo[1] - cy
    if dx == 0 and dy == 0:
        return cx, cy
    escala = min((w / 2) / abs(dx) if dx else 9e9,
                 (h / 2) / abs(dy) if dy else 9e9)
    return cx + dx * escala, cy + dy * escala


def liga(ent, los, card, tracejado=False, desloca=(0, 0)):
    x1, y1 = borda(ent, los)
    x2, y2 = los
    ax.plot([x1, x2], [y1, y2], color=LARANJA if tracejado else PRETO,
            lw=1.1, zorder=4,
            linestyle=(0, (4, 2)) if tracejado else '-')
    tx = x1 + (x2 - x1) * 0.28 + desloca[0]
    ty = y1 + (y2 - y1) * 0.28 + desloca[1]
    ax.text(tx, ty, card, ha='center', va='center', fontsize=6.6,
            color=CINZA, zorder=8,
            bbox=dict(boxstyle='round,pad=0.15', fc='white', ec='none'))


def atributos(ent, nomes, ang_ini, ang_fim, raio=19, chave=None, fs=6.3,
              degrau=0.0):
    """Espalha os atributos num leque em volta da entidade.

    Com degrau, os vizinhos saem em raios alternados. E o que salva as
    entidades de muitas colunas: em `leituras` sao vinte nomes compridos, e
    num leque de raio unico os rotulos se encavalam por mais que se abra o
    angulo.
    """
    cx, cy, w, h = ent
    n = len(nomes)
    for i, nome in enumerate(nomes):
        ang = math.radians(ang_ini + (ang_fim - ang_ini) *
                           (i / (n - 1) if n > 1 else 0.5))
        r = raio + (degrau if i % 2 else 0.0)
        ax_, ay = cx + r * math.cos(ang), cy + r * math.sin(ang)
        bx, by = borda(ent, (ax_, ay))
        ax.plot([bx, ax_], [by, ay], color=PRETO, lw=0.8, zorder=3)
        primaria = (nome == chave) or (chave is not None and
                                       isinstance(chave, (list, tuple)) and
                                       nome in chave)
        ax.add_patch(Circle((ax_, ay), 1.0, fc=PRETO if primaria else 'white',
                            ec=PRETO, lw=0.9, zorder=6))
        lado = 'left' if math.cos(ang) >= 0 else 'right'
        ax.text(ax_ + (1.8 if lado == 'left' else -1.8), ay, nome,
                ha=lado, va='center', fontsize=fs,
                fontweight='bold' if primaria else 'normal', color=PRETO,
                zorder=7)


# =====================================================================
# Arranjo em estrela: DISPOSITIVOS no centro, os seis relacionamentos nos
# quatro cantos e nos dois lados, e os atributos de cada entidade apontando
# para fora. Os atributos do centro sobem e descem pelo unico corredor que
# nenhum losango ocupa.
dispositivos = entidade(104, 76, 'DISPOSITIVOS', w=34)
atributos(dispositivos, ['id', 'nome', 'identificador_hardware',
                         'tipo_dispositivo'],
          -112, -68, raio=26, chave='id', fs=6.1, degrau=6.0)
atributos(dispositivos, ['ip_local', 'ativo', 'created_at', 'updated_at'],
          68, 112, raio=26, fs=6.1, degrau=6.0)

configuracoes = entidade(26, 76, 'CONFIGURACOES', w=34)
atributos(configuracoes,
          ['dispositivo_id', 'temperatura_meta', 'temp_timestamp',
           'umidade_meta', 'umid_timestamp', 'modo_silencioso',
           'modo_silencioso_timestamp', 'updated_at'],
          100, 260, raio=23, chave='dispositivo_id', degrau=8.0)

leituras = entidade(190, 76, 'LEITURAS', w=30)
atributos(leituras,
          ['id', 'dispositivo_id', 'timestamp_leitura', 'timestamp_origem_ms',
           'temperatura', 'umidade', 'temperatura_meta', 'umidade_meta',
           'alerta_incendio', 'aviso'],
          -94, -4, raio=28, chave='id', degrau=13.0, fs=5.9)
atributos(leituras,
          ['cor_status', 'fase_atual', 'tem_energia', 'tem_internet',
           'sinal_wifi', 'aquecedor_ligado', 'ventilador_ligado',
           'umidificador_ligado', 'fonte', 'created_at'],
          4, 94, raio=28, degrau=13.0, fs=5.9)

comandos = entidade(176, 20, 'COMANDOS_SYNC', w=36)
atributos(comandos,
          ['id', 'dispositivo_id', 'identificador_hardware', 'payload',
           'status', 'origem', 'erro', 'created_at', 'synced_at'],
          -150, -30, raio=20, chave='id', degrau=7.5)

push = entidade(30, 20, 'PUSH_DISPOSITIVOS', w=38)
atributos(push,
          ['token_push', 'identificador_hardware', 'plataforma',
           'preferencias', 'nome', 'updated_at'],
          -150, -30, raio=20, degrau=7.5,
          chave=['token_push', 'identificador_hardware'])

pendentes = entidade(176, 128, 'COMANDOS_PENDENTES', w=40)
atributos(pendentes,
          ['identificador_hardware', 'payload', 'updated_at'],
          38, 142, raio=17, chave='identificador_hardware', degrau=5.0)

agendados = entidade(30, 128, 'COMANDOS_AGENDADOS', w=40)
atributos(agendados,
          ['id', 'identificador_hardware', 'aplicar_em_ms', 'payload',
           'criado_em'],
          38, 142, raio=17, chave='id', degrau=5.0)

# ---- relacionamentos ----
tem = losango(65, 76, 'Tem')
liga(dispositivos, tem, '(1,1)')
liga(configuracoes, tem, '(1,1)')

gera = losango(146, 76, 'Gera')
liga(dispositivos, gera, '(1,1)')
liga(leituras, gera, '(0,n)')

recebe = losango(146, 40, 'Recebe')
liga(dispositivos, recebe, '(1,1)')
liga(comandos, recebe, '(0,n)')

registra = losango(62, 40, 'Registra', tracejado=True)
liga(dispositivos, registra, '(1,1)', tracejado=True)
liga(push, registra, '(0,n)', tracejado=True)

aguarda = losango(146, 112, 'Aguarda', tracejado=True)
liga(dispositivos, aguarda, '(1,1)', tracejado=True)
liga(pendentes, aguarda, '(0,1)', tracejado=True)

agenda = losango(62, 112, 'Agenda', tracejado=True)
liga(dispositivos, agenda, '(1,1)', tracejado=True)
liga(agendados, agenda, '(0,n)', tracejado=True)

# ---- legenda ----
ax.add_patch(Circle((70, 156), 1.0, fc=PRETO, ec=PRETO, lw=0.9, zorder=6))
ax.text(73, 156, 'chave primária', ha='left', va='center', fontsize=7,
        color=PRETO)
ax.add_patch(Circle((96, 156), 1.0, fc='white', ec=PRETO, lw=0.9, zorder=6))
ax.text(99, 156, 'atributo comum', ha='left', va='center', fontsize=7,
        color=PRETO)
ax.plot([124, 128], [156, 156], color=LARANJA, lw=1.1, linestyle=(0, (4, 2)))
ax.text(130, 156, 'ligação pelo identificador do aparelho, sem chave '
                  'estrangeira declarada', ha='left', va='center', fontsize=7,
        color=LARANJA)

destino = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       'der_chen.png')
fig.savefig(destino, facecolor='white', bbox_inches='tight', pad_inches=0.3)
print('gerado:', destino)
