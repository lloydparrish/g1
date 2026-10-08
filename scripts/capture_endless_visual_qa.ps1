$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Godot = Join-Path $ProjectRoot '.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$Profile = Join-Path $ProjectRoot '.godot-profile\visual-qa-endless'
$env:APPDATA = Join-Path $Profile 'Roaming'
$env:LOCALAPPDATA = Join-Path $Profile 'Local'

if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot is missing: $Godot" }

$CaptureCases = @(
	@{ Name = 'map1-unknown'; Size = '1920x1080'; Scenario = 'map_locked'; Overlay = 'map' },
	@{ Name = 'map1-unknown-large'; Size = '2560x1440'; Scenario = 'map_locked'; Overlay = 'map' },
	@{ Name = 'map1-unknown-mid'; Size = '1600x900'; Scenario = 'map_locked'; Overlay = 'map' },
	@{ Name = 'map1-unknown-minimum'; Size = '1280x720'; Scenario = 'map_locked'; Overlay = 'map' },
	@{ Name = 'map1-unknown-mobile'; Size = '2400x1080'; Scenario = 'map_locked'; Overlay = 'map'; Mobile = $true },
	@{ Name = 'map1-unknown-mobile-2340'; Size = '2340x1080'; Scenario = 'map_locked'; Overlay = 'map'; Mobile = $true },
	@{ Name = 'map1-stage6-boss'; Size = '1920x1080'; Scenario = 'boss_stage' },
	@{ Name = 'next-map-reveal'; Size = '1920x1080'; Scenario = 'map_reveal' },
	@{ Name = 'next-map-reveal-mobile'; Size = '2400x1080'; Scenario = 'map_reveal'; Mobile = $true },
	@{ Name = 'map2-visited-trail'; Size = '1920x1080'; Scenario = 'map2_world'; Overlay = 'map' },
	@{ Name = 'map2-visited-trail-mobile'; Size = '2400x1080'; Scenario = 'map2_world'; Overlay = 'map'; Mobile = $true },
	@{ Name = 'long-map-trail-latest'; Size = '2560x1440'; Scenario = 'long_map_trail'; Overlay = 'map' },
	@{ Name = 'long-map-trail-mobile'; Size = '2340x1080'; Scenario = 'long_map_trail'; Overlay = 'map'; Mobile = $true },
	@{ Name = 'long-map-trail-earlier'; Size = '1920x1080'; Scenario = 'long_map_trail_early'; Overlay = 'map' },
	@{ Name = 'resume-run-title'; Size = '1920x1080'; Scenario = 'resume_run'; Page = 'title' },
	@{ Name = 'resume-run-title-mobile'; Size = '2400x1080'; Scenario = 'resume_run'; Page = 'title'; Mobile = $true },
	@{ Name = 'new-run-confirmation'; Size = '1920x1080'; Scenario = 'new_run_confirmation'; Page = 'title' },
	@{ Name = 'run-summary'; Size = '1920x1080'; Scenario = 'run_summary' },
	@{ Name = 'run-summary-mobile'; Size = '2400x1080'; Scenario = 'run_summary'; Mobile = $true },
	@{ Name = 'run-summary-long-build'; Size = '1920x1080'; Scenario = 'run_summary_long' },
	@{ Name = 'run-summary-long-build-mobile'; Size = '2340x1080'; Scenario = 'run_summary_long'; Mobile = $true },
	@{ Name = 'deep-counter-format'; Size = '1920x1080'; Scenario = 'long_map_depth'; Overlay = 'map' }
)

foreach ($Case in $CaptureCases) {
	$CaseDirectory = "res://build/visual-qa/endless/$($Case.Name)"
	$Arguments = @("--capture=$($Case.Size)", "--capture-dir=$CaseDirectory", "--capture-scenario=$($Case.Scenario)")
	if ($Case.ContainsKey('Overlay')) { $Arguments += "--capture-overlay=$($Case.Overlay)" }
	if ($Case.ContainsKey('Page')) { $Arguments += "--capture-page=$($Case.Page)" }
	if ($Case.ContainsKey('Mobile') -and $Case.Mobile) { $Arguments += '--capture-mobile' }
	& $Godot --path $ProjectRoot -- @Arguments
	if ($LASTEXITCODE -ne 0) { throw "Visual capture failed: $($Case.Name) at $($Case.Size)." }
	$Capture = Join-Path $ProjectRoot "build\visual-qa\endless\$($Case.Name)\$($Case.Size).png"
	if (-not (Test-Path -LiteralPath $Capture)) { throw "Godot did not create the expected capture: $Capture" }
	Write-Output "Captured $Capture"
}
