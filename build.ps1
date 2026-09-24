<#
.SYNOPSIS
  rom-kitchen — build ROM custom không root cho Xiaomi lisa từ ROM gốc + APK mod.

.EXAMPLE
  .\build.ps1 -RomUrl "D:\LISA\lisa-ota_full-OS2.0.16.0.UKOCNXM-user-14.0-6326c122fd.zip"
  .\build.ps1 -RomUrl "https://.../lisa-ota_full-....zip"
  .\build.ps1 -SkipFetch -OtaZip "D:\LISA\lisa-ota_full-....zip"
#>
param(
    [string]$RomUrl = '',
    [string]$OtaZip = '',
    [string]$ApkDir = '',
    [switch]$SkipFetch,
    [switch]$SkipMods,
    [switch]$SkipLang,
    [switch]$SkipDebloat,
    [switch]$PackOnly,
    [switch]$NoVerify
)

. "$PSScriptRoot\scripts\tools.ps1"
$cfg = Get-KitchenConfig
$Root = $script:Root

$apkDir   = if ($ApkDir) { $ApkDir } else { Join-Path $Root $cfg.apk_dir }
$toolsDir = Join-Path $Root $cfg.tools_dir
$outDir   = Join-Path $Root $cfg.out_dir
$work     = Join-Path $Root 'work'
$cache    = Join-Path $Root 'cache'

Ensure-Dir $outDir; Ensure-Dir $work; Ensure-Dir $cache; Ensure-Dir $toolsDir

if ($PackOnly) {
    Write-Step 'PACK ONLY'
    & "$PSScriptRoot\packROM.ps1"
    exit 0
}

# ========== 0. Resolve OTA (skip download if payload/images cached) ==========
Write-Step '0. RESOLVE OTA'
$payload = Join-Path $cache 'payload.bin'
$images = Join-Path $cache 'images'
$cacheReady = (Test-Path $payload) -and (Test-Path (Join-Path $images 'system.img'))
if ($cacheReady -and -not $OtaZip) {
    Write-Ok 'cache payload+images sẵn — bỏ qua download'
} else {
    if (-not $OtaZip) {
        if (-not $RomUrl) { Fail 'Cần -RomUrl (link) hoặc -OtaZip (đường dẫn file)' }
        if (Test-Path -LiteralPath $RomUrl) {
            $OtaZip = $RomUrl
            Write-Ok "Local OTA: $OtaZip"
        } else {
            $OtaZip = Join-Path $cache 'rom_ota.zip'
            if ((Test-Path -LiteralPath $OtaZip) -and $SkipFetch) {
                Write-Ok "Skip fetch, dùng cache: $OtaZip"
            } else {
                Write-Ok "Downloading $RomUrl ..."
                curl.exe -L --fail --retry 3 --retry-delay 2 -o $OtaZip $RomUrl
                if ($LASTEXITCODE -ne 0) { Fail 'Download failed' }
                Write-Ok "Downloaded $([math]::Round((Get-Item $OtaZip).Length/1GB,2)) GB"
            }
        }
    }
    if (-not (Test-Path -LiteralPath $OtaZip)) { Fail "OTA not found: $OtaZip" }
}

# ========== 1. Extract payload.bin ==========
Write-Step '1. EXTRACT PAYLOAD'
if (-not (Test-Path $payload)) {
    if (-not $OtaZip) { Fail 'payload.bin cache miss và không có OTA' }
    $py = Get-Python
    & $py -c @"
import zipfile, shutil, os
src = r'''$OtaZip'''
dst = r'''$payload'''
print('extracting payload.bin...')
with zipfile.ZipFile(src) as z, open(dst, 'wb') as f:
    with z.open('payload.bin') as p:
        shutil.copyfileobj(p, f, 1024*1024)
print('payload.bin', os.path.getsize(dst))
"@
    if ($LASTEXITCODE -ne 0) { Fail 'extract payload.bin failed' }
} else { Write-Ok "payload.bin cache: $payload" }

# ========== 2. Dump partitions ==========
Write-Step '2. DUMP PARTITIONS'
$images = Join-Path $cache 'images'
Ensure-Dir $images
$need = @('system.img','product.img','system_ext.img','vendor.img','odm.img','mi_ext.img','boot.img','vbmeta.img','vbmeta_system.img','vendor_boot.img','modem.img')
$missing = $need | Where-Object { -not (Test-Path (Join-Path $images $_)) }
if ($missing.Count -gt 0) {
    $pd = Get-Tool 'payload-dumper-go\payload-dumper-go.exe'
    if (-not (Test-Path $pd)) { $pd = Get-Tool 'payload-dumper-go.exe' }
    & $pd -o $images $payload
    if ($LASTEXITCODE -ne 0) { Fail 'payload-dumper-go failed' }
} else { Write-Ok 'images already dumped' }

# ========== 3. Unpack EROFS ==========
Write-Step '3. UNPACK EROFS'
$extract = Get-Tool 'extract.erofs.exe'
foreach ($part in @('system','product','system_ext')) {
    $img = Join-Path $images "$part.img"
    $dst = Join-Path $work $part
    if (Test-Path (Join-Path $dst $part)) {
        Write-Ok "$part already unpacked"
        continue
    }
    Ensure-Dir $dst
    Write-Ok "extract $part.img ..."
    & $extract -i $img -o $dst -x -s -T8
    if ($LASTEXITCODE -ne 0) { Fail "extract $part failed" }
}

# ========== 4. Apply APK mods ==========
if (($cfg.install_mods -eq 'true') -and (-not $SkipMods)) {
    Write-Step '4. APPLY APK MODS'
    $mapFile = Join-Path $Root 'config\apk-map.txt'
    foreach ($line in Get-Content $mapFile) {
        $line = $line.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $p = $line.Split('|')
        if ($p.Count -lt 3) { continue }
        $part = $p[0]; $dstRel = $p[1]; $srcName = $p[2]; $rmOat = if ($p.Count -ge 4) { $p[3] } else { '1' }
        $src = Join-Path $apkDir $srcName
        # system partition path: system/system/... when part=system
        $rootMap = @{ product = 'product\product'; system = 'system\system'; system_ext = 'system_ext\system_ext' }
        $dst = Join-Path (Join-Path $work $rootMap[$part]) ($dstRel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $src)) { Write-Warn "skip (missing): $srcName"; continue }
        Ensure-Dir (Split-Path $dst -Parent)
        Copy-Literal $src $dst
        Write-Ok "$srcName -> $dstRel"
        if ($rmOat -eq '1') {
            $oat = Join-Path (Split-Path $dst -Parent) 'oat'
            if (Test-Path -LiteralPath $oat) { Remove-Item -LiteralPath $oat -Recurse -Force }
        }
    }
}

# ========== 4b. Debloat app rác ==========
if (($cfg.debloat -eq 'true') -and (-not $SkipDebloat) -and (Test-Path (Join-Path $Root 'config\debloat.txt'))) {
    Write-Step '4b. DEBLOAT'
    & "$PSScriptRoot\debloat.ps1"
}

# ========== 5. Patch framework ==========
if ($cfg.disable_signature -eq 'true' -or $cfg.install_toolbox -eq 'true' -or $cfg.disable_secure_flag -eq 'true' -or $cfg.cn_notification_fix -eq 'true') {
    Write-Step '5. PATCH FRAMEWORK'
    $fw  = Join-Path $work 'system\system\system\framework\framework.jar'
    $sv  = Join-Path $work 'system\system\system\framework\services.jar'
    $msv = Join-Path $work 'system_ext\system_ext\framework\miui-services.jar'
    # FrameworkPatcher optional (tools/FrameworkPatcher) — fallback = Python auto_patch
    $fpDir = Join-Path (Join-Path $Root 'tools') 'FrameworkPatcher\FrameworkPatcher-master'
    $bash = $null
    foreach ($b in @('C:\Program Files\Git\bin\bash.exe', (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'))) {
        if (Test-Path $b) { $bash = $b; break }
    }

    # 5a. FrameworkPatcher: signature + kaorios (copy jars in, run, copy out)
    if ((Test-Path $fpDir) -and (Test-Path $bash) -and ($cfg.disable_signature -eq 'true' -or $cfg.install_toolbox -eq 'true')) {
        Write-Ok 'FrameworkPatcher (signature + kaorios)...'
        Copy-Literal $fw  (Join-Path $fpDir 'framework.jar')
        Copy-Literal $sv  (Join-Path $fpDir 'services.jar')
        Copy-Literal $msv (Join-Path $fpDir 'miui-services.jar')
        $flags = @()
        if ($cfg.disable_signature -eq 'true') { $flags += '--disable-signature-verification' }
        if ($cfg.install_toolbox -eq 'true')   { $flags += '--kaorios-toolbox' }
        $cmd = "cd /d/LISA/build/tools/FrameworkPatcher/FrameworkPatcher-master && ./scripts/patcher_a14.sh 34 lisa OS2.0.16.0 --framework --services --miui-services " + ($flags -join ' ')
        & $bash -lc $cmd
        if (Test-Path (Join-Path $fpDir 'framework_patched.jar')) {
            Copy-Literal (Join-Path $fpDir 'framework_patched.jar') $fw
            Copy-Literal (Join-Path $fpDir 'services_patched.jar') $sv
            Copy-Literal (Join-Path $fpDir 'miui-services_patched.jar') $msv
            Write-Ok 'patched jars installed'
        } else { Write-Warn 'FrameworkPatcher output missing — dùng jar gốc' }
    }

    # 5b. Manual patches: checkCapability + secure flag + CN notification (Python)
    Write-Ok 'Manual patches (instance methods / secure flag / CN)...'
    $pyPatch = Join-Path $work 'auto_patch.py'
    @'
import re, zipfile, tempfile, shutil, os, subprocess, sys
from pathlib import Path

def decompile(jar, out, apktool):
    subprocess.check_call(["java","-jar",apktool,"d","-q","-f","-s","-o",out,jar])

def compile_apk(src, out, apktool):
    subprocess.check_call(["java","-jar",apktool,"b","-q","-f",src,"-o",out])

def force_return_z(path, method, value=0):
    text = path.read_text(encoding="utf-8", errors="replace")
    pat = re.compile(r"(\.method[^\n]*" + re.escape(method) + r"\([^\n]*\)Z\n)(.*?)(\.end method)", re.S)
    def repl(m):
        header, body, end = m.group(1), m.group(2), m.group(3)
        meta=[]
        for line in body.splitlines(keepends=True):
            s=line.strip()
            if s.startswith((".locals",".registers",".param",".annotation",".end annotation")) or s=="":
                meta.append(line)
            else: break
        locals_line = next((x for x in meta if x.strip().startswith((".locals",".registers"))), "    .locals 1\n")
        if not locals_line.strip().startswith((".locals",".registers")):
            locals_line = "    .locals 1\n"
        rest = "".join(x for x in meta if not x.strip().startswith((".locals",".registers")))
        return header + locals_line + rest + f"\n    const/4 v0, 0x{value:x}\n\n    return v0\n" + end
    new, n = pat.subn(repl, text)
    if n: path.write_text(new, encoding="utf-8")
    return n

def replace_is_intl(path):
    text = path.read_text(encoding="utf-8", errors="replace")
    new, n = re.subn(r"sget-boolean (v\d+), Lmiui/os/Build;->IS_INTERNATIONAL_BUILD:Z", r"const/4 \1, 0x1", text)
    if n: path.write_text(new, encoding="utf-8")
    return n

def fix_double_end(path):
    text = path.read_text(encoding="utf-8", errors="replace")
    text2 = re.sub(r"\.end method\s*\n\s*\.end method\s*\n", ".end method\n", text)
    path.write_text(text2, encoding="utf-8")

apktool = sys.argv[1]
work = Path(sys.argv[2])
do_secure = sys.argv[3] == "1"
do_cn = sys.argv[4] == "1"

sv_jar = work / "system/system/system/framework/services.jar"
msv_jar = work / "system_ext/system_ext/framework/miui-services.jar"
fw_jar = work / "system/system/system/framework/framework.jar"

for jar, tag, secure_cls, cn in [
    (fw_jar, "fw", False, False),
    (sv_jar, "sv", True, False),
    (msv_jar, "msv", True, True),
]:
    out = work / f"dec_{tag}"
    if out.exists(): shutil.rmtree(out, ignore_errors=True)
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
        fix_double_end(msv_jar)  # no-op
        for p in out.rglob("*.smali"):
            fix_double_end(p)
    if cn and do_cn:
        for name in ["BroadcastQueueModernStubImpl.smali","ActivityManagerServiceImpl.smali","ProcessManagerService.smali","ProcessSceneCleaner.smali"]:
            for p in out.rglob(name):
                replace_is_intl(p)
    rebuilt = work / f"{tag}_final.jar"
    compile_apk(str(out), str(rebuilt), apktool)
    shutil.copy2(rebuilt, jar)
    print("patched", jar.name)

print("AUTO_PATCH_DONE")
'@ | Set-Content -LiteralPath $pyPatch -Encoding UTF8

    $apktool = Get-Apktool
    $doSecure = if ($cfg.disable_secure_flag -eq 'true') { '1' } else { '0' }
    $doCn = if ($cfg.cn_notification_fix -eq 'true') { '1' } else { '0' }
    $py = Get-Python
    & $py $pyPatch $apktool $work $doSecure $doCn
    if ($LASTEXITCODE -ne 0) { Write-Warn 'auto_patch.py có lỗi — kiểm tra jar' }
}

# ========== 6. Kaorios app + props ==========
if ($cfg.install_toolbox -eq 'true') {
    Write-Step '6. KAORIOS APP'
    $kApp = Join-Path $Root "$($cfg.kaorios_dir)\KaoriosToolbox.apk"
    $kDst = Join-Path $work 'product\product\priv-app\KaoriosToolbox'
    if (Test-Path -LiteralPath $kApp) {
        Ensure-Dir $kDst
        Copy-Literal $kApp (Join-Path $kDst 'KaoriosToolbox.apk')
        $kXml = Join-Path $Root "$($cfg.kaorios_dir)\com.kousei.kaorios.xml"
        if (Test-Path -LiteralPath $kXml) {
            Copy-Literal $kXml (Join-Path $work 'product\product\etc\permissions\com.kousei.kaorios.xml')
        }
        Write-Ok 'KaoriosToolbox.apk installed'
    } else { Write-Warn "Kaorios APK missing: $kApp" }
    $bp = Join-Path $work 'system\system\system\build.prop'
    if (Test-Path $bp) {
        $txt = Get-Content $bp -Raw
        if ($txt -notmatch 'persist.sys.kaorios') {
            Add-Content -LiteralPath $bp -Value "`npersist.sys.kaorios=kousei`nro.control_privapp_permissions="
            Write-Ok 'build.prop + kaorios props'
        }
    }
}

# ========== 7. Vietnamese language (merge values-vi into Settings + framework-res) ==========
if (($cfg.add_vietnamese -eq 'true') -and (-not $SkipLang)) {
    Write-Step '7. VIETNAMESE LANGUAGE'
    $py = Get-Python
    $apktool = Get-Apktool
    $langDir = Join-Path $Root $cfg.lang_dir
    & $py -c @"
import os, shutil, subprocess, sys
from pathlib import Path

apktool = r'''$apktool'''
work = Path(r'''$work''')
lang = Path(r'''$langDir''')
java = 'java'

def rebuild_with_vi(apk, vi_src, tag):
    if not Path(apk).exists():
        print('skip', tag, 'apk missing'); return
    if not Path(vi_src).exists():
        print('skip', tag, 'values-vi missing'); return
    out = work / f'vi_{tag}'
    if out.exists(): shutil.rmtree(out, ignore_errors=True)
    subprocess.check_call([java, '-jar', apktool, 'd', '-q', '-f', '-s', '-o', str(out), apk])
    res = out / 'res'
    # copy values-vi (+ values-vi-rVN if present)
    for name in ('values-vi', 'values-vi-rVN'):
        src = Path(vi_src)
        if src.name != name:
            src = Path(vi_src).parent / name if (Path(vi_src).parent / name).exists() else src
        dst = res / name
        if src.exists() and src.is_dir():
            if dst.exists(): shutil.rmtree(dst, ignore_errors=True)
            shutil.copytree(src, dst)
            print(tag, 'copied', name)
    # remove invalid mcc folders that break aapt2
    import re
    for d in list(res.glob('values-mcc*')):
        if re.search(r'mcc(9460|9998|9999)', d.name):
            shutil.rmtree(d, ignore_errors=True)
            print(tag, 'removed', d.name)
    rebuilt = work / f'{tag}_vi.apk'
    subprocess.check_call([java, '-jar', apktool, 'b', '-q', '-f', str(out), str(rebuilt)])
    shutil.copy2(rebuilt, apk)
    print(tag, 'OK ->', apk)

# Settings (system_ext)
rebuild_with_vi(
    str(work / 'system_ext/system_ext/priv-app/Settings/Settings.apk'),
    str(lang / 'Settings' / 'values-vi'),
    'settings')
# framework-res (system)
rebuild_with_vi(
    str(work / 'system/system/system/framework/framework-res.apk'),
    str(lang / 'framework-res' / 'values-vi'),
    'fwres')
print('VIETNAMESE_DONE')
"@
    if ($LASTEXITCODE -eq 0) { Write-Ok 'values-vi merged into Settings + framework-res' }
    else { Write-Warn 'merge values-vi lỗi — kiểm tra assets/lang' }
}

# ========== 8. Strip fs_config prefix + rebuild EROFS ==========
Write-Step '8. REBUILD EROFS'
$mkfs = Get-Tool 'mkfs.erofs.exe'
foreach ($part in @('system','product','system_ext')) {
    $dir = Join-Path $work $part
    $src = Join-Path $dir $part
    $cfgd = Join-Path $dir 'config'
    $stripped = Join-Path $cfgd "$($part)_fs_config.stripped"
    $strippedFc = Join-Path $cfgd "$($part)_file_contexts.stripped"
    if (-not (Test-Path $stripped)) {
        $py = Get-Python
        & $py -c @"
from pathlib import Path
prefix = '$part'
cfg = Path(r'$cfgd')
def strip_cfg(inp, outp):
    lines = Path(inp).read_text(encoding='utf-8', errors='replace').splitlines()
    out=[]
    for line in lines:
        if not line.strip() or line.startswith('#'):
            out.append(line); continue
        parts=line.split()
        path=parts[0]
        if path=='/':
            out.append(line); continue
        if path==prefix or path==prefix+'/':
            out.append('/ '+' '.join(parts[1:])); continue
        if path.startswith(prefix+'/'):
            newp=path[len(prefix)+1:] or '/'
            out.append(newp+' '+' '.join(parts[1:])); continue
        out.append(line)
    Path(outp).write_text('\n'.join(out)+'\n', encoding='utf-8')
def strip_fc(inp, outp, prefix):
    lines=Path(inp).read_text(encoding='utf-8', errors='replace').splitlines()
    out=[]
    for line in lines:
        if not line.strip() or line.startswith('#'):
            out.append(line); continue
        parts=line.split()
        if len(parts)<2:
            out.append(line); continue
        path=parts[0]; rest=' '.join(parts[1:])
        if path in ('/','/.*'):
            out.append(line); continue
        if path.startswith('/'+prefix+'/'):
            out.append(path[1+len(prefix):] + ' ' + rest)
        elif path=='/'+prefix:
            out.append('/ '+rest)
        else:
            out.append(line)
    Path(outp).write_text('\n'.join(out)+'\n', encoding='utf-8')
strip_cfg(cfg / f'{prefix}_fs_config', cfg / f'{prefix}_fs_config.stripped')
strip_fc(cfg / f'{prefix}_file_contexts', cfg / f'{prefix}_file_contexts.stripped', prefix)
print('stripped', prefix)
"@
    }
    $outImg = Join-Path $images "$part.img"
    Write-Ok "mkfs.erofs $part ..."
    Push-Location $dir
    & $mkfs -d0 -z lz4hc,level=9 --all-root `
        --fs-config-file="config/$($part)_fs_config.stripped" `
        --file-contexts="config/$($part)_file_contexts.stripped" `
        -T0 --mkfs-time $outImg $part
    if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "mkfs.erofs $part failed (kiểm tra fs_config thiếu entry)" }
    Pop-Location
    Write-Ok "$part.img rebuilt"
}

# ========== 9. Pack super ==========
Write-Step '9. PACK SUPER'
$lpmake = Get-Tool 'lpmake.exe'
$superOut = Join-Path $images 'super.img'
Remove-Item -Force $superOut -EA 0
$szSys  = Pad-MB (Join-Path $images 'system.img')
$szExt  = Pad-MB (Join-Path $images 'system_ext.img')
$szProd = Pad-MB (Join-Path $images 'product.img')
$szVend = Pad-MB (Join-Path $images 'vendor.img')
$szOdm  = Pad-MB (Join-Path $images 'odm.img')
$szMi   = Pad-MB (Join-Path $images 'mi_ext.img')
[int64]$devSize = [int64]$cfg.super_device_size
& $lpmake --metadata-size $cfg.super_metadata_size --metadata-slots $cfg.super_metadata_slots --virtual-ab `
    --device-size $devSize --super-name super `
    "--group=qti_dynamic_partitions_a:${devSize}" `
    "--group=qti_dynamic_partitions_b:${devSize}" `
    "--partition=system_a:readonly:${szSys}:qti_dynamic_partitions_a" "--image=system_a=$(Join-Path $images 'system.img')" `
    "--partition=system_b:readonly:0:qti_dynamic_partitions_b" `
    "--partition=system_ext_a:readonly:${szExt}:qti_dynamic_partitions_a" "--image=system_ext_a=$(Join-Path $images 'system_ext.img')" `
    "--partition=system_ext_b:readonly:0:qti_dynamic_partitions_b" `
    "--partition=product_a:readonly:${szProd}:qti_dynamic_partitions_a" "--image=product_a=$(Join-Path $images 'product.img')" `
    "--partition=product_b:readonly:0:qti_dynamic_partitions_b" `
    "--partition=vendor_a:readonly:${szVend}:qti_dynamic_partitions_a" "--image=vendor_a=$(Join-Path $images 'vendor.img')" `
    "--partition=vendor_b:readonly:0:qti_dynamic_partitions_b" `
    "--partition=odm_a:readonly:${szOdm}:qti_dynamic_partitions_a" "--image=odm_a=$(Join-Path $images 'odm.img')" `
    "--partition=odm_b:readonly:0:qti_dynamic_partitions_b" `
    "--partition=mi_ext_a:readonly:${szMi}:qti_dynamic_partitions_a" "--image=mi_ext_a=$(Join-Path $images 'mi_ext.img')" `
    "--partition=mi_ext_b:readonly:0:qti_dynamic_partitions_b" `
    "--output=$superOut"
if ($LASTEXITCODE -ne 0) { Fail 'lpmake failed' }
Write-Ok "super.img = $((Get-Item $superOut).Length) bytes"

# ========== 10. Package flashable ==========
Write-Step '10. PACKAGE FLASHABLE'
& "$PSScriptRoot\packROM.ps1"

# ========== 11. Verify ==========
if (-not $NoVerify) {
    Write-Step '11. VERIFY'
    & "$PSScriptRoot\verify.ps1"
}

Write-Step 'DONE'
Write-Host "  Output: $outDir" -ForegroundColor Green
