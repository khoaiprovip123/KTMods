# tools.ps1 — shared helpers (portable: không hardcode D:\LISA)
$ErrorActionPreference = 'Stop'
$script:Root = Split-Path $PSScriptRoot -Parent
if (-not $script:Root) { $script:Root = (Get-Location).Path }

function Write-Step([string]$msg) { Write-Host ""; Write-Host "==== $msg ====" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "  !!  $msg" -ForegroundColor Yellow }
function Fail([string]$msg) { Write-Host "  XX  $msg" -ForegroundColor Red; exit 1 }

function Get-KitchenConfig {
    $cfg = @{}
    $path = Join-Path $script:Root 'config.env'
    foreach ($line in Get-Content $path) {
        $line = $line.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        # strip inline comment:  key=value  # note
        $hash = $line.IndexOf('#')
        if ($hash -gt 0) { $line = $line.Substring(0, $hash).TrimEnd() }
        $i = $line.IndexOf('=')
        if ($i -lt 1) { continue }
        $cfg[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1).Trim()
    }
    return $cfg
}

# Tool lookup: tools/ rồi PATH (CI download về tools/)
function Get-Tool([string]$name) {
    $tools = Join-Path $script:Root 'tools'
    foreach ($cand in @(
        (Join-Path $tools $name),
        (Join-Path (Join-Path $tools 'erofs') $name),
        (Join-Path (Join-Path $tools 'payload-dumper-go') $name),
        $name
    )) {
        if ($cand -and (Test-Path -LiteralPath $cand)) { return $cand }
        $cmd = Get-Command $name -EA 0
        if ($cmd) { return $cmd.Source }
    }
    Fail "Tool not found: $name (chạy setup.ps1 hoặc đưa vào tools/)"
}

function Get-Apktool {
    foreach ($cand in @(
        (Join-Path (Join-Path $script:Root 'tools') 'apktool.jar'),
        (Join-Path $script:Root 'tools\apktool\apktool.jar')
    )) {
        if (Test-Path -LiteralPath $cand) { return $cand }
    }
    Fail 'apktool.jar not found in tools/'
}

function Get-Java {
    $j = Get-Command java -EA 0
    if ($j) { return $j.Source }
    Fail 'java not found in PATH (cần JDK 17+)'
}

function Get-Python {
    if ($env:MIMO_PYTHON -and (Test-Path $env:MIMO_PYTHON)) { return $env:MIMO_PYTHON }
    $p = Get-Command python -EA 0
    if ($p) { return $p.Source }
    Fail 'python not found'
}

function Pad-MB([string]$path, [int]$headroomMB = 16) {
    $s = (Get-Item -LiteralPath $path).Length
    return [int64](([math]::Ceiling($s / 1MB) + $headroomMB) * 1MB)
}

function Copy-Literal([string]$src, [string]$dst) { Copy-Item -LiteralPath $src -Destination $dst -Force }
function Ensure-Dir([string]$p) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
