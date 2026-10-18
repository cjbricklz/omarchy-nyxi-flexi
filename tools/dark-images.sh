#!/bin/sh
# Turns the manual's images (black line art on white) into a dark version, in place: inverted, with the
# hues kept (blue stays blue, red stays red), near-blacks flattened so no JPEG noise shows, and the
# result mapped onto GitHub's dark background and a soft white.
# Run it after tools/manual-to-readme.py, which downloads the originals.
# Usage: tools/dark-images.sh [dir]   (default docs/manual/images)
dir="${1:-$(dirname "$0")/../docs/manual/images}"
for f in "$dir"/*.png "$dir"/*.jpeg; do
  [ -e "$f" ] || continue
  magick "$f" -negate -modulate 100,100,200 -level 6%,100%,1.5 +level-colors "#0d1117,#e6edf3" -quality 95 "$f"
done
