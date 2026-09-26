$ErrorActionPreference = "Stop"
$Root = "d:\LISA\rom-kitchen"
. "$Root\scripts\tools.ps1"
$cfg = Get-KitchenConfig
$work = "$Root\work"
$images = "$Root\cache\images"
$scripts = "$Root\scripts"
$tools = "$Root\tools"
$mkfs = "$tools\mkfs.erofs.exe"
$lpmake = "$tools\lpmake.exe"
$py = Get-Python

$ensurePy = "$scripts\ensure_fs_config.py"
$stripPy  = "$scripts\strip_fs_config.py"

Write-Host "=== STEP 1: REBUILDING MODDED EROFS IMAGES ===" -ForegroundColor Cyan
foreach ($part in @('system', 'product', 'system_ext')) {
    $dir = Join-Path $work $part
    $cfgd = Join-Path $dir 'config'
    $srcDir = Join-Path $dir $part
    
    Write-Host "Processing fs_config for $part..." -ForegroundColor Yellow
    & $py $ensurePy $srcDir $cfgd $part
    & $py $stripPy $cfgd $part
    
    $outImg = Join-Path $images ($part + '.img')
    Remove-Item -Force $outImg -ErrorAction SilentlyContinue
    
    Write-Host "Running mkfs.erofs for $part..." -ForegroundColor Yellow
    Push-Location $dir
    $fsCfg = "config/${part}_fs_config.stripped"
    $fsCtx = "config/${part}_file_contexts.stripped"
    & $mkfs -d0 -z lz4hc,level=9 --fs-config-file="$fsCfg" --file-contexts="$fsCtx" -T0 --mkfs-time $outImg $part
    $rc = $LASTEXITCODE
    Pop-Location
    if ($rc -ne 0) {
        throw "mkfs.erofs failed for $part with exit code $rc"
    }
    $len = (Get-Item $outImg).Length
    Write-Host "  -> $part.img created: $([math]::Round($len / 1MB, 2)) MB" -ForegroundColor Green
}

Write-Host "=== STEP 2: PACKING MODDED SUPER.IMG ===" -ForegroundColor Cyan
function Get-PadSize([string]$path, [int]$headroomMB = 4) {
    $s = (Get-Item -LiteralPath $path).Length
    return [int64](([math]::Ceiling($s / 1MB) + $headroomMB) * 1MB)
}

$szOdm  = Get-PadSize (Join-Path $images 'odm.img')
$szProd = Get-PadSize (Join-Path $images 'product.img')
$szSys  = Get-PadSize (Join-Path $images 'system.img')
$szExt  = Get-PadSize (Join-Path $images 'system_ext.img')
$szVend = Get-PadSize (Join-Path $images 'vendor.img')
$szMi   = Get-PadSize (Join-Path $images 'mi_ext.img')
[int64]$devSize = [int64]$cfg.super_device_size

$odmImg  = Join-Path $images 'odm.img'
$prodImg = Join-Path $images 'product.img'
$sysImg  = Join-Path $images 'system.img'
$extImg  = Join-Path $images 'system_ext.img'
$vendImg = Join-Path $images 'vendor.img'
$miImg   = Join-Path $images 'mi_ext.img'
$superOut = "$Root\out\LISA_OS_MOD_1.0.0_20260925\images\super.img"

Remove-Item -Force $superOut -ErrorAction SilentlyContinue

Write-Host "Running lpmake for super.img (Order: odm, product, system, system_ext, vendor, mi_ext)..." -ForegroundColor Yellow
& $lpmake --metadata-size $cfg.super_metadata_size --metadata-slots $cfg.super_metadata_slots --virtual-ab `
    --device-size $devSize --super-name super `
    "--group=qti_dynamic_partitions_a:${devSize}" `
    "--group=qti_dynamic_partitions_b:${devSize}" `
    "--partition=odm_a:none:${szOdm}:qti_dynamic_partitions_a" "--image=odm_a=$odmImg" `
    "--partition=odm_b:none:0:qti_dynamic_partitions_b" `
    "--partition=product_a:none:${szProd}:qti_dynamic_partitions_a" "--image=product_a=$prodImg" `
    "--partition=product_b:none:0:qti_dynamic_partitions_b" `
    "--partition=system_a:none:${szSys}:qti_dynamic_partitions_a" "--image=system_a=$sysImg" `
    "--partition=system_b:none:0:qti_dynamic_partitions_b" `
    "--partition=system_ext_a:none:${szExt}:qti_dynamic_partitions_a" "--image=system_ext_a=$extImg" `
    "--partition=system_ext_b:none:0:qti_dynamic_partitions_b" `
    "--partition=vendor_a:none:${szVend}:qti_dynamic_partitions_a" "--image=vendor_a=$vendImg" `
    "--partition=vendor_b:none:0:qti_dynamic_partitions_b" `
    "--partition=mi_ext_a:none:${szMi}:qti_dynamic_partitions_a" "--image=mi_ext_a=$miImg" `
    "--partition=mi_ext_b:none:0:qti_dynamic_partitions_b" `
    "--output=$superOut"

$superLen = (Get-Item $superOut).Length
Write-Host "super.img successfully created: $superLen bytes" -ForegroundColor Green

Write-Host "=== STEP 3: VERIFYING SUPER LAYOUT ===" -ForegroundColor Cyan
& "$tools\lpdumps.exe" $superOut
