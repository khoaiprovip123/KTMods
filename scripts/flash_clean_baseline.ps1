$ErrorActionPreference = "Stop"
$fb = "d:\LISA\rom-kitchen\out\LISA_OS_MOD_1.0.0_20260925\bin\fastboot.exe"
$img = "d:\LISA\rom-kitchen\out\LISA_OS_MOD_1.0.0_20260925\images"

Write-Host "=== FLASHING CLEAN BASELINE TO DEVICE ===" -ForegroundColor Cyan

Write-Host "[1/7] Setting active slot a..." -ForegroundColor Yellow
& $fb set_active a

Write-Host "[2/7] Erasing metadata and userdata..." -ForegroundColor Yellow
& $fb erase metadata
& $fb erase userdata

Write-Host "[3/7] Flashing firmware partitions..." -ForegroundColor Yellow
$firmware = @("abl", "aop", "bluetooth", "cpucp", "devcfg", "dsp", "dtbo", "featenabler", "hyp", "imagefv", "keymaster", "modem", "qupfw", "shrm", "tz", "uefisecapp", "xbl", "xbl_config")
foreach ($p in $firmware) {
    $file = "$img\$p.img"
    if (Test-Path $file) {
        Write-Host "  -> Flash ${p}_ab"
        & $fb flash "${p}_ab" $file
    }
}

Write-Host "[4/7] Flashing vbmeta & vbmeta_system..." -ForegroundColor Yellow
& $fb flash vbmeta_ab "$img\vbmeta.img"
& $fb flash vbmeta_system_ab "$img\vbmeta_system.img"

Write-Host "[5/7] Flashing boot & vendor_boot..." -ForegroundColor Yellow
& $fb flash boot_ab "$img\boot.img"
& $fb flash vendor_boot_ab "$img\vendor_boot.img"
if (Test-Path "$img\cust.img") {
    & $fb flash cust "$img\cust.img"
}

Write-Host "[6/7] Flashing super.img (8.5 GB)..." -ForegroundColor Yellow
& $fb flash super "$img\super.img"

Write-Host "[7/7] Erasing metadata & userdata again..." -ForegroundColor Yellow
& $fb erase metadata
& $fb erase userdata

Write-Host "=== FLASHING COMPLETE! REBOOTING DEVICE... ===" -ForegroundColor Green
& $fb reboot
