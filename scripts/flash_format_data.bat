@echo off
cd /d "%~dp0"
echo ============================================
echo  rom-kitchen lisa FLASH - FORMAT DATA
echo  Safe checks before flashing
echo ============================================

set "fastboot=bin\fastboot.exe"
if not exist "%fastboot%" (
  if exist "fastboot.exe" (set "fastboot=fastboot.exe") else (
    where fastboot >nul 2>&1 && (set "fastboot=fastboot") || (
      echo [ERROR] fastboot not found in bin\ or PATH
      pause & exit /B 1
    )
  )
)

rem ---- CHECK 1: device is lisa ----
echo.
echo [CHECK 1] Device...
"%fastboot%" getvar product 2>&1 | findstr /i /c:"product: lisa" >nul
if errorlevel 1 (
  echo [STOP] Device is NOT lisa or not in fastboot.
  echo        Flashing wrong device can HARD-BRICK.
  "%fastboot%" getvar product 2>&1
  pause & exit /B 1
)
echo [OK] Device = lisa

rem ---- CHECK 2: required images exist ----
echo.
echo [CHECK 2] Images...
for %%F in (
  images\super.img images\boot.img images\vbmeta.img images\vbmeta_system.img
  images\vendor_boot.img images\modem.img images\abl.img images\dtbo.img
) do (
  if not exist "%%F" (
    echo [STOP] Missing: %%F
    pause & exit /B 1
  )
)
echo [OK] All required images present

rem ---- CHECK 3: super.img size must be 8.5 GiB (9126805504) ----
echo.
echo [CHECK 3] super.img size...
for %%A in (images\super.img) do set SUPER_SIZE=%%~zA
echo        super.img = %SUPER_SIZE% bytes
if not "%SUPER_SIZE%"=="9126805504" (
  echo [STOP] super.img size != 9126805504. Wrong ROM for lisa super partition.
  echo        DO NOT FLASH. Rebuild with correct device_size.
  pause & exit /B 1
)
echo [OK] super.img size matches lisa (8.5 GiB)

rem ---- CHECK 4: warn ARB (cannot auto-read) ----
echo.
echo [WARN] Make sure this ROM is NOT older than current firmware (ARB).
echo        If unsure, do not flash. Backup EFS first.
echo.
set /p choice=All checks passed. Format data and flash? [y/N]
if /i not "%choice%"=="y" (
  echo Cancelled.
  exit /B 0
)

echo.
echo Flashing firmware...
"%fastboot%" set_active a || goto :fail
"%fastboot%" erase metadata || goto :fail
"%fastboot%" erase userdata || goto :fail
"%fastboot%" flash abl_ab images\abl.img || goto :fail
"%fastboot%" flash aop_ab images\aop.img || goto :fail
"%fastboot%" flash bluetooth_ab images\bluetooth.img || goto :fail
"%fastboot%" flash cpucp_ab images\cpucp.img || goto :fail
"%fastboot%" flash devcfg_ab images\devcfg.img || goto :fail
"%fastboot%" flash dsp_ab images\dsp.img || goto :fail
"%fastboot%" flash dtbo_ab images\dtbo.img || goto :fail
"%fastboot%" flash featenabler_ab images\featenabler.img || goto :fail
"%fastboot%" flash hyp_ab images\hyp.img || goto :fail
"%fastboot%" flash imagefv_ab images\imagefv.img || goto :fail
"%fastboot%" flash keymaster_ab images\keymaster.img || goto :fail
"%fastboot%" flash modem_ab images\modem.img || goto :fail
"%fastboot%" flash qupfw_ab images\qupfw.img || goto :fail
"%fastboot%" flash shrm_ab images\shrm.img || goto :fail
"%fastboot%" flash tz_ab images\tz.img || goto :fail
"%fastboot%" flash uefisecapp_ab images\uefisecapp.img || goto :fail
"%fastboot%" flash xbl_ab images\xbl.img || goto :fail
"%fastboot%" flash xbl_config_ab images\xbl_config.img || goto :fail
"%fastboot%" flash boot_ab images\boot.img || goto :fail
"%fastboot%" flash vendor_boot_ab images\vendor_boot.img || goto :fail

echo Flashing vbmeta (disable verity)...
"%fastboot%" --disable-verity --disable-verification flash vbmeta_ab images\vbmeta.img || goto :fail
"%fastboot%" --disable-verity --disable-verification flash vbmeta_system_ab images\vbmeta_system.img || goto :fail

echo Flashing super (few minutes)...
"%fastboot%" flash super images\super.img || goto :fail

echo.
echo [OK] Flash done. Rebooting...
"%fastboot%" reboot
pause
exit /B 0

:fail
echo.
echo [ERROR] Flash FAILED at a step. DO NOT reboot if possible.
echo         Report the error line above.
pause
exit /B 1
