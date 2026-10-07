param(
    [ValidateSet('Editor', 'Run', 'Test', 'Build', 'Android', 'BuildAll', 'Setup', 'SetupAndroid')]
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

if ($Mode -eq 'SetupAndroid') {
	& (Join-Path $PSScriptRoot 'setup_android.ps1')
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
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/mobile_acceptance_runner.gd'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/prompt6a_ui_runner.gd'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/progression_inventory_runner.gd'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/playtest_regressions_runner.gd'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/balance_runner.gd'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/combat_presentation_runner.gd'
        exit $LASTEXITCODE
    }
    'Android' {
        $PowerShell = (Get-Process -Id $PID).Path
        & $PowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'export_android.ps1')
        exit $LASTEXITCODE
    }
    'BuildAll' {
        $env:APPDATA = Join-Path $Profile 'test\Roaming'
        $env:LOCALAPPDATA = Join-Path $Profile 'test\Local'
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/test_runner.gd'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/production_path_runner.gd'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/mobile_acceptance_runner.gd'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/prompt6a_ui_runner.gd'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/progression_inventory_runner.gd'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/playtest_regressions_runner.gd'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/balance_runner.gd'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $GodotConsole --headless --path $ProjectRoot --script 'res://tests/combat_presentation_runner.gd'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        $env:APPDATA = Join-Path $Profile 'Roaming'
        $env:LOCALAPPDATA = Join-Path $Profile 'Local'
        $TemplateDir = Join-Path $env:APPDATA 'Godot\export_templates\4.7.2.stable'
        if (-not (Test-Path -LiteralPath (Join-Path $TemplateDir 'windows_debug_x86_64.exe'))) { throw "Windows export template not found at $TemplateDir. Run scripts\arcanist.ps1 Setup first." }
        New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot 'build\windows\current') | Out-Null
        & $GodotConsole --headless --path $ProjectRoot --export-debug 'Windows Desktop' 'build/windows/current/ProjectArcanist.exe'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        $PowerShell = (Get-Process -Id $PID).Path
        & $PowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'export_android.ps1')
        exit $LASTEXITCODE
    }
    'Build' {
        $TemplateDir = Join-Path $env:APPDATA 'Godot\export_templates\4.7.2.stable'
        if (-not (Test-Path -LiteralPath (Join-Path $TemplateDir 'windows_debug_x86_64.exe'))) {
            throw "Windows export template not found at $TemplateDir. Run scripts\arcanist.ps1 Setup first."
        }
        New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot 'build\windows\current') | Out-Null
        & $GodotConsole --headless --path $ProjectRoot --export-debug 'Windows Desktop' 'build/windows/current/ProjectArcanist.exe'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'build\windows\current\ProjectArcanist.exe'))) {
            throw 'Godot reported a successful export but the Windows executable was not created.'
        }
        Write-Output "Windows build: $(Join-Path $ProjectRoot 'build\windows\current\ProjectArcanist.exe')"
    }
}
