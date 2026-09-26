$ErrorActionPreference = "Stop"
$fb = "d:\LISA\rom-kitchen\out\LISA_OS_MOD_1.0.0_20260925\bin\fastboot.exe"
$superImg = "d:\LISA\rom-kitchen\out\LISA_OS_MOD_1.0.0_20260925\images\super.img"

Write-Host "1. Setting active slot a..." -ForegroundColor Cyan
& $fb set_active a

Write-Host "2. Flashing super.img (9.12 GB with 256M chunks)..." -ForegroundColor Cyan
& $fb -S 256M flash super $superImg

Write-Host "3. Erasing metadata and userdata..." -ForegroundColor Cyan
& $fb erase metadata
& $fb erase userdata

Write-Host "4. Rebooting device..." -ForegroundColor Green
& $fb reboot
