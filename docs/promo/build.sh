#!/bin/sh
# Build the promo from what is in this folder: the 3D shots, then the film in parts side by side, then the music under it.
# Needs a Mac (the captions use the system font), ffmpeg, and python3 with numpy and Pillow. About three minutes.
# The result is build/dighouse-promo.mp4. Move build/ aside to render the 3D shots again.
set -e
cd "$(dirname "$0")"
mkdir -p build/parts
[ -f build/cloud-hero/f0587.jpg ] || for p in 0 1 2 3; do python3 cloud_render.py hero build/cloud-hero $(seq $p 4 587) > build/cloud-hero-$p.log & done
[ -f build/cloud-slice/f0147.jpg ] || python3 cloud_render.py slice build/cloud-slice > build/cloud-slice.log &
[ -f build/cloud-end/f0223.jpg ] || python3 cloud_render.py end build/cloud-end > build/cloud-end.log &
[ -f build/cloud-mound/f0135.jpg ] || for p in 0 1 2; do python3 mound_render.py build/cloud-mound $(seq $p 3 135) > build/cloud-mound-$p.log & done
wait
: > build/parts/list.txt
for i in 0 1 2 3 4 5 6 7; do
  python3 render.py --range $((i * 9)) $((i * 9 + 9)) build/parts/$i.mp4 > build/parts/$i.log 2>&1 &
  echo "file '$i.mp4'" >> build/parts/list.txt
done
wait
ffmpeg -v error -y -f concat -safe 0 -i build/parts/list.txt -c copy build/video-only.mp4
ffmpeg -v error -y -i build/video-only.mp4 -i music/dighouse-promo.flac -c:v copy -c:a aac -b:a 256k -shortest -movflags +faststart build/dighouse-promo.mp4
ffprobe -v error -show_entries format=duration,size -of csv=p=0 build/dighouse-promo.mp4
