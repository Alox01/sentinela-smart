# Pagina 2: mapa da placa perfurada como ela esta montada hoje.
import matplotlib
matplotlib.use('Agg')
from matplotlib.patches import FancyBboxPatch, Circle

F1 = '#c62828'
V5 = '#1b7a3d'
GND = '#37474f'
AZ = '#1f3c88'
TXT = '#222222'
CZ = '#666666'
VERDE_PLACA = '#17603a'

L, A = 160.0, 100.0

CIMA = [
    ('A', 'VIN  (5 V da fonte)', V5),
    ('C', 'terra', GND),
    ('F', 'D25 — buzina', AZ),
    ('H', 'terra', GND),
    ('K', 'D14 — LED de controle', CZ),
    ('M', 'D26 — LED de alerta', AZ),
    ('P', 'D27 — LED de umidade', AZ),
    ('R', 'terra comum dos LEDs', GND),
    ('U', 'D13 — botão do buzzer', AZ),
    ('W', 'D33 — botão vermelho', AZ),
    ('Z', 'D4 — botão verde', AZ),
    ('B₂', 'terra comum dos botões', GND),
]

BAIXO = [
    ('A', '3V3 — display', V5),
    ('C', 'terra — display', GND),
    ('F', 'D18 = CLK do display', AZ),
    ('H', 'D19 = DIO do display', AZ),
    ('K', 'terra — DHT22 e DS18B20', GND),
    ('M', '3V3 — DS18B20', V5),
    ('P', 'D32 — dado do DHT22', AZ),
    ('R', '3V3 — DHT22', V5),
    ('U', 'D35 — DO do sensor de chama', AZ),
    ('W', '3V3 — sensor de chama', V5),
    ('Z', 'terra — sensor de chama', GND),
    ('B₂', 'D23 — DS18B20', AZ),
]

CARTOES_CIMA = [
    ('ALIMENTAÇÃO', 'vias A e C', 'os 5 V da fonte entram por aqui'),
    ('BUZINA', 'vias F e H', 'toca em alarme e em fogo'),
    ('LEDs', 'vias K · M · P · R', '220 Ω em cada · um terra para os três'),
    ('BOTÕES', 'vias U · W · Z · B₂', 'alarme · visor · ajuste · terra comum'),
]
CARTOES_BAIXO = [
    ('DISPLAY TM1637', 'vias A · C · F · H', '3V3, terra, CLK e DIO'),
    ('DHT22 — umidade', 'vias K · P · R', 'pull-up de 4,7 kΩ entre P e R'),
    ('DS18B20 — temperatura', 'vias K · M · B₂',
     'pull-up de 4,7 kΩ entre M e B₂'),
    ('SENSOR DE CHAMA', 'vias U · W · Z', 'DO, 3V3 e terra · fica na cabine'),
]


def rot(ax, x, y, t, cor=CZ, fs=6.0, ha='center', peso='normal', rodado=0):
    ax.text(x, y, t, ha=ha, va='center', fontsize=fs, color=cor, zorder=11,
            fontweight=peso, rotation=rodado, linespacing=1.4)


def cartoes(ax, dados, y, cor_borda=AZ):
    larg, folga = 31, 2.5
    x = 22
    for nome, vias, sub in dados:
        ax.add_patch(FancyBboxPatch((x, y), larg, 10,
                                    boxstyle='round,pad=0,rounding_size=0.8',
                                    fc='white', ec=cor_borda, lw=1.1,
                                    zorder=8))
        rot(ax, x + larg / 2, y + 3, nome, cor_borda, 7.0, peso='bold')
        rot(ax, x + larg / 2, y + 6, vias, TXT, 6.0, peso='bold')
        rot(ax, x + larg / 2, y + 8.6, sub, CZ, 5.3)
        x += larg + folga


def desenhar(fig):
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, L)
    ax.set_ylim(A, 0)
    ax.axis('off')

    ax.text(5, 5.5, 'A PLACA PERFURADA, COMO ESTÁ MONTADA',
            fontsize=13, fontweight='bold', color=AZ)
    ax.text(5, 9.5, 'Montada em 26–29/08 e 01/09/2026; o DS18B20 entrou em '
                    '09/09 e ocupou as duas vias que ainda estavam livres. '
                    'Os nomes das vias são os da serigrafia da própria placa.',
            fontsize=7.2, color=CZ)

    cartoes(ax, CARTOES_CIMA, 13)
    cartoes(ax, CARTOES_BAIXO, 83)

    # ---------- placa ----------
    x0, x1, y0, y1 = 22, 152, 42, 64
    ax.add_patch(FancyBboxPatch((x0, y0), x1 - x0, y1 - y0,
                                boxstyle='round,pad=0,rounding_size=1',
                                fc='#dff0e4', ec=VERDE_PLACA, lw=1.6,
                                zorder=2))
    for i in range(int((x1 - x0) / 2.4)):
        for j in range(int((y1 - y0) / 2.4)):
            ax.add_patch(Circle((x0 + 1.8 + i * 2.4, y0 + 1.8 + j * 2.4), 0.3,
                                fc='#b5d6c0', ec='none', zorder=3))

    # ESP32
    ax.add_patch(FancyBboxPatch((56, 47), 44, 12,
                                boxstyle='round,pad=0,rounding_size=0.8',
                                fc='#2b2b2b', ec='#111111', lw=1.2, zorder=5))
    rot(ax, 78, 50.5, 'ESP32 DevKit', 'white', 8.4, peso='bold')
    rot(ax, 78, 54, 'nas barras fêmea — sai e entra sem dessoldar nada',
        '#cfd8dc', 5.8)
    rot(ax, 78, 57, 'colunas G a U, linhas 12 e 22', '#90a4ae', 5.4)

    # barramentos, rotulados fora da placa
    ax.plot([x0 + 2, x1 - 2], [44.5, 44.5], color=GND, lw=2.0, zorder=6)
    rot(ax, 20, 44.5, 'TERRA (linha 6)', GND, 5.6, ha='right', peso='bold')
    ax.plot([x0 + 2, x1 - 2], [61, 61], color=GND, lw=2.0, zorder=6)
    rot(ax, 20, 61, 'TERRA (linha 28)', GND, 5.6, ha='right', peso='bold')
    ax.plot([x0 + 2, 128], [62.8, 62.8], color=V5, lw=2.0, zorder=6)
    rot(ax, 20, 62.8, '3V3 (linha 26)', V5, 5.6, ha='right', peso='bold')

    # ---------- vias ----------
    passo = (x1 - x0 - 12) / 11.0

    def fileira(lista, y_via, y_texto, acima):
        for i, (via, texto, cor) in enumerate(lista):
            x = x0 + 6 + i * passo
            ax.add_patch(FancyBboxPatch((x - 3.4, y_via - 2.3), 6.8, 4.6,
                                        boxstyle='round,pad=0,rounding_size=0.5',
                                        fc='#1565c0', ec='#0d3f7a', lw=0.9,
                                        zorder=7))
            rot(ax, x, y_via, via, 'white', 6.8, peso='bold')
            ax.plot([x, x], [y_via + (-2.7 if acima else 2.7), y_texto],
                    color=cor, lw=1.3, zorder=6)
            rot(ax, x, y_texto + (-1 if acima else 1), texto, cor, 5.7,
                ha='right' if acima else 'left', rodado=90)

    fileira(CIMA, 42, 28, True)
    fileira(BAIXO, 64, 78, False)

    rot(ax, 16, 42, 'BORDA DE CIMA\n(linha 4)', TXT, 6.2, ha='right',
        peso='bold')
    rot(ax, 16, 64, 'BORDA DE BAIXO\n(linha 30)', TXT, 6.2, ha='right',
        peso='bold')

    # ---------- relé ----------
    ax.add_patch(FancyBboxPatch((104, 47), 44, 12,
                                boxstyle='round,pad=0,rounding_size=0.8',
                                fc='#fff8e1', ec='#b8860b', lw=1.2, zorder=5))
    rot(ax, 126, 50, 'O RELÉ DA VENTOINHA VAI SOLDADO AQUI', '#8a6d00', 6.4,
        peso='bold')
    rot(ax, 126, 53, 'Não sobrou via de borne. GPIO 16 → 1 kΩ → base do '
                     'BC547;', '#8a6d00', 5.6)
    rot(ax, 126, 56, 'emissor → terra; coletor → IN do módulo; VCC → 5 V.',
        '#8a6d00', 5.6)

    rot(ax, 80, 97, 'A via K da borda de cima está no mapa porque a placa foi '
                    'feita para três LEDs. O terceiro — controle, D14 — nunca '
                    'foi instalado: são dois LEDs.', CZ, 6.2)
    ax.text(154, 97, 'pág. 2 de 4', ha='right', va='center', fontsize=6.4,
            color=CZ)
