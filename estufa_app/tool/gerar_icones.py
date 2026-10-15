# Gera o icone do app a partir da arte enviada pelo produtor (logo2).
#
# Dois conjuntos, porque o Android usa dois:
#   - ic_launcher.png por densidade: o icone quadrado dos aparelhos antigos.
#   - icone adaptativo (Android 8+): duas camadas, fundo e frente, que o
#     sistema recorta na forma que o fabricante quiser - circulo, quadrado
#     arredondado, gota. No S25 e um quadrado bem arredondado.
#
# O truque que evita recortar a arte do fundo: a camada de FRENTE leva a imagem
# quadrada inteira, reduzida para caber na zona segura, e a camada de FUNDO e a
# MESMA cor solida do fundo da imagem. A borda do quadrado desaparece dentro do
# fundo, e nada precisa ser mascarado por cor - o que arriscaria furar as
# sombras escuras das folhas, que sao quase da cor do fundo.
import os
from PIL import Image

# Roda de dentro de estufa_app:  python tool/gerar_icones.py
#
# A arte escura e a escolhida: o app inteiro e escuro, e a 48 px o contraste das
# folhas verdes contra o fundo quase preto segura a forma. Na versao clara
# (icone_estufa_smart.png) as folhas creme se fundem num borrao so.
ORIGEM = os.path.join('assets', 'images', 'icone_estufa_smart_escuro_v2.png')
RES = os.path.join('android', 'app', 'src', 'main', 'res')

# Zona segura do icone adaptativo: a arte vive nos 66 dp centrais de um quadro
# de 108 dp. Com a arte ocupando ~70% da imagem de origem, a imagem inteira a
# 80% do quadro deixa o desenho em ~56% - dentro da zona, com folga para a
# mascara mais agressiva.
FRACAO_FRENTE = 0.80

DENSIDADES = {
    'mdpi': 1,
    'hdpi': 1.5,
    'xhdpi': 2,
    'xxhdpi': 3,
    'xxxhdpi': 4,
}

original = Image.open(ORIGEM).convert('RGB')
fundo = original.getpixel((2, 2))
cor_fundo = '#%02X%02X%02X' % fundo


def quadro(dp, escala):
    return int(round(dp * escala))


for nome, escala in DENSIDADES.items():
    pasta = os.path.join(RES, 'mipmap-' + nome)
    os.makedirs(pasta, exist_ok=True)

    # 1. Icone quadrado de sempre (48 dp).
    lado = quadro(48, escala)
    original.resize((lado, lado), Image.LANCZOS).save(
        os.path.join(pasta, 'ic_launcher.png')
    )

    # 2. Camada de frente do icone adaptativo (108 dp), com a arte centrada e
    #    o resto transparente.
    canvas = quadro(108, escala)
    arte = quadro(int(108 * FRACAO_FRENTE), escala)
    frente = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    frente.paste(
        original.resize((arte, arte), Image.LANCZOS),
        ((canvas - arte) // 2, (canvas - arte) // 2),
    )
    frente.save(os.path.join(pasta, 'ic_launcher_foreground.png'))

    # 3. Imagem da tela de abertura. Menor de proposito: ela aparece no meio da
    #    tela inteira, nao dentro de um icone.
    abertura = quadro(120, escala)
    original.resize((abertura, abertura), Image.LANCZOS).save(
        os.path.join(pasta, 'launch_image.png')
    )

print('cor de fundo:', cor_fundo)
print('icones gerados')
