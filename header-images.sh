#!/bin/bash

set -e

IN_PATH="./assets/images/headers-original"
OUT_PATH="./assets/images/headers-resized"

mkdir -p "$OUT_PATH" || true

for f in $(find "$IN_PATH" -type f); do
    dir=$(dirname $f)
    filename=$(basename $f)

    f_ext="${filename##*.}"
    f_name="${filename%.*}"

    out_f="$OUT_PATH/$f_name"

    echo "Processing ${filename} to ${out_f}";

    cp "$f" "${OUT_PATH}/${filename}"
    convert "$f" -resize 1920x "${OUT_PATH}/${f_name}-1920.${f_ext}"
    convert "$f" -resize 1600x "${OUT_PATH}/${f_name}-1600.${f_ext}"
    convert "$f" -resize 1280x "${OUT_PATH}/${f_name}-1280.${f_ext}"
    convert "$f" -resize 960x "${OUT_PATH}/${f_name}-960.${f_ext}"
    convert "$f" -resize 800x "${OUT_PATH}/${f_name}-800.${f_ext}"
    convert "$f" -resize 640x "${OUT_PATH}/${f_name}-640.${f_ext}"
done
