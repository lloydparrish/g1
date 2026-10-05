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
	@{ Size = '2400x1080'; Overlay = 'abilities' },
	@{ Size = '2400x1080'; Overlay = 'pause' }
)) {
	$CaseDirectory = "res://build/visual-qa/$($CaptureCase.Overlay)"
	& $Godot --path $ProjectRoot -- "--capture=$($CaptureCase.Size)" "--capture-dir=$CaseDirectory" "--capture-overlay=$($CaptureCase.Overlay)"
	if ($LASTEXITCODE -ne 0) { throw "Overlay capture failed: $($CaptureCase.Overlay) at $($CaptureCase.Size)." }
	$Capture = Join-Path $ProjectRoot "build\visual-qa\$($CaptureCase.Overlay)\$($CaptureCase.Size).png"
	if (-not (Test-Path -LiteralPath $Capture)) { throw "Godot did not create the expected overlay capture: $Capture" }
	Write-Output "Captured $Capture"
}

$ScrolledWebDirectory = 'res://build/visual-qa/web-scrolled'
& $Godot --path $ProjectRoot -- '--capture=2400x1080' "--capture-dir=$ScrolledWebDirectory" '--capture-overlay=abilities' '--capture-full-web' '--capture-web-pan=1700,0'
if ($LASTEXITCODE -ne 0) { throw 'Scrolled ability-web capture failed.' }
$ScrolledWebCapture = Join-Path $ProjectRoot 'build\visual-qa\web-scrolled\2400x1080.png'
if (-not (Test-Path -LiteralPath $ScrolledWebCapture)) { throw "Godot did not create the expected capture: $ScrolledWebCapture" }
Write-Output "Captured $ScrolledWebCapture"

$TargetingDirectory = 'res://build/visual-qa/targeting'
& $Godot --path $ProjectRoot -- '--capture=2400x1080' "--capture-dir=$TargetingDirectory" '--capture-target=blood_lance'
if ($LASTEXITCODE -ne 0) { throw 'Targeting capture failed.' }
$TargetingCapture = Join-Path $ProjectRoot 'build\visual-qa\targeting\2400x1080.png'
if (-not (Test-Path -LiteralPath $TargetingCapture)) { throw "Godot did not create the expected capture: $TargetingCapture" }
Write-Output "Captured $TargetingCapture"
