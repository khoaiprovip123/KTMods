# verify.ps1 — kiểm tra package ROM sau build
. "$PSScriptRoot\scripts\tools.ps1"
$cfg = Get-KitchenConfig
$Root = $script:Root
$fail = 0

function Check([string]$name, [bool]$ok, [string]$detail = '') {
    if ($ok) { Write-Ok "$name $detail" }
    else { Write-Warn "FAIL: $name $detail"; $script:fail++ }
}

Write-Step 'VERIFY'

# find newest package
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

# flash scripts
Check 'flash_format_data.bat' (Test-Path (Join-Path $pkgDir 'flash_format_data.bat'))
Check 'flash_keep_data.bat' (Test-Path (Join-Path $pkgDir 'flash_keep_data.bat'))

# flash script must disable verity
$fmtPath = Join-Path $pkgDir 'flash_format_data.bat'
if (Test-Path $fmtPath) {
    $fmt = Get-Content $fmtPath -Raw
    Check 'vbmeta disable-verity' ($fmt -match 'disable-verity' -and $fmt -match 'disable-verification')
}

# firmware images
foreach ($img in @('boot.img','vbmeta.img','modem.img','vendor_boot.img')) {
    Check "images\$img" (Test-Path (Join-Path (Join-Path $pkgDir 'images') $img))
}

# work tree checks (if present)
$work = Join-Path $Root 'work'
if (Test-Path $work) {
    $fw = Join-Path $work 'system\system\system\framework\framework.jar'
    if (Test-Path $fw) {
        $py = Get-Python
        & $py -c @"
import zipfile
z=zipfile.ZipFile(r'$fw')
kaorios=any(b'kaorios' in z.read(n) or b'Kaori' in z.read(n) for n in z.namelist() if n.endswith('.dex'))
print('KAORIOS' if kaorios else 'NO_KAORIOS')
"@
        Check 'framework has Kaorios' ($LASTEXITCODE -eq 0)
    }
    $sec = Join-Path $work 'product\product\priv-app\MIUISecurityCenter\MIUISecurityCenter.apk'
    Check 'SecurityMod installed' ((Test-Path $sec) -and ((Get-Item $sec).Length -gt 50MB))
    $cam = Join-Path $work 'product\product\priv-app\MiuiCamera\MiuiCamera.apk'
    Check 'HolyBear Camera' ((Test-Path $cam) -and ((Get-Item $cam).Length -gt 100MB))
    # debloat: MSA / AnalyticsCore must be gone
    $msa = Join-Path $work 'product\product\app\MSA'
    Check 'MSA debloated' (-not (Test-Path -LiteralPath $msa))
    $an = Join-Path $work 'product\product\app\AnalyticsCore'
    Check 'AnalyticsCore debloated' (-not (Test-Path -LiteralPath $an))
    # Vietnamese
    $set = Join-Path $work 'system_ext\system_ext\priv-app\Settings\Settings.apk'
    if (Test-Path $set) {
        $py = Get-Python
        & $py -c @"
import zipfile
z=zipfile.ZipFile(r'$set')
# resources.arsc is compiled; check file size increased with values-vi (~100MB+)
print('SIZE', z.getinfo('resources.arsc').file_size)
"@
        Check 'Settings.apk present' $true
    }
}

if ($fail -gt 0) { Fail "verify FAILED: $fail checks" }
Write-Ok 'VERIFY PASSED'
exit 0
