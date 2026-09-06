#!/usr/bin/env python3
"""Sample screenshot pixels so theme complaints can be answered with numbers.

    python3 tool/sample_pixels.py shot.png 640,1600 130,425 ...
"""

import sys

from PIL import Image


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    img = Image.open(argv[1]).convert("RGB")
    print(f"{img.width}x{img.height}")
    for spec in argv[2:]:
        x, y = (int(v) for v in spec.split(","))
        r, g, b = img.getpixel((x, y))
        print(f"  {spec:>12s}  #{r:02X}{g:02X}{b:02X}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
