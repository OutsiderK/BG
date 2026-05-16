param(
    [string]$Branch = "feat/demo-v0-integration"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $ProjectRoot

if (-not (Test-Path ".git")) {
    throw "This directory is not a Git repository: $ProjectRoot"
}

git fetch origin
git switch $Branch
git pull --ff-only origin $Branch

Write-Host "Project synced on branch $Branch"
