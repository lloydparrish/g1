$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Godot = Join-Path $ProjectRoot '.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe'
$Profile = Join-Path $ProjectRoot '.godot-profile\visual-qa\summon-stage'

if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot is missing: $Godot" }

$Cases = @(
	@{ Name = 'phantom-follow-desktop'; Size = '1920x1080'; Scenario = 'summon_follow' },
	@{ Name = 'phantom-follow-mobile'; Size = '2400x1080'; Scenario = 'summon_follow'; Mobile = $true },
	@{ Name = 'stage-entry-desktop'; Size = '1920x1080'; Scenario = 'summon_stage_entry' },
	@{ Name = 'stage-entry-mobile'; Size = '2400x1080'; Scenario = 'summon_stage_entry'; Mobile = $true }
)

foreach ($Case in $Cases) {
	$CaseProfile = Join-Path $Profile $Case.Name
	$env:APPDATA = Join-Path $CaseProfile 'Roaming'
	$env:LOCALAPPDATA = Join-Path $CaseProfile 'Local'
	$CaptureDirectory = "res://build/visual-qa/summon-stage/$($Case.Name)"
	$Capture = Join-Path $ProjectRoot "build\visual-qa\summon-stage\$($Case.Name)\$($Case.Size).png"
	$Arguments = @("--capture=$($Case.Size)", "--capture-dir=$CaptureDirectory", "--capture-scenario=$($Case.Scenario)", '--capture-fresh-profile')
	if ($Case.ContainsKey('Mobile') -and $Case.Mobile) { $Arguments += '--capture-mobile' }
	& $Godot --path $ProjectRoot -- @Arguments
	$EngineExitCode = $LASTEXITCODE
	for ($attempt = 0; $attempt -lt 20; $attempt++) {
		if ((Test-Path -LiteralPath $Capture) -and (Get-Item -LiteralPath $Capture).Length -gt 0) { break }
		Start-Sleep -Milliseconds 250
	}
	if (-not (Test-Path -LiteralPath $Capture) -or (Get-Item -LiteralPath $Capture).Length -eq 0) { throw "Godot did not create the expected capture: $Capture" }
	if ($null -ne $EngineExitCode -and [int]$EngineExitCode -ne 0) { throw "Godot returned $EngineExitCode after writing $Capture" }
	Write-Output "Captured $Capture"
}
