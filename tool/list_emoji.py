"""Inventory every emoji the app can actually render, so the bundled font can be
subset to just those."""

import json
import pathlib
import re

EMOJI = re.compile(
    "[\U0001F300-\U0001FAFF\U00002600-\U000027BF\U0001F1E6-\U0001F1FF"
    "\U00002190-\U000021FF\U00002B00-\U00002BFF\U00002700-\U000027BF]"
)

root = pathlib.Path("/home/bali0531/Documents/Neptun-Mobile")
groups = {
    "lib/": sorted(root.glob("lib/**/*.dart")),
    "Languages/": sorted(root.glob("Languages/**/*.json")),
    "android/ widget": sorted(root.glob("android/app/src/main/**/*.java")),
}

everything = set()
for label, files in groups.items():
    found = set()
    for f in files:
        try:
            found.update(EMOJI.findall(f.read_text(encoding="utf-8")))
        except Exception:
            pass
    everything |= found
    print(f"{label:16} {len(found):3} distinct   {' '.join(sorted(found))}")

print()
print(f"TOTAL: {len(everything)} distinct emoji")

# Regional indicators only mean anything in pairs, so keep the whole block.
codepoints = sorted(ord(c) for c in everything)
spec = []
for cp in codepoints:
    if 0x1F1E6 <= cp <= 0x1F1FF:
        continue
    spec.append(f"U+{cp:04X}")
spec.append("U+1F1E6-1F1FF")     # flags
spec.append("U+FE0F")            # variation selector
spec.append("U+200D")            # zero width joiner
spec.append("U+E0020-E007F")     # tag characters for subdivision flags

out = ",".join(spec)
print()
print(out)
pathlib.Path("/tmp/emoji_codepoints.txt").write_text(out)
