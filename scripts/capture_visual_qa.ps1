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
	@{ Size = '2340x1080'; Overlay = 'action_palette' },
	@{ Size = '2400x1080'; Overlay = 'pause' },
	@{ Size = '1920x1080'; Overlay = 'combat_history'; Scenario = 'combat_history' }
)) {
	$CaseDirectory = "res://build/visual-qa/$($CaptureCase.Overlay)"
	$ExtraArguments = @("--capture=$($CaptureCase.Size)", "--capture-dir=$CaseDirectory", "--capture-overlay=$($CaptureCase.Overlay)")
	if ($CaptureCase.ContainsKey('Scenario')) { $ExtraArguments += "--capture-scenario=$($CaptureCase.Scenario)" }
	& $Godot --path $ProjectRoot -- @ExtraArguments
	if ($LASTEXITCODE -ne 0) { throw "Overlay capture failed: $($CaptureCase.Overlay) at $($CaptureCase.Size)." }
	$Capture = Join-Path $ProjectRoot "build\visual-qa\$($CaptureCase.Overlay)\$($CaptureCase.Size).png"
	if (-not (Test-Path -LiteralPath $Capture)) { throw "Godot did not create the expected overlay capture: $Capture" }
	Write-Output "Captured $Capture"
}

$ScrolledWebDirectory = 'res://build/visual-qa/web-scrolled'
& $Godot --path $ProjectRoot -- '--capture=2400x1080' "--capture-dir=$ScrolledWebDirectory" '--capture-overlay=abilities' '--capture-full-web' '--capture-web-pan=120,0'
if ($LASTEXITCODE -ne 0) { throw 'Scrolled ability-web capture failed.' }
$ScrolledWebCapture = Join-Path $ProjectRoot 'build\visual-qa\web-scrolled\2400x1080.png'
if (-not (Test-Path -LiteralPath $ScrolledWebCapture)) { throw "Godot did not create the expected capture: $ScrolledWebCapture" }
Write-Output "Captured $ScrolledWebCapture"

foreach ($CaptureCase in @(
	@{ Name = 'enemy-action'; Size = '1920x1080'; Scenario = 'enemy_action' },
	@{ Name = 'damage-feedback'; Size = '1920x1080'; Scenario = 'damage_action' },
	@{ Name = 'summon-feedback'; Size = '1920x1080'; Scenario = 'summon' },
	@{ Name = 'level-up'; Size = '1920x1080'; Scenario = 'level_up' },
	@{ Name = 'fast-playback'; Size = '1920x1080'; Scenario = 'fast_action' },
	@{ Name = 'instant-playback'; Size = '1920x1080'; Scenario = 'instant_action' },
	@{ Name = 'recent-events'; Size = '1920x1080'; Scenario = 'populated_history' },
	@{ Name = 'quickbar-customized'; Size = '2340x1080'; Scenario = 'quickbar_customized' },
	@{ Name = 'quickbar-unavailable'; Size = '2340x1080'; Scenario = 'quickbar_empty' },
	@{ Name = 'inventory-full'; Size = '1920x1080'; Scenario = 'full_inventory'; Overlay = 'inventory' },
	@{ Name = 'inventory-equipment'; Size = '1920x1080'; Scenario = 'selected_equipment'; Overlay = 'inventory' },
	@{ Name = 'inventory-consumable'; Size = '1920x1080'; Scenario = 'selected_consumable'; Overlay = 'inventory' },
	@{ Name = 'inventory-assign'; Size = '1920x1080'; Scenario = 'assign_item'; Overlay = 'inventory' },
	@{ Name = 'p6-selected-enemy'; Size = '1920x1080'; Scenario = 'selected_enemy' },
	@{ Name = 'p6-world-map'; Size = '1920x1080'; Scenario = 'visual'; Overlay = 'map' },
	@{ Name = 'p6-character-abilities'; Size = '1920x1080'; Scenario = 'visual'; Overlay = 'abilities' },
	@{ Name = 'p6-inventory-equipment'; Size = '1920x1080'; Scenario = 'visual'; Overlay = 'inventory' },
	@{ Name = 'p6-spellbook-discovery'; Size = '1920x1080'; Scenario = 'visual'; Overlay = 'spellbook'; Book = 'lesser_key_of_ash' },
	@{ Name = 'p6-ability-assignment'; Size = '1920x1080'; Scenario = 'assign_ability'; Overlay = 'abilities' },
	@{ Name = 'p6-item-assignment'; Size = '1920x1080'; Scenario = 'assign_item'; Overlay = 'inventory' }
)) {
	$CaseDirectory = "res://build/visual-qa/$($CaptureCase.Name)"
	$ExtraArguments = @("--capture=$($CaptureCase.Size)", "--capture-dir=$CaseDirectory", "--capture-scenario=$($CaptureCase.Scenario)")
	if ($CaptureCase.ContainsKey('Overlay')) { $ExtraArguments += "--capture-overlay=$($CaptureCase.Overlay)" }
	if ($CaptureCase.ContainsKey('Book')) { $ExtraArguments += "--capture-book=$($CaptureCase.Book)" }
	& $Godot --path $ProjectRoot -- @ExtraArguments
	if ($LASTEXITCODE -ne 0) { throw "Combat/inventory capture failed: $($CaptureCase.Name)." }
	$Capture = Join-Path $ProjectRoot "build\visual-qa\$($CaptureCase.Name)\$($CaptureCase.Size).png"
	if (-not (Test-Path -LiteralPath $Capture)) { throw "Godot did not create the expected state capture: $Capture" }
	Write-Output "Captured $Capture"
}

$BookInventoryDirectory = 'res://build/visual-qa/spellbook-inventory'
& $Godot --path $ProjectRoot -- '--capture=2340x1080' "--capture-dir=$BookInventoryDirectory" '--capture-overlay=inventory' '--capture-book=lesser_key_of_ash'
if ($LASTEXITCODE -ne 0) { throw 'Spellbook inventory capture failed.' }
$BookInventoryCapture = Join-Path $ProjectRoot 'build\visual-qa\spellbook-inventory\2340x1080.png'
if (-not (Test-Path -LiteralPath $BookInventoryCapture)) { throw "Godot did not create the expected capture: $BookInventoryCapture" }
Write-Output "Captured $BookInventoryCapture"

$BookCodexDirectory = 'res://build/visual-qa/spellbook-codex'
& $Godot --path $ProjectRoot -- '--capture=1920x1080' "--capture-dir=$BookCodexDirectory" '--capture-overlay=codex_book' '--capture-book=lesser_key_of_ash'
if ($LASTEXITCODE -ne 0) { throw 'Spellbook Codex capture failed.' }
$BookCodexCapture = Join-Path $ProjectRoot 'build\visual-qa\spellbook-codex\1920x1080.png'
if (-not (Test-Path -LiteralPath $BookCodexCapture)) { throw "Godot did not create the expected capture: $BookCodexCapture" }
Write-Output "Captured $BookCodexCapture"

$TargetingDirectory = 'res://build/visual-qa/targeting'
& $Godot --path $ProjectRoot -- '--capture=2400x1080' "--capture-dir=$TargetingDirectory" '--capture-target=blood_lance'
if ($LASTEXITCODE -ne 0) { throw 'Targeting capture failed.' }
$TargetingCapture = Join-Path $ProjectRoot 'build\visual-qa\targeting\2400x1080.png'
if (-not (Test-Path -LiteralPath $TargetingCapture)) { throw "Godot did not create the expected capture: $TargetingCapture" }
Write-Output "Captured $TargetingCapture"
