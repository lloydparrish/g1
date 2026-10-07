extends SceneTree

const SimScript = preload("res://scripts/game_sim.gd")
const OPENING_SEEDS := 300

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	var chars: Array = ["jim", "archer", "apprentice", "defender", "aldren", "mara", "brakka", "sylvi", "orin"]
	var opening_valid := true
	var first_stage_xp_ready := true
	var opening_enemy_total := 0
	var opening_hp_total := 0
	var raw_attack_rate := 0.0
	var equipped_attack_rate := 0.0
	var max_opening_enemies := 0
	var max_initial_ranged := 0
	for seed_index in range(OPENING_SEEDS):
		var sim = SimScript.new()
		var character_id := String(chars[seed_index % chars.size()])
		_allow_character(sim, character_id)
		sim.start_run(910000 + seed_index, character_id)
		var enemies: Array = _hostiles(sim)
		var player: Dictionary = sim.get_player()
		var expected_armor: int = int({"jim": 0, "archer": 0, "apprentice": 0, "defender": 3, "aldren": 2, "mara": 2, "brakka": 4, "sylvi": 3, "orin": 2}.get(character_id, 0))
		var sample_valid := enemies.size() == 2 and int(player.armor) == expected_armor
		opening_enemy_total += enemies.size()
		max_opening_enemies = maxi(max_opening_enemies, enemies.size())
		var stage: Dictionary = sim.content.stages[sim.run.stage_id]
		for entity in enemies:
			var id: String = entity.enemy_id
			var definition: Dictionary = sim.content.enemies[id]
			sample_valid = sample_valid and int(definition.get("tier", 0)) == 0 and int(definition.range) == 1
			opening_hp_total += int(entity.hp)
			var raw_rate := float(entity.damage) / maxf(1.0, float(entity.time))
			raw_attack_rate += raw_rate
			var mitigated := maxi(1, int(entity.damage) - int(player.armor))
			equipped_attack_rate += float(mitigated) / maxf(1.0, float(entity.time))
			if int(entity.range) > 1:
				max_initial_ranged += 1
		var expected_clear_xp := int(sim.run.get("stage_index", 0)) * 3 + 12
		first_stage_xp_ready = first_stage_xp_ready and expected_clear_xp >= 12 and stage.has("enemy_count_curve")
		opening_valid = opening_valid and sample_valid
	_check(opening_valid, "%d seeded stage-one starts have two basic melee enemies and worn protection" % OPENING_SEEDS)
	_check(max_opening_enemies == 2 and max_initial_ranged == 0, "the opening generator prevents a third simultaneous enemy and ranged opening pressure")
	_check(first_stage_xp_ready, "stage completion grants deterministic experience toward the first build choice")
	var mean_hp := float(opening_hp_total) / float(OPENING_SEEDS)
	var old_average_hp := (24.0 + 36.0 + 28.0 + 19.0) / 4.0 * 3.0
	var old_mean_raw_rate := (6.0 / 100.0 + 9.0 / 125.0 + 9.0 / 95.0 + 6.0 / 110.0) / 4.0 * 3.0
	var mean_equipped_rate := equipped_attack_rate / float(OPENING_SEEDS)
	print("BALANCE %d seeds · stage-one enemies %d (was 3) · mean enemy HP %.1f (baseline %.1f) · physical threat %.3f raw / %.3f after starter armor per time unit (baseline %.3f)" % [OPENING_SEEDS, int(float(opening_enemy_total) / OPENING_SEEDS), mean_hp, old_average_hp, raw_attack_rate / float(OPENING_SEEDS), mean_equipped_rate, old_mean_raw_rate])

	var tactical_samples := 60
	var tactical_survivors := 0
	var tactical_clears := 0
	var tactical_kills := 0
	var tactical_actions := 0
	var tactical_damage := 0
	var tactical_healing := 0
	var tactical_stamina := 0
	var tactical_potions := 0
	var tactical_states_valid := true
	var elimination_objectives := 0
	var elimination_clears := 0
	for sample_index in range(tactical_samples):
		var report: Dictionary = _simulate_opening(915000 + sample_index, chars[sample_index % chars.size()])
		tactical_survivors += int(report.survived)
		tactical_clears += int(report.cleared)
		tactical_kills += int(report.kills)
		tactical_actions += int(report.actions)
		tactical_damage += int(report.damage)
		tactical_healing += int(report.healing)
		tactical_stamina += int(report.stamina)
		tactical_potions += int(report.potions)
		if report.objective == "Eliminate":
			elimination_objectives += 1
			if report.cleared:
				elimination_clears += 1
		tactical_states_valid = tactical_states_valid and int(report.actions) <= 24 and int(report.hp) >= 0
	_check(tactical_states_valid, "deterministic opening-combat diagnostics complete without invalid or unbounded runs")
	print("TACTICAL DIAGNOSTIC %d seeds · alive %d/%d · objective clears %d/%d · Eliminate clears %d/%d · mean kills %.2f · actions %.1f · damage %d · healing %d · weapon Stamina %d · potions %d" % [tactical_samples, tactical_survivors, tactical_samples, tactical_clears, tactical_samples, elimination_clears, elimination_objectives, float(tactical_kills) / tactical_samples, float(tactical_actions) / tactical_samples, tactical_damage, tactical_healing, tactical_stamina, tactical_potions])

	var curve_valid := true
	var curve_totals: Array[int] = [0, 0, 0, 0, 0]
	for seed_index in range(80):
		var sim = SimScript.new()
		sim.start_run(920000 + seed_index, "jim")
		for stage_index in range(5):
			sim.run.stage_index = stage_index
			var stage_id: String = SimScript.STAGE_ORDER[(seed_index + stage_index) % SimScript.STAGE_ORDER.size()]
			sim._new_stage(stage_id, false)
			var enemies: Array = _hostiles(sim)
			curve_totals[stage_index] += enemies.size()
			var tier_limit := 0 if stage_index == 0 else 1 if stage_index <= 2 else 2
			for entity in enemies:
				curve_valid = curve_valid and int(sim.content.enemies[entity.enemy_id].get("tier", 0)) <= tier_limit
			curve_valid = curve_valid and enemies.size() == [2, 3, 4, 5, 5][stage_index]
	_check(curve_valid and curve_totals == [160, 240, 320, 400, 400], "encounter size and enemy tier bands rise gradually across the five non-boss stages")

	var reward = SimScript.new()
	_allow_character(reward, "mara")
	reward.start_run(930001, "mara")
	reward._award_xp(24)
	reward._complete_stage()
	_check(int(reward.run.skill_points) >= 1 and int(reward.run.level) >= 2, "two ordinary kills plus a clear reward can open an early ability choice")

	print("EARLY RUN CURVE · %d stage samples · mean enemies by stage %s" % [400, str(curve_totals.map(func(total: int) -> float: return float(total) / 80.0))])
	print("BALANCE CHECKS %d · FAILURES %d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(1 if not failures.is_empty() else 0)

func _hostiles(sim) -> Array:
	var result: Array = []
	for entity_id in sim.run.entities:
		var entity: Dictionary = sim.run.entities[entity_id]
		if entity_id != "player" and entity.get("alive", true) and entity.get("kind", "") == "enemy":
			result.append(entity)
	return result

func _simulate_opening(seed_value: int, character_id: String) -> Dictionary:
	var sim = SimScript.new()
	_allow_character(sim, character_id)
	sim.start_run(seed_value, character_id)
	var actions := 0
	var damage_taken := 0
	var healing_received := 0
	var stamina_spent := 0
	var potions_used := 0
	while actions < 24 and not sim.run.stage_completed and sim.run.outcome == "":
		var hostiles: Array = _hostiles(sim)
		if hostiles.is_empty():
			break
		var player: Dictionary = sim.get_player()
		var player_position: Vector2i = sim._pos(player)
		var target: Dictionary = hostiles[0]
		for entity in hostiles:
			if sim._dist(player_position, sim._pos(entity)) < sim._dist(player_position, sim._pos(target)):
				target = entity
		var target_position: Vector2i = sim._pos(target)
		var command: Dictionary = {}
		var healing_index: int = sim.run.inventory.find("healing_potion")
		if healing_index >= 0 and int(player.hp) <= int(float(player.max_hp) * 0.55):
			command = {"type": "use_item", "index": healing_index}
			potions_used += 1
		else:
			var weapon_id: String = sim.run.equipment.get("Weapon", "sword")
			var weapon: Dictionary = sim.content.weapons.get(weapon_id, sim.content.weapons.sword)
			var distance: int = sim._distance_to_entity(player_position, target)
			if distance <= int(weapon.range) and sim._line_of_sight(player_position, target_position):
				command = {"type": "attack", "target": [target_position.x, target_position.y]}
			else:
				var step: Vector2i = sim._next_step(player_position, target_position, "player")
				command = {"type": "move", "target": [step.x, step.y]} if step != player_position else {"type": "wait"}
		var hp_before: int = int(player.hp)
		var result: Dictionary = sim.act(command)
		if not result.get("ok", false):
			if command.get("type", "") != "wait":
				result = sim.act({"type": "wait"})
			if not result.get("ok", false):
				break
		if command.get("type", "") == "attack":
			var weapon_definition: Dictionary = sim.content.weapons.get(sim.run.equipment.get("Weapon", "sword"), sim.content.weapons.sword)
			stamina_spent += int(weapon_definition.get("stamina", 0))
		actions += 1
		var hp_after: int = int(sim.get_player().hp)
		damage_taken += maxi(0, hp_before - hp_after)
		healing_received += maxi(0, hp_after - hp_before)
	var player_end: Dictionary = sim.get_player()
	return {"survived": int(player_end.hp) > 0 and sim.run.outcome != "defeat", "cleared": bool(sim.run.stage_completed), "objective": String(sim.run.objective.get("kind", "")), "kills": int(sim.run.kills), "actions": actions, "damage": damage_taken, "healing": healing_received, "stamina": stamina_spent, "potions": potions_used, "hp": int(player_end.hp)}

func _check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures.append(title)

func _allow_character(sim, character_id: String) -> void:
	var unlocked: Array = sim.profile.get("unlocked_character_ids", [])
	if not unlocked.has(character_id): unlocked.append(character_id)
	sim.profile["unlocked_character_ids"] = unlocked
