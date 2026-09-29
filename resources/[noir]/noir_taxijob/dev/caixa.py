#!/usr/bin/env python3
"""Menor retângulo com algo visível (alfa > 16) no recorte, no formato do filtro crop do ffmpeg.

O cropdetect do ffmpeg errava o topo por alguns pixels e cortava o luminoso do táxi.

    ffmpeg ... -f rawvideo -pix_fmt rgba - | caixa.py LARGURA ALTURA   ->   crop=w:h:x:y
"""
import sys

width, height = int(sys.argv[1]), int(sys.argv[2])
data = sys.stdin.buffer.read()
alpha = data[3::4]
rows = [y for y in range(height) if max(alpha[y * width:(y + 1) * width]) > 16]
if not rows:
    sys.exit(0)
top, bottom = rows[0], rows[-1]
left, right = width, -1
for y in range(top, bottom + 1):
    line = alpha[y * width:(y + 1) * width]
    for x in range(width):
        if line[x] > 16:
            left = min(left, x)
            break
    for x in range(width - 1, -1, -1):
        if line[x] > 16:
            right = max(right, x)
            break
print(f'crop={right - left + 1}:{bottom - top + 1}:{left}:{top}')
