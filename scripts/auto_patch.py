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


def _split_meta_body(body: str):
    meta = []
    for line in body.splitlines(keepends=True):
        s = line.strip()
        if s.startswith((".locals", ".registers", ".param", ".annotation", ".end annotation", ".prologue")) or s == "":
            meta.append(line)
        else:
            break
    locals_line = next(
        (x for x in meta if x.strip().startswith((".locals", ".registers"))),
        None,
    )
    if locals_line is None:
        locals_line = "    .locals 1\n"
    rest = "".join(x for x in meta if not x.strip().startswith((".locals", ".registers")))
    return locals_line, rest


def force_return(path, method, ret="Z", value=0):
    """Force method body to return value. ret: V=void, Z=bool, I=int."""
    text = path.read_text(encoding="utf-8", errors="replace")
    # match any method with this name (static or instance)
    pat = re.compile(
        r"(\.method[^\n]*\b" + re.escape(method) + r"\([^\n]*\)[VIZB]\n)(.*?)(\.end method)",
        re.S,
    )

    def repl(m):
        header, body, end = m.group(1), m.group(2), m.group(3)
        # detect actual return type from header
        hm = re.search(r"\)[VIZB]\s*$", header.strip())
        actual = hm.group(0)[1] if hm else ret
        locals_line, rest = _split_meta_body(body)
        if actual == "V":
            code = "\n    return-void\n"
        else:
            code = "\n    const/4 v0, 0x%x\n\n    return v0\n" % (value & 0xF)
            if value > 0xF:
                code = "\n    const/16 v0, 0x%x\n\n    return v0\n" % value
        return header + locals_line + rest + code + end

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
    if text2 != text:
        path.write_text(text2, encoding="utf-8")


def patch_signature(out: Path, tag: str):
    """Signature / upgrade-key / hidden-api bypass scoped to relevant classes."""
    hits = 0
    if tag == "sv":
        # services.jar: PackageManagerService & KeySetManager
        sv_rules = [
            ("verifySignatures", 1),                # boolean: 1=valid
            ("matchSignaturesCompat", 0),           # int: 0=SIGNATURE_MATCH
            ("checkDowngrade", 0),                  # void: return-void
            ("shouldCheckUpgradeKeySetLocked", 0),  # boolean: 0=false
        ]
        target_files = []
        for pat in ["*PackageManagerServiceUtils*.smali", "*KeySetManagerService*.smali", "*PackageManagerService*.smali"]:
            target_files.extend(out.rglob(pat))
        for p in set(target_files):
            for name, val in sv_rules:
                hits += force_return(p, name, value=val)

    elif tag == "fw":
        # framework.jar: SigningDetails, StrictJarVerifier, ApkSignatureVerifier
        fw_rules = [
            ("getMinimumSignatureSchemeVersionForTargetSdk", 0),
            ("checkCapability", 1),
            ("checkCapabilityRecover", 1),
            ("verifyMessageDigest", 1),
            ("isPackageWhitelistedForHiddenApis", 1),
        ]
        target_files = []
        for pat in ["*SigningDetails*.smali", "*StrictJarVerifier*.smali", "*ApkSignatureVerifier*.smali", "*HiddenApi*.smali"]:
            target_files.extend(out.rglob(pat))
        for p in set(target_files):
            for name, val in fw_rules:
                hits += force_return(p, name, value=val)
    return hits


def main():
    apktool = sys.argv[1]
    work = Path(sys.argv[2])
    do_secure = sys.argv[3] == "1"
    do_cn = sys.argv[4] == "1"
    do_sig = sys.argv[5] == "1" if len(sys.argv) > 5 else True

    targets = [
        ("fw", work / "system/system/system/framework/framework.jar", True, False),
        ("sv", work / "system/system/system/framework/services.jar", True, False),
        ("msv", work / "system_ext/system_ext/framework/miui-services.jar", False, True),
    ]

    for tag, jar, secure_cls, cn in targets:
        if not jar.exists():
            print("skip", tag, "jar missing")
            continue
        out = work / ("dec_" + tag)
        if out.exists():
            shutil.rmtree(out, ignore_errors=True)
        decompile(str(jar), str(out), apktool)

        if do_sig and tag in ("fw", "sv"):
            n = patch_signature(out, tag)
            print(tag, "signature patches:", n)

        if secure_cls and do_secure:
            for p in out.rglob("WindowState.smali"):
                if "server/wm" in p.as_posix():
                    force_return(p, "isSecureLocked", value=0)
            for p in out.rglob("WindowManagerServiceImpl.smali"):
                force_return(p, "notAllowCaptureDisplay", value=0)

        if cn and do_cn:
            for name in [
                "BroadcastQueueModernStubImpl.smali",
                "ActivityManagerServiceImpl.smali",
                "ProcessManagerService.smali",
                "ProcessSceneCleaner.smali",
            ]:
                for p in out.rglob(name):
                    replace_is_intl(p)

        for p in out.rglob("*.smali"):
            fix_double_end(p)

        rebuilt = work / (tag + "_final.jar")
        compile_apk(str(out), str(rebuilt), apktool)
        shutil.copy2(rebuilt, jar)
        print("patched", jar.name)

    print("AUTO_PATCH_DONE")


if __name__ == "__main__":
    main()
