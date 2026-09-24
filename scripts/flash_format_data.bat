@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

set "LOG=flash_log.txt"
echo ============================================ > "%LOG%"
echo  rom-kitchen lisa FLASH LOG >> "%LOG%"
echo  Date: %DATE% %TIME% >> "%LOG%"
echo ============================================ >> "%LOG%"

echo === rom-kitchen lisa flash (format data) - LOGGING ===
echo Log: %CD%\%LOG%
echo.

set "fastboot=bin\fastboot.exe"
if not exist "%fastboot%" (
  if exist "fastboot.exe" (
    set "fastboot=fastboot.exe"
  ) else (
    where fastboot >nul 2>&1
    if errorlevel 1 (
      echo [ERROR] fastboot not found | tee -a "%LOG%" 2>nul
      echo [ERROR] fastboot not found >> "%LOG%"
      echo [ERROR] fastboot not found
      pause & exit /B 1
    )
    set "fastboot=fastboot"
  )
)

echo [INFO] fastboot = %fastboot% >> "%LOG%"
echo [INFO] fastboot = %fastboot%

rem ---- CHECK 1: device ----
echo [CHECK 1] Device... >> "%LOG%"
"%fastboot%" getvar product 2>&1 | findstr /i /c:"product: lisa" >nul
if errorlevel 1 (
  echo [STOP] Device is NOT lisa or not in fastboot >> "%LOG%"
  echo [STOP] Device is NOT lisa or not in fastboot
  "%fastboot%" getvar product 2>&1 >> "%LOG%"
  "%fastboot%" getvar product 2>&1
  pause & exit /B 1
)
echo [OK] Device = lisa >> "%LOG%"
echo [OK] Device = lisa

rem ---- CHECK 2: images ----
echo [CHECK 2] Images... >> "%LOG%"
for %%F in (
  images\super.img images\boot.img images\vbmeta.img images\vbmeta_system.img
  images\vendor_boot.img images\modem.img images\abl.img images\dtbo.img
) do (
  if not exist "%%F" (
    echo [STOP] Missing: %%F >> "%LOG%"
    echo [STOP] Missing: %%F
    pause & exit /B 1
  )
)
echo [OK] All required images present >> "%LOG%"
echo [OK] All required images present

rem ---- CHECK 3: super size ----
echo [CHECK 3] super.img size... >> "%LOG%"
for %%A in (images\super.img) do set SUPER_SIZE=%%~zA
echo        super.img = %SUPER_SIZE% bytes >> "%LOG%"
echo        super.img = %SUPER_SIZE% bytes
if not "%SUPER_SIZE%"=="9126805504" (
  echo [STOP] super.img size != 9126805504 >> "%LOG%"
  echo [STOP] super.img size != 9126805504
  pause & exit /B 1
)
echo [OK] super size matches lisa (8.5 GiB) >> "%LOG%"
echo [OK] super size matches lisa (8.5 GiB)

echo. >> "%LOG%"
echo [WARN] Check ARB - do not flash older firmware >> "%LOG%"
echo [WARN] Check ARB - do not flash older firmware
echo.
set /p choice=All checks passed. Format data and flash? [y/N]
if /i not "%choice%"=="y" (
  echo Cancelled. >> "%LOG%"
  echo Cancelled.
  exit /B 0
)

echo. >> "%LOG%"
echo === START FLASH %TIME% === >> "%LOG%"
echo === START FLASH ===

call :flash "set_active a" "%fastboot%" set_active a
call :flash "erase metadata" "%fastboot%" erase metadata
call :flash "erase userdata" "%fastboot%" erase userdata
call :flash "abl" "%fastboot%" flash abl_ab images\abl.img
call :flash "aop" "%fastboot%" flash aop_ab images\aop.img
call :flash "bluetooth" "%fastboot%" flash bluetooth_ab images\bluetooth.img
call :flash "cpucp" "%fastboot%" flash cpucp_ab images\cpucp.img
call :flash "devcfg" "%fastboot%" flash devcfg_ab images\devcfg.img
call :flash "dsp" "%fastboot%" flash dsp_ab images\dsp.img
call :flash "dtbo" "%fastboot%" flash dtbo_ab images\dtbo.img
call :flash "featenabler" "%fastboot%" flash featenabler_ab images\featenabler.img
call :flash "hyp" "%fastboot%" flash hyp_ab images\hyp.img
call :flash "imagefv" "%fastboot%" flash imagefv_ab images\imagefv.img
call :flash "keymaster" "%fastboot%" flash keymaster_ab images\keymaster.img
call :flash "modem" "%fastboot%" flash modem_ab images\modem.img
call :flash "qupfw" "%fastboot%" flash qupfw_ab images\qupfw.img
call :flash "shrm" "%fastboot%" flash shrm_ab images\shrm.img
call :flash "tz" "%fastboot%" flash tz_ab images\tz.img
call :flash "uefisecapp" "%fastboot%" flash uefisecapp_ab images\uefisecapp.img
call :flash "xbl" "%fastboot%" flash xbl_ab images\xbl.img
call :flash "xbl_config" "%fastboot%" flash xbl_config_ab images\xbl_config.img
call :flash "boot" "%fastboot%" flash boot_ab images\boot.img
call :flash "vendor_boot" "%fastboot%" flash vendor_boot_ab images\vendor_boot.img
call :flash "vbmeta" "%fastboot%" --disable-verity --disable-verification flash vbmeta_ab images\vbmeta.img
call :flash "vbmeta_system" "%fastboot%" --disable-verity --disable-verification flash vbmeta_system_ab images\vbmeta_system.img
call :flash "super" "%fastboot%" flash super images\super.img

echo. >> "%LOG%"
echo === FLASH DONE %TIME% === >> "%LOG%"
echo [OK] All flash steps done. Rebooting... >> "%LOG%"
echo [OK] All flash steps done. Rebooting...
"%fastboot%" reboot >> "%LOG%" 2>&1
echo reboot cmd exit=!ERRORLEVEL! >> "%LOG%"
echo Log saved: %CD%\%LOG%
pause
exit /B 0

:flash
echo [%TIME%] FLASH %~1 ... >> "%LOG%"
echo [%TIME%] FLASH %~1 ...
shift
"%~1" %2 %3 %4 %5 %6 %7 %8 %9 >> "%LOG%" 2>&1
set "RC=!ERRORLEVEL!"
echo [%TIME%]   -> exit=!RC! >> "%LOG%"
if not "!RC!"=="0" (
  echo [ERROR] FAILED: %~1 >> "%LOG%"
  echo [ERROR] FAILED: %~1
  echo Log: %CD%\%LOG%
  pause
  exit /B 1
)
goto :eof
