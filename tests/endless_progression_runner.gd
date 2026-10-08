extends SceneTree

const SimScript = preload("res://scripts/game_sim.gd")
const RegistryScript = preload("res://scripts/content_registry.gd")
const MainScene = preload("res://scenes/main.tscn")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	var sim = SimScript.new()
	sim.delete_saved_run()
	sim.profile["unlocked_character_ids"] = sim.get_starting_character_ids().duplicate()
	sim.profile["pending_character_reveals"] = []
	sim.save_profile()
	_check(sim.start_run(6102026, "jim"), "a new run creates its first map and stage")
	_check(String(sim.run.map_depth) == "1" and int(sim.run.stage_index) == 0 and sim.run.current_map.theme_id == "ruined_village", "Map 1 begins as the approachable Ruined Village at Stage 1")
	_check(sim.run.current_map.stage_templates.size() == 5 and sim.run.current_map.stage_plans.size() == 5 and sim.run.current_map.stage_plans.all(func(plan: Dictionary) -> bool: return plan.stage_template_id in sim.run.current_map.stage_templates), "each map stores a coherent five-template plan for its non-boss stages")
	_check(sim.run.current_map.stage_plans[0].objective in ["Eliminate", "Reach Exit"] and sim.run.current_map.stage_plans[0].enemy_ids.all(func(enemy_id: String) -> bool: return int(sim.content.enemies[enemy_id].get("tier", 0)) == 0), "Map 1 uses a limited objective set and only simple tier-zero enemies")
	_check(not _has_boss(sim), "ordinary stages do not spawn the map boss")

	var same_seed = SimScript.new()
	same_seed.profile["unlocked_character_ids"] = same_seed.get_starting_character_ids().duplicate()
	same_seed.profile["pending_character_reveals"] = []
	same_seed.start_run(6102026, "jim")
	_check(JSON.stringify(same_seed.run.current_map) == JSON.stringify(sim.run.current_map), "the same run seed deterministically reproduces Map 1 generation")
	var unknown_ui = MainScene.instantiate()
	root.add_child(unknown_ui)
	await process_frame
	unknown_ui.sim = sim
	var journey: Dictionary = unknown_ui.lower_dock._persistent_journey()
	_check(journey.entries.size() == 2 and journey.entries[1].unknown and String(journey.entries[1].name) == "UNKNOWN", "the world map exposes only one unknown next destination before completion")
	_check(not JSON.stringify(journey).contains(String(sim.run.current_map.get("next_map", {}).get("name", ""))) or sim.run.get("next_map", {}).is_empty(), "the unrevealed destination theme is absent from journey data")
	unknown_ui.queue_free()

	var map1_scaling: Dictionary = sim.get_enemy_scaling("1")
	var map3_scaling: Dictionary = sim.get_enemy_scaling("3")
	_check(float(map3_scaling.health_multiplier) > float(map1_scaling.health_multiplier) and float(map3_scaling.damage_multiplier) > float(map1_scaling.damage_multiplier), "numerical enemy difficulty rises with map depth")
	_check(int(map3_scaling.tier_limit) > int(map1_scaling.tier_limit) and int(map3_scaling.extra_enemies) >= int(map1_scaling.extra_enemies), "depth enables higher-tier enemies and additional composition pressure")
	var rare_boss := {"weight": 1.0, "rare": true, "depth_weight_growth": 0.08}
	var common_boss := {"weight": 1.0, "rare": false, "common_depth_decay": 0.015}
	_check(sim.get_boss_selection_weight(rare_boss, "100") > sim.get_boss_selection_weight(rare_boss, "1") and sim.get_boss_selection_weight(common_boss, "100") < sim.get_boss_selection_weight(common_boss, "1"), "rare bosses gain relative weight with depth while common bosses gradually recede")
	var common_reward := {"rarity": "Common", "drop_weight": 1.0, "tags": []}
	var legendary_reward := {"rarity": "Legendary", "drop_weight": 1.0, "tags": []}
	sim.run.map_depth = "100"
	_check(sim.get_content_weight(legendary_reward) > sim.get_content_weight(common_reward) and sim.get_content_weight(common_reward) > 0.0, "depth improves rare reward weight without removing ordinary reward eligibility")
	var enormous_depth := "9".repeat(300)
	var deep_scaling: Dictionary = sim.get_enemy_scaling(enormous_depth)
	_check(is_finite(float(deep_scaling.health_multiplier)) and is_finite(float(deep_scaling.damage_multiplier)) and int(deep_scaling.tier_limit) > 0, "hundreds-digit map depths keep scaling finite and valid")
	_check(sim._scaled_combat_stat(10000000000000, float(deep_scaling.health_multiplier)) == int(SimScript.MAX_SAFE_COMBAT_STAT), "extreme enemy values saturate safely at the combat numeric representation boundary")
	_check(sim._increment_decimal("999999999999999999999999") == "1000000000000000000000000", "map numbering increments beyond machine integer limits")

	var registry = RegistryScript.new()
	var core_content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	var core_manifest := {"id": "core", "name": "Core", "version": "1.0.0", "kind": "core", "dependencies": [], "content_file": "content.json", "assets": []}
	var fixture_content := {
		"enemies": {"test_fixture_sentinel": {"name": "Fixture Sentinel", "faction": "Goblinoids", "behavior": "melee", "damage_type": "Blunt", "hp": 20, "damage": 3, "tier": 1}},
		"stages": {"test_fixture_stage": {"name": "Fixture Glade", "terrain": {"wall": 0.02, "water": 0.0}, "objectives": ["Eliminate"], "enemies": ["test_fixture_sentinel"], "enemy_count_curve": [1, 1, 1, 1, 1]}},
		"maps": {"test_fixture_region": {"name": "Fixture Region", "stage_templates": ["test_fixture_stage"], "tags": ["test"], "weight": 1.0, "minimum_depth": 2}},
		"bosses": {"test_fixture_boss": {"name": "Fixture Sovereign", "enemy_id": "test_fixture_sentinel", "themes": ["test_fixture_region"], "stage_only": 6, "minimum_depth": 2, "rare": true, "weight": 1.0}}
	}
	var package_spec := [{"manifest": {"id": "test_fixture_maps", "name": "Test Fixture Maps", "version": "0.1.0", "kind": "official", "dependencies": [], "content_file": "content.json", "assets": []}, "definitions": fixture_content, "directory": "res://tests/fixtures", "origin": "official"}]
	var disabled_result: Dictionary = registry.assemble(core_manifest, core_content, package_spec, [])
	var enabled_result: Dictionary = registry.assemble(core_manifest, core_content, package_spec, ["test_fixture_maps"])
	_check(not disabled_result.content.maps.has("test_fixture_region") and enabled_result.content.maps.has("test_fixture_region"), "disabled packages contribute no map definitions while enabled packages load their map theme")
	_check(enabled_result.content.stages.has("test_fixture_stage") and enabled_result.content.bosses.has("test_fixture_boss") and enabled_result.errors.is_empty(), "an enabled package injects stage, enemy, and boss definitions without generator edits")
	var package_sim = SimScript.new()
	package_sim.content = enabled_result.content
	package_sim.profile["unlocked_character_ids"] = package_sim.get_starting_character_ids().duplicate()
	package_sim.profile["pending_character_reveals"] = []
	package_sim.start_run(6102030, "jim")
	var injected_map: Dictionary = package_sim._generate_map("2", "ruined_village", "test_fixture_region")
	_check(injected_map.theme_id == "test_fixture_region" and injected_map.stage_templates.size() == 5 and injected_map.stage_templates.all(func(stage_id: String) -> bool: return stage_id == "test_fixture_stage"), "procedural generation can select package-defined coherent map templates")
	_check(injected_map.boss_id == "test_fixture_boss" and package_sim._get_eligible_boss_candidates("test_fixture_region", "2").any(func(candidate: Dictionary) -> bool: return candidate.id == "test_fixture_boss"), "package bosses enter the eligible Stage-6 pool through content definitions")
	package_sim.run.current_map = injected_map
	package_sim.run.map_depth = "2"
	package_sim.run.stage_index = 5
	package_sim._new_stage("test_fixture_stage", true, true)
	_check(_has_boss(package_sim) and String(package_sim.run.boss_id) == "test_fixture_boss", "Stage 6 spawns the package-defined eligible boss from its map plan")
	package_sim.content.bosses = {}
	_check(package_sim._select_map_boss("test_fixture_region", "2") == "", "the generator does not substitute a hard-coded boss when definitions provide no eligible boss")
	_check(package_sim._get_map_boss_definition({}).is_empty(), "Stage 6 does not fall back to a hard-coded boss when a generated map lacks its boss ID")
	_check(package_sim._generate_map("2", "", "test_fixture_region").is_empty(), "map generation refuses a region with no eligible content-defined boss")

	var persistence = SimScript.new()
	persistence.profile["unlocked_character_ids"] = persistence.get_starting_character_ids().duplicate()
	persistence.profile["pending_character_reveals"] = []
	persistence.start_run(6102040, "jim")
	for stage_index in range(5):
		persistence._complete_stage()
		persistence.advance_stage()
	persistence._complete_stage()
	persistence.advance_stage()
	_check(int(persistence.run.stage_index) == 5 and _has_boss(persistence) and String(persistence.run.objective.kind) == "Boss", "the sixth stage of every generated map is a boss stage")
	_check(not persistence.run.route_choices.has("grave_tyrant") and persistence.run.current_map.boss_id == "grave_tyrant", "Stage-6-only boss identity is stored in the map plan, not offered as an early-stage route")
	var legacy_victory: Dictionary = persistence.run.duplicate(true)
	legacy_victory["version"] = 1
	legacy_victory["outcome"] = "victory"
	legacy_victory["stage_id"] = "grave_tyrant"
	legacy_victory["route"] = ["ruined_village", "graveyard", "flooded_ruins", "goblin_warrens", "thornwood", "grave_tyrant"]
	for removed_key in ["current_map", "map_history", "map_depth", "maps_completed", "stages_completed", "bosses_defeated", "enemies_defeated", "next_map", "map_reveal_pending", "map_reveal_index"]:
		legacy_victory.erase(removed_key)
	var migrated_victory: Dictionary = persistence._migrate_run_data(legacy_victory)
	_check(int(migrated_victory.get("version", 0)) == SimScript.SAVE_VERSION and str(migrated_victory.get("outcome", "")) == "" and bool(migrated_victory.get("stage_completed", false)) and str(migrated_victory.get("maps_completed", "")) == "1" and bool(migrated_victory.get("map_complete_pending", false)), "a legacy finite-run victory save migrates into a continuing completed Map state")
	var player: Dictionary = persistence.get_player()
	player.hp = maxi(1, int(player.hp) - 7)
	player.resources.Mana[0] = maxi(0, int(player.resources.Mana[0]) - 3)
	player.resources.Stamina[0] = maxi(0, int(player.resources.Stamina[0]) - 4)
	persistence.run.inventory.append("iron_shield")
	persistence.run.equipment.Weapon = "greatsword"
	persistence.run.known.append("magic_missile")
	persistence.run.relics = ["test_fixture_relic"]
	var artifact_ids: Array = persistence.content.artifacts.keys()
	if not artifact_ids.is_empty(): persistence.run.artifacts = [String(artifact_ids[0])]
	persistence.run.build_tag_counts["arcane"] = 3
	persistence.run.ability_states["magic_missile"] = {"level": 2, "cooldown": 1}
	var carried_state := {"hp": int(player.hp), "mana": int(player.resources.Mana[0]), "stamina": int(player.resources.Stamina[0]), "inventory": persistence.run.inventory.duplicate(), "equipment": persistence.run.equipment.duplicate(true), "known": persistence.run.known.duplicate(), "relics": persistence.run.relics.duplicate(), "artifacts": persistence.run.artifacts.duplicate(), "tags": persistence.run.build_tag_counts.duplicate(true), "ability_states": persistence.run.ability_states.duplicate(true)}
	_check(persistence.save_run(), "an active Stage-6 run saves before application-equivalent reload")
	var resumed = SimScript.new()
	_check(resumed.resume_run() and JSON.stringify(resumed.run.current_map) == JSON.stringify(persistence.run.current_map) and int(resumed.run.stage_index) == 5, "reload restores the established map and boss stage without rerolling")
	_check(JSON.stringify(resumed.run.inventory) == JSON.stringify(persistence.run.inventory) and JSON.stringify(resumed.run.ability_states) == JSON.stringify(persistence.run.ability_states), "reload retains run inventory and ability state")
	var resumed_boss := _boss_id(resumed)
	var original_boss := _boss_id(persistence)
	resumed._on_death(resumed_boss, "The Mundane", "player")
	persistence._on_death(original_boss, "The Mundane", "player")
	_check(resumed.reveal_next_map() and persistence.reveal_next_map() and JSON.stringify(resumed.run.next_map) == JSON.stringify(persistence.run.next_map), "identical saved RNG state produces the same next-map reveal after reload")
	carried_state = {"hp": int(resumed.get_player().hp), "mana": int(resumed.get_player().resources.Mana[0]), "stamina": int(resumed.get_player().resources.Stamina[0]), "inventory": resumed.run.inventory.duplicate(), "equipment": resumed.run.equipment.duplicate(true), "known": resumed.run.known.duplicate(), "relics": resumed.run.relics.duplicate(), "artifacts": resumed.run.artifacts.duplicate(), "tags": resumed.run.build_tag_counts.duplicate(true), "ability_states": resumed.run.ability_states.duplicate(true)}
	var reveal_ui = MainScene.instantiate()
	root.add_child(reveal_ui)
	await process_frame
	reveal_ui.sim = resumed
	var revealed_journey: Dictionary = reveal_ui.lower_dock._persistent_journey()
	_check(not revealed_journey.has_unknown and revealed_journey.entries.size() == 2 and bool(resumed.run.map_history[1].revealed), "map completion replaces the unknown destination with exactly one revealed map")
	var old_history: Array = resumed.run.map_history.duplicate(true)
	var generated_next: Dictionary = resumed.run.next_map.duplicate(true)
	_check(resumed.enter_next_map(), "the player can intentionally enter the revealed map")
	var next_player: Dictionary = resumed.get_player()
	_check(String(resumed.run.map_depth) == "2" and int(resumed.run.stage_index) == 0 and String(resumed.run.stage_id) == String(generated_next.stage_templates[0]), "map entry increments map number and resets only the within-map stage")
	_check(int(next_player.hp) == carried_state.hp and int(next_player.resources.Mana[0]) == carried_state.mana and int(next_player.resources.Stamina[0]) == carried_state.stamina, "health, Mana, and Stamina carry through without a map-transition refill")
	_check(JSON.stringify(resumed.run.inventory) == JSON.stringify(carried_state.inventory) and JSON.stringify(resumed.run.equipment) == JSON.stringify(carried_state.equipment), "inventory and equipped items carry forward across maps")
	_check(JSON.stringify(resumed.run.known) == JSON.stringify(carried_state.known) and JSON.stringify(resumed.run.relics) == JSON.stringify(carried_state.relics) and JSON.stringify(resumed.run.artifacts) == JSON.stringify(carried_state.artifacts), "abilities, relics, and artifacts carry forward across maps")
	_check(JSON.stringify(resumed.run.build_tag_counts) == JSON.stringify(carried_state.tags) and JSON.stringify(resumed.run.ability_states) == JSON.stringify(carried_state.ability_states), "dynamic build weighting and ability state carry forward across maps")
	_check(old_history.size() == 2 and old_history[0].completed and resumed.run.map_history[1].current and resumed.run.map_history.size() == 2, "completed maps remain in the world journey while the revealed map becomes current")
	reveal_ui.queue_free()

	var death = SimScript.new()
	death.profile["unlocked_character_ids"] = death.get_starting_character_ids().duplicate()
	death.profile["pending_character_reveals"] = []
	death.start_run(6102050, "jim")
	death.profile["unlocked_character_ids"].append("aldren")
	death.run["enemies_defeated"] = "17"
	death.run["bosses_defeated"] = "2"
	death.run["maps_completed"] = "4"
	death.run["stages_completed"] = "23"
	death._damage("player", 999999, "Fire", "Fixture Enemy")
	var death_summary: Dictionary = death.get_summary()
	_check(String(death.run.outcome) == "defeat" and String(death_summary.outcome) == "defeat" and death_summary.enemies_defeated == "17" and death_summary.bosses_defeated == "2", "lethal combat damage ends the run with accurate summary statistics")
	_check(death.save_run() and not death.has_saved_run() and death.is_character_unlocked("aldren") and death.profile.last_run_summary.outcome == "defeat", "death clears active-run resumability while permanent unlocks and the run summary persist")

	var long_run = SimScript.new()
	long_run.profile["unlocked_character_ids"] = long_run.get_starting_character_ids().duplicate()
	long_run.profile["pending_character_reveals"] = []
	long_run.start_run(6102060, "jim")
	var stress_maps := 60
	for map_index in range(stress_maps):
		for stage_index in range(6):
			_check(int(long_run.run.stage_index) == stage_index, "stress journey enters Stage %d for map %d" % [stage_index + 1, map_index + 1])
			if stage_index == 5:
				var boss_id := _boss_id(long_run)
				_check(boss_id != "" and String(long_run.run.objective.kind) == "Boss", "stress Map %d Stage 6 has an eligible boss" % (map_index + 1))
				long_run._on_death(boss_id, "The Mundane", "player")
			else:
				_check(not _has_boss(long_run), "stress Map %d Stage %d has no premature boss" % [map_index + 1, stage_index + 1])
				long_run._complete_stage()
			if stage_index < 5:
				_check(long_run.advance_stage(), "stress journey advances within Map %d" % (map_index + 1))
		_check(long_run.run.stage_completed and String(long_run.run.maps_completed) == str(map_index + 1), "stress Map %d resolves without ending the run" % (map_index + 1))
		_check(long_run.reveal_next_map() and long_run.enter_next_map(), "stress journey reveals and enters Map %d" % (map_index + 2))
	_check(long_run.run.outcome == "" and String(long_run.run.map_depth) == str(stress_maps + 1) and long_run.run.map_history.size() == stress_maps + 1, "60-map progression has no final map and retains its full visited trail")
	_check(String(long_run.run.current_map.map_number) == "61" and int(long_run.run.stage_index) == 0, "the deep-run world state remains addressable after dozens of maps")

	var title = MainScene.instantiate()
	root.add_child(title)
	await process_frame
	_check(title.page == "title" and title.sim.has_saved_run(), "an active saved expedition remains available from the title screen")
	_check(title._format_count_for_ui("0") == "0" and title._format_count_for_ui("9".repeat(120)).begins_with("~9.999e"), "UI map/stat counters preserve zero and compact arbitrarily long decimal values")
	var resume_hit := false
	for hit in title.active_hits:
		if String(hit.action.get("type", "")) == "resume": resume_hit = true
	_check(resume_hit, "the title screen exposes an explicit Resume Run action")
	title.sim.delete_saved_run()
	title.queue_free()

	print("ENDLESS PROGRESSION %d · STRESS MAPS %d · FAILURES %d" % [checks, stress_maps, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(1 if not failures.is_empty() else 0)

func _boss_id(sim) -> String:
	for entity_id in sim.run.entities:
		if sim.run.entities[entity_id].get("kind", "") == "boss" and sim.run.entities[entity_id].get("alive", true):
			return String(entity_id)
	return ""

func _has_boss(sim) -> bool:
	return _boss_id(sim) != ""

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
