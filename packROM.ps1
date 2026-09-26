<#
  packROM.ps1 — dong goi ROM flashable (copy flash scripts nguyen ban, khong overwrite)
#>
param(
    [switch]$Compress,
    [switch]$NoCompress
)
. "$PSScriptRoot\scripts\tools.ps1"
$cfg = Get-KitchenConfig
$Root = $script:Root
$images = Join-Path $Root 'cache\images'
$outDir = Join-Path $Root $cfg.out_dir
$ver = (Get-Content (Join-Path $Root 'Version') -Raw).Trim()
$name = "$($cfg.rom_name)_$($ver)_$(Get-Date -Format yyyyMMdd)"
$pkg = Join-Path $outDir $name

Write-Step "PACK $name"
Ensure-Dir (Join-Path $pkg 'images')
Ensure-Dir (Join-Path $pkg 'bin')

# firmware + super + cust (system/product/... nam trong super — khong copy le)
$skipParts = @('system.img', 'system_ext.img', 'product.img', 'vendor.img', 'odm.img', 'mi_ext.img')
foreach ($f in Get-ChildItem $images -Filter *.img) {
    if ($skipParts -contains $f.Name) { continue }
    $dstImg = Join-Path (Join-Path $pkg 'images') $f.Name
    Copy-Item -Force $f.FullName $dstImg
    Write-Ok "images\$($f.Name)"
}

# fastboot/adb
$binSrc = $null
$cands = @(
    (Join-Path (Join-Path $Root 'tools') 'platform-tools'),
    (Join-Path (Join-Path $Root 'tools') 'bin'),
    'D:\LISA\build\output\LISA_HyperOS2.0.16.0_CN_Mods\bin',
    'D:\LISA\NOthing\NTFlashTools-Windows\platform-tools'
)
foreach ($c in $cands) {
    if ((Test-Path (Join-Path $c 'fastboot.exe'))) { $binSrc = $c; break }
}
if ($binSrc) {
    Copy-Item -Recurse -Force "$binSrc\*" (Join-Path $pkg 'bin')
    Write-Ok "bin from $binSrc"
} else {
    foreach ($t in @('fastboot.exe', 'adb.exe', 'AdbWinApi.dll', 'AdbWinUsbApi.dll')) {
        $c = Get-Command $t -EA 0
        if ($c) { Copy-Item -Force $c.Source (Join-Path $pkg 'bin'); Write-Ok "bin $t" }
    }
    if (-not (Get-ChildItem (Join-Path $pkg 'bin') -EA 0)) { Write-Warn 'no fastboot/adb - user must install platform-tools' }
}

# flash scripts: copy nguyen ban va dam bao chuan CRLF cho Windows cmd.exe
$fmtTpl = Join-Path (Join-Path $Root 'scripts') 'flash_format_data.bat'
$keepTpl = Join-Path (Join-Path $Root 'scripts') 'flash_keep_data.bat'

function Copy-BatScript([string]$src, [string]$dst) {
    if (Test-Path $src) {
        $content = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::ASCII)
        $crlf = $content.Replace("`r`n", "`n").Replace("`n", "`r`n")
        [System.IO.File]::WriteAllText($dst, $crlf, [System.Text.Encoding]::ASCII)
        Write-Ok (Split-Path $dst -Leaf)
    } else {
        Write-Warn "missing $src"
    }
}

Copy-BatScript $fmtTpl (Join-Path $pkg 'flash_format_data.bat')
Copy-BatScript $keepTpl (Join-Path $pkg 'flash_keep_data.bat')

@"
# $name
Built by rom-kitchen $(Get-Date -Format 'yyyy-MM-dd HH:mm')

## Flash
- Lan dau: flash_format_data.bat (format data)
- Giu data: flash_keep_data.bat (cung ban ROM)

## Mods
- Signature bypass, Kaorios, Secure Flag, CN Notification
- APK mods from assets/apks
- Vietnamese language (neu bat)
"@ | Set-Content (Join-Path $pkg 'README.md') -Encoding UTF8

$total = (Get-ChildItem $pkg -Recurse -File | Measure-Object Length -Sum).Sum
Write-Ok "package: $([math]::Round($total/1GB,2)) GB -> $pkg"

if ((-not $NoCompress) -and ($Compress -or $cfg.compress -eq '7z')) {
    $seven = $null
    $pf = $env:ProgramFiles
    if (-not $pf) { $pf = 'C:\Program Files' }
    foreach ($c in @((Join-Path $pf '7-Zip\7z.exe'), 'C:\Program Files\7-Zip\7z.exe', '7z.exe')) {
        if ($c -and ((Test-Path $c) -or (Get-Command $c -EA 0))) { $seven = $c; break }
    }
    if ($seven) {
        $archive = Join-Path $outDir "$name.7z"
        Remove-Item -Force $archive -EA 0
        Write-Ok 'compressing 7z...'
        & $seven a -t7z -m0=LZMA2 -mx=1 -mmt=on -bso0 $archive "$pkg\*"
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "archive: $([math]::Round((Get-Item $archive).Length/1GB,2)) GB"
        }
    } else { Write-Warn '7z.exe not found — skip compress' }
}
