param(
    [string]$Branch   = "feat/demo-v0-integration",
    [string]$GodotExe = $env:GODOT_EXE
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

& (Join-Path $PSScriptRoot "sync_project.ps1") -Branch $Branch
& (Join-Path $PSScriptRoot "run_demo.ps1") -GodotExe $GodotExe
