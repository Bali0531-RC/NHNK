#!/usr/bin/env python3
"""Print the shape of a JSON response: paths and types, never values.

For probing an API without the answer containing anybody's name, grades or
credit counts. Reads stdin.

    curl -s ... | python3 tool/json_shape.py
"""

import json
import sys


def shape(node, path="$"):
    if isinstance(node, dict):
        if not node:
            print(f"{path}  empty object")
        for key, value in node.items():
            shape(value, f"{path}.{key}")
    elif isinstance(node, list):
        print(f"{path}[]  list of {len(node)}")
        if node:
            shape(node[0], f"{path}[0]")
    elif node is None:
        print(f"{path}  null")
    else:
        # Length matters for strings (is it a name or a code?) but the text does not.
        extra = f", len {len(node)}" if isinstance(node, str) else ""
        print(f"{path}  {type(node).__name__}{extra}")


def main():
    raw = sys.stdin.read().strip()
    if not raw:
        print("no input on stdin")
        return 2
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as err:
        print(f"not JSON ({err}). First 200 characters, in case it is an error page:")
        print(raw[:200])
        return 1

    # A lone message or error key is a server complaint, not student data, so the
    # text is safe to show and is the only thing that explains a failed probe.
    if isinstance(parsed, dict) and len(parsed) == 1:
        only = next(iter(parsed))
        if only.lower() in {"message", "error", "detail", "title"}:
            print(f"looks like an error response: {only} = {parsed[only]!r}")
            return 1

    shape(parsed)
    return 0


if __name__ == "__main__":
    sys.exit(main())
