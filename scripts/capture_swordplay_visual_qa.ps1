$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Godot = Join-Path $ProjectRoot '.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe'
$Profile = Join-Path $ProjectRoot '.godot-profile\visual-qa\swordplay'

if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot is missing: $Godot" }

$CaptureCases = @(
	@{ Name = 'content-mods'; Size = '1920x1080'; Page = 'title'; Scenario = 'swordplay_package_menu'; Overlay = 'content_mods'; Fresh = $true },
	@{ Name = 'content-mods-mobile'; Size = '2400x1080'; Page = 'title'; Scenario = 'swordplay_package_menu'; Overlay = 'content_mods'; Mobile = $true; Fresh = $true },
	@{ Name = 'characters-locked'; Size = '1920x1080'; Page = 'title'; Scenario = 'swordplay_characters_locked'; Fresh = $true },
	@{ Name = 'characters-unlocked'; Size = '1920x1080'; Page = 'title'; Scenario = 'swordplay_characters_unlocked'; Fresh = $true },
	@{ Name = 'berserker-locked'; Size = '2400x1080'; Page = 'title'; Scenario = 'swordplay_berserker_locked'; Mobile = $true; Fresh = $true },
	@{ Name = 'berserker-unlocked'; Size = '1920x1080'; Page = 'title'; Scenario = 'swordplay_berserker_unlocked'; Fresh = $true },
	@{ Name = 'portrait-duelist'; Size = '1920x1080'; Page = 'title'; Scenario = 'title_reveal_duelist'; Fresh = $true },
	@{ Name = 'portrait-fencer'; Size = '1920x1080'; Page = 'title'; Scenario = 'title_reveal_fencer'; Fresh = $true },
	@{ Name = 'portrait-berserker'; Size = '2400x1080'; Page = 'title'; Scenario = 'title_reveal_berserker'; Mobile = $true; Fresh = $true },
	@{ Name = 'technique-lunge'; Size = '1920x1080'; Page = 'battle'; Scenario = 'swordplay_ability_lunge' },
	@{ Name = 'technique-cleave'; Size = '1920x1080'; Page = 'battle'; Scenario = 'swordplay_ability_cleave' },
	@{ Name = 'technique-parry-mobile'; Size = '2400x1080'; Page = 'battle'; Scenario = 'swordplay_ability_swordplay_parry'; Mobile = $true },
	@{ Name = 'technique-whirlwind'; Size = '1920x1080'; Page = 'battle'; Scenario = 'swordplay_ability_swordplay_whirlwind' },
	@{ Name = 'technique-blade-dance'; Size = '1920x1080'; Page = 'battle'; Scenario = 'swordplay_ability_swordplay_blade_dance' },
	@{ Name = 'technique-skewer'; Size = '1920x1080'; Page = 'battle'; Scenario = 'swordplay_ability_swordplay_skewer' },
	@{ Name = 'technique-forced-movement'; Size = '1920x1080'; Page = 'battle'; Scenario = 'swordplay_ability_swordplay_battering_blow' },
	@{ Name = 'technique-combination'; Size = '2400x1080'; Page = 'battle'; Scenario = 'swordplay_ability_swordplay_great_cleaver'; Mobile = $true },
	@{ Name = 'parry-state'; Size = '1920x1080'; Page = 'battle'; Scenario = 'swordplay_parry' },
	@{ Name = 'enemy-family'; Size = '1920x1080'; Page = 'battle'; Scenario = 'swordplay_combat' },
	@{ Name = 'unique-weapon'; Size = '1920x1080'; Page = 'battle'; Scenario = 'swordplay_weapon' },
	@{ Name = 'relic-detail'; Size = '1920x1080'; Page = 'battle'; Scenario = 'swordplay_relic' },
	@{ Name = 'artifact-detail'; Size = '2400x1080'; Page = 'battle'; Scenario = 'swordplay_artifact'; Mobile = $true },
	@{ Name = 'sword-lord-encounter'; Size = '1920x1080'; Page = 'battle'; Scenario = 'swordplay_boss_encounter' },
	@{ Name = 'sword-lord-reward'; Size = '1920x1080'; Page = 'battle'; Scenario = 'swordplay_boss_reward'; Overlay = 'rewards' },
	@{ Name = 'later-endless-map'; Size = '2400x1080'; Page = 'battle'; Scenario = 'swordplay_late_map'; Overlay = 'map'; Mobile = $true }
)

foreach ($Case in $CaptureCases) {
	$CaseProfile = Join-Path $Profile $Case.Name
	$env:APPDATA = Join-Path $CaseProfile 'Roaming'
	$env:LOCALAPPDATA = Join-Path $CaseProfile 'Local'
	$CaseDirectory = "res://build/visual-qa/swordplay/$($Case.Name)"
	$Capture = Join-Path $ProjectRoot "build\visual-qa\swordplay\$($Case.Name)\$($Case.Size).png"
	$Arguments = @("--capture=$($Case.Size)", "--capture-dir=$CaseDirectory", "--capture-page=$($Case.Page)", "--capture-scenario=$($Case.Scenario)")
	if ($Case.ContainsKey('Overlay')) { $Arguments += "--capture-overlay=$($Case.Overlay)" }
	if ($Case.ContainsKey('Mobile') -and $Case.Mobile) { $Arguments += '--capture-mobile' }
	if ($Case.ContainsKey('Fresh') -and $Case.Fresh) { $Arguments += '--capture-fresh-profile' }
	& $Godot --path $ProjectRoot -- @Arguments
	$EngineExitCode = $LASTEXITCODE
	for ($attempt = 0; $attempt -lt 20; $attempt++) {
		if ((Test-Path -LiteralPath $Capture) -and (Get-Item -LiteralPath $Capture).Length -gt 0) { break }
		Start-Sleep -Milliseconds 250
	}
	if (-not (Test-Path -LiteralPath $Capture) -or (Get-Item -LiteralPath $Capture).Length -eq 0) { throw "Godot did not create the expected capture: $Capture (exit $EngineExitCode)" }
	if ($null -ne $EngineExitCode -and [int]$EngineExitCode -ne 0) { Write-Warning "Godot returned $EngineExitCode after writing $Capture; inspect the image." }
	Write-Output "Captured $Capture"
}
