#!/bin/bash 
#
# Copyright (C) 2022 Kazuo Moriwaka
# Copyright (C) 2021 Hirofumi Kojima
#
# SPDX-License-Identifier: Apache-2.0

GEOMETRYX=1920
GEOMETRYY=1080
FPS=30
MAXBLANKMSEC=500

keyframe_interval=$((FPS * MAXBLANKMSEC / 1000))
ffmpeg_loglevel=warning

print_usage ()
{
    echo "Usage:"
    echo "  $(basename "$0") PDF_FILE WAV_DIR" 
    exit 1
}

PDF_FILE=$(realpath "$1")
shift || print_usage
WAV_DIR=$(realpath "$1")
shift || print_usage
shift && print_usage

BASENAME="$(basename "$PDF_FILE")"
OUT_FILE=$(realpath "./${BASENAME%.pdf}.mp4")
TMP_DIR=./tmp-${BASENAME%.pdf}
mkdir -p "$TMP_DIR"
cd "$TMP_DIR" || exit 1

pngs=(*.png)
if [ ! -e "${pngs[0]}" ] || [ "$PDF_FILE" -nt "${pngs[0]}" ]; then
    rm -f ./*.png
    pdftocairo -png -scale-to-x $GEOMETRYX -scale-to-y $GEOMETRYY "$PDF_FILE" tmp
fi

pngs=(*.png)
wavs=("${WAV_DIR}"/*.wav)

if [ ${#pngs[@]} != ${#wavs[@]} ]; then
    echo "Error: PDF_FILE pages(${#pngs[@]} isn't same with WAV_DIR wav files(${#wavs[@]})"
    exit 1
fi

modified=0
LIST=conv_list.txt
rm -f "$LIST"
for i in "${!wavs[@]}"; do
    wav=${wavs[$i]} 
    png=${pngs[$i]}
    mp4=${png%.png}.mp4
    if [ ! -e "$mp4" ] || [ "$wav" -nt "$mp4" ] || [ "$png" -nt "$mp4" ]; then
        printf "%s\x00%s\x00%s\n" "$png" "$wav" "$mp4" >> "$LIST"
        ((modified++))
    fi
done
if [ "$modified" == 0 ] && [ -e "$OUT_FILE" ]; then
    echo "Info: no file is changed. Update pdf/wav OR rm -rf '$TMP_DIR'."
    exit 0
fi

parallel --colsep '\0' \
         ffmpeg -loglevel $ffmpeg_loglevel -y -loop 1 -i "{1}" -i "{2}" \
         -acodec aac -vcodec libx264 -x264opts keyint=$keyframe_interval -pix_fmt yuv420p -shortest -r $FPS "{3}" \
         :::: "$LIST"

rm -f list.txt 
mp4s=(*mp4)
for mp4 in "${mp4s[@]}"; do echo "file ${mp4}" >> list.txt; done
ffmpeg -loglevel $ffmpeg_loglevel -y -f concat -i list.txt -vcodec libx264 "$OUT_FILE"

