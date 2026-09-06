#!/usr/bin/env python3
"""WCAG contrast for the built-in themes, read straight out of colors.dart.

Body text needs 4.5:1 against its background. This exists because a reviewer said
the contrast looked bad and squinting at it is not an answer. It is also the
check to run when adding a theme, an OLED one included.

    python3 tool/contrast_check.py
"""

import pathlib
import re
import sys

COLORS = pathlib.Path(__file__).resolve().parent.parent / "lib" / "colors.dart"
AA_BODY = 4.5

# accents that get used as text somewhere, so they answer to the body threshold
ACCENTS = [
    "secondary",
    "onPrimaryContainer",
    "currentClassGreen",
    "errorRed",
    "grade3",
]


def _linear(channel):
    c = channel / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(rgb):
    r, g, b = rgb
    return 0.2126 * _linear(r) + 0.7152 * _linear(g) + 0.0722 * _linear(b)


def ratio(fg, bg):
    a, b = luminance(fg), luminance(bg)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def blend(fg, bg, alpha):
    return tuple(round(f * alpha + b * (1 - alpha)) for f, b in zip(fg, bg))


def palettes(source):
    """Every AppPalette block, as {name: {field: (r, g, b)}}."""
    out = {}
    for block in re.split(r"_appColors\.add\(AppPalette\('", source)[1:]:
        name = block.split("'")[0]
        fields = {}
        for field, r, g, b in re.findall(
            r"(\w+):\s*Color\.fromRGBO\(0x([0-9A-Fa-f]{2}),\s*0x([0-9A-Fa-f]{2}),"
            r"\s*0x([0-9A-Fa-f]{2})",
            block,
        ):
            fields[field] = (int(r, 16), int(g, 16), int(b, 16))
        if "rootBackground" in fields:
            out[name] = fields
    return out


def check_oled(found):
    """A near-black OLED theme is pointless; the panel only saves power at #000000."""
    fields = found.get("OLED")
    if fields is None:
        return 0

    problems = []
    if fields["rootBackground"] != (0, 0, 0):
        problems.append(f"rootBackground is {fields['rootBackground']}, not pure black")
    for bar in ("navbarNavibarColor", "navbarStatusBarColor"):
        if fields.get(bar) != (0, 0, 0):
            problems.append(f"{bar} is {fields.get(bar)}, which shows a seam against the page")

    print("\n=== OLED, true black check ===")
    for problem in problems:
        print(f"    FAIL {problem}")
    if not problems:
        print("    background and system bars are all #000000")
    return len(problems)


def main():
    source = COLORS.read_text(encoding="utf-8")
    found = palettes(source)
    if not found:
        print("no palettes found; did colors.dart change shape?")
        return 1

    failures = 0
    for name, fields in found.items():
        bg = fields["rootBackground"]
        print(f"\n=== {name}, background #{bg[0]:02X}{bg[1]:02X}{bg[2]:02X} ===")

        text = fields.get("textColor")
        if text:
            print("  dimmed body text")
            floor = None
            for step in range(85, 20, -5):
                alpha = step / 100
                r = ratio(blend(text, bg, alpha), bg)
                ok = r >= AA_BODY
                if ok:
                    floor = alpha
                print(f"    alpha {alpha:.2f}  {r:6.2f}:1  {'pass' if ok else 'FAIL'}")
            if floor is not None:
                print(f"    -> mutedText floor for this theme: {floor:.2f}")

        print("  accents on the background")
        for field in ACCENTS:
            rgb = fields.get(field)
            if rgb is None:
                continue
            r = ratio(rgb, bg)
            ok = r >= AA_BODY
            if not ok:
                failures += 1
            print(f"    {field:22s} {r:6.2f}:1  {'pass' if ok else 'FAIL'}")

    print(f"\n{failures} accent measurement(s) below {AA_BODY}:1")
    failures += check_oled(found)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
