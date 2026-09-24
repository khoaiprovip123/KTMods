<#
.SYNOPSIS
  rom-kitchen — build custom Xiaomi lisa ROM (no root) from stock OTA + mods.
.EXAMPLE
  .\build.ps1 -RomUrl "https://cdnorg.d.miui.com/OS2.0.16.0.UKOCNXM/lisa-ota_full-OS2.0.16.0.UKOCNXM-user-14.0-6326c122fd.zip"
  .\build.ps1 -OtaZip "D:\rom\ota.zip"
  .\build.ps1 -PackOnly
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
$scripts  = Join-Path $Root 'scripts'

Ensure-Dir $outDir
Ensure-Dir $work
Ensure-Dir $cache
Ensure-Dir $toolsDir
$py = Get-Python

if ($PackOnly) {
    Write-Step 'PACK ONLY'
    & "$PSScriptRoot\packROM.ps1"
    exit 0
}

# ========== 0. Resolve OTA ==========
Write-Step '0. RESOLVE OTA'
$payload = Join-Path $cache 'payload.bin'
$images  = Join-Path $cache 'images'
$cacheReady = (Test-Path $payload) -and (Test-Path (Join-Path $images 'system.img'))

if ($cacheReady -and -not $OtaZip) {
    Write-Ok 'cache ready - skip download'
}
else {
    if (-not $OtaZip) {
        if (-not $RomUrl) {
            Fail 'Need -RomUrl (link) or -OtaZip (file path)'
        }
        if (Test-Path -LiteralPath $RomUrl) {
            $OtaZip = $RomUrl
            Write-Ok "Local OTA: $OtaZip"
        }
        else {
            $OtaZip = Join-Path $cache 'rom_ota.zip'
            if ((Test-Path -LiteralPath $OtaZip) -and $SkipFetch) {
                Write-Ok "Skip fetch, use cache: $OtaZip"
            }
            else {
                Write-Ok "Downloading $RomUrl ..."
                # aria2c multi-conn faster; fallback curl with resume
                $aria = Get-Command aria2c -ErrorAction SilentlyContinue
                if ($aria) {
                    & $aria.Source -x 8 -s 8 -k 4M --file-allocation=none --retry-wait=3 -c -d $cache -o rom_ota.zip $RomUrl
                }
                else {
                    curl.exe -L --fail --retry 5 --retry-delay 3 -C - -o $OtaZip $RomUrl
                }
                if ($LASTEXITCODE -ne 0) { Fail 'Download failed' }
                Write-Ok "Downloaded $([math]::Round((Get-Item $OtaZip).Length / 1GB, 2)) GB"
            }
        }
    }
    if (-not (Test-Path -LiteralPath $OtaZip)) {
        Fail "OTA not found: $OtaZip"
    }
}

# ========== 1. Extract payload.bin ==========
Write-Step '1. EXTRACT PAYLOAD'
Write-Host "  Free disk: $([math]::Round((Get-PSDrive (Split-Path $Root -Qualifier).TrimEnd(':')).Free / 1GB, 1)) GB"
if (-not (Test-Path $payload)) {
    if (-not $OtaZip) { Fail 'payload.bin cache miss and no OTA' }
    & $py (Join-Path $scripts 'extract_payload.py') $OtaZip $payload
    if ($LASTEXITCODE -ne 0) { Fail 'extract payload.bin failed' }
    # free disk: delete OTA zip after payload extracted
    if ($OtaZip -and (Test-Path -LiteralPath $OtaZip) -and ($OtaZip -like '*rom_ota.zip')) {
        Remove-Item -LiteralPath $OtaZip -Force -ErrorAction SilentlyContinue
        Write-Ok 'removed rom_ota.zip (free disk)'
    }
}
else {
    Write-Ok "payload.bin cache: $payload"
}

# ========== 2. Dump partitions ==========
Write-Step '2. DUMP PARTITIONS'
Ensure-Dir $images
$need = @(
    'system.img', 'product.img', 'system_ext.img', 'vendor.img', 'odm.img',
    'mi_ext.img', 'boot.img', 'vbmeta.img', 'vbmeta_system.img',
    'vendor_boot.img', 'modem.img'
)
$missing = $need | Where-Object { -not (Test-Path (Join-Path $images $_)) }
if ($missing.Count -gt 0) {
    $pd = Join-Path (Join-Path $toolsDir 'payload-dumper-go') 'payload-dumper-go.exe'
    if (-not (Test-Path $pd)) { $pd = Get-Tool 'payload-dumper-go.exe' }
    & $pd -o $images $payload
    if ($LASTEXITCODE -ne 0) { Fail 'payload-dumper-go failed' }
}
else {
    Write-Ok 'images already dumped'
}
# free disk: payload no longer needed after dump
if ((Test-Path $payload) -and (Test-Path (Join-Path $images 'system.img'))) {
    Remove-Item -Force $payload -ErrorAction SilentlyContinue
    Write-Ok 'removed payload.bin (free disk)'
}

# ========== 3. Unpack EROFS ==========
Write-Step '3. UNPACK EROFS'
$extract = Get-Tool 'extract.erofs.exe'
foreach ($part in @('system', 'product', 'system_ext')) {
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
    $rootMap = @{
        product    = 'product\product'
        system     = 'system\system'
        system_ext = 'system_ext\system_ext'
    }
    foreach ($line in Get-Content $mapFile) {
        $line = $line.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $p = $line.Split('|')
        if ($p.Count -lt 3) { continue }
        $part   = $p[0]
        $dstRel = $p[1]
        $srcName = $p[2]
        $rmOat = '1'
        if ($p.Count -ge 4) { $rmOat = $p[3] }
        $src = Join-Path $apkDir $srcName
        $dst = Join-Path (Join-Path $work $rootMap[$part]) ($dstRel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $src)) {
            Write-Warn "skip (missing): $srcName"
            continue
        }
        Ensure-Dir (Split-Path $dst -Parent)
        Copy-Literal $src $dst
        Write-Ok "$srcName -> $dstRel"
        if ($rmOat -eq '1') {
            $oat = Join-Path (Split-Path $dst -Parent) 'oat'
            if (Test-Path -LiteralPath $oat) {
                Remove-Item -LiteralPath $oat -Recurse -Force
            }
        }
    }
}

# ========== 4b. Debloat ==========
if (($cfg.debloat -eq 'true') -and (-not $SkipDebloat) -and (Test-Path (Join-Path $Root 'config\debloat.txt'))) {
    Write-Step '4b. DEBLOAT'
    & "$PSScriptRoot\debloat.ps1"
}

# ========== 5. Patch framework ==========
$needPatch = (
    $cfg.disable_signature -eq 'true' -or
    $cfg.install_toolbox -eq 'true' -or
    $cfg.disable_secure_flag -eq 'true' -or
    $cfg.cn_notification_fix -eq 'true'
)
if ($needPatch) {
    Write-Step '5. PATCH FRAMEWORK'
    $apktool = Get-Apktool
    $doSecure = if ($cfg.disable_secure_flag -eq 'true') { '1' } else { '0' }
    $doCn = if ($cfg.cn_notification_fix -eq 'true') { '1' } else { '0' }
    & $py (Join-Path $scripts 'auto_patch.py') $apktool $work $doSecure $doCn
    if ($LASTEXITCODE -ne 0) { Write-Warn 'auto_patch.py failed' }
}

# ========== 6. Kaorios app + props ==========
if ($cfg.install_toolbox -eq 'true') {
    Write-Step '6. KAORIOS APP'
    $kApp = Join-Path $Root (Join-Path $cfg.kaorios_dir 'KaoriosToolbox.apk')
    $kDst = Join-Path $work 'product\product\priv-app\KaoriosToolbox'
    if (Test-Path -LiteralPath $kApp) {
        Ensure-Dir $kDst
        Copy-Literal $kApp (Join-Path $kDst 'KaoriosToolbox.apk')
        $kXml = Join-Path $Root (Join-Path $cfg.kaorios_dir 'com.kousei.kaorios.xml')
        if (Test-Path -LiteralPath $kXml) {
            Copy-Literal $kXml (Join-Path $work 'product\product\etc\permissions\com.kousei.kaorios.xml')
        }
        Write-Ok 'KaoriosToolbox.apk installed'
    }
    else {
        Write-Warn "Kaorios APK missing: $kApp"
    }
    $bp = Join-Path $work 'system\system\system\build.prop'
    if (Test-Path $bp) {
        $txt = Get-Content $bp -Raw
        if ($txt -notmatch 'persist.sys.kaorios') {
            Add-Content -LiteralPath $bp -Value "`npersist.sys.kaorios=kousei`nro.control_privapp_permissions="
            Write-Ok 'build.prop + kaorios props'
        }
    }
}

# ========== 7. Vietnamese language (values-vi from xiaomi.eu) ==========
if (($cfg.add_vietnamese -eq 'true') -and (-not $SkipLang)) {
    Write-Step '7. VIETNAMESE LANGUAGE'
    $apktool = Get-Apktool
    $langDir = Join-Path $Root $cfg.lang_dir
    $mergePy = Join-Path $scripts 'merge_vi_eu.py'
    & $py $mergePy $apktool $work $langDir
    $langEu = Join-Path $work 'lang_eu'
    if (Test-Path $langEu) {
        & $py $mergePy $apktool $work $langEu
    }
    Write-Ok 'values-vi merged'
}

# ========== 8. Rebuild EROFS ==========
Write-Step '8. REBUILD EROFS'
$mkfs = Get-Tool 'mkfs.erofs.exe'
$stripPy = Join-Path $scripts 'strip_fs_config.py'
foreach ($part in @('system', 'product', 'system_ext')) {
    $dir = Join-Path $work $part
    $cfgd = Join-Path $dir 'config'
    $stripped = Join-Path $cfgd ($part + '_fs_config.stripped')
    if (-not (Test-Path $stripped)) {
        & $py $stripPy $cfgd $part
    }
    $outImg = Join-Path $images ($part + '.img')
    Write-Ok "mkfs.erofs $part ..."
    Push-Location $dir
    $fsCfg = 'config/' + $part + '_fs_config.stripped'
    $fsCtx = 'config/' + $part + '_file_contexts.stripped'
    & $mkfs -d0 -z lz4hc,level=9 --all-root --fs-config-file="$fsCfg" --file-contexts="$fsCtx" -T0 --mkfs-time $outImg $part
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { Fail "mkfs.erofs $part failed" }
    Write-Ok "$part.img rebuilt"
}

# ========== 9. Pack super ==========
Write-Step '9. PACK SUPER'
$lpmake = Get-Tool 'lpmake.exe'
$superOut = Join-Path $images 'super.img'
Remove-Item -Force $superOut -ErrorAction SilentlyContinue
$szSys  = Pad-MB (Join-Path $images 'system.img')
$szExt  = Pad-MB (Join-Path $images 'system_ext.img')
$szProd = Pad-MB (Join-Path $images 'product.img')
$szVend = Pad-MB (Join-Path $images 'vendor.img')
$szOdm  = Pad-MB (Join-Path $images 'odm.img')
$szMi   = Pad-MB (Join-Path $images 'mi_ext.img')
[int64]$devSize = [int64]$cfg.super_device_size

$sysImg  = Join-Path $images 'system.img'
$extImg  = Join-Path $images 'system_ext.img'
$prodImg = Join-Path $images 'product.img'
$vendImg = Join-Path $images 'vendor.img'
$odmImg  = Join-Path $images 'odm.img'
$miImg   = Join-Path $images 'mi_ext.img'

& $lpmake --metadata-size $cfg.super_metadata_size --metadata-slots $cfg.super_metadata_slots --virtual-ab `
    --device-size $devSize --super-name super `
    "--group=qti_dynamic_partitions_a:${devSize}" `
    "--group=qti_dynamic_partitions_b:${devSize}" `
    "--partition=system_a:none:${szSys}:qti_dynamic_partitions_a" "--image=system_a=$sysImg" `
    "--partition=system_b:none:0:qti_dynamic_partitions_b" `
    "--partition=system_ext_a:none:${szExt}:qti_dynamic_partitions_a" "--image=system_ext_a=$extImg" `
    "--partition=system_ext_b:none:0:qti_dynamic_partitions_b" `
    "--partition=product_a:none:${szProd}:qti_dynamic_partitions_a" "--image=product_a=$prodImg" `
    "--partition=product_b:none:0:qti_dynamic_partitions_b" `
    "--partition=vendor_a:none:${szVend}:qti_dynamic_partitions_a" "--image=vendor_a=$vendImg" `
    "--partition=vendor_b:none:0:qti_dynamic_partitions_b" `
    "--partition=odm_a:none:${szOdm}:qti_dynamic_partitions_a" "--image=odm_a=$odmImg" `
    "--partition=odm_b:none:0:qti_dynamic_partitions_b" `
    "--partition=mi_ext_a:none:${szMi}:qti_dynamic_partitions_a" "--image=mi_ext_a=$miImg" `
    "--partition=mi_ext_b:none:0:qti_dynamic_partitions_b" `
    "--output=$superOut"
if ($LASTEXITCODE -ne 0) { Fail 'lpmake failed' }
Write-Ok "super.img = $((Get-Item $superOut).Length) bytes"

# ========== 10. Package ==========
Write-Step '10. PACKAGE FLASHABLE'
if ($SkipCompress) {
    & "$PSScriptRoot\packROM.ps1" -NoCompress
}
else {
    & "$PSScriptRoot\packROM.ps1"
}

# ========== 11. Verify ==========
if (-not $NoVerify) {
    Write-Step '11. VERIFY'
    & "$PSScriptRoot\verify.ps1"
}

Write-Step 'DONE'
Write-Host "  Output: $outDir" -ForegroundColor Green
