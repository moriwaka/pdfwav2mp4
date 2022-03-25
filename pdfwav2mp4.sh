#!/bin/bash 
#
# Copyright (C) 2022 Kazuo Moriwaka
# Copyright (C) 2021 Hirofumi Kojima
#
# SPDX-License-Identifier: Apache-2.0

out_x=1920
out_y=1080
fps=10

ffmpeg_loglevel=warning

function print_usage ()
{
    echo "Usage:"
    echo "  $(basename "$0") PDF_FILE WAV_DIR" 
    exit 0
}

if (( $# < 2)); then
    print_usage
fi

PDF_FILE=$(realpath "$1"); shift 
WAV_DIR=$(realpath "$1"); shift 
shift && print_usage

BASENAME="$(basename "$PDF_FILE")"
OUT_FILE=$(realpath "./${BASENAME%.pdf}.mp4")
TMP_DIR=./tmp-${BASENAME%.pdf}
mkdir -p "$TMP_DIR"
cd "$TMP_DIR" || exit 1

function wavduration ()
{
    ffprobe -loglevel $ffmpeg_loglevel -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $1
}

pngs=(*.png)                    # already existing pngs   
if [ ! -e "${pngs[0]}" ] || [ "$PDF_FILE" -nt "${pngs[0]}" ]; then
    rm -f ./*.png
    pdftocairo -png -scale-to-x $out_x -scale-to-y $out_y "$PDF_FILE" tmp
fi

pngs=(*.png)                    # up-to-date pngs
wavs=("${WAV_DIR}"/*.wav)
if [ ${#pngs[@]} != ${#wavs[@]} ]; then
    echo "Error: PDF_FILE pages(${#pngs[@]} isn't same with WAV_DIR wav files(${#wavs[@]})"
    exit 1
fi

modified=0
total_duration=0
audio_list=audio_list.txt
video_list=video_list.txt
rm -f "$audio_list" "$video_list"
for i in "${!wavs[@]}"; do
    wav=${wavs[$i]} 
    png=${pngs[$i]}
    if [ ! -e "$OUT_FILE" ] || [ "$wav" -nt "$OUT_FILE" ] || [ "$png" -nt "$OUT_FILE" ]; then
        ((modified++))
    fi
    duration=$(wavduration $wav)
    printf "file '%s'\nduration %s\n" "$png" "$duration"  >> "$video_list"
    printf "file '%s'\n" "$wav"  >> "$audio_list"
    total_duration=$(awk "BEGIN{ print $total_duration + $duration }")
done

if [ "$modified" == 0 ]; then
    echo "Info: no file is changed. Update pdf/wav OR rm -rf '$TMP_DIR'."
    exit 0
fi

ffmpeg -loglevel $ffmpeg_loglevel -y -safe 0 -f concat -i $audio_list -f concat -i $video_list -vcodec libx264 -r $fps -to $total_duration "$OUT_FILE"

