#!/usr/bin/env python3
"""Limpa a franja verde do recorte sem mexer na lataria.

Pixel transparente vira preto transparente. Fora isso, só são tocados pixels da borda (semitransparentes, que misturam carro e fundo), pixels quase
verde puro (buraco de grade) e pixels em que o verde passa com folga do vermelho e do azul
(fundo visto por grade e farol). Amarelo e laranja têm vermelho alto e ficam como estão: o
despill em todos os pixels é que deixava o táxi laranja. Carro pintado de verde perderia cor.

Buraco cercado pelo carro (sem ligação com a borda da imagem) é vidro ou grade: o fundo verde
aparecia pelo para-brisa, que no GTA não aceita película. Esses pixels viram vidro escuro.

    ffmpeg ... -f rawvideo -pix_fmt rgba - | borda.py LARGURA ALTURA | ffmpeg -f rawvideo ...
"""
import sys
from collections import deque

GLASS = (12, 13, 15, 255)  # vidro fosco, quase preto, sem transparência

width, height = int(sys.argv[1]), int(sys.argv[2])
data = bytearray(sys.stdin.buffer.read())

# Fundo de verdade: tudo que não é opaco e se liga à borda da imagem.
outside = bytearray(width * height)
queue = deque()
for x in range(width):
    queue.append(x)
    queue.append((height - 1) * width + x)
for y in range(height):
    queue.append(y * width)
    queue.append(y * width + width - 1)
while queue:
    p = queue.popleft()
    if outside[p] or data[p * 4 + 3] == 255:
        continue
    outside[p] = 1
    x, y = p % width, p // width
    if x > 0: queue.append(p - 1)
    if x < width - 1: queue.append(p + 1)
    if y > 0: queue.append(p - width)
    if y < height - 1: queue.append(p + width)

for p in range(width * height):
    i = p * 4
    a = data[i + 3]
    if a == 255 or outside[p]:
        continue
    # Vidro: compõe o que sobrou do pixel sobre o vidro escuro.
    for k in range(3):
        data[i + k] = (data[i + k] * a + GLASS[k] * (255 - a)) // 255
    data[i + 3] = a + GLASS[3] * (255 - a) // 255

for i in range(0, len(data), 4):
    r, g, b, a = data[i], data[i + 1], data[i + 2], data[i + 3]
    # Transparente ainda guarda o verde do fundo por baixo, e a redução (lanczos) mistura
    # vizinhos: sem zerar a cor, esse verde vaza para a borda do carro.
    if a == 0 or (g > 150 and r < 110 and b < 110 and g - max(r, b) > 90):
        data[i:i + 4] = b'\0\0\0\0'
        continue
    elif (a < 255 and g > max(r, b)) or g - max(r, b) > 40:
        data[i + 1] = max(r, b)  # borda/fundo misturado: tira o verde
sys.stdout.buffer.write(data)
