#!/usr/bin/env bash
# Recorta as fotos cruas do /taxifotos (fundo verde) e grava PNG transparente em
# html/img/vehicles/<model>.png, todas no mesmo quadro: o do táxi original (176x68, carro
# centralizado ocupando ~72% da largura), para os cards da central ficarem iguais.
#     cd resources/[noir]/noir_taxijob && bash dev/fotos.sh
set -euo pipefail
cd "$(dirname "$0")/.."
WIDTH=${WIDTH:-880}
HEIGHT=$(( WIDTH * 68 / 176 / 2 * 2 ))
BOX_W=$(( WIDTH * 72 / 100 )); BOX_H=$(( HEIGHT * 88 / 100 ))
mkdir -p html/img/vehicles
shopt -s nullglob
for raw in dev/fotos/*.png; do
    model=$(basename "$raw" .png)
    keyed=$(mktemp --suffix=.png)
    # Enhanced: largura fora de múltiplo de 64 px chega com faixas; relê com a linha real.
    read -r w h < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$raw" | tr ',' ' ')
    if (( w % 64 != 0 )); then
        fixed=$(mktemp --suffix=.png)
        ffmpeg -loglevel error -i "$raw" -f rawvideo -pix_fmt rgba - | python3 dev/desfaixa.py "$w" "$h" \
            | ffmpeg -loglevel error -y -f rawvideo -pix_fmt rgba -s "${w}x${h}" -i - -frames:v 1 "$fixed"
        raw=$fixed
    fi
    # Verde puro vira transparente. Sem despill: ele puxa o verde do amarelo e o táxi fica laranja.
    ffmpeg -loglevel error -y -i "$raw" -vf "chromakey=0x00FF00:0.22:0.06,format=rgba" -frames:v 1 "$keyed"
    # Menor retângulo com algo visível (alfa > 0).
    crop=$(ffmpeg -loglevel error -i "$keyed" -f rawvideo -pix_fmt rgba - | python3 dev/caixa.py "$w" "$h")
    if [ -z "$crop" ]; then echo "$model: nada visível na foto"; rm -f "$keyed" "${fixed:-}"; fixed=; continue; fi
    # Recorta, fecha os vidros, limpa a franja verde (só borda) e centraliza no quadro padrão.
    read -r cw ch _ < <(echo "${crop#crop=}" | tr ':' ' ')
    ffmpeg -loglevel error -i "$keyed" -vf "$crop" -f rawvideo -pix_fmt rgba - | python3 dev/borda.py "$cw" "$ch" \
        | ffmpeg -loglevel error -y -f rawvideo -pix_fmt rgba -s "${cw}x${ch}" -i - \
            -vf "scale=${BOX_W}:${BOX_H}:force_original_aspect_ratio=decrease:flags=lanczos,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=0x00000000,format=rgba" \
            -frames:v 1 "html/img/vehicles/$model.png"
    rm -f "$keyed" "${fixed:-}"; fixed=
    echo "$model: html/img/vehicles/$model.png (${crop#crop=})"
done
