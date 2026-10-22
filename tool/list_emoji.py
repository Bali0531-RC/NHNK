"""Inventory every emoji the app can actually render, so the bundled font can be
subset to just those."""

import json
import pathlib


def is_emoji_codepoint(cp: int) -> bool:
    return (
        0x1F300 <= cp <= 0x1FAFF
        or 0x2600 <= cp <= 0x27BF
        or 0x1F1E6 <= cp <= 0x1F1FF
        or 0x2190 <= cp <= 0x21FF
        or 0x2B00 <= cp <= 0x2BFF
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
            text = f.read_text(encoding="utf-8")
            found.update(ch for ch in text if is_emoji_codepoint(ord(ch)))
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
