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
	echo "	$(basename $0) PDF_FILE WAV_DIR" 
	exit
}

PDF_FILE=$1
shift || print_usage
WAV_DIR=$1
shift || print_usage
shift && print_usage

TMP_DIR="${PDF_FILE%.pdf}.tmp"
mkdir -p "$TMP_DIR"

firstpng=("$TMP_DIR"/*1.png)
if [ ! -e "$firstpng" -o "$PDF_FILE" -nt "$firstpng" ]; then
  rm -f "$TMP_DIR"/*.png
  pdftocairo -png -scale-to-x $GEOMETRYX -scale-to-y $GEOMETRYY "$PDF_FILE" "$TMP_DIR"/image
fi

pngs=("$TMP_DIR"/*png)
wavs=("$WAV_DIR"/*wav)

if [ ${#pngs[@]} != ${#wavs[@]} ]; then
  echo "Error: PDF_FILE pages(${#pngs[@]} isn't same with WAV_DIR *.wav(${#wavs[@]})"
  exit
fi

modified=0
for i in ${!wavs[@]}; do
    wav=${wavs[$i]} 
    png=${pngs[$i]}
    mp4=${png%.png}.mp4
    if [ ! -e "$mp4" -o "$wav" -nt "$mp4" -o "$png" -nt "$mp4" ]; then
      ffmpeg -loglevel $ffmpeg_loglevel -y -loop 1 -i "$png" -i "$wav" \
      -acodec aac -vcodec libx264 -x264opts keyint=$keyframe_interval -pix_fmt yuv420p -shortest -r $FPS "$mp4"
      ((modified++))
    fi
done
if [ $modified == 0 ]; then
  echo "Info: no file is changed. Update pdf/wav OR rm -rf '$TMP_DIR'."
  exit
fi


rm -f "$TMP_DIR"/list.txt 
mp4s=("$TMP_DIR"/*mp4)
for mp4 in ${mp4s[@]}; do echo "file ${mp4#$TMP_DIR/}" >> "$TMP_DIR"/list.txt; done
ffmpeg -loglevel $ffmpeg_loglevel -y -f concat -i "$TMP_DIR"/list.txt -vcodec libx264 "${PDF_FILE%.pdf}.mp4"

