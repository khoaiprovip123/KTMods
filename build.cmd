@echo off
rem rom-kitchen — build ROM from URL or local OTA
rem Usage:  build <url-or-path>
rem Example: build https://cdnorg.d.miui.com/OS2.0.16.0.UKOCNXM/lisa-ota_full-OS2.0.16.0.UKOCNXM-user-14.0-6326c122fd.zip
setlocal
set SCRIPT_DIR=%~dp0
if "%~1"=="" (
  echo Usage: build ^<url-or-ota-path^>
  echo Example: build https://cdnorg.d.miui.com/OS2.0.16.0.UKOCNXM/lisa-ota_full-OS2.0.16.0.UKOCNXM-user-14.0-6326c122fd.zip
  exit /B 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%build.ps1" -RomUrl "%~1"
exit /B %ERRORLEVEL%
