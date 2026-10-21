#!/bin/zsh
set -eu
cd "${0:A:h}/.."
command -v ffmpeg >/dev/null || { print -u2 "ffmpeg is required to encode the demo GIF."; exit 1; }
frame_dir=$(mktemp -d "${TMPDIR:-/tmp}/clipflow-demo.XXXXXX")
trap 'rm -rf "$frame_dir"' EXIT
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
swift scripts/generate-demo.swift "$frame_dir"
mkdir -p docs/media
ffmpeg -hide_banner -loglevel error -y -framerate 25 -i "$frame_dir/%04d.png" \
  -filter_complex '[0:v]split[a][b];[a]palettegen=stats_mode=diff:max_colors=192[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle' \
  -loop 0 docs/media/demo.gif
print "Created docs/media/demo.gif (25 fps / 16.4 seconds)"
