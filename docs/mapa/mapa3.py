# Pagina 3: o mesmo aparelho montado em protoboard, com os mesmos pinos.
import matplotlib
matplotlib.use('Agg')
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, Polygon

V5 = '#1b7a3d'
GND = '#37474f'
SIN = '#7b1fa2'
AZ = '#1f3c88'
VERM = '#c62828'
TXT = '#222222'
CZ = '#666666'

L, A = 160.0, 100.0

# ESP32 DevKit de 30 pinos, na ordem em que as pernas saem da placa.
ESQ = ['EN', 'VP', 'VN', 'D34', 'D35', 'D32', 'D33', 'D25', 'D26', 'D27',
       'D14', 'D12', 'D13', 'GND', 'VIN']
DIR = ['D23', 'D22', 'TX0', 'RX0', 'D21', 'D19', 'D18', 'D5', 'TX2', 'RX2',
       'D4', 'D2', 'D15', 'GND', '3V3']

# pino -> (o que liga, cor)
USADOS = {
    'D35': ('sensor de chama  DO', AZ),
    'D32': ('DHT22  dado', AZ),
    'D33': ('botão vermelho', AZ),
    'D25': ('buzina', AZ),
    'D26': ('LED alerta  220 Ω', AZ),
    'D27': ('LED umidade  220 Ω', AZ),
    'D13': ('botão do buzzer', AZ),
    'VIN': ('→ trilho +', V5),
    'GND': ('→ trilho −', GND),
    'D23': ('DS18B20  dado', AZ),
    'D19': ('display  DIO', AZ),
    'D18': ('display  CLK', AZ),
    'RX2': ('relé da ventoinha  (GPIO 16)', SIN),
    'D4': ('botão verde', AZ),
    '3V3': ('3,3 V dos sensores', V5),
}


def rot(ax, x, y, t, cor=CZ, fs=6.0, ha='center', peso='normal', rodado=0,
        va='center'):
    ax.text(x, y, t, ha=ha, va=va, fontsize=fs, color=cor, zorder=12,
            fontweight=peso, rotation=rodado, linespacing=1.4)


def desenhar(fig):
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, L)
    ax.set_ylim(A, 0)
    ax.axis('off')

    ax.text(5, 5.5, 'O MESMO APARELHO EM PROTOBOARD',
            fontsize=13, fontweight='bold', color=AZ)
    ax.text(5, 9.5, 'Mesmos pinos da placa perfurada — o firmware é o mesmo '
                    'e não sabe em que tipo de placa está rodando.',
            fontsize=7.2, color=CZ)

    # ---------- protoboard ----------
    x0, x1 = 20, 140
    colunas = 30
    passo = (x1 - x0) / colunas
    linhas = {'a': 34, 'b': 37, 'c': 40, 'd': 43, 'e': 46,
              'f': 53, 'g': 56, 'h': 59, 'i': 62, 'j': 65}

    ax.add_patch(FancyBboxPatch((x0 - 4, 22), x1 - x0 + 8, 56,
                                boxstyle='round,pad=0,rounding_size=1.5',
                                fc='#f7f7f4', ec='#c9c9c2', lw=1.4, zorder=1))

    # trilhos de alimentacao
    for y, cor, nome in ((26, VERM, '+'), (29, AZ, '−'),
                         (71, VERM, '+'), (74, AZ, '−')):
        ax.plot([x0 - 1, x1 + 1], [y, y], color=cor, lw=0.9, zorder=2,
                alpha=0.55)
        rot(ax, x0 - 5.5, y, nome, cor, 8, peso='bold')
        for i in range(colunas):
            ax.add_patch(Circle((x0 + passo / 2 + i * passo, y), 0.45,
                                fc='white', ec='#b9b9b2', lw=0.5, zorder=3))

    # bancos
    for nome, y in linhas.items():
        rot(ax, x0 - 2.6, y, nome, CZ, 5.4)
        rot(ax, x1 + 2.6, y, nome, CZ, 5.4)
        for i in range(colunas):
            ax.add_patch(Circle((x0 + passo / 2 + i * passo, y), 0.45,
                                fc='white', ec='#b9b9b2', lw=0.5, zorder=3))
    for i in range(0, colunas, 5):
        rot(ax, x0 + passo / 2 + i * passo, 24, str(i + 1), CZ, 5.2)
        rot(ax, x0 + passo / 2 + i * passo, 76.5, str(i + 1), CZ, 5.2)

    # canaleta
    ax.add_patch(Rectangle((x0 - 4, 48), x1 - x0 + 8, 3, fc='#ebebe6',
                           ec='none', zorder=2))

    # ---------- ESP32 ----------
    col_ini = 5                     # primeira perna na coluna 6
    larg = 15 * passo
    xe = x0 + passo / 2 + col_ini * passo
    ax.add_patch(FancyBboxPatch((xe - passo / 2, linhas['b'] - 1.5), larg,
                                linhas['i'] - linhas['b'] + 3,
                                boxstyle='round,pad=0,rounding_size=0.8',
                                fc='#2b2b2b', ec='#111111', lw=1.2, zorder=6,
                                alpha=0.93))
    rot(ax, xe + larg / 2 - passo / 2, 49.5, 'ESP32 DevKit  —  30 pinos',
        'white', 8, peso='bold')
    rot(ax, xe + larg / 2 - passo / 2, 53.5,
        'as pernas caem nas linhas b e i', '#cfd8dc', 5.6)

    # pernas e rotulos
    for k, nome in enumerate(ESQ):
        x = xe + k * passo
        ax.add_patch(Circle((x, linhas['i']), 0.75, fc='#ffd54f',
                            ec='#8d6e00', lw=0.5, zorder=8))
        usado = USADOS.get(nome)
        rot(ax, x, linhas['j'] + 1.5, nome, TXT if usado else '#b0b0b0', 5.2,
            rodado=90, peso='bold' if usado else 'normal', ha='right')
        if usado:
            texto, cor = usado
            ax.plot([x, x], [linhas['j'] + 0.8, 69], color=cor, lw=1.2,
                    zorder=5)
            rot(ax, x, 81, texto, cor, 5.6, rodado=90, ha='right')

    for k, nome in enumerate(DIR):
        x = xe + k * passo
        ax.add_patch(Circle((x, linhas['b']), 0.75, fc='#ffd54f',
                            ec='#8d6e00', lw=0.5, zorder=8))
        usado = USADOS.get(nome)
        rot(ax, x, linhas['a'] - 1.5, nome, TXT if usado else '#b0b0b0', 5.2,
            rodado=90, peso='bold' if usado else 'normal', ha='left')
        if usado:
            texto, cor = usado
            ax.plot([x, x], [linhas['a'] - 0.8, 30], color=cor, lw=1.2,
                    zorder=5)
            rot(ax, x, 14, texto, cor, 5.8, rodado=90, ha='left')

    # ---------- o estagio do rele, desenhado a parte ----------
    ax.add_patch(FancyBboxPatch((8, 84), 66, 14,
                                boxstyle='round,pad=0,rounding_size=1',
                                fc='#faf5fd', ec=SIN, lw=1.2, zorder=4))
    rot(ax, 41, 87.3, 'O ESTÁGIO DO RELÉ, NA PROTOBOARD', SIN, 7.4,
        peso='bold')
    rot(ax, 41, 90.8, 'RX2 (GPIO 16) → 1 kΩ → perna do meio do BC547 (base).  '
                      'Com a face chata virada para você:', TXT, 6.0)
    rot(ax, 41, 93.8, 'esquerda = coletor → IN do módulo  ·  meio = base  ·  '
                      'direita = emissor → trilho −', TXT, 6.0)
    rot(ax, 41, 96.8, 'VCC do módulo → trilho +5 V  ·  GND do módulo → '
                      'trilho −  ·  COM e NO vão à bobina do contator (pág. 1)',
        TXT, 6.0)

    # ---------- avisos ----------
    ax.add_patch(FancyBboxPatch((80, 84), 72, 14,
                                boxstyle='round,pad=0,rounding_size=1',
                                fc='#fffdf5', ec='#b8860b', lw=1.2, zorder=4))
    rot(ax, 116, 87.3, 'O QUE NÃO PODE FALTAR', '#8a6d00', 7.4, peso='bold')
    rot(ax, 116, 90.8, '4,7 kΩ entre D32 e 3V3 (DHT22)  ·  4,7 kΩ entre D23 e '
                       '3V3 (DS18B20)', TXT, 6.0)
    rot(ax, 116, 93.8, '220 Ω em série com cada LED  ·  um terra comum para '
                       'tudo, inclusive a fonte do relé', TXT, 6.0)
    rot(ax, 116, 96.8, 'Botão sem lado certo: os dois sentidos servem  ·  '
                       'o D35 só lê, não tem pull-up interno', TXT, 6.0)

    ax.text(154, 99, 'pág. 3 de 4', ha='right', va='center', fontsize=6.4,
            color=CZ)
