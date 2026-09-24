#!/usr/bin/env python3
"""auto_patch.py — signature bypass + secure flag + CN notification."""
import re
import shutil
import subprocess
import sys
from pathlib import Path


def decompile(jar, out, apktool):
    subprocess.check_call(["java", "-jar", apktool, "d", "-q", "-f", "-s", "-o", out, jar])


def compile_apk(src, out, apktool):
    subprocess.check_call(["java", "-jar", apktool, "b", "-q", "-f", "-o", out, src])


def force_return_z(path, method, value=0):
    text = path.read_text(encoding="utf-8", errors="replace")
    pat = re.compile(
        r"(\.method[^\n]*" + re.escape(method) + r"\([^\n]*\)Z\n)(.*?)(\.end method)",
        re.S,
    )

    def repl(m):
        header, body, end = m.group(1), m.group(2), m.group(3)
        meta = []
        for line in body.splitlines(keepends=True):
            s = line.strip()
            if s.startswith((".locals", ".registers", ".param", ".annotation", ".end annotation")) or s == "":
                meta.append(line)
            else:
                break
        locals_line = next(
            (x for x in meta if x.strip().startswith((".locals", ".registers"))),
            "    .locals 1\n",
        )
        if not locals_line.strip().startswith((".locals", ".registers")):
            locals_line = "    .locals 1\n"
        rest = "".join(x for x in meta if not x.strip().startswith((".locals", ".registers")))
        return (
            header
            + locals_line
            + rest
            + "\n    const/4 v0, 0x" + format(value, "x") + "\n\n    return v0\n"
            + end
        )

    new, n = pat.subn(repl, text)
    if n:
        path.write_text(new, encoding="utf-8")
    return n


def replace_is_intl(path):
    text = path.read_text(encoding="utf-8", errors="replace")
    new, n = re.subn(
        r"sget-boolean (v\d+), Lmiui/os/Build;->IS_INTERNATIONAL_BUILD:Z",
        r"const/4 \1, 0x1",
        text,
    )
    if n:
        path.write_text(new, encoding="utf-8")
    return n


def fix_double_end(path):
    text = path.read_text(encoding="utf-8", errors="replace")
    text2 = re.sub(r"\.end method\s*\n\s*\.end method\s*\n", ".end method\n", text)
    path.write_text(text2, encoding="utf-8")


def main():
    apktool = sys.argv[1]
    work = Path(sys.argv[2])
    do_secure = sys.argv[3] == "1"
    do_cn = sys.argv[4] == "1"

    targets = [
        ("fw", work / "system/system/system/framework/framework.jar", False, False),
        ("sv", work / "system/system/system/framework/services.jar", True, False),
        ("msv", work / "system_ext/system_ext/framework/miui-services.jar", True, True),
    ]

    for tag, jar, secure_cls, cn in targets:
        if not jar.exists():
            print("skip", tag, "jar missing")
            continue
        out = work / ("dec_" + tag)
        if out.exists():
            shutil.rmtree(out, ignore_errors=True)
        decompile(str(jar), str(out), apktool)
        if secure_cls and do_secure:
            for p in out.rglob("WindowState.smali"):
                if "server/wm" in p.as_posix():
                    force_return_z(p, "isSecureLocked", 0)
            for p in out.rglob("WindowManagerServiceImpl.smali"):
                force_return_z(p, "notAllowCaptureDisplay", 0)
            for p in out.rglob("SigningDetails.smali"):
                force_return_z(p, "checkCapability", 1)
                force_return_z(p, "checkCapabilityRecover", 1)
            for p in out.rglob("StrictJarVerifier.smali"):
                force_return_z(p, "verifyMessageDigest", 1)
            for p in out.rglob("*.smali"):
                fix_double_end(p)
        if cn and do_cn:
            for name in [
                "BroadcastQueueModernStubImpl.smali",
                "ActivityManagerServiceImpl.smali",
                "ProcessManagerService.smali",
                "ProcessSceneCleaner.smali",
            ]:
                for p in out.rglob(name):
                    replace_is_intl(p)
        rebuilt = work / (tag + "_final.jar")
        compile_apk(str(out), str(rebuilt), apktool)
        shutil.copy2(rebuilt, jar)
        print("patched", jar.name)

    print("AUTO_PATCH_DONE")


if __name__ == "__main__":
    main()
