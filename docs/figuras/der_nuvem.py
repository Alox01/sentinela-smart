# -*- coding: utf-8 -*-
"""DER do banco em nuvem (PostgreSQL/Supabase), desenhado a partir de
database/schema.sql.

Inclui as SETE tabelas. O bloco Mermaid de docs/DIAGRAMAS.md mostra quatro:
push_dispositivos, comandos_pendentes e comandos_agendados nasceram depois,
direto no db.js, e nunca entraram no diagrama. Ficar de fora do desenho foi o
mesmo motivo de elas terem escapado da revisao de RLS uma vez.

Gera:  python docs/figuras/der_nuvem.py
"""
import os

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle

AZUL = '#1f3c88'
AZUL_FRACO = '#eaeff9'
CINZA = '#555555'
PRETO = '#222222'
VERDE = '#17603a'

LINHA = 3.1          # altura de cada coluna da tabela
CABECALHO = 5.0

fig = plt.figure(figsize=(15.5, 10.6), dpi=200)
ax = fig.add_axes([0, 0, 1, 1])
ax.set_xlim(0, 162)
ax.set_ylim(112, 0)
ax.axis('off')


def entidade(x, y, largura, nome, colunas):
    """Caixa de tabela: barra com o nome e uma linha por coluna.

    Devolve (esquerda, direita, meio_vertical) para as linhas de relacao.
    """
    altura = CABECALHO + LINHA * len(colunas) + 1.4
    ax.add_patch(FancyBboxPatch((x, y), largura, altura,
                                boxstyle='round,pad=0,rounding_size=0.8',
                                fc='white', ec=AZUL, lw=1.3, zorder=3))
    ax.add_patch(Rectangle((x, y), largura, CABECALHO, fc=AZUL_FRACO,
                           ec='none', zorder=4))
    ax.plot([x, x + largura], [y + CABECALHO, y + CABECALHO], color=AZUL,
            lw=1.0, zorder=5)
    ax.text(x + largura / 2, y + CABECALHO / 2, nome, ha='center',
            va='center', fontsize=9, fontweight='bold', color=AZUL, zorder=6)

    for i, (campo, tipo, marca) in enumerate(colunas):
        ly = y + CABECALHO + 1.0 + LINHA * i + LINHA / 2
        cor = VERDE if marca else PRETO
        peso = 'bold' if marca else 'normal'
        ax.text(x + 2.2, ly, campo, ha='left', va='center', fontsize=6.6,
                color=cor, fontweight=peso, zorder=6)
        ax.text(x + largura - 2.2, ly, tipo + ('  ' + marca if marca else ''),
                ha='right', va='center', fontsize=6.0, color=CINZA, zorder=6)
    return (x, x + largura, y + altura / 2, y, y + altura)


def relacao(origem, destino, texto, tracejada=False, desvio=None,
            por_cima=False, rotulo_em=None):
    """Liga duas entidades.

    Com por_cima, o caminho sobe acima de todas as caixas antes de atravessar:
    e o unico jeito de alcancar a coluna da direita sem passar por dentro de
    `leituras`, que ocupa a faixa do meio de ponta a ponta.
    """
    estilo = (0, (4, 2)) if tracejada else '-'
    cor_texto = '#8a6d00' if tracejada else CINZA
    if por_cima:
        xo = (origem[0] + origem[1]) / 2
        ax.plot([xo, xo, desvio, desvio, destino[0]],
                [origem[3], 4, 4, destino[2], destino[2]],
                color=CINZA, lw=1.2, zorder=2, linestyle=estilo)
        xr, yr = (desvio, rotulo_em if rotulo_em is not None else destino[2])
    else:
        x1 = origem[1] if destino[0] > origem[1] else origem[0]
        x2 = destino[0] if destino[0] > origem[1] else destino[1]
        y1, y2 = origem[2], destino[2]
        meio = desvio if desvio is not None else (x1 + x2) / 2
        ax.plot([x1, meio, meio, x2], [y1, y1, y2, y2], color=CINZA, lw=1.2,
                zorder=2, linestyle=estilo)
        xr, yr = meio, (y1 + y2) / 2
    ax.text(xr, yr, ' ' + texto + ' ', ha='center', va='center',
            fontsize=6.4, color=cor_texto,
            bbox=dict(boxstyle='round,pad=0.25', fc='white', ec='none'),
            zorder=7)


# ------------------------------------------------------------------
dispositivos = entidade(6, 8, 44, 'dispositivos', [
    ('id', 'uuid', 'PK'),
    ('nome', 'text', ''),
    ('identificador_hardware', 'text', 'UK'),
    ('tipo_dispositivo', 'text', ''),
    ('ip_local', 'text', ''),
    ('ativo', 'boolean', ''),
    ('created_at', 'timestamptz', ''),
    ('updated_at', 'timestamptz', ''),
])

configuracoes = entidade(6, 46, 44, 'configuracoes', [
    ('dispositivo_id', 'uuid', 'PK/FK'),
    ('temperatura_meta', 'numeric', ''),
    ('temp_timestamp', 'bigint', ''),
    ('umidade_meta', 'numeric', ''),
    ('umid_timestamp', 'bigint', ''),
    ('modo_silencioso', 'boolean', ''),
    ('modo_silencioso_timestamp', 'bigint', ''),
    ('updated_at', 'timestamptz', ''),
])

comandos_agendados = entidade(6, 84, 44, 'comandos_agendados', [
    ('id', 'bigserial', 'PK'),
    ('identificador_hardware', 'text', ''),
    ('aplicar_em_ms', 'bigint', ''),
    ('payload', 'jsonb', ''),
    ('criado_em', 'timestamptz', ''),
])

leituras = entidade(62, 8, 42, 'leituras', [
    ('id', 'bigserial', 'PK'),
    ('dispositivo_id', 'uuid', 'FK'),
    ('timestamp_leitura', 'timestamptz', ''),
    ('timestamp_origem_ms', 'bigint', ''),
    ('temperatura', 'numeric', ''),
    ('umidade', 'numeric', ''),
    ('temperatura_meta', 'numeric', ''),
    ('umidade_meta', 'numeric', ''),
    ('alerta_incendio', 'boolean', ''),
    ('aviso', 'text', ''),
    ('cor_status', 'text', ''),
    ('fase_atual', 'text', ''),
    ('tem_energia', 'boolean', ''),
    ('tem_internet', 'boolean', ''),
    ('sinal_wifi', 'integer', ''),
    ('aquecedor_ligado', 'boolean', ''),
    ('ventilador_ligado', 'boolean', ''),
    ('umidificador_ligado', 'boolean', ''),
    ('fonte', 'text', ''),
    ('created_at', 'timestamptz', ''),
])

comandos_sync = entidade(116, 8, 42, 'comandos_sync', [
    ('id', 'bigserial', 'PK'),
    ('dispositivo_id', 'uuid', 'FK'),
    ('identificador_hardware', 'text', ''),
    ('payload', 'jsonb', ''),
    ('status', 'text', ''),
    ('origem', 'text', ''),
    ('erro', 'text', ''),
    ('created_at', 'timestamptz', ''),
    ('synced_at', 'timestamptz', ''),
])

push_dispositivos = entidade(116, 52, 42, 'push_dispositivos', [
    ('token_push', 'text', 'PK'),
    ('identificador_hardware', 'text', 'PK'),
    ('plataforma', 'text', ''),
    ('preferencias', 'jsonb', ''),
    ('nome', 'text', ''),
    ('updated_at', 'timestamptz', ''),
])

comandos_pendentes = entidade(116, 86, 42, 'comandos_pendentes', [
    ('identificador_hardware', 'text', 'PK'),
    ('payload', 'jsonb', ''),
    ('updated_at', 'timestamptz', ''),
])

# --- relacoes com chave estrangeira declarada ---
relacao(dispositivos, configuracoes, '1 : 1', desvio=2.5)
relacao(dispositivos, leituras, '1 : N', desvio=56)
relacao(dispositivos, comandos_sync, '1 : N', desvio=108, por_cima=True)

# --- relacoes por identificador, sem FK declarada ---
relacao(dispositivos, push_dispositivos, 'por identificador', True,
        desvio=111, por_cima=True, rotulo_em=40)
relacao(dispositivos, comandos_pendentes, 'por identificador', True,
        desvio=114, por_cima=True, rotulo_em=78)
relacao(dispositivos, comandos_agendados, 'por identificador', True,
        desvio=2.5)

# --- legenda ---
ax.text(62, 104, 'Linha cheia: chave estrangeira declarada, com exclusão em '
                 'cascata.', fontsize=7.4, color=CINZA, ha='left')
ax.text(62, 108, 'Linha tracejada: ligação pelo identificador do aparelho, '
                 'sem chave estrangeira.', fontsize=7.4, color='#8a6d00',
        ha='left')

destino = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       'der_nuvem.png')
fig.savefig(destino, facecolor='white', bbox_inches='tight', pad_inches=0.25)
print('gerado:', destino)
