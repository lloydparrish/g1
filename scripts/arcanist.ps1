param(
    [ValidateSet('Editor', 'Run', 'Test', 'Build', 'Setup')]
    [string]$Mode = 'Run'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$EngineDir = Join-Path $ProjectRoot '.tools\godot-4.7.2'
$GodotWindow = Join-Path $EngineDir 'Godot_v4.7.2-stable_win64.exe'
$GodotConsole = Join-Path $EngineDir 'Godot_v4.7.2-stable_win64_console.exe'
$Profile = Join-Path $ProjectRoot '.godot-profile'
$env:APPDATA = Join-Path $Profile 'Roaming'
$env:LOCALAPPDATA = Join-Path $Profile 'Local'

if ($Mode -eq 'Setup') {
    & (Join-Path $PSScriptRoot 'setup_godot.ps1') -InstallTemplates
    exit $LASTEXITCODE
}

if (-not (Test-Path -LiteralPath $GodotConsole)) {
    throw "Godot is not installed in $EngineDir. Run scripts\arcanist.ps1 Setup first."
}

switch ($Mode) {
    'Editor' {
        if (-not (Test-Path -LiteralPath $GodotWindow)) { throw "Missing editor executable: $GodotWindow" }
        & $GodotWindow --editor --path $ProjectRoot
    }
    'Run' {
        if (-not (Test-Path -LiteralPath $GodotWindow)) { throw "Missing game executable: $GodotWindow" }
        & $GodotWindow --path $ProjectRoot
    }
    'Test' {
        $env:APPDATA = Join-Path $Profile 'test\Roaming'
        $env:LOCALAPPDATA = Join-Path $Profile 'test\Local'
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/test_runner.gd'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/production_path_runner.gd'
        exit $LASTEXITCODE
    }
    'Build' {
        $TemplateDir = Join-Path $env:APPDATA 'Godot\export_templates\4.7.2.stable'
        if (-not (Test-Path -LiteralPath (Join-Path $TemplateDir 'windows_debug_x86_64.exe'))) {
            throw "Windows export template not found at $TemplateDir. Run scripts\arcanist.ps1 Setup first."
        }
        New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot 'build\windows') | Out-Null
        & $GodotConsole --headless --path $ProjectRoot --export-debug 'Windows Desktop' 'build/windows/ProjectArcanist.exe'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'build\windows\ProjectArcanist.exe'))) {
            throw 'Godot reported a successful export but the Windows executable was not created.'
        }
        Write-Output "Windows build: $(Join-Path $ProjectRoot 'build\windows\ProjectArcanist.exe')"
    }
}
