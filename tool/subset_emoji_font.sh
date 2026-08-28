#!/usr/bin/env bash
# Rebuilds assets/noto_color_emoji.ttf from the full Noto Color Emoji.
#
# The full font is 22.9 MB and ships inside the base module of the app bundle, so
# every user downloads all of it. The app renders 28 emoji. Subsetting to those
# keeps the point of bundling a font at all, which is that the glyphs look the
# same on every device, without the other 1400.
#
# The SVG table is dropped: Google's build carries both COLR and SVG copies of
# every glyph, Skia draws the COLR one, and SVG alone was 6.1 MB of the subset.
#
# Run tool/list_emoji.py first if the app started using new emoji.
set -euo pipefail

cd "$(dirname "$0")/.."

SOURCE="tool/noto_color_emoji_full.ttf"
TARGET="assets/noto_color_emoji.ttf"
CODEPOINTS="U+2705,U+274C,U+2753,U+2764,U+2B50,U+1F393,U+1F480,U+1F4B0,U+1F4C4,\
U+1F4D1,U+1F4DA,U+1F4DD,U+1F4EC,U+1F4ED,U+1F58B,U+1F60C,U+1F610,U+1F62C,U+1F649,\
U+1F913,U+1F917,U+1F921,U+1FAAA,U+1F1E6-1F1FF,U+FE0F,U+200D,U+E0020-E007F"

if [ ! -f "$SOURCE" ]; then
  echo "missing $SOURCE" >&2
  exit 1
fi

if ! command -v pyftsubset > /dev/null; then
  echo "pyftsubset not found: pip install fonttools" >&2
  exit 1
fi

pyftsubset "$SOURCE" \
  --unicodes="$CODEPOINTS" \
  --layout-features='*' \
  --drop-tables+=SVG \
  --output-file="$TARGET"

before=$(stat -c%s "$SOURCE")
after=$(stat -c%s "$TARGET")
python3 - "$before" "$after" <<'PY'
import sys
before, after = int(sys.argv[1]), int(sys.argv[2])
mb = 1048576
print(f"full   {before/mb:6.2f} MB")
print(f"subset {after/mb:6.2f} MB")
print(f"saved  {(before-after)/mb:6.2f} MB")
PY
