extends SceneTree

const SimScript = preload("res://scripts/game_sim.gd")

var checks := 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	var sim = SimScript.new()
	_check(sim.validate_content().is_empty(), "content references validate")
	_check(sim._duplicate_json_keys("{\"item\": 1, \"item\": 2, \"inner\": {\"name\": \"a\", \"name\": \"b\"}}" ).size() == 2, "content scanner detects duplicate keys within data registries")
	var original_slot: String = sim.content.items.leather_armor.slot
	sim.content.items.leather_armor.slot = "Finger"
	_check(not sim.validate_content().is_empty(), "content validation rejects invalid equipment slots")
	sim.content.items.leather_armor.slot = original_slot
	_check(sim.validate_content().is_empty(), "restoring a valid content definition clears validation errors")
	_check(sim.start_run(20261004, "jim"), "character selection starts a run")
	_check(sim.run.grid.size() == 16 and sim.run.grid[0].size() == 25, "stage generation creates a 25 by 16 battlefield")
	_check(sim.get_timeline()[0].id == "player", "player is first at the initial decision point")
	_check(sim.run.equipment.Weapon == "sword" and sim.run.known.size() == 3, "Jim starts with a weapon and no magic")
	_check(sim.content.weapons.dagger.time < sim.content.weapons.greatsword.time and sim.content.weapons.bow.range > sim.content.weapons.sword.range, "weapon definitions have distinct time and range")
	var start := sim._pos(sim.get_player())
	var path_step: Vector2i = sim._next_step(start, Vector2i(20, 8), "player")
	_check(path_step != start and sim._dist(start, path_step) == 1, "eight-direction pathfinding returns the first legal step")
	var stamina_before := int(sim.get_player().resources.Stamina[0])
	var move_result: Dictionary = sim.act({"type": "move", "target": [13, 8]})
	_check(move_result.ok and sim._pos(sim.get_player()) == Vector2i(13, 8), "player movement commits through the production action API")
	_check(int(sim.get_player().resources.Stamina[0]) < stamina_before, "movement spends Stamina")
	var los_origin := sim._pos(sim.get_player())
	var blocked_cell := Vector2i(los_origin.x + 1, los_origin.y)
	var beyond_wall := Vector2i(los_origin.x + 2, los_origin.y)
	sim._set_grid(blocked_cell, "wall")
	_check(not sim._line_of_sight(los_origin, beyond_wall), "wall blocks line of sight")
	sim._set_grid(blocked_cell, "floor")
	var test_enemy_id: String = sim._spawn_enemy("skeleton", Vector2i(6, 8), false)
	var enemy: Dictionary = sim.run.entities[test_enemy_id]
	enemy.resist["Fire"] = 0.5
	enemy.hp = 100
	enemy.max_hp = 100
	var health_before := int(enemy.hp)
	sim._damage(test_enemy_id, 10, "Fire", "test")
	_check(int(enemy.hp) == health_before - 5, "resistance scales incoming damage")
	sim._apply_status(test_enemy_id, "Wet", 1)
	health_before = int(enemy.hp)
	sim._damage(test_enemy_id, 12, "Lightning", "test")
	_check(int(enemy.hp) == health_before - 18, "Wet targets take amplified Lightning damage")
	sim._apply_status(test_enemy_id, "Burning", 2)
	health_before = int(enemy.hp)
	sim._tick_statuses(test_enemy_id)
	_check(int(enemy.hp) < health_before and sim._has_status(test_enemy_id, "Burning"), "stacking status ticks and remains for its duration")
	sim._set_grid(Vector2i(7, 8), "water")
	sim._transform_terrain(Vector2i(7, 8), "Ice")
	_check(sim._terrain_at(Vector2i(7, 8)) == "ice", "Cold freezes Water into Ice")
	sim._set_grid(Vector2i(8, 8), "vegetation")
	sim._transform_terrain(Vector2i(8, 8), "Fire")
	_check(sim._terrain_at(Vector2i(8, 8)) == "fire", "Fire spreads into Vegetation")
	var mana_before := int(sim.get_player().resources.Mana[0])
	sim.get_player().resources.Mana[0] = maxi(0, mana_before - 2)
	mana_before = int(sim.get_player().resources.Mana[0])
	sim._regenerate(200)
	_check(int(sim.get_player().resources.Mana[0]) > mana_before, "Mana regenerates over simulated time")
	_check(sim._dist(Vector2i(0, 0), Vector2i(2, 1)) == 2, "grid uses eight-direction movement distance")

	var mara = SimScript.new()
	mara.start_run(77, "mara")
	var blood_target: String = mara._spawn_enemy("goblin", Vector2i(8, 8), false)
	var blood_before := int(mara.get_player().resources.Blood[0])
	var lance_result: Dictionary = mara.act({"type": "cast", "id": "blood_lance", "target": [8, 8]})
	_check(lance_result.ok and int(mara.get_player().resources.Blood[0]) == blood_before - 3, "Blood Lance spends its Blood cost")
	_check(not mara.run.known.has("fireball"), "temporary spells do not become permanent knowledge")
	var scroll_index: int = mara.run.inventory.find("fireball_scroll")
	var scroll_result: Dictionary = mara.use_item(scroll_index, Vector2i(8, 8))
	_check(scroll_result.ok and not mara.run.inventory.has("fireball_scroll"), "spell scroll casts once and is consumed")
	_check(not mara.run.known.has("fireball") and int(mara.run.temporary_abilities.get("fireball", 0)) == 0, "scroll use leaves no permanent ability or charge")
	_check(mara.run.grid[8][8] in ["fire", "floor", "blood"], "Fireball resolves its area terrain effect")

	var aldren = SimScript.new()
	aldren.start_run(778, "aldren")
	var summon_result: Dictionary = aldren.act({"type": "cast", "id": "phantom_blade", "target": aldren.get_player().pos})
	_check(summon_result.ok, "Phantom Blade is summoned through a reusable ability effect")
	var blade_id := ""
	for entity_id in aldren.run.entities:
		if aldren.run.entities[entity_id].get("enemy_id") == "phantom_blade":
			blade_id = entity_id
	_check(blade_id != "" and aldren.run.entities[blade_id].owner == "player" and aldren.run.entities[blade_id].faction == "Adventurers", "summon stores its owner and faction")
	_check(int(aldren.get_player().resources.Command[0]) == 1, "summon occupies Command capacity")
	var command_before := int(aldren.get_player().resources.Command[0])
	aldren._damage(blade_id, 999, "Arcane", "test")
	_check(int(aldren.get_player().resources.Command[0]) == command_before - 1, "summon death frees Command capacity")
	_check(aldren._is_hostile("player", aldren._spawn_enemy("goblin", Vector2i(5, 8), false)), "hostile faction relationships are recognized")
	_check(not aldren._is_hostile("player", blade_id), "summons are not hostile to their owner")
	aldren._emit_trigger("OnCast", {"ability_id": "arcane_bolt", "school": "Arcane", "targets": []})
	_check(aldren._has_status("player", "Empowered"), "data-defined Spellsteel trigger empowers a weapon attack")
	var mirror = SimScript.new()
	mirror.start_run(88, "jim")
	mirror._acquire_artifact("mirror_of_embers")
	var echo_target: String = mirror._spawn_enemy("goblin", Vector2i(14, 8), false)
	var echo_hp := int(mirror.run.entities[echo_target].hp)
	for cast_index in range(3):
		mirror._emit_trigger("OnCast", {"ability_id": "firebolt", "school": "Fire", "targets": [echo_target]})
	_check(int(mirror.run.entities[echo_target].hp) == echo_hp - 5, "every-third-spell artifact uses the generic trigger rule")
	var bell = SimScript.new()
	bell.start_run(89, "jim")
	bell._acquire_artifact("ossuary_bell")
	for kill_index in range(9):
		bell._emit_trigger("OnKill", {"faction": "Goblinoids", "pos": [8, 8]})
	var summons_before := 0
	for entity_id in bell.run.entities:
		if bell.run.entities[entity_id].get("kind") == "summon":
			summons_before += 1
	bell._emit_trigger("OnKill", {"faction": "Goblinoids", "pos": [8, 8]})
	var summons_after := 0
	for entity_id in bell.run.entities:
		if bell.run.entities[entity_id].get("kind") == "summon":
			summons_after += 1
	_check(summons_before == 0 and summons_after == 1, "OnKill trigger creates its defined summon at the threshold")
	var heart = SimScript.new()
	heart.start_run(90, "jim")
	var max_health_before := int(heart.get_player().max_hp)
	var command_capacity_before := int(heart.get_player().resources.Command[1])
	heart._acquire_artifact("heart_of_command")
	_check(int(heart.get_player().max_hp) == max_health_before - 20 and int(heart.get_player().resources.Command[1]) == command_capacity_before + 1, "artifact acquisition applies its data-defined run changes")
	var armor_before_equip: int = int(sim.get_player().armor)
	sim.run.inventory.append("scale_armor")
	var weapon_index: int = sim.run.inventory.find("scale_armor")
	_check(sim.equip_item(weapon_index) and int(sim.get_player().armor) == armor_before_equip - int(sim.content.items.leather_armor.armor) + int(sim.content.items.scale_armor.armor), "inventory equipment replaces armor and recalculates protection")
	_check(sim.run.inventory.size() <= 30, "inventory stays within its thirty item capacity")

	var objective = SimScript.new()
	objective.start_run(330, "jim")
	objective.run.objective = {"kind": "Eliminate", "turns": 6}
	for entity_id in objective.run.entities:
		if entity_id != "player":
			objective.run.entities[entity_id].alive = false
	objective._check_objective()
	_check(objective.run.stage_completed and objective.run.reward_choices.size() == 3, "Eliminate objective awards three defined rewards")
	_check(objective.claim_reward(0), "reward can be claimed through the run API")
	var next_stage: String = objective.run.route_choices[0]
	_check(objective.choose_route(next_stage) and objective.run.stage_id == next_stage, "cleared encounter opens a selected branch")
	objective.run.objective = {"kind": "Reach Exit", "turns": 0}
	objective.run.stage_completed = false
	objective.run.objects = [{"id": "road_exit", "kind": "exit", "name": "Exit", "pos": [4, 8], "hp": 1, "max_hp": 1}]
	objective._check_objective_at_player()
	_check(not objective.run.stage_completed, "exit objective waits until the player reaches the exit")
	objective.run.entities.player.pos = [4, 8]
	objective._check_objective_at_player()
	_check(objective.run.stage_completed, "Reach Exit objective completes at the marked exit")
	objective.run.stage_completed = false
	objective.run.objective = {"kind": "Destroy Targets", "turns": 0}
	objective.run.objects = [{"id": "ward", "kind": "ward", "name": "Ward", "pos": [8, 8], "hp": 0, "max_hp": 1}]
	objective._check_objective()
	_check(objective.run.stage_completed, "Destroy Targets objective completes after the ward is destroyed")
	objective.run.stage_completed = false
	objective.run.objective = {"kind": "Survive", "turns": 1}
	objective.run.turn = 0
	objective._spend_player_time(60, "")
	_check(objective.run.stage_completed, "Survive objective resolves on its final turn")

	var save_sim = SimScript.new()
	save_sim.start_run(60210, "aldren")
	save_sim.act({"type": "wait"})
	var saved_digest := save_sim.state_digest()
	var resumed = SimScript.new()
	_check(resumed.resume_run(), "run save reloads from disk")
	if resumed.state_digest() != saved_digest:
		print("SAVE DIAGNOSTIC entities=%s grid=%s objects=%s player=%s" % [str(resumed.run.entities == save_sim.run.entities), str(resumed.run.grid == save_sim.run.grid), str(resumed.run.objects == save_sim.run.objects), str(resumed.get_player() == save_sim.get_player())])
		for entity_id in save_sim.run.entities:
			var left: Dictionary = save_sim.run.entities[entity_id]
			var right: Dictionary = resumed.run.entities.get(entity_id, {})
			for key in left:
				if left[key] != right.get(key):
					print("ENTITY DIFF %s.%s original=%s restored=%s" % [entity_id, key, str(left[key]), str(right.get(key))])
		for i in range(mini(save_sim.run.objects.size(), resumed.run.objects.size())):
			for key in save_sim.run.objects[i]:
				if save_sim.run.objects[i][key] != resumed.run.objects[i].get(key):
					print("OBJECT DIFF %s original=%s restored=%s" % [key, str(save_sim.run.objects[i][key]), str(resumed.run.objects[i].get(key))])
	_check(resumed.state_digest() == saved_digest, "save and reload restore deterministic state")
	save_sim.act({"type": "wait"})
	resumed.act({"type": "wait"})
	_check(resumed.state_digest() == save_sim.state_digest(), "resumed and uninterrupted runs remain equivalent")

	var ai = SimScript.new()
	ai.start_run(99, "jim")
	for entity_id in ai.run.entities:
		if entity_id != "player":
			ai.run.entities[entity_id].alive = false
	var goblin_id: String = ai._spawn_enemy("goblin", Vector2i(11, 8), false)
	ai.run.entities[goblin_id].next_time = int(ai.get_player().next_time)
	var hp_before := int(ai.get_player().hp)
	ai.act({"type": "wait"})
	_check(int(ai.get_player().hp) < hp_before, "hostile AI takes a scheduled attack turn")
	var timeline := ai.get_timeline()
	var ordered := true
	for i in range(1, timeline.size()):
		if int(timeline[i].time) < int(timeline[i - 1].time):
			ordered = false
	_check(ordered, "timeline displays actors in deterministic time order")

	var death = SimScript.new()
	death.start_run(4, "jim")
	for entity_id in death.run.entities:
		if entity_id != "player":
			death.run.entities[entity_id].alive = false
	var lethal_id: String = death._spawn_enemy("goblin", Vector2i(11, 8), false)
	death.run.entities[lethal_id].damage = 30
	death.run.entities[lethal_id].next_time = 0
	death.get_player().hp = 1
	death.act({"type": "wait"})
	_check(death.run.outcome == "defeat", "player death ends the run")

	var boss = SimScript.new()
	boss.start_run(5, "jim")
	for entity_id in boss.run.entities:
		if entity_id != "player":
			boss.run.entities[entity_id].alive = false
	boss.run.stage_index = 5
	boss._new_stage("graveyard", true)
	var tyrant_id := ""
	for entity_id in boss.run.entities:
		if boss.run.entities[entity_id].get("kind") == "boss":
			tyrant_id = entity_id
	_check(tyrant_id != "" and int(boss.run.entities[tyrant_id].footprint) == 2, "boss spawns as a multi-tile creature")
	boss._damage(tyrant_id, 999, "Slashing", boss.get_player().name)
	_check(boss.run.outcome == "victory", "boss death completes the run")

	var stress = SimScript.new()
	stress.start_run(2026, "jim")
	var spawned := 0
	for y in range(1, SimScript.HEIGHT - 1):
		for x in range(1, SimScript.WIDTH - 1):
			var cell := Vector2i(x, y)
			if spawned >= 100:
				break
			if stress._terrain_at(cell) != "wall" and stress._occupant(cell) == "":
				stress._spawn_enemy("goblin", cell, false)
				spawned += 1
		if spawned >= 100:
			break
	var stress_start := Time.get_ticks_msec()
	var stress_timeline: Array = stress.get_timeline(100)
	var stress_visible: Array = stress.get_visible_entities()
	var stress_elapsed := Time.get_ticks_msec() - stress_start
	_check(spawned == 100 and stress_timeline.size() == 100 and stress_visible.size() > 1, "100 simultaneous enemies fit the battle state")
	print("STRESS 100 ACTORS · timeline and visibility snapshot: %d ms" % stress_elapsed)
	var long_run = SimScript.new()
	long_run.start_run(919, "jim")
	for entity_id in long_run.run.entities:
		if entity_id != "player":
			long_run.run.entities[entity_id].alive = false
	var turns_start := Time.get_ticks_msec()
	for turn_index in range(300):
		long_run._spend_player_time(100, "")
	var turns_elapsed := Time.get_ticks_msec() - turns_start
	_check(int(long_run.get_player().next_time) >= 30000, "hundreds of deterministic timeline turns resolve")
	print("STRESS 300 PLAYER DECISIONS · simulation: %d ms" % turns_elapsed)
	for stage_index in range(160):
		var stage_id: String = SimScript.STAGE_ORDER[stage_index % SimScript.STAGE_ORDER.size()]
		long_run._new_stage(stage_id, false)
	_check(long_run.run.grid.size() == SimScript.HEIGHT, "160 repeated stage generations produce valid grids")
	print("STRESS 160 GENERATED STAGES · complete")

	print("TESTS %d · FAILURES %d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(1 if not failures.is_empty() else 0)

func _check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures.append(title)

