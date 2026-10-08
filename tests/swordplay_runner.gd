extends SceneTree

const SimScript = preload("res://scripts/game_sim.gd")
const MainScene = preload("res://scenes/main.tscn")

var checks := 0
var failures: Array[String] = []

const BASE_TECHNIQUES := [
	"lunge", "cleave", "swordplay_pommel_strike", "swordplay_whirlwind", "swordplay_execute",
	"swordplay_impale", "swordplay_advance", "swordplay_reposition", "swordplay_driving_blow",
	"swordplay_blade_rush", "swordplay_parry", "swordplay_thrust", "swordplay_feint",
	"swordplay_disengage", "swordplay_overhead_strike", "swordplay_sweeping_blow", "swordplay_reckless_swing"
]
const UPGRADES := [
	"swordplay_blade_dance", "swordplay_executioners_stroke", "swordplay_skewer", "swordplay_perfect_parry",
	"swordplay_unstoppable_charge", "swordplay_battering_blow", "swordplay_berserkers_arc"
]
const COMBINATIONS := [
	"swordplay_transfixing_charge", "swordplay_sundering_sweep", "swordplay_relentless_advance",
	"swordplay_masterstroke", "swordplay_dancing_steel", "swordplay_armor_splitter",
	"swordplay_parting_thrust", "swordplay_great_cleaver"
]

func _initialize() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	var disabled = SimScript.new()
	disabled.delete_saved_run()
	disabled.profile["enabled_package_ids"] = []
	disabled.profile["unlocked_character_ids"] = disabled.get_starting_character_ids().duplicate()
	disabled.profile["pending_character_reveals"] = []
	disabled.save_profile()
	var disabled_load: Dictionary = disabled.content_registry.load_from_disk([])
	disabled.content = disabled_load.content
	_check(disabled.content.get("abilities", {}).has("lunge") and not disabled.content.abilities.has("swordplay_pommel_strike") and not disabled.content.enemies.has("goblin_swordsman"), "Core remains playable while disabled Swordplay contributes no new techniques or enemies")
	_check(disabled.start_run(880101, "jim") and disabled.act({"type": "wait"}).ok, "Core-only run starts and advances without Swordplay")

	var sim = SimScript.new()
	sim.delete_saved_run()
	sim.profile["enabled_package_ids"] = []
	sim.profile["unlocked_character_ids"] = sim.get_starting_character_ids().duplicate()
	sim.profile["pending_character_reveals"] = []
	var enabled_result: Dictionary = sim.set_package_enabled("swordplay", true)
	if not enabled_result.ok: print("SWORDPLAY ENABLE FAILURE: " + String(enabled_result.get("error", "")))
	_check(enabled_result.ok and sim.content_registry.load_order.has("swordplay") and sim.package_load_errors.is_empty(), "official Swordplay enables through the generic package registry with no definition errors")
	_check(sim.content.abilities.size() >= 29 and sim.content.characters.has("duelist") and sim.content.characters.has("fencer") and sim.content.characters.has("berserker"), "package loads the full technique roster and three stable character identities")
	_check(sim.content.weapons.has("rapier") and sim.content.weapons.has("greatsword") and sim.content.items.has("goblinbane") and sim.content.items.has("swordplay_sword_of_the_goblin_horde"), "generic and distinctive named martial weapons load as item definitions")
	_check(sim.content.get("relics", {}).size() >= 9 and sim.content.get("artifacts", {}).size() >= 4 and sim.content.enemies.size() >= 10, "relic, artifact, and fantasy-race enemy families load from the package")
	_check(BASE_TECHNIQUES.size() == 17 and BASE_TECHNIQUES.all(func(id: String) -> bool: return sim.content.abilities.has(id)), "all 17 approved base techniques have stable content definitions")
	_check(UPGRADES.size() == 7 and UPGRADES.all(func(id: String) -> bool: return sim.content.abilities.has(id)), "the seven selective technique transformations are present without filler upgrades")
	_check(COMBINATIONS.size() == 8 and COMBINATIONS.all(func(id: String) -> bool: return sim.content.abilities.has(id) and bool(sim.content.abilities[id].get("combination", false))), "all eight rare combinations use the generic prerequisite definition")
	_check(["goblin_swordsman", "goblin_fencer", "goblin_blade_dancer", "kobold_duelist", "kobold_skirmisher", "orc_cleaver", "orc_breaker", "orc_berserker", "goblin_bladeguard"].all(func(id: String) -> bool: return sim.content.enemies.has(id)), "the Goblin, Kobold, and Orc tactical roster is present")
	_check(FileAccess.file_exists("res://data/packages/official/swordplay/assets/portraits/duelist.png") and FileAccess.file_exists("res://data/packages/official/swordplay/assets/portraits/fencer.png") and FileAccess.file_exists("res://data/packages/official/swordplay/assets/portraits/berserker.png"), "all three package portraits are installed at stable package asset paths")

	var unlocks: Array = sim.profile.get("unlocked_character_ids", [])
	_check(not unlocks.has("duelist") and not unlocks.has("fencer") and not unlocks.has("berserker"), "new characters remain locked on a fresh profile")
	_check(sim.content.characters.duelist.weapon == "sword" and sim.content.characters.fencer.weapon == "rapier" and sim.content.characters.berserker.weapon == "greatsword", "Duelist, Fencer, and Berserker start with their authored weapon families")
	_check(sim.content.characters.duelist.get("known", []).size() <= 1 and sim.content.characters.fencer.get("known", []).size() <= 1 and sim.content.characters.berserker.get("known", []).size() <= 1, "Swordplay characters start with a small progression kit")

	var threshold_sim = SimScript.new()
	threshold_sim.content = sim.content
	threshold_sim.profile = sim.profile.duplicate(true)
	threshold_sim.profile["unlocked_character_ids"] = threshold_sim.get_starting_character_ids().duplicate()
	threshold_sim.start_run(880102, "jim")
	threshold_sim.run["successful_parries"] = 4
	_check(not threshold_sim.check_authored_character_unlocks().has("duelist"), "four successful Parry resolutions do not meet the Duelist threshold")
	threshold_sim.run["successful_parries"] = 5
	_check(threshold_sim.check_authored_character_unlocks().has("duelist") and threshold_sim.is_character_unlocked("duelist"), "five successful Parry resolutions permanently unlock the Duelist")
	_check(threshold_sim.get_unlocked_character_ids().has("duelist"), "Duelist unlock persists through the profile identity list")

	var boss_candidates: Array = sim._get_eligible_boss_candidates("swordplay_blade_warrens", "1")
	var sword_lord: Dictionary = sim.content.bosses.get("sword_lord_of_the_goblin_horde", {})
	_check(not sword_lord.is_empty() and int(sword_lord.get("stage_only", 0)) == 6 and bool(sword_lord.get("rare", false)), "Sword Lord is authored as a rare Stage 6 boss")
	_check(boss_candidates.any(func(candidate: Dictionary) -> bool: return candidate.get("id", "") == "sword_lord_of_the_goblin_horde"), "Sword Lord enters the eligible boss pool only through Swordplay definitions")
	_check(float(sim.get_boss_selection_weight(sword_lord, "20")) > float(sim.get_boss_selection_weight(sword_lord, "1")), "Sword Lord's rare-boss weighting increases at deeper map depth")
	var stage_one_map: Dictionary = sim._generate_map("2", "", "swordplay_blade_warrens")
	_check(not stage_one_map.is_empty() and stage_one_map.get("boss_id", "") != "" and stage_one_map.get("stage_templates", []).size() == 5, "the rare boss is stored on the map's future boss slot rather than inserted into its five planned ordinary stages")
	sim.start_run(880109, "jim")
	var encounter_plan: Dictionary = {}
	var procedural_enemy_found := false
	for seed_value in range(120):
		sim._rng.seed = seed_value * 7919 + 23
		encounter_plan = sim._make_encounter_plan("goblin_warrens", "12", 1)
		if encounter_plan.get("enemy_ids", []).any(func(enemy_id: String) -> bool: return String(enemy_id).begins_with("goblin_") and String(enemy_id) != "goblin" and sim.content.enemies.get(String(enemy_id), {}).get("tags", []).has("martial")):
			procedural_enemy_found = true
			break
	_check(procedural_enemy_found, "eligible Swordplay martial foes can enter another Goblinoid procedural encounter through faction definitions")
	_check(sim.get_reward_candidates(true).any(func(candidate: Dictionary) -> bool: return String(candidate.get("id", "")) == "goblinbane"), "enabled Swordplay equipment joins the ordinary global reward pool")

	var boss_flow = SimScript.new()
	boss_flow.content = sim.content
	boss_flow.profile = sim.profile.duplicate(true)
	boss_flow.profile["unlocked_character_ids"] = boss_flow.get_starting_character_ids().duplicate()
	boss_flow.start_run(880110, "jim")
	var boss_map: Dictionary = boss_flow._generate_map("2", "", "swordplay_blade_warrens")
	boss_map["boss_id"] = "sword_lord_of_the_goblin_horde"
	boss_flow.run["current_map"] = boss_map
	boss_flow.run["map_depth"] = "2"
	for ordinary_stage in range(5):
		boss_flow.run["stage_index"] = ordinary_stage
		boss_flow._new_stage(String(boss_map.stage_templates[ordinary_stage]), false, true)
		_check(not boss_flow.run.entities.values().any(func(entity: Dictionary) -> bool: return entity.get("kind", "") == "boss"), "Sword Lord cannot spawn during ordinary Stage %d" % (ordinary_stage + 1))
	boss_flow.run["stage_index"] = 4
	boss_flow.run["stage_completed"] = true
	_check(boss_flow.advance_stage() and int(boss_flow.run.stage_index) == 5, "the production stage transition enters the map's Stage 6 boss encounter")
	var lord_id := ""
	for entity_id in boss_flow.run.entities:
		if boss_flow.run.entities[entity_id].get("kind", "") == "boss": lord_id = String(entity_id)
	_check(lord_id != "" and boss_flow.run.entities[lord_id].get("boss_definition_id", "") == "sword_lord_of_the_goblin_horde", "Stage 6 spawns the content-defined Sword Lord rather than substituting a Core boss")
	_check(boss_flow.save_run(), "a generated Stage 6 boss plan is saved before combat")
	var reloaded_boss = SimScript.new()
	_check(reloaded_boss.resume_run() and String(reloaded_boss.run.current_map.boss_id) == "sword_lord_of_the_goblin_horde", "save/resume preserves the established rare boss identity without rerolling")
	var boss_actor_id := ""
	for entity_id in reloaded_boss.run.entities:
		if reloaded_boss.run.entities[entity_id].get("kind", "") == "boss": boss_actor_id = String(entity_id)
	reloaded_boss.run.entities[boss_actor_id].pos = [13, 8]
	reloaded_boss.run.entities["player"].pos = [12, 8]
	reloaded_boss.run.entities[boss_actor_id].statuses = {}
	reloaded_boss.run.entities[boss_actor_id].technique_turn_count = 0
	reloaded_boss.run.entities[boss_actor_id].technique_cooldowns = {}
	reloaded_boss.run["last_player_action"] = {"type": "attack", "target_id": boss_actor_id}
	var player_hp_before_boss_ai := int(reloaded_boss.get_player().hp)
	var boss_parry_used := reloaded_boss._enemy_tactical_ability(boss_actor_id, "player")
	_check(boss_parry_used and reloaded_boss._has_status(boss_actor_id, "PerfectParrying") and int(reloaded_boss.get_player().hp) == player_hp_before_boss_ai, "Sword Lord uses his actual Perfect Parry kit without an automatic counterattack")
	reloaded_boss.run.entities[boss_actor_id].statuses.erase("PerfectParrying")
	reloaded_boss.run.entities[boss_actor_id].hp = 1
	reloaded_boss.run.entities[boss_actor_id].next_time = 999999
	reloaded_boss._set_grid(Vector2i(12, 8), "floor")
	reloaded_boss._set_grid(Vector2i(13, 8), "floor")
	var boss_victory: Dictionary = reloaded_boss.act({"type": "attack", "target": [13, 8]})
	_check(boss_victory.ok and bool(reloaded_boss.run.stage_completed) and reloaded_boss.is_character_unlocked("berserker"), "defeating Sword Lord through a production attack permanently unlocks the Berserker")
	_check(reloaded_boss.run.reward_choices.size() == 3 and reloaded_boss.run.reward_choices[0].get("id", "") == "swordplay_sword_of_the_goblin_horde", "first Sword Lord victory guarantees the signature weapon reward opportunity")
	var first_pending_count := int(reloaded_boss.profile.pending_character_reveals.count("berserker"))
	reloaded_boss.run["stage_index"] = 4
	reloaded_boss.run["stage_completed"] = true
	_check(reloaded_boss.advance_stage(), "a later Stage 6 can load the same rare boss definition")
	var repeat_boss_id := ""
	for entity_id in reloaded_boss.run.entities:
		if reloaded_boss.run.entities[entity_id].get("kind", "") == "boss": repeat_boss_id = String(entity_id)
	reloaded_boss.run.entities[repeat_boss_id].pos = [13, 8]
	reloaded_boss.run.entities[repeat_boss_id].hp = 1
	reloaded_boss.run.entities[repeat_boss_id].next_time = 999999
	reloaded_boss._set_grid(Vector2i(13, 8), "floor")
	var repeat_victory: Dictionary = reloaded_boss.act({"type": "attack", "target": [13, 8]})
	_check(repeat_victory.ok and reloaded_boss.run.reward_choices[0].get("id", "") == "swordplay_sword_of_the_goblin_horde" and int(reloaded_boss.profile.pending_character_reveals.count("berserker")) == first_pending_count, "later Sword Lord victories retain the special reward without duplicating the Berserker unlock")

	var probe = SimScript.new()
	probe.content = sim.content
	probe.profile = sim.profile.duplicate(true)
	probe.profile["unlocked_character_ids"] = probe.get_starting_character_ids().duplicate()
	probe.start_run(880103, "jim")
	for ability_id in BASE_TECHNIQUES + UPGRADES + COMBINATIONS:
		var definition: Dictionary = probe.content.abilities[ability_id]
		var ability_known: Array = [String(ability_id)]
		var parents: Array = definition.get("prerequisites", {}).get("all_of", definition.get("requires", []))
		for parent_id in parents:
			if not ability_known.has(String(parent_id)): ability_known.append(String(parent_id))
		probe.run["known"] = ability_known
		probe.run["ability_cooldowns"] = {}
		probe.run["stage_technique_used"] = false
		probe.run["stage_completed"] = false
		var target_cells := [Vector2i(13, 8), Vector2i(14, 8), Vector2i(13, 9)]
		_prepare_fixture(probe, target_cells)
		if ability_id == "lunge": probe.run.entities[_enemy_at(probe, Vector2i(14, 8))].pos = [15, 8]
		if ability_id in ["swordplay_blade_rush", "swordplay_unstoppable_charge", "swordplay_transfixing_charge"]:
			probe.run.entities[_enemy_at(probe, Vector2i(13, 8))].hp = 1
			probe.run.entities[_enemy_at(probe, Vector2i(14, 8))].hp = 1
		var target_id := "player" if String(definition.get("target", "enemy")) == "self" else _enemy_at(probe, Vector2i(13, 8))
		var target_pos := Vector2i(-1, -1) if target_id == "player" else probe._pos(probe.run.entities[target_id])
		var cast_result: Dictionary = probe.act({"type": "cast", "id": String(ability_id), "target": [target_pos.x, target_pos.y]})
		_check(bool(cast_result.get("ok", false)), "%s resolves through the production cast path (%s)" % [String(definition.get("name", ability_id)), String(cast_result.get("message", ""))])

	var movement = SimScript.new()
	movement.content = sim.content
	movement.profile = sim.profile.duplicate(true)
	movement.profile["unlocked_character_ids"] = movement.get_starting_character_ids().duplicate()
	movement.start_run(880104, "jim")
	movement.run["known"].append("lunge")
	movement.run["technique_movement_actions"] = 7
	_prepare_fixture(movement, [Vector2i(13, 8), Vector2i(14, 8)])
	var adjacent_id := _enemy_at(movement, Vector2i(13, 8))
	var blocked_lunge: Dictionary = movement.act({"type": "cast", "id": "lunge", "target": [13, 8]})
	_check(blocked_lunge.ok and int(movement.run.technique_movement_actions) == 7, "activating Lunge without moving does not advance the Fencer unlock counter")
	_prepare_fixture(movement, [Vector2i(14, 8), Vector2i(17, 8)])
	var moved_lunge: Dictionary = movement.act({"type": "cast", "id": "lunge", "target": [14, 8]})
	_check(moved_lunge.ok and int(movement.run.technique_movement_actions) == 8 and (movement.is_character_unlocked("fencer") or moved_lunge.get("unlocked_characters", []).has("fencer")), "eight actual technique-driven movements unlock the Fencer")
	_check(movement.is_character_unlocked("fencer") and movement.content.characters.fencer.weapon == "rapier", "Fencer unlock retains the stable identity and Rapier start")

	var parry = SimScript.new()
	parry.content = sim.content
	parry.profile = sim.profile.duplicate(true)
	parry.profile["unlocked_character_ids"] = parry.get_starting_character_ids().duplicate()
	parry.start_run(880105, "jim")
	parry.run["known"].append("swordplay_parry")
	_prepare_fixture(parry, [Vector2i(13, 8), Vector2i(14, 8)])
	var attacker_id := _enemy_at(parry, Vector2i(13, 8))
	var parry_cast: Dictionary = parry.act({"type": "cast", "id": "swordplay_parry", "target": [-1, -1]})
	_check(parry_cast.ok and int(parry.run.successful_parries) == 0, "Parry activation without an incoming strike does not count toward unlock progress")
	parry._damage("player", 16, "Slashing", "Goblin", attacker_id)
	_check(int(parry.run.successful_parries) == 1 and int(parry.get_player().max_hp) - int(parry.get_player().hp) <= 4, "a real melee strike is sharply reduced and counted as one successful base Parry")
	parry.run.relics = ["swordplay_mirror_guard"]
	var reflect_status: int = int(parry.content.relics.swordplay_mirror_guard.get("modifiers", {}).get("stamina_on_parry", 0))
	_check(reflect_status > 0 and parry._run_modifier("stamina_on_parry", 0.0) == float(reflect_status), "Parry-focused relic behavior reaches the generic combat modifier path")

	var pair = SimScript.new()
	pair.content = sim.content
	pair.profile = sim.profile.duplicate(true)
	var pair_unlocks: Array = pair.get_starting_character_ids().duplicate()
	pair_unlocks.append("berserker")
	pair.profile["unlocked_character_ids"] = pair_unlocks
	pair.start_run(880106, "berserker")
	_prepare_fixture(pair, [Vector2i(13, 8), Vector2i(12, 7), Vector2i(13, 9)])
	var pair_first := _enemy_at(pair, Vector2i(13, 8))
	var pair_second := _enemy_at(pair, Vector2i(12, 7))
	pair.run.entities[pair_first].hp = 500
	pair.run.entities[pair_second].hp = 500
	var before_action_count := int(pair.run.player_action_count)
	var before_time := int(pair.get_player().next_time)
	var pair_result: Dictionary = pair.act({"type": "berserker_pair", "actions": [
		{"type": "attack", "id": "attack", "target_id": pair_first, "target": [13, 8]},
		{"type": "attack", "id": "attack", "target_id": pair_second, "target": [12, 7]}
	]})
	_check(pair_result.ok and bool(pair_result.get("second_action_resolved", false)), "the Berserker resolves two selected basic attacks")
	_check(int(pair.run.player_action_count) == before_action_count + 1 and int(pair.get_player().next_time) - before_time <= int(pair.content.weapons.greatsword.time), "both attacks consume one player action and one timeline window")
	_check(bool(pair.run.berserker_power_used), "Berserker paired-action use persists in the active run state")
	var second_use: Dictionary = pair.act({"type": "berserker_pair", "actions": []})
	_check(not second_use.ok and bool(pair.run.berserker_power_used), "the special action cannot be reused during the same map")
	pair.save_run()
	var resumed_pair = SimScript.new()
	_check(resumed_pair.resume_run() and bool(resumed_pair.run.get("berserker_power_used", false)), "save and resume preserve the once-per-map Berserker power state")

	var invalidated = SimScript.new()
	invalidated.content = sim.content
	invalidated.profile = pair.profile.duplicate(true)
	invalidated.start_run(880107, "berserker")
	_prepare_fixture(invalidated, [Vector2i(13, 8), Vector2i(12, 7), Vector2i(13, 9)])
	var whirl_target := _enemy_at(invalidated, Vector2i(13, 8))
	var second_target := _enemy_at(invalidated, Vector2i(12, 7))
	invalidated.run.entities[whirl_target].hp = 25
	invalidated.run.entities[second_target].hp = 5
	invalidated.run["known"] = ["swordplay_whirlwind"]
	var invalidated_result: Dictionary = invalidated.act({"type": "berserker_pair", "actions": [
		{"type": "cast", "id": "swordplay_whirlwind", "target_id": whirl_target, "target": [13, 8]},
		{"type": "attack", "id": "attack", "target_id": second_target, "target": [12, 7]}
	]})
	_check(invalidated_result.ok and not bool(invalidated_result.get("second_action_resolved", true)) and not invalidated.run.entities[second_target].alive, "a first area attack that kills the second chosen foe skips the second action without retargeting")
	_check(bool(invalidated.run.berserker_power_used) and int(invalidated.run.player_action_count) == 1, "an invalidated second target still consumes one special use and one turn")

	var combination = SimScript.new()
	combination.content = sim.content
	combination.profile = sim.profile.duplicate(true)
	combination.profile["unlocked_character_ids"] = combination.get_starting_character_ids().duplicate()
	combination.start_run(880108, "jim")
	var combo_id := "swordplay_transfixing_charge"
	var combo_parents: Array = combination.content.abilities[combo_id].get("prerequisites", {}).get("all_of", [])
	combination.run["known"] = ["lunge"]
	_check(not combination.get_ability_progress(combo_id).get("visible", false), "a rare combination stays hidden until both parent techniques are owned")
	combination.run["known"].append("swordplay_impale")
	combination.run["level"] = 3
	combination.run["skill_points"] = 1
	var combo_progress: Dictionary = combination.get_ability_progress(combo_id)
	_check(combo_progress.get("visible", false) and combo_progress.get("learnable", false), "owning both combination parents makes the rare technique eligible")
	_check(combination.learn_ability(combo_id) and combo_parents.all(func(id: Variant) -> bool: return combination.run.known.has(String(id))), "learning a combination does not consume either parent technique")
	var disabled_while_used := SimScript.new()
	disabled_while_used.content = sim.content
	disabled_while_used.profile = sim.profile.duplicate(true)
	disabled_while_used.start_run(880111, "jim")
	disabled_while_used.run["package_ids"] = ["swordplay"]
	_check(not disabled_while_used.set_package_enabled("swordplay", false).ok, "an active run that stores Swordplay content prevents disabling its package mid-run")

	var ui := MainScene.instantiate()
	ui.playback_mode = "Instant"
	root.add_child(ui)
	await process_frame
	ui.sim = pair
	ui.page = "battle"
	pair.run["berserker_power_used"] = false
	pair.run["known"] = ["swordplay_whirlwind"]
	ui._handle_action({"type": "begin_berserker_pair"})
	_check(ui.overlay == "berserker_pair" and ui._berserker_pair_options().size() >= 1, "the production action bar opens the Berserker action-selection panel")
	var whirlwind_index := -1
	for option_index in range(ui._berserker_pair_options().size()):
		var option: Dictionary = ui._berserker_pair_options()[option_index]
		if option.get("type", "") == "cast" and option.get("id", "") == "swordplay_whirlwind": whirlwind_index = option_index
	ui._handle_action({"type": "pair_select_action", "index": whirlwind_index})
	ui._handle_action({"type": "pair_select_action", "index": 0})
	_check(whirlwind_index >= 0 and ui.berserker_pair_actions.size() == 2, "the UI allows an area technique and a basic attack to be selected before targeting")
	ui._handle_action({"type": "pair_choose_targets"})
	var pair_action_count_before_ui := int(pair.run.player_action_count)
	ui._battlefield_tap(Vector2i(13, 8))
	ui._battlefield_tap(Vector2i(12, 7))
	_check(ui.target_mode == "" and bool(pair.run.berserker_power_used) and int(pair.run.player_action_count) == pair_action_count_before_ui + 1, "the UI resolves both selected actions into one Berserker turn")
	ui.queue_free()

	var stage_reset = SimScript.new()
	stage_reset.content = sim.content
	stage_reset.profile = pair.profile.duplicate(true)
	stage_reset.start_run(880109, "berserker")
	stage_reset.run["berserker_power_used"] = true
	var current_map: Dictionary = stage_reset.run.current_map.duplicate(true)
	current_map["map_number"] = "2"
	current_map["current"] = false
	stage_reset.run["next_map"] = current_map
	stage_reset.run["map_history"] = [stage_reset.run.current_map.duplicate(true), current_map.duplicate(true)]
	stage_reset.run["map_reveal_index"] = 1
	stage_reset.run["map_reveal_pending"] = true
	_check(stage_reset.enter_next_map() and not bool(stage_reset.run.berserker_power_used) and String(stage_reset.run.map_depth) == "2", "the Berserker power refreshes only on map entry")

	var endless_swordplay = SimScript.new()
	endless_swordplay.delete_saved_run()
	endless_swordplay.profile["enabled_package_ids"] = []
	endless_swordplay.profile["unlocked_character_ids"] = endless_swordplay.get_starting_character_ids().duplicate()
	endless_swordplay.profile["pending_character_reveals"] = []
	endless_swordplay.save_profile()
	var endless_package_result: Dictionary = endless_swordplay.set_package_enabled("swordplay", true)
	var endless_started: bool = bool(endless_package_result.get("ok", false)) and endless_swordplay.start_run(880112, "jim")
	_check(endless_started and endless_swordplay.run.package_ids.has("swordplay"), "a Swordplay-enabled endless run starts with the package recorded in its save")
	var endless_progression_ok: bool = endless_started
	if endless_started:
		endless_swordplay.run["successful_parries"] = 4
		endless_swordplay.run["technique_movement_actions"] = 7
		for map_index in range(3):
			var planned_map: Dictionary = endless_swordplay.run.current_map
			var stage_plans: Array = planned_map.get("stage_plans", [])
			var valid_plan: bool = stage_plans.size() == 5 and endless_swordplay.content.bosses.has(String(planned_map.get("boss_id", "")))
			for plan: Dictionary in stage_plans:
				valid_plan = valid_plan and endless_swordplay.content.stages.has(String(plan.get("stage_template_id", ""))) and plan.get("enemy_ids", []).all(func(enemy_id: Variant) -> bool: return endless_swordplay.content.enemies.has(String(enemy_id)))
			_check(valid_plan and String(planned_map.get("map_number", "")) == str(map_index + 1), "Swordplay Map %d has five valid encounter plans and a content-defined boss" % (map_index + 1))
			if not valid_plan:
				endless_progression_ok = false
				break
			for stage_index in range(6):
				endless_swordplay._complete_stage()
				if stage_index < 5:
					var advanced: bool = endless_swordplay.advance_stage()
					_check(advanced and int(endless_swordplay.run.stage_index) == stage_index + 1, "Swordplay Map %d advances through Stage %d" % [map_index + 1, stage_index + 2])
					if not advanced:
						endless_progression_ok = false
						break
			if not endless_progression_ok:
				break
			_check(String(endless_swordplay.run.maps_completed) == str(map_index + 1) and not endless_swordplay.get_reward_candidates(true).is_empty(), "Swordplay Map %d completes with a populated reward pool" % (map_index + 1))
			if map_index < 2:
				var entered := endless_swordplay.reveal_next_map() and endless_swordplay.enter_next_map()
				_check(entered and String(endless_swordplay.run.map_depth) == str(map_index + 2) and endless_swordplay.run.package_ids.has("swordplay"), "Swordplay progression enters Map %d with the package still active" % (map_index + 2))
				_check(int(endless_swordplay.run.successful_parries) == 4 and int(endless_swordplay.run.technique_movement_actions) == 7, "character unlock progress carries across Swordplay map transitions")
				if not entered:
					endless_progression_ok = false
					break
				if map_index == 0:
					endless_swordplay.save_run()
					var resumed_endless = SimScript.new()
					var resumed_endless_ok: bool = resumed_endless.resume_run() and String(resumed_endless.run.map_depth) == "2" and resumed_endless.run.package_ids.has("swordplay") and resumed_endless.content.enemies.has("goblin_swordsman")
					_check(resumed_endless_ok, "save/resume preserves Swordplay content and progression on Map 2")
					if resumed_endless_ok: endless_swordplay = resumed_endless
					else: endless_progression_ok = false
		_check(endless_progression_ok and String(endless_swordplay.run.maps_completed) == "3" and endless_swordplay.run.map_history.size() == 3, "three-map Swordplay progression completes without exhausting procedural content")
	endless_swordplay.delete_saved_run()

	sim.delete_saved_run()
	disabled.delete_saved_run()
	_check(failures.is_empty(), "all Swordplay package integration checks pass")
	for failure in failures:
		printerr("FAIL: " + failure)
	print("SWORDPLAY PACKAGE  ·  %d checks  ·  %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func _prepare_fixture(sim, enemy_cells: Array) -> void:
	var player: Dictionary = sim.get_player()
	player["pos"] = [12, 8]
	player["next_time"] = 0
	player["alive"] = true
	player["hp"] = int(player.get("max_hp", 40))
	player["statuses"] = {}
	var stamina: Array = player.get("resources", {}).get("Stamina", [0, 0])
	stamina[0] = stamina[1]
	player["resources"]["Stamina"] = stamina
	sim.run["entities"] = {"player": player}
	sim.run["objects"] = []
	sim.run["corpses"] = []
	sim.run["outcome"] = ""
	sim.run["stage_completed"] = false
	sim.run["visible"] = sim._bool_grid(true)
	sim.run["explored"] = sim._bool_grid(true)
	for y in range(SimScript.HEIGHT):
		for x in range(SimScript.WIDTH):
			sim._set_grid(Vector2i(x, y), "floor" if x > 0 and y > 0 and x < SimScript.WIDTH - 1 and y < SimScript.HEIGHT - 1 else "wall")
	for cell in enemy_cells:
		var enemy_id: String = sim._spawn_enemy("goblin_swordsman", cell, false)
		if enemy_id != "":
			sim.run.entities[enemy_id]["hp"] = 500
			sim.run.entities[enemy_id]["max_hp"] = 500
			sim.run.entities[enemy_id]["next_time"] = 999999
			sim.run.entities[enemy_id]["armor"] = 0
	sim._update_vision()

func _enemy_at(sim, cell: Vector2i) -> String:
	return sim._occupant(cell)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
