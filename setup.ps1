<#
  setup.ps1 — portable: tải/copy tool + APK + Kaorios + lang
  Nguồn tùy chọn (có thì dùng): $env:KITCHEN_SRC_TOOLS, $env:KITCHEN_SRC_APK
  Mặc định không hardcode ổ D — CI chỉ cần tools/ đã có trong repo (LFS).
#>
. "$PSScriptRoot\scripts\tools.ps1"
$Root = $script:Root
Ensure-Dir (Join-Path $Root 'tools')
Ensure-Dir (Join-Path $Root 'assets\apks')
Ensure-Dir (Join-Path $Root 'assets\kaorios')
Ensure-Dir (Join-Path $Root 'assets\lang')

Write-Step 'SETUP rom-kitchen'

# --- tools từ KITCHEN_SRC_TOOLS (optional) ---
$srcTools = $env:KITCHEN_SRC_TOOLS
if ($srcTools -and (Test-Path $srcTools)) {
    Write-Ok "copy tools from $srcTools"
    foreach ($t in @('lpmake.exe','lpunpack.exe','lpdumps.exe','simg2img.exe','extract.erofs.exe','mkfs.erofs.exe','cygwin1.dll','apktool.jar')) {
        $s = Join-Path $srcTools $t
        if (-not (Test-Path $s)) {
            $s = Join-Path (Join-Path $srcTools 'erofs\erofs_tool_win-main\engine') $t
        }
        if (-not (Test-Path $s)) {
            $s = Join-Path (Join-Path $srcTools 'FrameworkPatcher\FrameworkPatcher-master\tools') $t
        }
        if (Test-Path $s) { Copy-Item -Force $s (Join-Path $Root "tools\$t"); Write-Ok $t }
    }
    $pd = Join-Path $srcTools 'payload-dumper-go\payload-dumper-go.exe'
    if (Test-Path $pd) {
        Ensure-Dir (Join-Path $Root 'tools\payload-dumper-go')
        Copy-Item -Force $pd (Join-Path $Root 'tools\payload-dumper-go')
        Write-Ok 'payload-dumper-go'
    }
}

# --- APK từ KITCHEN_SRC_APK (optional) ---
$apkSrc = $env:KITCHEN_SRC_APK
if ($apkSrc -and (Test-Path $apkSrc)) {
    Write-Ok "copy APKs from $apkSrc"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Get-ChildItem $apkSrc -Filter *.apk | ForEach-Object {
        Copy-Item -Force $_.FullName (Join-Path $Root 'assets\apks')
        Write-Ok "apk $($_.Name)"
    }
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

# --- Kaorios từ KITCHEN_SRC_TOOLS hoặc assets/kaorios đã LFS ---
$k = Join-Path $Root 'assets\kaorios\KaoriosToolbox.apk'
if (-not (Test-Path $k) -and $srcTools) {
    $kFp = Join-Path $srcTools 'FrameworkPatcher\FrameworkPatcher-master\kaorios_toolbox\KaoriosToolbox.apk'
    if (Test-Path $kFp) { Copy-Item -Force $kFp $k; Write-Ok 'KaoriosToolbox.apk' }
}

# --- Download APKs from config/apk-sources.txt ---
$sources = Join-Path $Root 'config\apk-sources.txt'
if (Test-Path $sources) {
    Write-Step 'DOWNLOAD APKs from apk-sources.txt'
    $apkOut = Join-Path $Root 'assets\apks'
    Ensure-Dir $apkOut
    foreach ($line in Get-Content $sources) {
        $url = $line.Trim()
        if (-not $url -or $url.StartsWith('#')) { continue }
        $fname = ($url -split '[/?]')[-1]
        if ($fname -match 'usp=|download' -or $fname.Length -gt 80) {
            $fname = 'apk_' + [guid]::NewGuid().ToString('N').Substring(0,8) + '.apk'
        }
        if ($fname -notmatch '\.apk$') { $fname = "$fname.apk" }
        $dest = Join-Path $apkOut $fname
        if (Test-Path -LiteralPath $dest) { Write-Ok "skip $fname"; continue }
        Write-Ok "get $url"
        if ($url -match 'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)') {
            $url = "https://drive.google.com/uc?export=download&id=$($Matches[1])"
        }
        curl.exe -L --fail --retry 3 -o $dest $url
        if ($LASTEXITCODE -eq 0) { Write-Ok "saved $fname" }
        else { Write-Warn "download failed: $url" }
    }
}

Write-Step 'SETUP DONE'
Write-Host '  Build:  .\build.ps1 -RomUrl "<link OTA>"' -ForegroundColor Green
Write-Host '  Verify: .\verify.ps1' -ForegroundColor Green
