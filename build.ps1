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
    [switch]$NoVerify,
    [switch]$SkipCompress
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
    $extractPy = Join-Path (Join-Path $Root 'scripts') 'extract_payload.py'
    & $py $extractPy $OtaZip $payload
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
        $cmd = "cd '" + ($fpDir -replace '\\','/') + "' && ./scripts/patcher_a14.sh 34 lisa OS2.0.16.0 --framework --services --miui-services " + ($flags -join ' ')
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
    $apktool = Get-Apktool
    $doSecure = if ($cfg.disable_secure_flag -eq 'true') { '1' } else { '0' }
    $doCn = if ($cfg.cn_notification_fix -eq 'true') { '1' } else { '0' }
    $py = Get-Python
    $autoPy = Join-Path (Join-Path $Root 'scripts') 'auto_patch.py'
    & $py $autoPy $apktool $work $doSecure $doCn
    if ($LASTEXITCODE -ne 0) { Write-Warn 'auto_patch.py failed' }
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
    $langDir = Join-Path $Root $cfg.lang_dir
    $mergePy = Join-Path (Join-Path $Root 'scripts') 'merge_vi_eu.py'
    & $py $mergePy $apktool $work $langDir
    $langEu = Join-Path $work 'lang_eu'
    if (Test-Path $langEu) {
        & $py $mergePy $apktool $work $langEu
    }
    Write-Ok 'values-vi merged from xiaomi.eu'
}

# ========== 8. Strip fs_config + rebuild EROFS ==========
Write-Step '8. REBUILD EROFS'
$mkfs = Get-Tool 'mkfs.erofs.exe'
$py = Get-Python
$stripPy = Join-Path (Join-Path $Root 'scripts') 'strip_fs_config.py'
foreach ($part in @('system','product','system_ext')) {
    $dir = Join-Path $work $part
    $cfgd = Join-Path $dir 'config'
    $stripped = Join-Path $cfgd "$($part)_fs_config.stripped"
    if (-not (Test-Path $stripped)) {
        & $py $stripPy $cfgd $part
    }
    $outImg = Join-Path $images "$part.img"
    Write-Ok "mkfs.erofs $part ..."
    Push-Location $dir
    & $mkfs -d0 -z lz4hc,level=9 --all-root `
        --fs-config-file="config/$($part)_fs_config.stripped" `
        --file-contexts="config/$($part)_file_contexts.stripped" `
        -T0 --mkfs-time $outImg $part
    if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "mkfs.erofs $part failed" }
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
if ($SkipCompress) { & "$PSScriptRoot\packROM.ps1" -NoCompress }
else { & "$PSScriptRoot\packROM.ps1" }

# ========== 11. Verify ==========
if (-not $NoVerify) {
    Write-Step '11. VERIFY'
    & "$PSScriptRoot\verify.ps1"
}

Write-Step 'DONE'
Write-Host "  Output: $outDir" -ForegroundColor Green
