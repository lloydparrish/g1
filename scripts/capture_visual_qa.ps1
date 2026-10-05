$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Godot = Join-Path $ProjectRoot '.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$Profile = Join-Path $ProjectRoot '.godot-profile\visual-qa'
$env:APPDATA = Join-Path $Profile 'Roaming'
$env:LOCALAPPDATA = Join-Path $Profile 'Local'
$CaptureDirectory = 'res://build/visual-qa'
$Sizes = @('1920x1080', '2560x1440', '2400x1080', '2340x1080', '1280x720')

if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot is missing: $Godot" }
foreach ($Size in $Sizes) {
    & $Godot --path $ProjectRoot -- "--capture=$Size" "--capture-dir=$CaptureDirectory"
    if ($LASTEXITCODE -ne 0) { throw "Visual capture failed at $Size." }
    $Capture = Join-Path $ProjectRoot "build\visual-qa\$Size.png"
    if (-not (Test-Path -LiteralPath $Capture)) { throw "Godot did not create the expected capture: $Capture" }
    Write-Output "Captured $Capture"
}

foreach ($CaptureCase in @(
	@{ Size = '2400x1080'; Overlay = 'inventory' },
	@{ Size = '1280x720'; Overlay = 'map' },
	@{ Size = '1920x1080'; Overlay = 'rewards' },
	@{ Size = '2400x1080'; Overlay = 'pause' }
)) {
	$CaseDirectory = "res://build/visual-qa/$($CaptureCase.Overlay)"
	& $Godot --path $ProjectRoot -- "--capture=$($CaptureCase.Size)" "--capture-dir=$CaseDirectory" "--capture-overlay=$($CaptureCase.Overlay)"
	if ($LASTEXITCODE -ne 0) { throw "Overlay capture failed: $($CaptureCase.Overlay) at $($CaptureCase.Size)." }
	$Capture = Join-Path $ProjectRoot "build\visual-qa\$($CaptureCase.Overlay)\$($CaptureCase.Size).png"
	if (-not (Test-Path -LiteralPath $Capture)) { throw "Godot did not create the expected overlay capture: $Capture" }
	Write-Output "Captured $Capture"
}
