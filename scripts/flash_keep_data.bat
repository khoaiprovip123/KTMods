@echo off
cd /d "%~dp0"
echo === rom-kitchen lisa FLASH - KEEP DATA (same ROM only) ===
set "fastboot=bin\fastboot.exe"
if not exist "%fastboot%" set "fastboot=fastboot.exe"
"%fastboot%" getvar product 2>&1 | findstr /i /c:"product: lisa" >nul
if errorlevel 1 (
  echo [STOP] Device is NOT lisa. DO NOT FLASH.
  pause & exit /B 1
)
for %%A in (images\super.img) do set SUPER_SIZE=%%~zA
if not "%SUPER_SIZE%"=="9126805504" (
  echo [STOP] super.img size wrong: %SUPER_SIZE%
  pause & exit /B 1
)
echo [OK] lisa + super size OK. Only use if already on OS2.0.16.0.
set /p choice=Keep data and flash? [y/N]
if /i not "%choice%"=="y" exit /B 0
"%fastboot%" flash boot_ab images\boot.img || goto :fail
"%fastboot%" flash vendor_boot_ab images\vendor_boot.img || goto :fail
"%fastboot%" --disable-verity --disable-verification flash vbmeta_ab images\vbmeta.img || goto :fail
"%fastboot%" --disable-verity --disable-verification flash vbmeta_system_ab images\vbmeta_system.img || goto :fail
"%fastboot%" flash super images\super.img || goto :fail
"%fastboot%" reboot
pause
exit /B 0
:fail
echo [ERROR] Flash failed.
pause
exit /B 1
