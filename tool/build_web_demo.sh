#!/usr/bin/env bash
# Builds the web demo that the website embeds.
#
# The emoji font is dropped: it is 23 MB and the browser fetches it eagerly, which
# is absurd for a try-it-out demo. Browsers render emoji with their own font, so the
# only loss is the exact glyph style. The mobile builds keep it.
set -euo pipefail

APP_DIR="$HOME/Documents/Neptun-Mobile"
OUT_DIR="$HOME/Documents/NHNK-web/public/demo"

cd "$APP_DIR"
cp pubspec.yaml /tmp/pubspec.backup.yaml
trap 'mv /tmp/pubspec.backup.yaml "$APP_DIR/pubspec.yaml"' EXIT

python3 - <<'PY'
import re
p = "pubspec.yaml"
s = open(p, encoding="utf-8").read()
s = re.sub(r"\n  fonts:\n    - family: Noto Color Emoji\n      fonts:\n        - asset: assets/noto_color_emoji\.ttf\n", "\n", s)
open(p, "w", encoding="utf-8").write(s)
PY

~/flutter/bin/flutter build web --release --no-wasm-dry-run --base-href=/demo/

# Only the variant the browser negotiates is ever fetched, but shipping all of them
# would put ~30 MB of dead weight in the website repository.
rm -rf build/web/canvaskit/chromium build/web/canvaskit/experimental_webparagraph
rm -f build/web/canvaskit/skwasm_heavy.wasm build/web/canvaskit/skwasm_heavy.js \
      build/web/canvaskit/skwasm_heavy.worker.js

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
cp -r build/web/. "$OUT_DIR/"

echo
echo "demo written to $OUT_DIR"
du -sh "$OUT_DIR"
