@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"
set "LOG=flash_keep_data_log.txt"
echo === keep-data flash %DATE% %TIME% === > "%LOG%"
set "fastboot=bin\fastboot.exe"
if not exist "%fastboot%" set "fastboot=fastboot.exe"
"%fastboot%" getvar product 2>&1 | findstr /i /c:"product: lisa" >nul
if errorlevel 1 (
  echo [STOP] not lisa >> "%LOG%" & echo [STOP] not lisa & pause & exit /B 1
)
for %%A in (images\super.img) do set SUPER_SIZE=%%~zA
if not "%SUPER_SIZE%"=="9126805504" (
  echo [STOP] bad super size %SUPER_SIZE% >> "%LOG%" & echo [STOP] bad super size & pause & exit /B 1
)
set /p choice=Keep data and flash? [y/N]
if /i not "%choice%"=="y" exit /B 0
for %%C in (
  "boot_ab images\boot.img"
  "vendor_boot_ab images\vendor_boot.img"
) do for /f "tokens=1,2" %%a in (%%C) do (
  echo flash %%a >> "%LOG%"
  "%fastboot%" flash %%a %%b >> "%LOG%" 2>&1 || (echo FAIL %%a & pause & exit /B 1)
)
"%fastboot%" --disable-verity --disable-verification flash vbmeta_ab images\vbmeta.img >> "%LOG%" 2>&1
"%fastboot%" --disable-verity --disable-verification flash vbmeta_system_ab images\vbmeta_system.img >> "%LOG%" 2>&1
echo flash super >> "%LOG%"
"%fastboot%" flash super images\super.img >> "%LOG%" 2>&1 || (echo FAIL super & pause & exit /B 1)
"%fastboot%" reboot >> "%LOG%" 2>&1
echo Log: %CD%\%LOG%
pause
