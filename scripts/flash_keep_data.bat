@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"
title LISA ROM Flasher (Keep Data)
color 0B

echo ==============================================================
echo           XIAOMI 11 LITE 5G NE (LISA) ROM INSTALLER
echo                 Mode: KEEP DATA (Update/Dirty Flash)
echo ==============================================================
echo.

set "LOG=flash_keep_data_log.txt"
echo === keep-data flash %DATE% %TIME% === > "%LOG%"

set fastboot=bin\fastboot.exe
if not exist %fastboot% set fastboot=bin\windows\fastboot.exe
if not exist %fastboot% set fastboot=fastboot.exe
if not exist %fastboot% (
  color 0C
  echo [ERROR] fastboot.exe not found!
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
  pause
  exit /B 1
)

echo Your device: %device%
if /i "%device%" neq "lisa" (
  color 0C
  echo [STOP] Incompatible device: %device% >> "%LOG%"
  echo [STOP] Incompatible device: %device%
  pause
  exit /B 1
)

if not exist "images\super.img" (
  color 0C
  echo [ERROR] images\super.img not found!
  pause
  exit /B 1
)

set SUPER_SIZE=
for %%A in (images\super.img) do set SUPER_SIZE=%%~zA
echo super.img=%SUPER_SIZE% >> "%LOG%"
if not "%SUPER_SIZE%"=="9126805504" (
  color 0C
  echo [STOP] super.img size = %SUPER_SIZE% (need 9126805504) >> "%LOG%"
  echo [STOP] super.img size = %SUPER_SIZE% (need 9126805504)
  pause
  exit /B 1
)

echo.
echo ==============================================================
echo  NOTE: Keep Data mode preserves apps and files.
echo  Only use when updating within the same base ROM.
echo ==============================================================
set /p choice=Do you want to continue? [y/N]:
if /i "%choice%" neq "y" exit /B 0

echo.
echo ##############################################################
echo  Flashing in progress... Please DO NOT disconnect USB cable!
echo ##############################################################
echo.

REM keep-data: chi flash boot/vbmeta/cust/super ? khong dong firmware bootloader
call :do set_active a
call :do flash vbmeta_ab images\vbmeta.img
if exist "images\vbmeta_system.img" call :do flash vbmeta_system_ab images\vbmeta_system.img
call :do flash boot_ab images\boot.img
call :do flash vendor_boot_ab images\vendor_boot.img
if exist "images\cust.img" call :do flash cust images\cust.img
call :do flash super images\super.img

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
  echo [ERROR] FAILED: %*  (see %LOG%)
  echo [ERROR] FAILED: %* >> "%LOG%"
  pause
  exit /B 1
)
echo   OK: %*
goto :eof
