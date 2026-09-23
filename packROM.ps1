<#
  packROM.ps1 — đóng gói ROM flashable + nén 7z
#>
param(
    [switch]$Compress
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

# firmware images
foreach ($f in Get-ChildItem $images -Filter *.img) {
    Copy-Item -Force $f.FullName (Join-Path $pkg 'images' $f.Name)
    Write-Ok "images\$($f.Name)"
}

# fastboot/adb
$binSrc = 'D:\LISA\NOthing\NTFlashTools-Windows\platform-tools'
if (Test-Path $binSrc) {
    Copy-Item -Recurse -Force "$binSrc\*" (Join-Path $pkg 'bin')
}

# flash scripts
$vb = $cfg  # flags
@'
@echo off
cd /d "%~dp0"
set fastboot=bin\fastboot.exe
echo === rom-kitchen lisa flash (format data) ===
set /p choice=Format data and flash? [y/N]
if /i "%choice%" neq "y" exit /B 0
%fastboot% set_active a
%fastboot% erase metadata
%fastboot% erase userdata
%fastboot% flash abl_ab images\abl.img
%fastboot% flash aop_ab images\aop.img
%fastboot% flash bluetooth_ab images\bluetooth.img
%fastboot% flash cpucp_ab images\cpucp.img
%fastboot% flash devcfg_ab images\devcfg.img
%fastboot% flash dsp_ab images\dsp.img
%fastboot% flash dtbo_ab images\dtbo.img
%fastboot% flash featenabler_ab images\featenabler.img
%fastboot% flash hyp_ab images\hyp.img
%fastboot% flash imagefv_ab images\imagefv.img
%fastboot% flash keymaster_ab images\keymaster.img
%fastboot% flash modem_ab images\modem.img
%fastboot% flash qupfw_ab images\qupfw.img
%fastboot% flash shrm_ab images\shrm.img
%fastboot% flash tz_ab images\tz.img
%fastboot% flash uefisecapp_ab images\uefisecapp.img
%fastboot% flash xbl_ab images\xbl.img
%fastboot% flash xbl_config_ab images\xbl_config.img
%fastboot% flash boot_ab images\boot.img
%fastboot% flash vendor_boot_ab images\vendor_boot.img
%fastboot% --disable-verity --disable-verification flash vbmeta_ab images\vbmeta.img
%fastboot% --disable-verity --disable-verification flash vbmeta_system_ab images\vbmeta_system.img
%fastboot% flash super images\super.img
%fastboot% reboot
pause
'@ | Set-Content (Join-Path $pkg 'flash_format_data.bat') -Encoding ASCII

@'
@echo off
cd /d "%~dp0"
set fastboot=bin\fastboot.exe
echo === keep data (cung ban 2.0.16.0) ===
set /p choice=Continue? [y/N]
if /i "%choice%" neq "y" exit /B 0
%fastboot% flash boot_ab images\boot.img
%fastboot% flash vendor_boot_ab images\vendor_boot.img
%fastboot% --disable-verity --disable-verification flash vbmeta_ab images\vbmeta.img
%fastboot% --disable-verity --disable-verification flash vbmeta_system_ab images\vbmeta_system.img
%fastboot% flash super images\super.img
%fastboot% reboot
pause
'@ | Set-Content (Join-Path $pkg 'flash_keep_data.bat') -Encoding ASCII

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

if ($Compress -or $cfg.compress -eq '7z') {
    $seven = 'C:\Program Files\7-Zip\7z.exe'
    if (Test-Path $seven) {
        $archive = Join-Path $outDir "$name.7z"
        Remove-Item -Force $archive -EA 0
        Write-Ok 'compressing 7z...'
        & $seven a -t7z -m0=LZMA2 -mx=1 -mmt=on -bso0 $archive "$pkg\*"
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "archive: $([math]::Round((Get-Item $archive).Length/1GB,2)) GB"
        }
    } else { Write-Warn '7z.exe not found — bỏ qua nén' }
}
