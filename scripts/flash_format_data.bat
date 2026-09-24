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

rem ZKOS-style fastboot path
set "fastboot=bin\fastboot.exe"
if not exist "%fastboot%" if exist "bin\windows\fastboot.exe" set "fastboot=bin\windows\fastboot.exe"
if not exist "%fastboot%" set "fastboot=fastboot.exe"

echo [INFO] fastboot=%fastboot% >> "%LOG%"
echo Waiting for device...
set device=
for /f "tokens=2" %%A in ('"%fastboot%" getvar product 2^>^&1 ^| findstr /l /b /c:"product:"') do set device=%%A
echo product=!device! >> "%LOG%"
if "!device!"=="" (
  echo Your device could not be detected. >> "%LOG%"
  echo Your device could not be detected.
  pause & exit /B 1
)
echo Your device: !device!
if /i not "!device!"=="lisa" (
  echo [STOP] Compatible devices: lisa - current: !device! >> "%LOG%"
  echo [STOP] Compatible devices: lisa - current: !device!
  pause & exit /B 1
)
echo [OK] Device = lisa >> "%LOG%"

rem super size check (anti-brick)
for %%A in (images\super.img) do set SUPER_SIZE=%%~zA
echo super.img=!SUPER_SIZE! >> "%LOG%"
if not "!SUPER_SIZE!"=="9126805504" (
  echo [STOP] super.img size != 9126805504 >> "%LOG%"
  echo [STOP] super.img size != 9126805504
  pause & exit /B 1
)

echo Your device will be flashed and the data partition will be formatted.
echo You will lose your apps, settings and files on internal storage.
set /p choice=Do you want to continue? [y/N]
if /i not "!choice!"=="y" (
  echo Cancelled. >> "%LOG%"
  exit /B 0
)

echo ############################################################## >> "%LOG%"
echo Please wait. The device will reboot once flashing is complete.
echo ##############################################################

call :do flash set_active a
call :do erase metadata
call :do erase userdata
call :do flash abl_ab images\abl.img
call :do flash aop_ab images\aop.img
call :do flash bluetooth_ab images\bluetooth.img
call :do flash cpucp_ab images\cpucp.img
call :do flash devcfg_ab images\devcfg.img
call :do flash dsp_ab images\dsp.img
call :do flash dtbo_ab images\dtbo.img
call :do flash featenabler_ab images\featenabler.img
call :do flash hyp_ab images\hyp.img
call :do flash imagefv_ab images\imagefv.img
call :do flash keymaster_ab images\keymaster.img
call :do flash modem_ab images\modem.img
call :do flash qupfw_ab images\qupfw.img
call :do flash shrm_ab images\shrm.img
call :do flash tz_ab images\tz.img
call :do flash uefisecapp_ab images\uefisecapp.img
rem ZKOS order: vbmeta then xbl/boot (NO --disable-verity, same as stock)
call :do flash vbmeta_ab images\vbmeta.img
call :do flash vbmeta_system_ab images\vbmeta_system.img
call :do flash xbl_ab images\xbl.img
call :do flash xbl_config_ab images\xbl_config.img
call :do flash boot_ab images\boot.img
call :do flash vendor_boot_ab images\vendor_boot.img
if exist images\cust.img call :do flash cust images\cust.img
call :do flash super images\super.img

echo [%TIME%] ALL DONE - rebooting >> "%LOG%"
echo All flash steps done. Rebooting...
"%fastboot%" reboot >> "%LOG%" 2>&1
echo Log: %CD%\%LOG%
pause
exit /B 0

:do
echo [%TIME%] %* >> "%LOG%"
"%fastboot%" %* >> "%LOG%" 2>&1
set "RC=!ERRORLEVEL!"
echo [%TIME%]   exit=!RC! >> "%LOG%"
if not "!RC!"=="0" (
  echo [ERROR] FAILED: %* >> "%LOG%"
  echo [ERROR] FAILED: %*
  echo Log: %CD%\%LOG%
  pause
  exit /B 1
)
goto :eof
