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
DENSITY=600
GEOMETRYX=1920
GEOMETRYY=1080
FPS=30

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

mkdir -p tmp

png=(tmp/*1.png)
if [ ! -e $png -o "$PDF_FILE" -nt $png ]; then
  rm -f tmp/*.png
  pdftocairo -png -r $DENSITY -scale-to-x $GEOMETRYX -scale-to-y $GEOMETRYY "$PDF_FILE" tmp/tmp
fi

pngs=(tmp/*png)
wavs=("$WAV_DIR"/*wav)

if [ ${#pngs[@]} != ${#wavs[@]} ]; then
  echo "Error: PDF_FILE pages(${#pngs[@]} isn't same with WAV_DIR *.wav(${#wavs[@]})"
  exit
fi

for i in ${!wavs[@]}; do
    wav=${wavs[$i]} 
    png=${pngs[$i]}
    mp4=${png%.png}.mp4
    if [ ! -e $mp4 -o "$wav" -nt $mp4 -o $png -nt $mp4 ]; then
      ffmpeg -loglevel $ffmpeg_loglevel -y -loop 1 -i $png -i "$wav" \
      -acodec aac -vcodec libx264 -pix_fmt yuv420p -shortest -r $FPS $mp4
      touch $mp4
    fi
done


rm -f tmp/list.txt 
mp4s=(tmp/*mp4)
for mp4 in ${mp4s[@]}; do echo "file ${mp4#tmp/}" >> tmp/list.txt; done
ffmpeg -loglevel $ffmpeg_loglevel -y -f concat -i tmp/list.txt -c copy "${PDF_FILE%.pdf}.mp4"

