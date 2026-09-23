# tools.ps1 — shared helpers for rom-kitchen
# Dot-source: . "$PSScriptRoot\tools.ps1"

$ErrorActionPreference = 'Stop'
$script:Root = Split-Path $PSScriptRoot -Parent
if (-not $script:Root) { $script:Root = (Get-Location).Path }

function Write-Step([string]$msg) {
    Write-Host ""
    Write-Host "==== $msg ====" -ForegroundColor Cyan
}
function Write-Ok([string]$msg) { Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "  !!  $msg" -ForegroundColor Yellow }
function Fail([string]$msg) {
    Write-Host "  XX  $msg" -ForegroundColor Red
    exit 1
}

function Get-KitchenConfig {
    $cfg = @{}
    $path = Join-Path $script:Root 'config.env'
    foreach ($line in Get-Content $path) {
        $line = $line.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $i = $line.IndexOf('=')
        if ($i -lt 1) { continue }
        $k = $line.Substring(0, $i).Trim()
        $v = $line.Substring($i + 1).Trim()
        $cfg[$k] = $v
    }
    return $cfg
}

function Get-Tool([string]$name) {
    $tools = Join-Path $script:Root 'tools'
    $p = Join-Path $tools $name
    if (Test-Path -LiteralPath $p) { return $p }
    # fallback: D:\LISA\build\tools (bộ tool đã tải từ lần build trước)
    $fallback = "D:\LISA\build\tools\$name"
    if (Test-Path -LiteralPath $fallback) { return $fallback }
    $erofs = "D:\LISA\build\tools\erofs\erofs_tool_win-main\engine\$name"
    if (Test-Path -LiteralPath $erofs) { return $erofs }
    Fail "Tool not found: $name (chạy setup.ps1 hoặc copy vào tools\)"
}

function Get-Apktool {
    $cands = @(
        (Join-Path $script:Root 'tools\apktool.jar'),
        'D:\LISA\build\tools\FrameworkPatcher\FrameworkPatcher-master\tools\apktool.jar'
    )
    foreach ($c in $cands) { if (Test-Path -LiteralPath $c) { return $c } }
    Fail 'apktool.jar not found'
}

function Pad-MB([string]$path, [int]$headroomMB = 16) {
    $s = (Get-Item -LiteralPath $path).Length
    return [int64](([math]::Ceiling($s / 1MB) + $headroomMB) * 1MB)
}

function Copy-Literal([string]$src, [string]$dst) {
    Copy-Item -LiteralPath $src -Destination $dst -Force
}

function Ensure-Dir([string]$p) {
    New-Item -ItemType Directory -Force -Path $p | Out-Null
}
