#!/usr/bin/env python3
"""extract_payload.py — extract payload.bin from OTA zip."""
import os
import shutil
import sys
import zipfile


def main():
    src, dst = sys.argv[1], sys.argv[2]
    print("extracting payload.bin...")
    with zipfile.ZipFile(src) as z, open(dst, "wb") as f:
        with z.open("payload.bin") as p:
            shutil.copyfileobj(p, f, 1024 * 1024)
    print("payload.bin", os.path.getsize(dst))


if __name__ == "__main__":
    main()
