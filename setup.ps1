<#
  setup.ps1 — tải tool + link APK/Kaorios vào rom-kitchen
#>
. "$PSScriptRoot\scripts\tools.ps1"
$Root = $script:Root
Ensure-Dir (Join-Path $Root 'tools')
Ensure-Dir (Join-Path $Root 'assets\apks')
Ensure-Dir (Join-Path $Root 'assets\kaorios')
Ensure-Dir (Join-Path $Root 'assets\lang')

Write-Step 'SETUP rom-kitchen'

# Copy tools from previous build workspace if present
$srcTools = 'D:\LISA\build\tools'
if (Test-Path $srcTools) {
    foreach ($t in @('lpmake.exe','lpunpack.exe','lpdumps.exe','simg2img.exe')) {
        $s = Join-Path $srcTools $t
        if (Test-Path $s) { Copy-Item -Force $s (Join-Path $Root "tools\$t"); Write-Ok $t }
    }
    $erofs = Join-Path $srcTools 'erofs\erofs_tool_win-main\engine'
    if (Test-Path $erofs) {
        Copy-Item -Force "$erofs\extract.erofs.exe" (Join-Path $Root 'tools')
        Copy-Item -Force "$erofs\mkfs.erofs.exe" (Join-Path $Root 'tools')
        Copy-Item -Force "$erofs\cygwin1.dll" (Join-Path $Root 'tools')
        Write-Ok 'erofs tools'
    }
    $pd = Join-Path $srcTools 'payload-dumper-go\payload-dumper-go.exe'
    if (Test-Path $pd) {
        Ensure-Dir (Join-Path $Root 'tools\payload-dumper-go')
        Copy-Item -Force $pd (Join-Path $Root 'tools\payload-dumper-go')
        Write-Ok 'payload-dumper-go'
    }
    $apk = Join-Path $srcTools 'FrameworkPatcher\FrameworkPatcher-master\tools\apktool.jar'
    if (Test-Path $apk) { Copy-Item -Force $apk (Join-Path $Root 'tools\apktool.jar'); Write-Ok 'apktool.jar' }
}

# Copy APKs from D:\LISA\APk
$apkSrc = 'D:\LISA\APk'
if (Test-Path $apkSrc) {
    Get-ChildItem $apkSrc -Filter *.apk | ForEach-Object {
        Copy-Item -Force $_.FullName (Join-Path $Root 'assets\apks')
        Write-Ok "apk $($_.Name)"
    }
    # extract zip modules to get inner APKs
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Get-ChildItem $apkSrc -Filter *.zip | ForEach-Object {
        $dest = Join-Path $Root ("assets\apks\" + ($_.BaseName -replace '@.*',''))
        if (-not (Test-Path $dest)) {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($_.FullName, $dest)
        }
        Get-ChildItem $dest -Recurse -Filter *.apk | ForEach-Object {
            Copy-Item -Force $_.FullName (Join-Path $Root 'assets\apks')
            Write-Ok "apk from zip $($_.Name)"
        }
    }
}

# Kaorios
$kSrc = 'D:\LISA\build\tools\kaorios'
$kFp = 'D:\LISA\build\tools\FrameworkPatcher\FrameworkPatcher-master\kaorios_toolbox'
if (Test-Path (Join-Path $kFp 'KaoriosToolbox.apk')) {
    Copy-Item -Force (Join-Path $kFp 'KaoriosToolbox.apk') (Join-Path $Root 'assets\kaorios')
    Copy-Item -Force (Join-Path $kFp 'privapp_whitelist_com.kousei.kaorios.xml') (Join-Path $Root 'assets\kaorios') -EA 0
    Write-Ok 'KaoriosToolbox.apk'
}
if (Test-Path (Join-Path $kSrc 'com.kousei.kaorios.xml')) {
    Copy-Item -Force (Join-Path $kSrc 'com.kousei.kaorios.xml') (Join-Path $Root 'assets\kaorios')
}

# Vietnamese values-vi from previous lang_check
$viFw = 'D:\LISA\build\work\lang_check\global_fwres\res\values-vi'
$viSet = 'D:\LISA\build\work\lang_check\global_settings\res\values-vi'
if (Test-Path $viFw) {
    Ensure-Dir (Join-Path $Root 'assets\lang\framework-res')
    Copy-Item -Recurse -Force $viFw (Join-Path $Root 'assets\lang\framework-res')
    Write-Ok 'lang framework-res values-vi'
}
if (Test-Path $viSet) {
    Ensure-Dir (Join-Path $Root 'assets\lang\Settings')
    Copy-Item -Recurse -Force $viSet (Join-Path $Root 'assets\lang\Settings')
    Write-Ok 'lang Settings values-vi'
}

Write-Step 'SETUP DONE'
Write-Host '  Build:  .\build.ps1 -RomUrl "<link OTA>"' -ForegroundColor Green
Write-Host '  Hoac:   .\build.ps1 -OtaZip "D:\LISA\lisa-ota_full-....zip"' -ForegroundColor Green
