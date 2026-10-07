$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Godot = Join-Path $ProjectRoot '.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe'
$Profile = Join-Path $ProjectRoot '.godot-profile\visual-qa'
$env:APPDATA = Join-Path $Profile 'Roaming'
$env:LOCALAPPDATA = Join-Path $Profile 'Local'

if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot is missing: $Godot" }

$Cases = @(
	@{ Name = 'p6d-abilities-cleave'; Size = '1920x1080'; Scenario = 'abilities_cleave'; Overlay = 'character' },
	@{ Name = 'p6d-abilities-cleave-2560'; Size = '2560x1440'; Scenario = 'abilities_cleave'; Overlay = 'character' },
	@{ Name = 'p6d-abilities-cleave-reduced'; Size = '1280x720'; Scenario = 'abilities_cleave'; Overlay = 'character' },
	@{ Name = 'p6d-passives'; Size = '1920x1080'; Scenario = 'passives'; Overlay = 'character' },
	@{ Name = 'p6d-known'; Size = '1920x1080'; Scenario = 'known'; Overlay = 'character' },
	@{ Name = 'p6d-mobile-cleave'; Size = '2400x1080'; Scenario = 'abilities_cleave'; Overlay = 'character'; Mobile = $true },
	@{ Name = 'p6d-mobile-passives'; Size = '2400x1080'; Scenario = 'passives'; Overlay = 'character'; Mobile = $true },
	@{ Name = 'p6d-mobile-known'; Size = '2400x1080'; Scenario = 'known'; Overlay = 'character'; Mobile = $true },
	@{ Name = 'p6d-mobile-character-no-effects'; Size = '2400x1080'; Scenario = 'mobile_character_no_effects'; Overlay = 'character'; Mobile = $true },
	@{ Name = 'p6d-mobile-character-effects'; Size = '2400x1080'; Scenario = 'mobile_character_effects'; Overlay = 'character'; Mobile = $true }
)

foreach ($CaptureCase in $Cases) {
	$CaptureDirectory = "res://build/visual-qa/$($CaptureCase.Name)"
	$Arguments = @(
		"--capture=$($CaptureCase.Size)",
		"--capture-dir=$CaptureDirectory",
		"--capture-scenario=$($CaptureCase.Scenario)",
		"--capture-overlay=$($CaptureCase.Overlay)"
	)
	if ($CaptureCase.ContainsKey('Mobile') -and $CaptureCase.Mobile) { $Arguments += '--capture-mobile' }
	& $Godot --path $ProjectRoot -- @Arguments
	$EngineExitCode = $LASTEXITCODE
	$Capture = Join-Path $ProjectRoot "build\visual-qa\$($CaptureCase.Name)\$($CaptureCase.Size).png"
	for ($attempt = 0; $attempt -lt 20; $attempt++) {
		if ((Test-Path -LiteralPath $Capture) -and (Get-Item -LiteralPath $Capture).Length -gt 0) { break }
		Start-Sleep -Milliseconds 250
	}
	if (-not (Test-Path -LiteralPath $Capture) -or (Get-Item -LiteralPath $Capture).Length -eq 0) { throw "Godot did not create the expected capture: $Capture" }
	if ($null -ne $EngineExitCode -and [int]$EngineExitCode -ne 0) { Write-Warning "Godot returned $EngineExitCode after writing the screenshot; the capture file exists for inspection." }
	Write-Output "Captured $Capture"
}
