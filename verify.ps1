<#
  verify.ps1 — kiem tra package ROM sau build
#>
. "$PSScriptRoot\scripts\tools.ps1"
$cfg = Get-KitchenConfig
$Root = $script:Root
$fail = 0

function Check([string]$name, [bool]$ok, [string]$detail = '') {
    if ($ok) { Write-Ok "$name $detail" }
    else { Write-Warn "FAIL: $name $detail"; $script:fail++ }
}

Write-Step 'VERIFY'

$pkg = Get-ChildItem (Join-Path $Root $cfg.out_dir) -Directory -EA 0 |
    Where-Object { $_.Name -like "$($cfg.rom_name)*" } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $pkg) { Fail 'No package in out/' }
$pkgDir = $pkg.FullName
Write-Ok "package: $pkgDir"

$super = Join-Path (Join-Path $pkgDir 'images') 'super.img'
Check 'super.img exists' (Test-Path $super)
if (Test-Path $super) {
    $sz = (Get-Item $super).Length
    $expect = [int64]$cfg.super_device_size
    Check "super size == $expect" ($sz -eq $expect) "($sz)"
}

# flash scripts (copy nguyen ban — anti-brick + ZKOS order + cust)
Check 'flash_format_data.bat' (Test-Path (Join-Path $pkgDir 'flash_format_data.bat'))
Check 'flash_keep_data.bat' (Test-Path (Join-Path $pkgDir 'flash_keep_data.bat'))

$fmtPath = Join-Path $pkgDir 'flash_format_data.bat'
if (Test-Path $fmtPath) {
    $fmt = Get-Content $fmtPath -Raw
    Check 'flash checks device lisa' ($fmt -match 'lisa')
    Check 'flash checks super size' ($fmt -match '9126805504')
    Check 'flash has cust.img' ($fmt -match 'cust')
    Check 'flash has vbmeta' ($fmt -match 'flash vbmeta_ab')
    $bytes = [System.IO.File]::ReadAllBytes($fmtPath)
    $hasCR = ($bytes | Where-Object { $_ -eq 13 }).Count -gt 0
    Check 'flash script has CRLF line endings' $hasCR
}

# firmware images
foreach ($img in @('boot.img', 'vbmeta.img', 'modem.img', 'vendor_boot.img', 'cust.img', 'xbl.img')) {
    Check "images\$img" (Test-Path (Join-Path (Join-Path $pkgDir 'images') $img))
}

# super layout: partition order should start with odm (ZKOS/stock)
$lpd = Join-Path (Join-Path $Root 'tools') 'lpdumps.exe'
if ((Test-Path $lpd) -and (Test-Path $super)) {
    $dump = & $lpd $super 2>&1 | Out-String
    Check 'super Attributes none' ($dump -notmatch 'Attributes: readonly')
    Check 'super virtual_ab' ($dump -match 'virtual_ab')
    Check 'super has odm_a' ($dump -match 'odm_a')
    Check 'super has mi_ext_a' ($dump -match 'mi_ext_a')
    # order hint: odm_a should appear before system_a in partition table
    $iOdm = $dump.IndexOf('Name: odm_a')
    $iSys = $dump.IndexOf('Name: system_a')
    Check 'partition order odm before system' (($iOdm -ge 0) -and ($iSys -gt $iOdm)) "(odm@$iOdm system@$iSys)"
}

# work tree checks (if present)
$work = Join-Path $Root 'work'
if (Test-Path $work) {
    $fw = Join-Path $work 'system\system\system\framework\framework.jar'
    Check 'framework.jar present' (Test-Path $fw)
    $sec = Join-Path $work 'product\product\priv-app\MIUISecurityCenter\MIUISecurityCenter.apk'
    Check 'SecurityMod installed' ((Test-Path $sec) -and ((Get-Item $sec).Length -gt 10MB))
    $cam = Join-Path $work 'product\product\priv-app\MiuiCamera\MiuiCamera.apk'
    Check 'HolyBear Camera' ((Test-Path $cam) -and ((Get-Item $cam).Length -gt 50MB))
    $msa = Join-Path $work 'product\product\app\MSA'
    Check 'MSA debloated' (-not (Test-Path -LiteralPath $msa))
    $kao = Join-Path $work 'product\product\priv-app\KaoriosToolbox\KaoriosToolbox.apk'
    Check 'KaoriosToolbox installed' (Test-Path -LiteralPath $kao)
}

if ($fail -gt 0) { Fail "verify FAILED: $fail checks" }
Write-Ok 'VERIFY PASSED'
exit 0
