#!/usr/bin/env python3
"""strip_fs_config.py — strip partition prefix from fs_config / file_contexts."""
import sys
from pathlib import Path


def strip_cfg(inp, outp, prefix):
    lines = Path(inp).read_text(encoding="utf-8", errors="replace").splitlines()
    out = []
    for line in lines:
        if not line.strip() or line.startswith("#"):
            out.append(line)
            continue
        parts = line.split()
        path = parts[0]
        if path == "/":
            out.append(line)
            continue
        if path == prefix or path == prefix + "/":
            out.append("/ " + " ".join(parts[1:]))
            continue
        if path.startswith(prefix + "/"):
            newp = path[len(prefix) + 1 :] or "/"
            out.append(newp + " " + " ".join(parts[1:]))
            continue
        out.append(line)
    Path(outp).write_text("\n".join(out) + "\n", encoding="utf-8")
    print("stripped cfg", prefix)


def strip_fc(inp, outp, prefix):
    lines = Path(inp).read_text(encoding="utf-8", errors="replace").splitlines()
    out = []
    for line in lines:
        if not line.strip() or line.startswith("#"):
            out.append(line)
            continue
        parts = line.split()
        if len(parts) < 2:
            out.append(line)
            continue
        path = parts[0]
        rest = " ".join(parts[1:])
        if path in ("/", "/.*"):
            out.append(line)
            continue
        if path.startswith("/" + prefix + "/"):
            out.append(path[1 + len(prefix) :] + " " + rest)
        elif path == "/" + prefix:
            out.append("/ " + rest)
        else:
            out.append(line)
    Path(outp).write_text("\n".join(out) + "\n", encoding="utf-8")
    print("stripped fc", prefix)


def main():
    cfgdir = Path(sys.argv[1])
    prefix = sys.argv[2]
    strip_cfg(cfgdir / (prefix + "_fs_config"), cfgdir / (prefix + "_fs_config.stripped"), prefix)
    strip_fc(cfgdir / (prefix + "_file_contexts"), cfgdir / (prefix + "_file_contexts.stripped"), prefix)


if __name__ == "__main__":
    main()
