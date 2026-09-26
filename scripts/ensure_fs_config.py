#!/usr/bin/env python3
"""ensure_fs_config.py — append missing fs_config entries for new files (then strip)."""
import sys
from pathlib import Path


def mode_of(p: Path) -> str:
    if p.is_dir():
        return "0755"
    return "0644"


def main():
    src = Path(sys.argv[1])       # work/product/product
    cfg_dir = Path(sys.argv[2])   # work/product/config
    prefix = sys.argv[3]          # product | system | system_ext

    cfg = cfg_dir / (prefix + "_fs_config")
    existing = set()
    has_prefix = False
    if cfg.exists():
        for line in cfg.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if not parts:
                continue
            path = parts[0]
            if path.startswith(prefix + "/"):
                has_prefix = True
                existing.add(path[len(prefix) + 1 :])
            elif path.startswith("/" + prefix + "/"):
                has_prefix = True
                existing.add(path[len(prefix) + 2 :])
            else:
                existing.add(path)
            existing.add(path)
            existing.add(path.rstrip("/"))

    add = []
    for p in sorted(src.rglob("*")):
        rel = p.relative_to(src).as_posix()
        if rel in existing or (rel + "/") in existing or ("/" + rel) in existing:
            continue
        uid, gid = ("1000", "1000") if rel == "data" or rel.startswith("data/") else ("0", "0")
        entry_path = f"{prefix}/{rel}" if has_prefix else rel
        add.append(f"{entry_path} {uid} {gid} {mode_of(p)}")

    if add:
        with cfg.open("a", encoding="utf-8") as f:
            f.write("\n".join(add) + "\n")
        print(prefix, "fs_config +", len(add))
    else:
        print(prefix, "fs_config complete")

    # file_contexts: dam bao file moi co SELinux label (priv-app/overlay)
    fc = cfg_dir / (prefix + "_file_contexts")
    if fc.exists():
        fc_text = fc.read_text(encoding="utf-8", errors="replace")
        fc_add = []
        for p in sorted(src.rglob("*")):
            rel = p.relative_to(src).as_posix()
            # chi them entry cho path con moi trong app / priv-app / overlay / etc
            if not (rel.startswith("app/") or rel.startswith("priv-app/") or rel.startswith("overlay/") or rel.startswith("etc/")):
                continue
            # neu da co regex match thi bo qua (file_contexts dung regex)
            if rel.startswith("priv-app/"):
                label = "u:object_r:system_file:s0"
            elif rel.startswith("overlay/"):
                label = "u:object_r:system_file:s0"
            else:
                label = "u:object_r:system_file:s0"
            entry = f"/{rel} {label}"
            if rel not in fc_text and f"/{rel} " not in fc_text:
                fc_add.append(entry)
        if fc_add:
            with fc.open("a", encoding="utf-8") as f:
                f.write("\n".join(fc_add) + "\n")
            print(prefix, "file_contexts +", len(fc_add))


if __name__ == "__main__":
    main()
