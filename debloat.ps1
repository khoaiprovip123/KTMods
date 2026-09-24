<#
  debloat.ps1 — gỡ app rác theo config/debloat.txt
#>
. "$PSScriptRoot\scripts\tools.ps1"
$cfg = Get-KitchenConfig
$Root = $script:Root
$work = Join-Path $Root 'work'
$list = Join-Path $Root 'config\debloat.txt'

Write-Step 'DEBLOAT'
if (-not (Test-Path -LiteralPath $list)) { Fail "missing $list" }

$searchRoots = @(
    (Join-Path $work 'product\product\app'),
    (Join-Path $work 'product\product\priv-app'),
    (Join-Path $work 'product\product\data-app'),
    (Join-Path $work 'product\product\pangu\system\app'),
    (Join-Path $work 'product\product\pangu\system\priv-app'),
    (Join-Path $work 'system\system\system\app'),
    (Join-Path $work 'system\system\system\priv-app'),
    (Join-Path $work 'system_ext\system_ext\app'),
    (Join-Path $work 'system_ext\system_ext\priv-app')
)

$removed = 0
foreach ($line in Get-Content $list) {
    $name = $line.Trim()
    if (-not $name -or $name.StartsWith('#')) { continue }
    $hit = $false
    foreach ($root in $searchRoots) {
        $p = Join-Path $root $name
        if (Test-Path -LiteralPath $p) {
            Remove-Item -LiteralPath $p -Recurse -Force
            Write-Ok "removed $name"
            $removed++
            $hit = $true
        }
    }
    if (-not $hit) { Write-Warn "not found: $name" }
}
Write-Ok "debloat done — $removed apps removed"
