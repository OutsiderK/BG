param(
    [string]$TargetDir = "C:\Users\joeyK\BG",
    [string]$RepoUrl   = "https://github.com/OutsiderK/BG.git",
    [string]$Branch    = "feat/demo-v0-integration"
)

$ErrorActionPreference = "Stop"

function Assert-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name. Please install Git for Windows first."
    }
}

Assert-Command "git"

$parent = Split-Path -Parent $TargetDir
if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent | Out-Null
}

if (Test-Path (Join-Path $TargetDir ".git")) {
    Write-Host "Existing repo found at $TargetDir, pulling latest..."
    Set-Location $TargetDir
    git fetch origin
    git switch $Branch
    git pull --ff-only origin $Branch
}
elseif (Test-Path $TargetDir) {
    $items = Get-ChildItem -Force $TargetDir
    if ($items) {
        throw "$TargetDir exists and is not empty but is not a Git repo. Move or remove it first."
    }
    Set-Location $TargetDir
    git clone --branch $Branch $RepoUrl .
}
else {
    Write-Host "Cloning into $TargetDir ..."
    git clone --branch $Branch $RepoUrl $TargetDir
    Set-Location $TargetDir
}

Write-Host ""
Write-Host "Project ready at: $TargetDir"
Write-Host "Branch: $Branch"
Write-Host ""
Write-Host "Next:"
Write-Host "  cd $TargetDir"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tools\windows\run_demo.ps1"
