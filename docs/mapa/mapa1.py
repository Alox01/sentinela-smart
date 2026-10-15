# Pagina 1 do mapa: a parte eletrica inteira numa figura so, com foto das pecas
# que o produtor tem na mao.
#
# Leitura: de cima para baixo e da esquerda para a direita. A faixa vermelha e o
# 220 V, a azul e a eletronica de 5 V. Os dois fios da tomada tem cor propria o
# tempo todo, para dar para seguir qualquer um deles do plugue ate o motor.
import os

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, Polygon, Ellipse
import matplotlib.image as mpimg

# Recortes das fotos da propria montagem, ao lado deste arquivo.
BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fotos') + '/'

F1 = '#c62828'
F2 = '#1565c0'
V5 = '#1b7a3d'
GND = '#37474f'
SIN = '#7b1fa2'
LAR = '#e07b00'
TXT = '#222222'
CZ = '#666666'

L, A = 160.0, 100.0


def pagina(fig):
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, L)
    ax.set_ylim(A, 0)
    ax.axis('off')
    return ax


def foto(fig, arquivo, x, y, w, h):
    eixo = fig.add_axes([x / L, 1 - (y + h) / A, w / L, h / A])
    eixo.imshow(mpimg.imread(BASE + arquivo))
    eixo.set_xticks([])
    eixo.set_yticks([])
    for lado in eixo.spines.values():
        lado.set_edgecolor('#8d8d8d')
        lado.set_linewidth(1.2)


def titulo(ax, x, y, t, sub='', cor=TXT, fs=8.4):
    ax.text(x, y, t, ha='center', va='center', fontsize=fs, fontweight='bold',
            color=cor, zorder=12)
    if sub:
        ax.text(x, y + 2.7, sub, ha='center', va='center', fontsize=6.0,
                color=CZ, zorder=12, linespacing=1.4)


def caixa(ax, x, y, w, h, t, sub='', cor=TXT, fundo='white', fs=7.4):
    ax.add_patch(FancyBboxPatch((x, y), w, h,
                                boxstyle='round,pad=0.3,rounding_size=0.8',
                                lw=1.2, ec=cor, fc=fundo, zorder=6))
    ax.text(x + w / 2, y + h / 2 - (1.3 if sub else 0), t, ha='center',
            va='center', fontsize=fs, fontweight='bold', color=cor, zorder=7)
    if sub:
        ax.text(x + w / 2, y + h / 2 + 2.2, sub, ha='center', va='center',
                fontsize=5.8, color=CZ, zorder=7)


def wago(ax, x, y, nome, detalhe):
    ax.add_patch(FancyBboxPatch((x - 4.6, y - 3.0), 9.2, 6.0,
                                boxstyle='round,pad=0.2,rounding_size=0.6',
                                lw=1.3, ec=LAR, fc='#fff4e6', zorder=6))
    for i in range(3):
        ax.add_patch(Rectangle((x - 3.6 + i * 2.5, y - 2.4), 1.6, 1.8,
                               fc=LAR, ec='none', zorder=7))
    ax.text(x, y + 1.2, nome, ha='center', va='center', fontsize=7.6,
            fontweight='bold', color='#8a4b00', zorder=8)
    ax.text(x, y - 5.0, detalhe, ha='center', va='center', fontsize=5.5,
            color=CZ, zorder=8, linespacing=1.3)


def fio(ax, pontos, cor, lw=1.9):
    ax.plot([p[0] for p in pontos], [p[1] for p in pontos], color=cor, lw=lw,
            zorder=4, solid_capstyle='round', solid_joinstyle='round')


def terminal(ax, x, y, nome, cor, ha='left', dx=1.4):
    ax.add_patch(Circle((x, y), 0.7, fc=cor, ec='white', lw=0.6, zorder=10))
    ax.text(x + (dx if ha == 'left' else -dx), y, nome, ha=ha, va='center',
            fontsize=6.0, fontweight='bold', color=cor, zorder=11)


def rot(ax, x, y, t, cor=CZ, fs=6.0, ha='center', peso='normal'):
    ax.text(x, y, t, ha=ha, va='center', fontsize=fs, color=cor,
            linespacing=1.45, zorder=11, fontweight=peso)


def ventoinha(ax, x, y, r):
    ax.add_patch(Circle((x, y), r, fc='#eceff1', ec=CZ, lw=1.3, zorder=6))
    for ang in (0, 72, 144, 216, 288):
        ax.add_patch(Ellipse((x, y), r * 1.5, r * 0.5, angle=ang,
                             fc='#b0bec5', ec=CZ, lw=0.7, zorder=7))
    ax.add_patch(Circle((x, y), r * 0.22, fc=CZ, ec=CZ, zorder=8))


def desenhar(fig):
    ax = pagina(fig)

    ax.text(5, 5.5, 'SENTINELA SMART — mapa elétrico do acionamento da '
                    'ventoinha', fontsize=13, fontweight='bold', color='#1f3c88')
    ax.text(5, 9.5, 'Desenhado a partir da montagem de outubro de 2026. '
                    'As fotos são das peças deste aparelho.',
            fontsize=7.2, color=CZ)

    # ---------- faixas ----------
    ax.add_patch(Rectangle((4, 13.5), 152, 41, fc='#fdf2f2', ec='#f0d4d4',
                           lw=1.0, zorder=0))
    ax.text(6, 16.2, '220 V — tire da tomada antes de encostar', fontsize=7.4,
            color=F1, fontweight='bold', zorder=1)
    ax.add_patch(Rectangle((4, 58), 152, 36, fc='#f2f6fd', ec='#d4e0f2',
                           lw=1.0, zorder=0))
    ax.text(6, 60.5, '5 V — a eletrônica', fontsize=7.4, color='#1f3c88',
            fontweight='bold', zorder=1)

    # ================= 220 V =================
    caixa(ax, 7, 26, 12, 9, 'TOMADA', '220 V', cor=F1)
    rot(ax, 13, 39.5, 'cabo PP 2 × 1,5 mm²', CZ, 5.8)
    caixa(ax, 23, 27, 6.5, 7, 'PRENSA', '', cor=CZ, fs=5.8)
    fio(ax, [(19, 30.5), (23, 30.5)], F1)

    fio(ax, [(29.5, 29.5), (32, 29.5), (32, 24), (35.4, 24)], F1)
    fio(ax, [(29.5, 32), (32, 32), (32, 45), (35.4, 45)], F2)

    wago(ax, 40, 24, 'E1', 'entrada · fusível 1 · 1/L1')
    wago(ax, 40, 45, 'E2', 'entrada · fusível 2 · 3/L2')

    caixa(ax, 49, 21, 11, 6, 'FUSÍVEL 2 A', cor=F1, fs=6.4)
    caixa(ax, 49, 42, 11, 6, 'FUSÍVEL 2 A', cor=F1, fs=6.4)
    fio(ax, [(44.6, 24), (49, 24)], F1)
    fio(ax, [(44.6, 45), (49, 45)], F2)

    wago(ax, 67, 24, 'P1', 'fusível 1 · fonte · COM do relé')
    wago(ax, 67, 45, 'P2', 'fusível 2 · fonte · A2 da bobina')
    fio(ax, [(60, 24), (62.4, 24)], F1)
    fio(ax, [(60, 45), (62.4, 45)], F2)

    # ---- contator ----
    foto(fig, 'corte_contator.png', 112, 22, 19, 22)
    titulo(ax, 121.5, 20, 'CONTATOR Soprano CS(T)-12 10')
    rot(ax, 121.5, 46.5, 'bobina 220 V · A1 e A2 no corpo do contator',
        CZ, 5.6)
    rot(ax, 121.5, 49.5, 'o relé fecha a bobina, nunca o motor', CZ, 5.6)
    # Entrada pela esquerda, saida pela direita: e o caminho que o fio faz
    # dentro da caixa, com os WAGO de um lado e a ventoinha do outro.
    terminal(ax, 112, 26, '1/L1', F1, ha='right')
    terminal(ax, 112, 31, '3/L2', F2, ha='right')
    terminal(ax, 131, 26, '2/T1', F1)
    terminal(ax, 131, 31, '4/T2', F2)
    terminal(ax, 112, 38, 'A1', F1, ha='right')
    terminal(ax, 112, 42.5, 'A2', F2, ha='right')

    # ---- motor ----
    ventoinha(ax, 148, 31, 6)
    titulo(ax, 148, 42, 'MOTOR DA VENTOINHA',
           'WEG 1/8 cv · 220 V · 0,86 A')
    fio(ax, [(131, 26), (140, 26), (140, 28), (143, 28)], F1)
    fio(ax, [(131, 31), (137, 31), (137, 34), (143, 34)], F2)
    rot(ax, 137, 23.5, 'cabo PP até a ventoinha', CZ, 5.8)

    # ---- forca: sai dos WAGO de entrada, antes dos fusiveis ----
    fio(ax, [(40, 27.2), (40, 33), (43, 33), (43, 49), (109, 49), (109, 26),
             (112, 26)], F1, 2.3)
    fio(ax, [(44.6, 45), (46, 45), (46, 52), (107, 52), (107, 31),
             (112, 31)], F2, 2.3)
    rot(ax, 40, 56, 'FORÇA DO MOTOR — sai antes dos fusíveis, que protegem só '
                    'a eletrônica', F1, 6.4, peso='bold')

    # ---- bobina ----
    fio(ax, [(112, 42.5), (102, 42.5), (102, 45), (71.6, 45)], F2)
    rot(ax, 90, 40.5, 'A2 ← fio 2 da tomada', F2, 5.8)

    # ================= 5 V =================
    foto(fig, 'corte_fonte.png', 88, 68, 13, 22)
    titulo(ax, 94.5, 65.5, 'FONTE 220 V → 5 V')
    rot(ax, 94.5, 92.5, 'a que saiu do receptor de satélite', CZ, 5.8)
    fio(ax, [(67, 27.2), (84, 27.2), (84, 70), (88, 70)], F1)
    fio(ax, [(71.6, 45), (74, 45), (74, 63), (86, 63), (86, 74), (88, 74)], F2)
    rot(ax, 86, 66.5, 'entrada de 220 V da fonte', CZ, 5.6)

    foto(fig, 'corte_placa.png', 8, 68, 15, 22)
    titulo(ax, 15.5, 65.5, 'PLACA PERFURADA + ESP32')
    rot(ax, 15.5, 92.5, 'os 12 bornes: ver página 2', CZ, 5.8)

    caixa(ax, 46, 68, 17, 12, 'MÓDULO RELÉ', '1 canal · 5 V · dispara em LOW',
          cor='#1f3c88')
    terminal(ax, 46, 71, 'IN', SIN, ha='right')
    terminal(ax, 46, 75, 'VCC', V5, ha='right')
    terminal(ax, 46, 79, 'GND', GND, ha='right')
    terminal(ax, 63, 72, 'COM', F1)
    terminal(ax, 63, 77, 'NO', F1)

    # BC547 + 1k entre o GPIO 16 e o IN
    ax.add_patch(Polygon([(37, 67.5), (37, 74.5), (42.5, 71)], closed=True,
                         fc='white', ec=TXT, lw=1.2, zorder=7))
    rot(ax, 39.3, 71, 'BC547', TXT, 5.4, peso='bold')
    ax.add_patch(FancyBboxPatch((30, 69.8), 5, 2.4,
                                boxstyle='round,pad=0.15,rounding_size=0.4',
                                lw=1.1, ec=SIN, fc='#f5eefa', zorder=7))
    rot(ax, 32.5, 71, '1 kΩ', SIN, 5.4, peso='bold')
    fio(ax, [(23, 71), (30, 71)], SIN, 1.6)
    fio(ax, [(35, 71), (37, 71)], SIN, 1.6)
    fio(ax, [(42.5, 71), (46, 71)], SIN, 1.6)
    rot(ax, 27, 68.5, 'GPIO 16', SIN, 6.4, peso='bold')
    rot(ax, 27, 74.5, 'serigrafia\nRX2', SIN, 5.2)
    # emissor ao terra
    fio(ax, [(39.7, 74.5), (39.7, 85), (24, 85)], GND, 1.5)
    rot(ax, 32, 86.5, 'emissor → GND', GND, 5.6)

    # 5 V e GND da fonte, barramentos horizontais abaixo das fotos
    fio(ax, [(88, 80), (82, 80), (82, 88), (28, 88), (28, 80), (23, 80)],
        V5, 1.7)
    fio(ax, [(88, 84), (80, 84), (80, 91), (26, 91), (26, 84), (23, 84)],
        GND, 1.7)
    fio(ax, [(44, 88), (44, 75), (46, 75)], V5, 1.6)
    fio(ax, [(42, 91), (42, 79), (46, 79)], GND, 1.6)
    rot(ax, 62, 86.6, '5 V', V5, 6.4, peso='bold')
    rot(ax, 62, 93, 'GND — o mesmo para a placa, o relé e o transistor',
        GND, 5.8)

    # COM e NO: o fio 1 protegido entra, e sai para a bobina
    fio(ax, [(67, 27.2), (80, 27.2), (80, 59), (70, 59), (70, 72), (63, 72)],
        F1, 1.7)
    rot(ax, 74, 68, 'fio 1 protegido → COM', F1, 5.8)
    fio(ax, [(63, 77), (66, 77), (66, 63), (104, 63), (104, 38), (112, 38)],
        F1, 1.7)
    rot(ax, 90, 60, 'NO → A1 da bobina: é este contato que liga o motor',
        F1, 6.2, peso='bold')

    # ---------- legenda ----------
    legenda = [(F1, 'fio 1 da tomada'), (F2, 'fio 2 da tomada'),
               (V5, '5 V'), (GND, 'GND (comum)'), (SIN, 'sinal do ESP32')]
    x = 7
    for cor, texto in legenda:
        ax.plot([x, x + 4.5], [97.5, 97.5], color=cor, lw=2.6,
                solid_capstyle='round')
        ax.text(x + 5.5, 97.5, texto, ha='left', va='center', fontsize=6.4,
                color=TXT)
        x += 26
    ax.text(154, 97.5, 'pág. 1 de 4', ha='right', va='center', fontsize=6.4,
            color=CZ)
