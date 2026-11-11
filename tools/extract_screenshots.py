#!/usr/bin/env python3
"""Pulls the base64 screenshots out of a downloaded CI log.

Usage: python3 tools/extract_screenshots.py <job-log.txt> <output-dir>
"""
import base64
import re
import sys
from pathlib import Path

TIMESTAMP = re.compile(r"^\S+Z ")


def main(log_path, out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    name, chunks, saved = None, [], []
    for raw in Path(log_path).read_text(errors="replace").splitlines():
        line = TIMESTAMP.sub("", raw).strip()
        if line.startswith("SCREENSHOT-BEGIN "):
            name, chunks = line.split(" ", 1)[1], []
        elif line.startswith("SCREENSHOT-END ") and name:
            path = out / f"{name}.jpg"
            path.write_bytes(base64.b64decode("".join(chunks)))
            saved.append(path)
            name = None
        elif name:
            chunks.append(line)
    for path in saved:
        print(path)
    return 0 if saved else 1


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:3]))
