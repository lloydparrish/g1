$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Godot = Join-Path $ProjectRoot '.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe'
$Profile = Join-Path $ProjectRoot '.godot-profile\visual-qa\content-foundation'
$env:APPDATA = Join-Path $Profile 'Roaming'
$env:LOCALAPPDATA = Join-Path $Profile 'Local'

if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot is missing: $Godot" }

$Cases = @(
	@{ Name = 'character-select'; Size = '1920x1080'; Page = 'title'; Scenario = 'title_locked' },
	@{ Name = 'character-select-small'; Size = '1280x720'; Page = 'title'; Scenario = 'title_locked' },
	@{ Name = 'character-select-large'; Size = '2560x1440'; Page = 'title'; Scenario = 'title_locked' },
	@{ Name = 'character-select-mobile'; Size = '2400x1080'; Page = 'title'; Scenario = 'title_locked'; Mobile = $true },
	@{ Name = 'character-select-mobile-2340'; Size = '2340x1080'; Page = 'title'; Scenario = 'title_locked'; Mobile = $true },
	@{ Name = 'character-select-all-unlocked'; Size = '1920x1080'; Page = 'title'; Scenario = 'title_all_unlocked' },
	@{ Name = 'character-select-all-unlocked-small'; Size = '1280x720'; Page = 'title'; Scenario = 'title_all_unlocked' },
	@{ Name = 'character-select-all-unlocked-mobile'; Size = '2400x1080'; Page = 'title'; Scenario = 'title_all_unlocked'; Mobile = $true },
	@{ Name = 'character-select-all-unlocked-mobile-2340'; Size = '2340x1080'; Page = 'title'; Scenario = 'title_all_unlocked'; Mobile = $true },
	@{ Name = 'content-mods'; Size = '1920x1080'; Page = 'title'; Scenario = 'title_mods'; Overlay = 'content_mods' },
	@{ Name = 'content-mods-large'; Size = '2560x1440'; Page = 'title'; Scenario = 'title_mods'; Overlay = 'content_mods' },
	@{ Name = 'content-mods-mobile'; Size = '2400x1080'; Page = 'title'; Scenario = 'title_mods'; Overlay = 'content_mods'; Mobile = $true },
	@{ Name = 'character-reveal'; Size = '1920x1080'; Page = 'title'; Scenario = 'title_reveal' },
	@{ Name = 'portrait-reveal-bloodletter'; Size = '1920x1080'; Page = 'title'; Scenario = 'title_reveal_bloodletter' },
	@{ Name = 'portrait-reveal-warrior'; Size = '1920x1080'; Page = 'title'; Scenario = 'title_reveal_warrior' },
	@{ Name = 'portrait-reveal-necromancer'; Size = '1920x1080'; Page = 'title'; Scenario = 'title_reveal_necromancer' },
	@{ Name = 'portrait-reveal-ranger'; Size = '1920x1080'; Page = 'title'; Scenario = 'title_reveal_ranger' },
	@{ Name = 'character-reveal-mobile'; Size = '2400x1080'; Page = 'title'; Scenario = 'title_reveal_spellblade'; Mobile = $true },
	@{ Name = 'character-reveal-mobile-2340'; Size = '2340x1080'; Page = 'title'; Scenario = 'title_reveal_spellblade'; Mobile = $true },
	@{ Name = 'stage-rewards'; Size = '1920x1080'; Page = 'battle'; Scenario = 'visual'; Overlay = 'rewards' },
	@{ Name = 'stage-rewards-small'; Size = '1280x720'; Page = 'battle'; Scenario = 'visual'; Overlay = 'rewards' },
	@{ Name = 'stage-rewards-large'; Size = '2560x1440'; Page = 'battle'; Scenario = 'visual'; Overlay = 'rewards' },
	@{ Name = 'stage-rewards-mobile'; Size = '2400x1080'; Page = 'battle'; Scenario = 'visual'; Overlay = 'rewards'; Mobile = $true },
	@{ Name = 'exploration-chest'; Size = '1920x1080'; Page = 'battle'; Scenario = 'exploration_chest' },
	@{ Name = 'exploration-book'; Size = '1920x1080'; Page = 'battle'; Scenario = 'exploration_book' },
	@{ Name = 'exploration-star'; Size = '1920x1080'; Page = 'battle'; Scenario = 'exploration_star' },
	@{ Name = 'exploration-loot-mobile'; Size = '2400x1080'; Page = 'battle'; Scenario = 'exploration_chest'; Mobile = $true },
	@{ Name = 'inventory-equipment'; Size = '1920x1080'; Page = 'battle'; Scenario = 'selected_equipment'; Overlay = 'inventory' },
	@{ Name = 'ability-window-mobile'; Size = '2400x1080'; Page = 'battle'; Scenario = 'abilities_cleave'; Overlay = 'character'; Mobile = $true }
)

foreach ($CaptureCase in $Cases) {
	$CaptureDirectory = "res://build/visual-qa/content-foundation/$($CaptureCase.Name)"
	$Capture = Join-Path $ProjectRoot "build\visual-qa\content-foundation\$($CaptureCase.Name)\$($CaptureCase.Size).png"
	if (Test-Path -LiteralPath $Capture) { Remove-Item -LiteralPath $Capture -Force }
	$Arguments = @(
		"--capture=$($CaptureCase.Size)",
		"--capture-dir=$CaptureDirectory",
		"--capture-page=$($CaptureCase.Page)",
		"--capture-scenario=$($CaptureCase.Scenario)",
		'--capture-fresh-profile'
	)
	if ($CaptureCase.ContainsKey('Overlay')) { $Arguments += "--capture-overlay=$($CaptureCase.Overlay)" }
	if ($CaptureCase.ContainsKey('Mobile') -and $CaptureCase.Mobile) { $Arguments += '--capture-mobile' }
	& $Godot --path $ProjectRoot -- @Arguments
	$EngineExitCode = $LASTEXITCODE
	for ($attempt = 0; $attempt -lt 20; $attempt++) {
		if ((Test-Path -LiteralPath $Capture) -and (Get-Item -LiteralPath $Capture).Length -gt 0) { break }
		Start-Sleep -Milliseconds 250
	}
	if (-not (Test-Path -LiteralPath $Capture) -or (Get-Item -LiteralPath $Capture).Length -eq 0) { throw "Godot did not create the expected capture: $Capture (exit $EngineExitCode)" }
	if ($null -ne $EngineExitCode -and [int]$EngineExitCode -ne 0) { Write-Warning "Godot returned $EngineExitCode after writing the screenshot; inspect the capture for QA." }
	Write-Output "Captured $Capture"
}
