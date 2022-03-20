#!/bin/bash 
#
# Copyright (C) 2022 Kazuo Moriwaka
# Copyright (C) 2021 Hirofumi Kojima
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

GEOMETRYX=1920
GEOMETRYY=1080
FPS=30
MAXBLANKMSEC=500

keyframe_interval=$((FPS * MAXBLANKSEC / 1000))
ffmpeg_loglevel=warning

print_usage ()
{
    echo "Usage:"
    echo "  $(basename $0) PDF_FILE WAV_DIR" 
    exit
}

PDF_FILE=$(realpath "$1")
OUT_FILE="${PDF_FILE%.pdf}.mp4"
shift || print_usage
WAV_DIR=$(realpath "$1")
shift || print_usage
shift && print_usage

BASENAME="$(basename "$PDF_FILE")"
TMP_DIR=./tmp-${BASENAME%.pdf}
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

firstpng=(*1.png)
if [ ! -e "$firstpng" -o "$PDF_FILE" -nt "$firstpng" ]; then
    rm -f *.png
    pdftocairo -png -scale-to-x $GEOMETRYX -scale-to-y $GEOMETRYY "$PDF_FILE" tmp
fi

pngs=(*png)
wavs=("$WAV_DIR"/*wav)

if [ ${#pngs[@]} != ${#wavs[@]} ]; then
    echo "Error: PDF_FILE pages(${#pngs[@]} isn't same with WAV_DIR *.wav(${#wavs[@]})"
    exit
fi

modified=0
LIST=conv_list.txt
rm -f "$LIST"
for i in ${!wavs[@]}; do
    wav=${wavs[$i]} 
    png=${pngs[$i]}
    mp4=${png%.png}.mp4
    if [ ! -e "$mp4" -o "$wav" -nt "$mp4" -o "$png" -nt "$mp4" ]; then
        printf "$png\x00$wav\x00$mp4\n" >> "$LIST"
        ((modified++))
    fi
done
if [ $modified == 0 -a -e "$OUT_FILE" ]; then
    echo "Info: no file is changed. Update pdf/wav OR rm -rf '$TMP_DIR'."
    exit
fi

parallel --colsep '\0' \
         ffmpeg -loglevel $ffmpeg_loglevel -y -loop 1 -i "{1}" -i "{2}" \
         -acodec aac -vcodec libx264 -x264opts keyint=$keyframe_interval -pix_fmt yuv420p -shortest -r $FPS "{3}" \
         :::: "$LIST"

rm -f list.txt 
mp4s=(*mp4)
for mp4 in ${mp4s[@]}; do echo "file ${mp4}" >> list.txt; done
ffmpeg -loglevel $ffmpeg_loglevel -y -f concat -i list.txt -vcodec libx264 "$OUT_FILE"

