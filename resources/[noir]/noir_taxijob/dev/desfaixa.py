#!/usr/bin/env python3
"""Desfaz as faixas da captura de tela do FiveM Enhanced.

O Enhanced entrega a imagem do jogo com cada linha completada até 256 bytes, e o CEF lê sem a
sobra: em larguras fora de múltiplos de 64 px cada linha começa um pouco adiante e a foto vira
faixas. Relendo o buffer com a largura de linha real (pitch) a imagem volta. As últimas linhas
não existem nos dados e repetem a última lida.

    ffmpeg -i cru.png -f rawvideo -pix_fmt rgba - | desfaixa.py LARGURA ALTURA | ffmpeg -f rawvideo ...
"""
import sys

width, height = int(sys.argv[1]), int(sys.argv[2])
pitch = -(-width * 4 // 256) * 64
data = sys.stdin.buffer.read()
row_bytes, pitch_bytes = width * 4, pitch * 4
out, last = bytearray(), b'\0' * row_bytes
for row in range(height):
    start = row * pitch_bytes
    if start + row_bytes <= len(data):
        last = data[start:start + row_bytes]
    out += last
sys.stdout.buffer.write(out)
