@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"
title LISA ROM Flasher (Format Data)
color 0B

echo ==============================================================
echo           XIAOMI 11 LITE 5G NE (LISA) ROM INSTALLER
echo                Mode: FORMAT DATA (Clean Install)
echo ==============================================================
echo.

set "LOG=flash_log.txt"
echo === format-data flash %DATE% %TIME% === > "%LOG%"

set fastboot=bin\fastboot.exe
if not exist %fastboot% set fastboot=bin\windows\fastboot.exe
if not exist %fastboot% set fastboot=fastboot.exe
if not exist %fastboot% (
  color 0C
  echo [ERROR] fastboot.exe not found!
  echo [ERROR] fastboot.exe not found >> "%LOG%"
  pause
  exit /B 1
)

echo Waiting for device in FASTBOOT mode...
set device=
for /f "tokens=2" %%A in ('%fastboot% getvar product 2^>^&1 ^| findstr /l /b /c:"product:"') do set device=%%A
echo product=%device% >> "%LOG%"

if "%device%" equ "" (
  color 0C
  echo [ERROR] Your device could not be detected!
  echo  - Dua dien thoai ve FASTBOOT - Giu phim Nguon va Giam Am Luong
  echo  - Kiem tra cap USB va Driver Xiaomi Qualcomm
  pause
  exit /B 1
)

echo Your device: %device%
if /i "%device%" neq "lisa" (
  color 0C
  echo [STOP] Incompatible device: %device% >> "%LOG%"
  echo [STOP] Incompatible device: %device%
  echo This ROM is only for Xiaomi 11 Lite 5G NE lisa
  pause
  exit /B 1
)

if not exist "images\super.img" (
  color 0C
  echo [ERROR] images\super.img not found!
  pause
  exit /B 1
)

REM anti-brick: super MUST be exactly 9126805504 bytes
set SUPER_SIZE=
for %%A in (images\super.img) do set SUPER_SIZE=%%~zA
echo super.img=%SUPER_SIZE% >> "%LOG%"
if not "%SUPER_SIZE%"=="9126805504" (
  color 0C
  echo [STOP] super.img size = %SUPER_SIZE%, expected 9126805504 bytes >> "%LOG%"
  echo [STOP] super.img size = %SUPER_SIZE%, expected 9126805504 bytes
  pause
  exit /B 1
)

echo.
echo ==============================================================
echo  WARNING: All your apps, photos and data will be ERASED.
echo  Continue if you are flashing this ROM for the first time.
echo ==============================================================
set /p choice=Do you want to continue? [y/N]:
if /i "%choice%" neq "y" exit /B 0

echo.
echo ##############################################################
echo  Flashing in progress... Please DO NOT disconnect USB cable!
echo ##############################################################
echo.

call :do set_active a
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

echo Flashing vbmeta...
call :do flash vbmeta_ab images\vbmeta.img
if exist "images\vbmeta_system.img" call :do flash vbmeta_system_ab images\vbmeta_system.img

call :do flash xbl_ab images\xbl.img
call :do flash xbl_config_ab images\xbl_config.img
call :do flash boot_ab images\boot.img
call :do flash vendor_boot_ab images\vendor_boot.img

if exist "images\cust.img" call :do flash cust images\cust.img

echo Flashing super.img (takes about 2-3 minutes, please wait)...
call :do -S 256M flash super images\super.img

echo.
echo ##############################################################
color 0A
echo  FLASHING COMPLETED SUCCESSFULLY!
echo  Your device will reboot now.
echo ##############################################################
echo.
%fastboot% reboot >> "%LOG%" 2>&1
echo Log: %CD%\%LOG%
pause
exit /B 0

:do
echo   FLASH %*
echo [%TIME%] %* >> "%LOG%"
%fastboot% %* >> "%LOG%" 2>&1
set "RC=!ERRORLEVEL!"
echo [%TIME%]   exit=!RC! >> "%LOG%"
if not "!RC!"=="0" (
  color 0C
  echo [ERROR] FAILED: %* - check %LOG%
  echo [ERROR] FAILED: %* - check %LOG% >> "%LOG%"
  pause
  exit /B 1
)
echo   OK: %*
goto :eof
