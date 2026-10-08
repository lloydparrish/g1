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
	var starters: Array[String] = ["jim", "archer", "apprentice", "defender"]
	sim.profile["unlocked_character_ids"] = starters.duplicate()
	sim.profile["pending_character_reveals"] = []
	sim.save_profile()
	_check(sim.validate_content().is_empty(), "the merged Core content validates before play")
	_check(sim.get_starting_character_ids() == starters and sim.get_unlocked_character_ids() == starters, "a fresh profile starts with exactly four classes")
	_check(sim.content.characters.has("aldren") and sim.content.characters.has("mara") and sim.content.characters.has("brakka") and sim.content.characters.has("orin") and sim.content.characters.has("sylvi"), "advanced characters remain in content while hidden from a fresh profile")
	var advanced_titles := {"aldren": "The Spellblade", "mara": "The Bloodletter", "brakka": "The Warrior", "orin": "The Necromancer", "sylvi": "The Ranger"}
	for stable_id in advanced_titles:
		_check(String(sim.content.characters[stable_id].get("name", "")) == String(advanced_titles[stable_id]) and String(sim.content.characters[stable_id].get("class_title", "")) == String(advanced_titles[stable_id]), "%s keeps its stable ID and resolves to its approved class title" % stable_id)
	_check(sim.content.characters.aldren.portrait_path == "res://assets/portraits/spellblade.png" and sim.content.characters.mara.portrait_path == "res://assets/portraits/bloodletter.png" and sim.content.characters.brakka.portrait_path == "res://assets/portraits/warrior.png" and sim.content.characters.orin.portrait_path == "res://assets/portraits/necromancer.png" and sim.content.characters.sylvi.portrait_path == "res://assets/portraits/ranger.png", "all five advanced stable IDs reference their matching static portrait assets")
	_check(FileAccess.file_exists("res://assets/portraits/mundane.png") and FileAccess.file_exists("res://assets/portraits/archer.png") and FileAccess.file_exists("res://assets/portraits/apprentice.png") and FileAccess.file_exists("res://assets/portraits/defender.png"), "all four starter portraits exist as static game assets")
	_check(not sim.start_run(1, "aldren"), "a locked advanced character cannot start a normal run")

	var mundane = SimScript.new()
	mundane.profile["unlocked_character_ids"] = starters.duplicate()
	_check(mundane.start_run(20, "jim") and mundane.run.character_id == "jim" and mundane.run.known.is_empty(), "The Mundane keeps its stable legacy ID and begins with an empty ability build")
	_check(mundane.run.equipment.Weapon == "sword" and int(mundane.get_player().armor) == 0 and mundane.run.character_affinities.is_empty(), "The Mundane begins with the basic sword and receives no character weighting")
	_check(mundane.run.build_tag_counts.is_empty() and is_equal_approx(mundane.get_content_weight({"tags": ["sword", "physical"]}), 1.0), "The Mundane's sword does not create hidden sword or physical weighting")

	var archer = SimScript.new()
	archer.profile["unlocked_character_ids"] = starters.duplicate()
	archer.start_run(21, "archer")
	_check(archer.run.equipment.Weapon == "bow" and archer.run.known.is_empty(), "The Archer starts with a bow and no advanced ability suite")
	_check(archer.get_content_weight({"tags": ["bow", "ranged", "projectile"]}) > mundane.get_content_weight({"tags": ["bow", "ranged", "projectile"]}), "Archer tags increase related content weight without excluding other tags")
	_check(archer.get_content_weight({"tags": ["blood"]}) > 0.0 and archer.get_reward_candidates(false).any(func(entry: Dictionary) -> bool: return String(entry.id) == "fireball_scroll"), "off-build content remains eligible for hybrid builds")
	var weight_archer = SimScript.new()
	weight_archer.profile["unlocked_character_ids"] = starters.duplicate()
	weight_archer.start_run(31, "archer")
	var bow_pick_count := 0
	var mundane_bow_pick_count := 0
	var mundane_choices: Array = [{"id": "bow", "weight": mundane.get_content_weight(mundane.content.items.bow)}, {"id": "fireball_scroll", "weight": mundane.get_content_weight(mundane.content.items.fireball_scroll)}]
	var archer_choices: Array = [{"id": "bow", "weight": weight_archer.get_content_weight(weight_archer.content.items.bow)}, {"id": "fireball_scroll", "weight": weight_archer.get_content_weight(weight_archer.content.items.fireball_scroll)}]
	for sample in range(3000):
		mundane._rng.seed = sample * 7919 + 17
		weight_archer._rng.seed = sample * 7919 + 17
		if mundane._pick_weighted_candidate(mundane_choices).id == "bow": mundane_bow_pick_count += 1
		if weight_archer._pick_weighted_candidate(archer_choices).id == "bow": bow_pick_count += 1
	_check(bow_pick_count > mundane_bow_pick_count and bow_pick_count < 3000, "archetype weighting changes reward probability without turning off-build options into hard locks")

	var apprentice = SimScript.new()
	apprentice.profile["unlocked_character_ids"] = starters.duplicate()
	apprentice.start_run(22, "apprentice")
	_check(apprentice.run.known == ["magic_missile"] and apprentice.content.abilities.magic_missile.school == "Arcane", "The Apprentice starts with only Magic Missile as direct, school-less Arcane magic")
	_check(apprentice.get_content_weight({"tags": ["magic", "arcane"]}) > mundane.get_content_weight({"tags": ["magic", "arcane"]}), "Apprentice affinities favor Magic and Arcane tags")

	var defender = SimScript.new()
	defender.profile["unlocked_character_ids"] = starters.duplicate()
	defender.start_run(23, "defender")
	_check(defender.run.equipment.Offhand == "iron_shield" and defender.run.known == ["shield_bash"], "The Defender starts with a shield and Shield Bash")
	_check(defender.get_content_weight({"tags": ["shield", "armor", "defense", "health"]}) > mundane.get_content_weight({"tags": ["shield", "armor", "defense", "health"]}), "Defender affinities favor shield, armor, defense, and survivability tags")
	_check(mundane.run.character_affinities.is_empty(), "starter weapons do not grant The Mundane a hidden affinity")

	var build_weight_before := archer.get_content_weight({"tags": ["fire"]})
	archer.run.build_tag_counts["fire"] = 4
	var build_weight_after := archer.get_content_weight({"tags": ["fire"]})
	_check(build_weight_after > build_weight_before and build_weight_after < 2.0, "selected Fire content conservatively increases future Fire weight")
	_check(archer.get_content_weight({"tags": ["blood"]}) > 0.0, "dynamic build weighting never removes off-build choices")
	archer.run.stage_completed = true
	archer._make_rewards()
	_check(archer.run.reward_choices.size() == 3 and archer.run.reward_choices.all(func(choice: Dictionary) -> bool: return choice.has("id")), "stage completion builds three valid, randomized reward choices")
	_check(archer.get_reward_candidates(false).any(func(entry: Dictionary) -> bool: return not (entry.id in ["bow", "crossbow"])), "the global eligibility pool still includes off-archetype rewards")

	var unlock_fixture := {"name": "Hidden Test", "class_title": "Test Class", "class_description": "A temporary reveal fixture."}
	sim.content.characters["unlock_fixture"] = unlock_fixture
	var tag_gate: Dictionary = sim.try_unlock_character("unlock_fixture", {"conditions": [{"type": "tags", "ids": ["bow", "blood"]}]})
	_check(not tag_gate.ok, "unmet multi-tag requirements block character unlocks")
	sim.run = {"character_id": "archer", "known": [], "inventory": [], "equipment": {}, "artifacts": [], "schools": [], "disciplines": [], "discoveries": [], "build_tag_counts": {"bow": 1, "blood": 1}, "level": 1, "entities": {"player": {"resources": {}}}}
	var passing_tag_gate: Dictionary = sim.try_unlock_character("unlock_fixture", {"conditions": [{"type": "tags", "ids": ["bow", "blood"]}]})
	_check(passing_tag_gate.ok and sim.is_character_unlocked("unlock_fixture"), "satisfied generic prerequisites unlock a permanent character identity")

	var locked_ui = MainScene.instantiate()
	root.add_child(locked_ui)
	await process_frame
	locked_ui.sim.profile["unlocked_character_ids"] = starters.duplicate()
	for stable_id in advanced_titles:
		var locked_card: Dictionary = locked_ui._character_card_presentation(String(stable_id))
		_check(not locked_card.get("unlocked", true) and not locked_card.has("class_title") and not locked_card.has("portrait_path") and String(locked_card.get("requirement", "")) == String(locked_ui.sim.content.characters[stable_id].unlock_requirement), "%s locked presentation hides title and portrait while retaining its authored requirement" % stable_id)
	locked_ui.queue_free()

	var spellblade_sword_only = SimScript.new()
	spellblade_sword_only.profile["unlocked_character_ids"] = starters.duplicate()
	spellblade_sword_only.start_run(24, "jim")
	spellblade_sword_only.run.stage_completed = true
	_check(not spellblade_sword_only.evaluate_prerequisites(spellblade_sword_only.content.characters.aldren.unlock).eligible, "Sword alone does not satisfy The Spellblade's unlock")
	var spellblade_arcane_only = SimScript.new()
	spellblade_arcane_only.profile["unlocked_character_ids"] = starters.duplicate()
	spellblade_arcane_only.start_run(25, "apprentice")
	spellblade_arcane_only.run.stage_completed = true
	_check(not spellblade_arcane_only.evaluate_prerequisites(spellblade_arcane_only.content.characters.aldren.unlock).eligible, "Arcane alone does not satisfy The Spellblade's unlock")
	var spellblade = SimScript.new()
	spellblade.profile["unlocked_character_ids"] = starters.duplicate()
	spellblade.start_run(26, "jim")
	spellblade.run.known.append_array(["lunge", "magic_missile"])
	spellblade._complete_stage()
	_check(spellblade.is_character_unlocked("aldren") and spellblade.profile.pending_character_reveals.has("aldren"), "completing a stage with owned Sword and Arcane content unlocks and queues The Spellblade")
	var reloaded_profile = SimScript.new()
	_check(reloaded_profile.is_character_unlocked("aldren") and reloaded_profile.get_pending_character_reveal() == "aldren", "the preserved aldren ID, profile unlock and reveal queue persist across simulation instances")
	_check(reloaded_profile.content.characters.aldren.class_title == "The Spellblade" and reloaded_profile.content.characters.aldren.portrait_path == "res://assets/portraits/spellblade.png", "the persisted advanced unlock resolves the correct name and portrait")
	reloaded_profile.consume_character_reveal("aldren")
	_check(reloaded_profile.get_pending_character_reveal() == "", "the reveal is dismissed after the player acknowledges it")
	var revealed_ui = MainScene.instantiate()
	root.add_child(revealed_ui)
	await process_frame
	var advanced_portraits := {"aldren": "res://assets/portraits/spellblade.png", "mara": "res://assets/portraits/bloodletter.png", "brakka": "res://assets/portraits/warrior.png", "orin": "res://assets/portraits/necromancer.png", "sylvi": "res://assets/portraits/ranger.png"}
	for stable_id in advanced_titles:
		revealed_ui.sim.profile["unlocked_character_ids"] = starters + [String(stable_id)]
		var revealed_card: Dictionary = revealed_ui._character_card_presentation(String(stable_id))
		_check(revealed_card.get("unlocked", false) and String(revealed_card.get("class_title", "")) == String(advanced_titles[stable_id]) and String(revealed_card.get("portrait_path", "")) == String(advanced_portraits[stable_id]), "%s unlock reveals its correct title and static portrait" % stable_id)
	revealed_ui.queue_free()

	var blood_requirement: Dictionary = sim.content.characters.mara.unlock
	_check(blood_requirement.conditions.size() == 1 and blood_requirement.conditions[0].type == "owned_tags" and blood_requirement.conditions[0].ids == ["blood", "dagger"], "The Bloodletter keeps only its authored Blood plus Dagger condition with no substitute achievement")
	var blood_pool = SimScript.new()
	blood_pool.profile["unlocked_character_ids"] = starters.duplicate()
	blood_pool.start_run(43, "jim")
	var blood_candidates := blood_pool.get_reward_candidates(true)
	_check(blood_candidates.any(func(entry: Dictionary) -> bool: return String(entry.get("type", "")) == "artifact" and String(entry.id) == "crimson_crown") and blood_candidates.any(func(entry: Dictionary) -> bool: return String(entry.id) == "dagger"), "the central reward pool can legitimately offer Blood-tagged Crimson Crown and Dagger content")
	blood_pool.run.equipment.Weapon = "dagger"
	blood_pool.run.artifacts.append("crimson_crown")
	_check(blood_pool.check_authored_character_unlocks().has("mara") and blood_pool.is_character_unlocked("mara"), "the existing Blood artifact plus Dagger can satisfy The Bloodletter's authored condition through play state")
	var blood_dagger_only = SimScript.new()
	blood_dagger_only.profile["unlocked_character_ids"] = starters.duplicate()
	blood_dagger_only.start_run(27, "jim")
	blood_dagger_only.run.equipment.Weapon = "dagger"
	_check(not blood_dagger_only.evaluate_prerequisites(blood_requirement).eligible and not blood_dagger_only.check_authored_character_unlocks().has("mara"), "a dagger without Blood content leaves The Bloodletter legitimately locked")
	blood_dagger_only.run.known.append("blood_lance")
	_check(blood_dagger_only.evaluate_prerequisites(blood_requirement).eligible, "Blood plus Dagger content satisfies The Bloodletter's authored condition")

	var warrior_base = SimScript.new()
	warrior_base.profile["unlocked_character_ids"] = starters.duplicate()
	warrior_base.start_run(28, "jim")
	warrior_base.run.stage_completed = true
	warrior_base.run.equipment.Weapon = "greatsword"
	_check(not warrior_base.evaluate_prerequisites(warrior_base.content.characters.brakka.unlock).eligible, "a Greatsword without the Might threshold does not unlock The Warrior")
	var warrior_stat_only = SimScript.new()
	warrior_stat_only.profile["unlocked_character_ids"] = starters.duplicate()
	warrior_stat_only.start_run(29, "jim")
	warrior_stat_only.run.stage_completed = true
	warrior_stat_only.run.attributes.Might = 14
	_check(not warrior_stat_only.evaluate_prerequisites(warrior_stat_only.content.characters.brakka.unlock).eligible, "Might 14 without a Greatsword does not unlock The Warrior")
	var warrior = SimScript.new()
	warrior.profile["unlocked_character_ids"] = starters.duplicate()
	warrior.start_run(30, "jim")
	warrior.run.equipment.Weapon = "greatsword"
	warrior.run.attributes.Might = 14
	warrior._complete_stage()
	_check(warrior.is_character_unlocked("brakka"), "a completed stage with Greatsword and Might 14 unlocks The Warrior")
	warrior.run.stage_completed = false
	warrior.run.attributes.Might = 13
	_check(not warrior.evaluate_prerequisites(warrior.content.characters.brakka.unlock).eligible, "Might 13 falls below the documented threshold")

	var ranger_bow_only = SimScript.new()
	ranger_bow_only.profile["unlocked_character_ids"] = starters.duplicate()
	ranger_bow_only.start_run(31, "archer")
	ranger_bow_only.run.stage_completed = true
	_check(not ranger_bow_only.evaluate_prerequisites(ranger_bow_only.content.characters.sylvi.unlock).eligible, "Bow alone does not unlock The Ranger")
	var ranger_pool = SimScript.new()
	ranger_pool.profile["unlocked_character_ids"] = starters.duplicate()
	ranger_pool.start_run(44, "archer")
	var nature_reward_candidates := ranger_pool.get_reward_candidates(true).filter(func(entry: Dictionary) -> bool:
		var definition: Dictionary = ranger_pool.content.artifacts.get(String(entry.id), {}) if String(entry.get("type", "")) == "artifact" else ranger_pool.content.items.get(String(entry.id), {})
		return definition.get("tags", []).has("nature")
	)
	var nature_spellbooks: Array = ranger_pool.content.items.values().filter(func(item: Dictionary) -> bool: return String(item.get("type", "")) == "spellbook" and String(item.get("school", "")) == "Nature")
	var mend_progress: Dictionary = ranger_pool.get_ability_progress("mend")
	_check(nature_reward_candidates.is_empty() and nature_spellbooks.is_empty() and not mend_progress.get("learnable", false), "The Ranger's Nature requirement currently has no obtainable tagged reward or skill book, with no substitute condition")
	var ranger_nature_only = SimScript.new()
	ranger_nature_only.profile["unlocked_character_ids"] = starters.duplicate()
	ranger_nature_only.start_run(32, "apprentice")
	ranger_nature_only.run.known.append("mend")
	ranger_nature_only.run.stage_completed = true
	_check(not ranger_nature_only.evaluate_prerequisites(ranger_nature_only.content.characters.sylvi.unlock).eligible, "Nature without Bow does not unlock The Ranger")
	var ranger = SimScript.new()
	ranger.profile["unlocked_character_ids"] = starters.duplicate()
	ranger.start_run(33, "archer")
	ranger.run.known.append("mend")
	ranger._complete_stage()
	_check(ranger.is_character_unlocked("sylvi"), "a completed stage with Bow and Nature content unlocks The Ranger")

	var command_only = SimScript.new()
	command_only.profile["unlocked_character_ids"] = starters.duplicate()
	command_only.start_run(34, "jim")
	command_only.get_player().resources.Command = [0, 5]
	_check(not command_only.evaluate_prerequisites(command_only.content.characters.orin.unlock).eligible, "five Command capacity alone does not satisfy The Necromancer's unlock")
	var available_command_increase := 0
	for candidate in command_only.get_reward_candidates(true):
		if String(candidate.get("type", "")) != "artifact": continue
		var artifact: Dictionary = command_only.content.artifacts.get(String(candidate.id), {})
		available_command_increase += int(artifact.get("on_acquire", {}).get("command_capacity", 0))
	_check(int(command_only.content.characters.jim.resources.Command[1]) + available_command_increase == 2, "current eligible Core artifacts can raise a starting class to only two Command capacity")
	var necromancer_four = SimScript.new()
	necromancer_four.profile["unlocked_character_ids"] = starters.duplicate()
	necromancer_four.start_run(35, "jim")
	var four_summons := _spawn_test_summons(necromancer_four, 4, 5)
	_check(four_summons == 4 and not necromancer_four.evaluate_prerequisites(necromancer_four.content.characters.orin.unlock).eligible, "four simultaneously controlled Undead do not unlock The Necromancer")
	var necromancer_five = SimScript.new()
	necromancer_five.profile["unlocked_character_ids"] = starters.duplicate()
	necromancer_five.start_run(36, "jim")
	var five_summons := _spawn_test_summons(necromancer_five, 5, 5)
	_check(five_summons == 5 and necromancer_five.content.enemies.skeleton.faction == "Undead" and necromancer_five.check_authored_character_unlocks().has("orin") and necromancer_five.is_character_unlocked("orin"), "five real living player-owned Undead entities unlock The Necromancer through the production summon state")
	var historical_summons = SimScript.new()
	historical_summons.profile["unlocked_character_ids"] = starters.duplicate()
	historical_summons.start_run(37, "jim")
	_spawn_test_summons(historical_summons, 5, 5)
	var alive_count := 0
	for entity in historical_summons.run.entities.values():
		if entity.get("kind", "") == "summon" and entity.get("enemy_id", "") == "skeleton" and entity.get("alive", false):
			alive_count += 1
			if alive_count > 1: entity["alive"] = false
	_check(not historical_summons.evaluate_prerequisites(historical_summons.content.characters.orin.unlock).eligible, "summons from the run's history do not count when four are dead")

	var prereq = SimScript.new()
	prereq.profile["unlocked_character_ids"] = starters.duplicate()
	prereq.start_run(24, "apprentice")
	prereq.run.build_tag_counts = {"bow": 1}
	_check(not prereq.evaluate_prerequisites({"conditions": [{"type": "tags", "ids": ["bow", "blood"]}]}).eligible, "a multiple-tag prerequisite requires every requested tag")
	prereq.run.build_tag_counts["blood"] = 1
	_check(prereq.evaluate_prerequisites({"conditions": [{"type": "tags", "ids": ["bow", "blood"]}]}).eligible, "hybrid Bow plus Blood content can require multiple tags")
	_check(prereq.evaluate_prerequisites({"conditions": [{"type": "ability", "id": "magic_missile"}]}).eligible, "ability ownership satisfies generic prerequisites")
	_check(not prereq.evaluate_prerequisites({"conditions": [{"type": "ability", "id": "blood_lance"}]}).eligible, "missing ability ownership blocks eligibility")
	prereq.run.inventory.append("copper_ring")
	_check(prereq.evaluate_prerequisites({"conditions": [{"type": "item", "id": "copper_ring"}]}).eligible, "item ownership satisfies generic prerequisites")
	_check(not prereq.evaluate_prerequisites({"conditions": [{"type": "item", "id": "iron_shield"}]}).eligible, "missing item ownership blocks eligibility")
	prereq.run.artifacts.append("copper_hare")
	_check(prereq.evaluate_prerequisites({"conditions": [{"type": "artifact", "id": "copper_hare"}]}).eligible and prereq.evaluate_prerequisites({"conditions": [{"type": "character", "id": "apprentice"}]}).eligible, "artifact and character prerequisites use the same condition evaluator")
	_check(prereq.evaluate_prerequisites({"conditions": [{"type": "package", "id": "core"}]}).eligible, "package prerequisites can be checked against the active package set")
	var locked_item: Dictionary = {"name": "Cross-build Test Ring", "type": "equipment", "slot": "Ring 1", "tags": ["magic"], "prerequisites": {"conditions": [{"type": "tags", "ids": ["bow", "blood"]}, {"type": "item", "id": "copper_ring"}]}}
	prereq.content.items["cross_build_fixture"] = locked_item
	_check(prereq.get_reward_candidates(false).any(func(entry: Dictionary) -> bool: return String(entry.id) == "cross_build_fixture"), "a package-style item uses the same multi-condition reward eligibility path")
	prereq.run.build_tag_counts.erase("blood")
	_check(not prereq.get_reward_candidates(false).any(func(entry: Dictionary) -> bool: return String(entry.id) == "cross_build_fixture"), "unmet package prerequisites remove only that definition from the eligible pool")

	var cross_build: Dictionary = {"name": "Bow Blood Probe", "school": "Arcane", "categories": ["arcane"], "description": "Test-only hybrid ability.", "time": 70, "range": 4, "target": "enemy", "costs": {}, "effects": [{"type": "damage", "amount": 1, "damage": "Arcane"}], "tags": ["bow", "blood", "hybrid"], "prerequisites": {"conditions": [{"type": "tags", "ids": ["bow", "blood"]}]}}
	prereq.content.abilities["cross_build_standalone_probe"] = cross_build
	prereq.run.skill_points = 1
	_check(not prereq.get_ability_progress("cross_build_standalone_probe").learnable, "standalone hybrid abilities remain unavailable while their tags are unmet")
	prereq.run.build_tag_counts["blood"] = 1
	_check(prereq.get_ability_progress("cross_build_standalone_probe").learnable and prereq.learn_ability("cross_build_standalone_probe"), "a conditional standalone hybrid ability becomes learnable without transforming another ability")

	var evolution_sim = SimScript.new()
	evolution_sim.profile["unlocked_character_ids"] = starters.duplicate()
	evolution_sim.start_run(25, "apprentice")
	evolution_sim.content.abilities["magic_missile_evolved_probe"] = {"name": "Evolved Missile Probe", "school": "Arcane", "categories": ["arcane"], "description": "Test-only evolution fixture.", "time": 75, "range": 6, "target": "enemy", "costs": {}, "effects": [{"type": "damage", "amount": 1, "damage": "Arcane"}], "tags": ["magic", "arcane"], "evolution": {"from": "magic_missile", "min_level": 2, "prerequisites": {"conditions": [{"type": "tags", "ids": ["bow", "blood"]}, {"type": "item", "id": "copper_ring"}]}}}
	_check(not evolution_sim.get_evolution_eligibility("magic_missile_evolved_probe").eligible, "evolution cannot appear before its required build conditions")
	evolution_sim.run.ability_states.magic_missile = {"level": 2}
	evolution_sim.run.build_tag_counts = {"bow": 1, "blood": 1}
	evolution_sim.run.inventory.append("copper_ring")
	_check(evolution_sim.get_evolution_eligibility("magic_missile_evolved_probe").eligible, "owning and leveling the base ability plus required tags and item unlocks an evolution")
	_check(evolution_sim.evolve_ability("magic_missile_evolved_probe") and not evolution_sim.run.known.has("magic_missile") and evolution_sim.run.known.has("magic_missile_evolved_probe"), "evolution transforms the run ability state rather than adding an unrelated random ability")
	var evolved_id := "magic_missile_evolved_probe"
	var evolved_state: Dictionary = evolution_sim.run.ability_states[evolved_id]
	evolution_sim.save_run()
	var evolution_loaded = SimScript.new()
	_check(evolution_loaded.resume_run() and evolution_loaded.run.ability_states.get(evolved_id, {}) == evolved_state, "evolution identity and state serialize in the run save")

	var registry := RegistryScript.new()
	var core_manifest := {"id": "core", "name": "Core", "version": "1.0.0", "kind": "core", "dependencies": [], "content_file": "content.json", "assets": []}
	var core_content := {"tag_registry": {"physical": {}}, "items": {"fixture_stable_id": {"name": "Stable Fixture"}}}
	var package_a := {"manifest": {"id": "pack-a", "name": "Official Fixture A", "version": "1.2.0", "kind": "official", "dependencies": [], "content_file": "content.json", "assets": []}, "definitions": {"items": {"fixture_a": {"name": "Package A"}}, "passives": {"fixture_passive": {"name": "Package Passive"}}, "maps": {"fixture_map": {"name": "Package Map"}}, "events": {"fixture_event": {"name": "Package Event"}}, "evolutions": {"fixture_evolution": {"name": "Package Evolution"}}}, "directory": "res://fixture-a", "origin": "official"}
	var package_b := {"manifest": {"id": "pack-b", "name": "Official Fixture B", "version": "2.0.0", "kind": "official", "dependencies": ["pack-a"], "content_file": "content.json", "assets": []}, "definitions": {"items": {"fixture_b": {"name": "Package B"}}}, "directory": "res://fixture-b", "origin": "official"}
	var disabled_load: Dictionary = registry.assemble(core_manifest, core_content, [package_b, package_a], [])
	_check(not disabled_load.content.items.has("fixture_a") and not disabled_load.content.items.has("fixture_b"), "disabled packages contribute no definitions")
	var incomplete_load: Dictionary = registry.assemble(core_manifest, core_content, [package_b, package_a], ["pack-b"])
	_check(not incomplete_load.content.items.has("fixture_b") and incomplete_load.errors.any(func(error: String) -> bool: return error.contains("requires 'pack-a' to be enabled")), "a package with a disabled required dependency is rejected")
	var enabled_load: Dictionary = registry.assemble(core_manifest, core_content, [package_b, package_a], ["pack-b", "pack-a"])
	_check(enabled_load.content.items.has("fixture_a") and enabled_load.content.items.has("fixture_b"), "enabled official packages contribute definitions")
	_check(enabled_load.content.passives.has("fixture_passive") and enabled_load.content.maps.has("fixture_map") and enabled_load.content.events.has("fixture_event") and enabled_load.content.evolutions.has("fixture_evolution"), "package definitions accept future passives, maps, events and evolution records through the same stable-ID loader")
	_check(enabled_load.load_order == ["core", "pack-a", "pack-b"], "package load order is deterministic and dependency-first")
	var duplicate_package: Dictionary = package_a.duplicate(true)
	duplicate_package.definitions.items["fixture_stable_id"] = {"name": "Duplicate"}
	var duplicate_load: Dictionary = registry.assemble(core_manifest, core_content, [duplicate_package], ["pack-a"])
	_check(duplicate_load.errors.any(func(error: String) -> bool: return error.contains("Duplicate stable content ID 'fixture_stable_id'")), "duplicate stable IDs are rejected with their content section")
	var missing_dependency: Dictionary = package_a.duplicate(true)
	missing_dependency.manifest.id = "missing-dep"
	missing_dependency.manifest.dependencies = ["not-installed"]
	var dependency_load: Dictionary = registry.assemble(core_manifest, core_content, [missing_dependency], ["missing-dep"])
	_check(dependency_load.errors.any(func(error: String) -> bool: return error.contains("requires missing package 'not-installed'")), "missing package dependencies are reported")
	var cyclic_a: Dictionary = package_a.duplicate(true)
	var cyclic_b: Dictionary = package_b.duplicate(true)
	cyclic_a.manifest.dependencies = ["pack-b"]
	cyclic_b.manifest.dependencies = ["pack-a"]
	var cycle_load: Dictionary = registry.assemble(core_manifest, core_content, [cyclic_b, cyclic_a], ["pack-a", "pack-b"])
	_check(cycle_load.errors.any(func(error: String) -> bool: return error.contains("dependency cycle")) and cycle_load.load_order == ["core"], "dependency cycles block the involved packages")
	var bad_asset: Dictionary = package_a.duplicate(true)
	bad_asset.manifest.assets = ["missing_portrait.png"]
	var bad_asset_load: Dictionary = registry.assemble(core_manifest, core_content, [bad_asset], ["pack-a"])
	_check(bad_asset_load.errors.any(func(error: String) -> bool: return error.contains("missing asset 'missing_portrait.png'")), "package validation reports broken asset references")
	var malformed_definition: Dictionary = package_a.duplicate(true)
	malformed_definition.definitions = {"events": {"malformed_event": "not an object"}}
	var malformed_load: Dictionary = registry.assemble(core_manifest, core_content, [malformed_definition], ["pack-a"])
	_check(malformed_load.errors.any(func(error: String) -> bool: return error.contains("definition 'malformed_event' in section 'events' must be an object")), "package validation rejects malformed definition records before merging them")
	var core_location: Dictionary = registry.assemble(core_manifest, core_content, [], [])
	var moved_to_core: Dictionary = registry.assemble(core_manifest, {"tag_registry": {"physical": {}}, "items": {"fixture_stable_id": {"name": "Stable Fixture"}}}, [], [])
	var package_stable := package_a.duplicate(true)
	package_stable.definitions.items = {"fixture_stable_id": {"name": "Stable Fixture"}}
	var originally_packaged: Dictionary = registry.assemble(core_manifest, {"tag_registry": {"physical": {}}}, [package_stable], ["pack-a"])
	_check(originally_packaged.content.items.has("fixture_stable_id") and moved_to_core.content.items.has("fixture_stable_id"), "package-to-Core movement preserves stable content identity")
	var disk_package_id := "qa-content-foundation-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var disk_package_dir := "user://mods/" + disk_package_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(disk_package_dir))
	var disk_manifest := {"id": disk_package_id, "name": "Content Foundation QA Fixture", "version": "1.0.0", "kind": "mod", "dependencies": [], "content_file": "content.json", "assets": []}
	var disk_fragment := {"items": {"qa_package_fixture_item": {"name": "QA Package Fixture", "type": "consumable", "effect": "heal", "amount": 1, "tags": ["physical"]}}}
	_write_json(disk_package_dir + "/manifest.json", disk_manifest)
	_write_json(disk_package_dir + "/content.json", disk_fragment)
	var disk_package_sim = SimScript.new()
	_check(disk_package_sim.content_registry.available_packages.any(func(package: Dictionary) -> bool: return package.id == disk_package_id and not package.enabled) and not disk_package_sim.content.items.has("qa_package_fixture_item"), "on-disk mod manifests are discovered while disabled definitions stay out of gameplay")
	var enabled_result: Dictionary = disk_package_sim.set_package_enabled(disk_package_id, true)
	_check(enabled_result.ok and disk_package_sim.content.items.has("qa_package_fixture_item"), "the production profile toggle loads valid installed package content")
	var disk_reloaded = SimScript.new()
	_check(disk_reloaded.content.items.has("qa_package_fixture_item") and disk_reloaded.profile.enabled_package_ids.has(disk_package_id), "package enable state and definitions persist across simulation reload")
	var disabled_result: Dictionary = disk_reloaded.set_package_enabled(disk_package_id, false)
	_check(disabled_result.ok and not disk_reloaded.content.items.has("qa_package_fixture_item"), "disabling an installed package removes its definitions from the active content pool")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(disk_package_dir + "/manifest.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(disk_package_dir + "/content.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(disk_package_dir))
	var invalid_tag_sim = SimScript.new()
	invalid_tag_sim.content.items["invalid_tag_fixture"] = {"name": "Invalid Tag Fixture", "type": "consumable", "effect": "heal", "amount": 1, "tags": ["tag-does-not-exist"]}
	_check(invalid_tag_sim.validate_content().any(func(error: String) -> bool: return error.contains("invalid_tag_fixture references unknown content tag")), "content validation catches invalid tag references")
	var invalid_future_metadata_sim = SimScript.new()
	invalid_future_metadata_sim.content["passives"] = {"invalid_passive_fixture": {"name": "Invalid Passive Fixture", "tags": ["tag-does-not-exist"], "prerequisites": {"conditions": [{"type": "ability", "id": "missing_ability"}]}}}
	var future_metadata_errors: Array = invalid_future_metadata_sim.validate_content()
	_check(future_metadata_errors.any(func(error: String) -> bool: return error.contains("invalid_passive_fixture references unknown content tag")) and future_metadata_errors.any(func(error: String) -> bool: return error.contains("invalid_passive_fixture requires unknown ability missing_ability")), "generic tag and prerequisite validation covers future package definition families")
	var invalid_prerequisite_sim = SimScript.new()
	invalid_prerequisite_sim.content.abilities["invalid_prerequisite_fixture"] = {"name": "Invalid Prerequisite Fixture", "school": "Swordsmanship", "categories": ["swordsmanship"], "description": "A validation-only fixture.", "time": 50, "range": 1, "target": "enemy", "costs": {}, "effects": [{"type": "damage", "amount": 1, "damage": "Slashing"}], "prerequisites": {"schools": ["Arcane"], "resources": {"Unknown Resource": 1}}}
	var prerequisite_errors: Array = invalid_prerequisite_sim.validate_content()
	_check(prerequisite_errors.any(func(error: String) -> bool: return error.contains("invalid_prerequisite_fixture requires unknown magic school Arcane")) and prerequisite_errors.any(func(error: String) -> bool: return error.contains("invalid_prerequisite_fixture requires unknown resource Unknown Resource")), "validation rejects unsupported Arcane-school gates and unknown prerequisite resources")

	var loot_sim = SimScript.new()
	loot_sim.profile["unlocked_character_ids"] = starters.duplicate()
	loot_sim.start_run(26, "jim")
	_check(loot_sim.run.objects.any(func(object: Dictionary) -> bool: return object.get("kind", "") in ["chest", "skill_book", "item", "loot"]), "stage definitions can place exploration rewards")
	loot_sim.run.current_map = loot_sim._generate_map("2", "ruined_village", "graveyard")
	loot_sim.run.map_depth = "2"
	loot_sim.run.stage_index = 0
	loot_sim._new_stage("graveyard", false, true)
	_check(not loot_sim.run.objects.any(func(object: Dictionary) -> bool: return object.get("kind", "") in ["chest", "skill_book", "item", "loot"]), "a stage can explicitly contain zero exploration loot")
	loot_sim.run.objects = [{"id": "test_chest", "kind": "chest", "name": "Travel Chest", "pos": loot_sim.get_player().pos.duplicate(), "hp": 1, "max_hp": 1}]
	_check(not loot_sim.run.objects[0].has("contents"), "chest contents are hidden before opening")
	var chest_position: Array = loot_sim.get_player().pos.duplicate()
	var chest_result: Dictionary = loot_sim.act({"type": "interact", "target": chest_position})
	_check(chest_result.ok and loot_sim.run.objects[0].get("opened", false) and loot_sim.run.objects[0].contents.has("id"), "the chest rolls through central eligibility and weighting only when opened")
	var generated_kinds := {"chest": 0, "skill_book": 0, "item": 0}
	loot_sim.run.objects = []
	loot_sim._spawn_exploration_loot({"exploration_loot": {"min_count": 1, "max_count": 1, "types": ["skill_book"]}})
	for object in loot_sim.run.objects: generated_kinds[String(object.kind)] = int(generated_kinds.get(String(object.kind), 0)) + 1
	_check(generated_kinds.skill_book == 1 and loot_sim.content.items[loot_sim.run.objects[0].item_id].type == "spellbook", "stage exploration tables can place run-specific skill books")
	var book_sim = SimScript.new()
	book_sim.profile["unlocked_character_ids"] = starters.duplicate()
	book_sim.start_run(27, "jim")
	book_sim.run.inventory.append("cinder_primer")
	var cinder_index: int = book_sim.run.inventory.find("cinder_primer")
	_check(book_sim.study_spellbook(cinder_index, []) and book_sim.run.known.has("firebolt"), "studying a skill book teaches an ability for the active run")
	book_sim.start_run(28, "jim")
	_check(not book_sim.run.known.has("firebolt") and not book_sim.profile.has("known_abilities"), "run-specific book learning disappears when a new run starts")
	var drop_sim = SimScript.new()
	drop_sim.profile["unlocked_character_ids"] = starters.duplicate()
	drop_sim.start_run(29, "jim")
	for entity_id in drop_sim.run.entities:
		if entity_id != "player":
			drop_sim.run.entities[entity_id].alive = false
	var drop_enemy := drop_sim._spawn_enemy("goblin", Vector2i(10, 8), false)
	drop_sim._rng.seed = 42
	drop_sim._on_death(drop_enemy, "test", "player")
	var dropped_loot: Array = drop_sim.run.objects.filter(func(object: Dictionary) -> bool: return object.get("marker", "") == "star")
	_check(dropped_loot.size() <= 1 and (dropped_loot.is_empty() or drop_sim.content.items.has(dropped_loot[0].item_id)), "enemy loot is occasional and resolves to meaningful item content")
	if not dropped_loot.is_empty():
		_check(dropped_loot[0].marker == "star" and drop_sim._object_index_at(Vector2i(dropped_loot[0].pos[0], dropped_loot[0].pos[1])) >= 0, "an enemy drop is marked with a star at its world location")
	else:
		var found_drop := false
		for seed_value in range(100):
			var retry = SimScript.new()
			retry.profile["unlocked_character_ids"] = starters.duplicate()
			retry.start_run(100 + seed_value, "jim")
			for other_id in retry.run.entities:
				if other_id != "player": retry.run.entities[other_id].alive = false
			var retry_enemy := retry._spawn_enemy("goblin", Vector2i(10, 8), false)
			retry._rng.seed = seed_value
			retry._on_death(retry_enemy, "test", "player")
			if retry.run.objects.any(func(object: Dictionary) -> bool: return object.get("marker", "") == "star"):
				found_drop = true
				break
		_check(found_drop, "some enemy defeats leave a star-marked meaningful drop")

	var migration_source = SimScript.new()
	migration_source.profile["unlocked_character_ids"] = starters.duplicate()
	migration_source.start_run(30, "jim")
	migration_source.run.character = "Jim the Mundane"
	migration_source.get_player().name = "Jim the Mundane"
	var stable_id_before := String(migration_source.run.character_id)
	migration_source.save_run()
	var migrated = SimScript.new()
	_check(migrated.resume_run() and migrated.run.character_id == stable_id_before and migrated.run.character == "The Mundane" and migrated.get_player().name == "The Mundane", "legacy Jim run saves migrate the display name while preserving the stable character ID")

	var ui = MainScene.instantiate()
	ui.playback_mode = "Instant"
	root.add_child(ui)
	await process_frame
	await process_frame
	ui.sim.profile["unlocked_character_ids"] = starters.duplicate()
	ui.sim.profile["pending_character_reveals"] = []
	ui.sim.save_profile()
	ui.queue_redraw()
	await process_frame
	await process_frame
	var selectable_ids: Dictionary = {}
	for hit in ui.active_hits:
		if String(hit.action.get("type", "")) == "select_character": selectable_ids[String(hit.action.get("id", ""))] = true
	var selectable_starting: Array = selectable_ids.keys()
	selectable_starting.sort()
	_check(selectable_starting == ["apprentice", "archer", "defender", "jim"], "the character-selection UI exposes four selectable starting classes")
	ui._handle_action({"type": "content_mods"})
	ui.queue_redraw()
	await process_frame
	_check(ui.overlay == "content_mods" and ui.sim.content_registry.available_packages.any(func(package: Dictionary) -> bool: return package.id == "core" and package.required), "the Content/Mods screen distinguishes installed packages while keeping Core active")
	ui.queue_free()

	print("CONTENT FOUNDATION %d · FAILURES %d" % [checks, failures.size()])
	for failure in failures: printerr("FAIL: " + failure)
	quit(1 if not failures.is_empty() else 0)

func _check(condition: bool, title: String) -> void:
	checks += 1
	if not condition: failures.append(title)

func _spawn_test_summons(sim, requested_count: int, capacity: int) -> int:
	var command: Array = sim.get_player().resources.Command
	command[0] = 0
	command[1] = capacity
	sim.get_player().resources.Command = command
	sim.run.objects = []
	for entity_id in sim.run.entities.keys():
		if String(entity_id) != "player": sim.run.entities[entity_id]["alive"] = false
	var player_position: Vector2i = sim._pos(sim.get_player())
	for _index in range(requested_count):
		if not sim._spawn_summon("skeleton", player_position): break
	return sim._count_controlled_summons("Undead", "player")

func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(value))
	file.close()
