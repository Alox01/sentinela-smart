# Pagina 4: as duas tabelas - os pinos do ESP32 e a parte de 220 V.
import matplotlib
matplotlib.use('Agg')
from matplotlib.patches import FancyBboxPatch, Rectangle

AZ = '#1f3c88'
TXT = '#222222'
CZ = '#666666'
VERM = '#c62828'
V5 = '#1b7a3d'
LAR = '#8a4b00'

L, A = 160.0, 100.0

PINOS = [
    ('VIN', '5 V da fonte', 'cima · via A', 'trilho +', ''),
    ('GND', 'terra comum', 'cima · C H R B₂  /  baixo · C K Z', 'trilho −',
     'um só retorno para LEDs e botões'),
    ('3V3', 'alimentação dos sensores', 'baixo · A R W M', 'trilho de 3,3 V',
     ''),
    ('D4', 'botão verde — ajuste e +', 'cima · via Z', 'linha b ou i', ''),
    ('D13', 'botão do buzzer — silencia e trava a ventoinha', 'cima · via U',
     'linha b ou i', 'segurar 3 s liga/desliga o alarme'),
    ('D33', 'botão vermelho — troca o visor e −', 'cima · via W',
     'linha b ou i', ''),
    ('D25', 'buzina', 'cima · via F', 'linha b ou i', ''),
    ('D26', 'LED de alerta', 'cima · via M', 'linha b ou i', '220 Ω em série'),
    ('D27', 'LED de umidade', 'cima · via P', 'linha b ou i', '220 Ω em série'),
    ('D14', 'LED de controle', 'cima · via K', '—',
     'NUNCA FOI INSTALADO — são dois LEDs'),
    ('D18', 'display TM1637 — CLK', 'baixo · via F', 'linha b ou i', ''),
    ('D19', 'display TM1637 — DIO', 'baixo · via H', 'linha b ou i', ''),
    ('D32', 'DHT22 — dado (umidade)', 'baixo · via P', 'linha b ou i',
     '4,7 kΩ até o 3V3'),
    ('D23', 'DS18B20 — dado (temperatura)', 'baixo · via B₂', 'linha b ou i',
     '4,7 kΩ até o 3V3'),
    ('D35', 'sensor de chama — DO', 'baixo · via U', 'linha b ou i',
     'só entrada, sem pull-up interno'),
    ('D16', 'relé da ventoinha', 'soldado direto (sem via livre)',
     'linha b ou i', '1 kΩ + BC547 · serigrafia RX2'),
]

FORCA = [
    ('E1', 'fio 1 da tomada  ·  entrada do fusível 1  ·  1/L1 do contator',
     'o motor sai daqui, antes do fusível'),
    ('E2', 'fio 2 da tomada  ·  entrada do fusível 2  ·  3/L2 do contator',
     'o motor sai daqui, antes do fusível'),
    ('P1', 'saída do fusível 1  ·  fonte 220 V  ·  COM do relé',
     'protegido por 2 A'),
    ('P2', 'saída do fusível 2  ·  fonte 220 V  ·  A2 da bobina',
     'protegido por 2 A'),
]


def rot(ax, x, y, t, cor=CZ, fs=6.2, ha='left', peso='normal'):
    ax.text(x, y, t, ha=ha, va='center', fontsize=fs, color=cor, zorder=6,
            fontweight=peso)


def desenhar(fig):
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, L)
    ax.set_ylim(A, 0)
    ax.axis('off')

    ax.text(5, 5.5, 'TABELA DE LIGAÇÕES', fontsize=13, fontweight='bold',
            color=AZ)
    ax.text(5, 9.5, 'Os nomes dos pinos são os da serigrafia do ESP32; as '
                    'vias são as da placa perfurada (página 2).',
            fontsize=7.2, color=CZ)

    # ---------- tabela dos pinos ----------
    cols = [(6, 'PINO'), (18, 'O QUE É'), (72, 'PLACA PERFURADA'),
            (108, 'PROTOBOARD'), (126, 'OBSERVAÇÃO')]
    y = 15
    ax.add_patch(Rectangle((5, y - 3), 150, 5, fc=AZ, ec='none', zorder=2))
    for x, nome in cols:
        rot(ax, x, y - 0.5, nome, 'white', 6.6, peso='bold')

    y += 3.8
    for i, (pino, oque, placa, proto, obs) in enumerate(PINOS):
        if i % 2 == 0:
            ax.add_patch(Rectangle((5, y - 1.6), 150, 3.2, fc='#f4f6fa',
                                   ec='none', zorder=1))
        cor_pino = VERM if pino == 'D14' else (
            V5 if pino in ('VIN', '3V3', 'GND') else AZ)
        rot(ax, 6, y, pino, cor_pino, 6.6, peso='bold')
        rot(ax, 18, y, oque, TXT, 6.2)
        rot(ax, 72, y, placa, TXT, 6.2)
        rot(ax, 108, y, proto, CZ, 6.2)
        rot(ax, 126, y, obs, VERM if pino == 'D14' else CZ, 6.0)
        y += 3.2

    # ---------- tabela do 220 V ----------
    y += 3
    ax.text(5, y - 4, 'OS QUATRO WAGO DA PARTE DE 220 V', fontsize=9,
            fontweight='bold', color=VERM)
    ax.add_patch(Rectangle((5, y - 1.5), 150, 5, fc=VERM, ec='none', zorder=2))
    rot(ax, 6, y + 1, 'WAGO', 'white', 6.6, peso='bold')
    rot(ax, 18, y + 1, 'O QUE SE JUNTA DENTRO DELE', 'white', 6.6, peso='bold')
    rot(ax, 108, y + 1, 'OBSERVAÇÃO', 'white', 6.6, peso='bold')
    y += 5.2
    for i, (nome, junta, obs) in enumerate(FORCA):
        if i % 2 == 0:
            ax.add_patch(Rectangle((5, y - 1.6), 150, 3.2, fc='#fdf4f4',
                                   ec='none', zorder=1))
        rot(ax, 6, y, nome, LAR, 6.6, peso='bold')
        rot(ax, 18, y, junta, TXT, 6.2)
        rot(ax, 108, y, obs, CZ, 6.0)
        y += 3.2

    # ---------- a regra que governa tudo isso ----------
    y += 0.5
    ax.add_patch(FancyBboxPatch((5, y), 150, 7.8,
                                boxstyle='round,pad=0,rounding_size=1',
                                fc='#f3f9f4', ec=V5, lw=1.2, zorder=3))
    rot(ax, 10, y + 2.4, 'A REGRA DA VENTOINHA, NO FIRMWARE', V5, 7.2,
        peso='bold')
    rot(ax, 10, y + 5.2, 'Liga 2 °F abaixo do ajuste e desliga 1 °F acima. '
                         'Entre duas partidas passam sempre 30 s; parar nunca '
                         'espera. Para na hora com fogo detectado, com a sonda '
                         'falhando ou travada no botão —', TXT, 6.3)
    rot(ax, 10, y + 7.1, 'e nesse caso os dois pontos do visor piscam. No '
                         'boot o GPIO 16 nasce baixo: a ventoinha nunca parte '
                         'sozinha ao ligar o aparelho.', TXT, 6.3)

    ax.text(154, 8, 'pág. 4 de 4', ha='right', va='center', fontsize=6.4,
            color=CZ)
