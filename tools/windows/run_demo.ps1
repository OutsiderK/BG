param(
    [string]$GodotExe = $env:GODOT_EXE
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Resolve-GodotExecutable {
    param([string]$Preferred)

    if ($Preferred -and (Test-Path $Preferred)) {
        return (Resolve-Path $Preferred).Path
    }

    foreach ($command in @("godot4", "godot")) {
        $found = Get-Command $command -ErrorAction SilentlyContinue
        if ($found) {
            return $found.Source
        }
    }

    $localTools = Join-Path $ProjectRoot "tools\godot"
    if (Test-Path $localTools) {
        $localExe = Get-ChildItem $localTools -Filter "Godot*.exe" -File | Select-Object -First 1
        if ($localExe) {
            return $localExe.FullName
        }
    }

    return $null
}

$Godot = Resolve-GodotExecutable -Preferred $GodotExe

if (-not $Godot) {
    Write-Host "Godot executable was not found."
    Write-Host "Set GODOT_EXE before running this script, for example:"
    Write-Host '$env:GODOT_EXE = "D:\Tools\Godot\Godot.exe"'
    exit 1
}

Write-Host "Running demo with $Godot"
& $Godot --path $ProjectRoot
