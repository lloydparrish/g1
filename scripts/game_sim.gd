extends RefCounted
class_name ArcanistSim

const WIDTH := 25
const HEIGHT := 16
const SAVE_PATH := "user://run_save.json"
const CODEX_PATH := "user://codex.json"
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]
const STAGE_ORDER := ["ruined_village", "graveyard", "flooded_ruins", "goblin_warrens", "thornwood"]

var content: Dictionary = {}
var run: Dictionary = {}
var codex: Dictionary = {"creatures": [], "abilities": [], "spellbooks": [], "artifacts": [], "schools": []}
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	if parsed is Dictionary:
		content = parsed
	_load_codex()

func validate_content() -> Array:
	var errors: Array = []
	var types: Array = content.get("damage_types", [])
	var valid_slots := ["Weapon", "Offhand", "Head", "Body", "Hands", "Feet", "Ring 1", "Ring 2", "Amulet"]
	var valid_targets := ["self", "enemy", "area", "tile"]
	var valid_effects := ["damage", "heal", "heal_on_hit", "move", "status", "summon", "teleport", "terrain", "resource"]
	var valid_objectives := ["Eliminate", "Survive", "Reach Exit", "Destroy Targets"]
	var valid_terrain := ["floor", "wall", "water", "ice", "fire", "blood", "vegetation", "poison", "smoke", "oil"]
	var valid_behaviors := ["melee", "ranged", "caster", "summoner", "beast", "boss"]
	for duplicate_key in _duplicate_json_keys(FileAccess.get_file_as_string("res://data/content.json")):
		errors.append("Duplicate JSON key %s" % duplicate_key)
	for value_registry in [["damage_types", types], ["resources", content.get("resources", [])]]:
		var seen: Dictionary = {}
		for value in value_registry[1]:
			if seen.has(value):
				errors.append("%s contains duplicate %s" % [value_registry[0], value])
			seen[value] = true
	for ability_id in content.get("abilities", {}):
		var ability: Dictionary = content.abilities[ability_id]
		if String(ability.get("name", "")) == "":
			errors.append("%s has no display name" % ability_id)
		if not valid_targets.has(ability.get("target", "")):
			errors.append("%s has an invalid target type" % ability_id)
		if int(ability.get("range", -1)) < 0 or int(ability.get("time", 0)) <= 0:
			errors.append("%s has an invalid range or action time" % ability_id)
		for effect in ability.get("effects", []):
			if not valid_effects.has(effect.get("type", "")):
				errors.append("%s uses an unknown effect %s" % [ability_id, effect.get("type", "")])
			if effect.get("type") == "damage" and not types.has(effect.get("damage", "")):
				errors.append("%s uses unknown damage type %s" % [ability_id, effect.get("damage", "" )])
			if effect.get("type") == "status" and not content.get("statuses", {}).has(effect.get("id", "")):
				errors.append("%s uses unknown status %s" % [ability_id, effect.get("id", "" )])
			if effect.get("type") == "summon" and not content.get("enemies", {}).has(effect.get("id", "")) and not content.get("summons", {}).has(effect.get("id", "")):
				errors.append("%s summons unknown creature %s" % [ability_id, effect.get("id", "" )])
			if effect.get("type") == "resource" and not content.get("resources", []).has(effect.get("id", "")):
				errors.append("%s changes unknown resource %s" % [ability_id, effect.get("id", "" )])
		for resource in ability.get("costs", {}):
			if not content.get("resources", []).has(resource):
				errors.append("%s uses unknown resource %s" % [ability_id, resource])
		for prerequisite in ability.get("requires", []):
			if not content.get("abilities", {}).has(prerequisite):
				errors.append("%s requires unknown ability %s" % [ability_id, prerequisite])
	for weapon_id in content.get("weapons", {}):
		var weapon: Dictionary = content.weapons[weapon_id]
		if not valid_slots.has(weapon.get("slot", "")) or not types.has(weapon.get("type", "")):
			errors.append("%s has an invalid slot or damage type" % weapon_id)
		if int(weapon.get("hands", 0)) not in [1, 2] or int(weapon.get("range", 0)) < 1 or int(weapon.get("time", 0)) <= 0 or int(weapon.get("stamina", -1)) < 0:
			errors.append("%s has invalid weapon behavior" % weapon_id)
	for item_id in content.get("items", {}):
		var item: Dictionary = content.items[item_id]
		if String(item.get("name", "")) == "":
			errors.append("%s has no display name" % item_id)
		if item.get("type") == "equipment":
			if not valid_slots.has(item.get("slot", "")):
				errors.append("%s uses an invalid equipment slot" % item_id)
			if item.get("slot") == "Weapon" and not content.get("weapons", {}).has(item.get("weapon", "")):
				errors.append("%s refers to an unknown weapon" % item_id)
		if item.get("type") == "scroll" and not content.get("abilities", {}).has(item.get("ability", "")):
			errors.append("%s refers to an unknown scroll ability" % item_id)
		if item.get("type") == "spellbook":
			for learned_ability in item.get("learns", []):
				if not content.get("abilities", {}).has(learned_ability):
					errors.append("%s teaches unknown ability %s" % [item_id, learned_ability])
	for enemy_id in content.get("enemies", {}):
		var enemy: Dictionary = content.enemies[enemy_id]
		if not types.has(enemy.get("damage_type", "")):
			errors.append("%s uses unknown damage type %s" % [enemy_id, enemy.get("damage_type", "" )])
		if String(enemy.get("name", "")) == "" or String(enemy.get("symbol", "")) == "":
			errors.append("%s is missing its display name or battlefield symbol" % enemy_id)
		if not valid_behaviors.has(enemy.get("behavior", "")) or int(enemy.get("footprint", 1)) < 1:
			errors.append("%s has invalid AI or footprint settings" % enemy_id)
	for summon_id in content.get("summons", {}):
		var summon: Dictionary = content.summons[summon_id]
		if String(summon.get("name", "")) == "" or String(summon.get("symbol", "")) == "" or int(summon.get("command", 0)) < 0:
			errors.append("%s is missing its display, symbol or Command definition" % summon_id)
	for stage_id in content.get("stages", {}):
		var stage: Dictionary = content.stages[stage_id]
		if String(stage.get("name", "")) == "" or stage.get("enemies", []).is_empty() or stage.get("objectives", []).is_empty():
			errors.append("%s needs a name, an enemy and an objective" % stage_id)
		for enemy_id in stage.get("enemies", []):
			if not content.enemies.has(enemy_id):
				errors.append("%s references unknown enemy %s" % [stage_id, enemy_id])
		for objective in stage.get("objectives", []):
			if not valid_objectives.has(objective):
				errors.append("%s uses an invalid objective %s" % [stage_id, objective])
		var terrain: Dictionary = stage.get("terrain", {})
		var probability_sum := 0.0
		for terrain_id in terrain:
			var probability := float(terrain[terrain_id])
			if not ["wall", "water", "fire", "blood", "vegetation"].has(terrain_id) or probability < 0.0 or probability > 1.0:
				errors.append("%s has an invalid terrain weight for %s" % [stage_id, terrain_id])
			probability_sum += probability
		if probability_sum > 1.0:
			errors.append("%s terrain weights exceed one" % stage_id)
	for character_id in content.get("characters", {}):
		var character: Dictionary = content.characters[character_id]
		if not content.weapons.has(character.get("weapon", "")):
			errors.append("%s starts with unknown weapon" % character_id)
		for ability_id in character.get("known", []):
			if not content.abilities.has(ability_id):
				errors.append("%s starts with unknown ability %s" % [character_id, ability_id])
	for rule_id in content.get("environment_rules", []):
		if not valid_terrain.has(rule_id.get("terrain", "")) or not valid_terrain.has(rule_id.get("result", "")):
			errors.append("An environment rule has an invalid terrain reference")
		if rule_id.has("status") and not content.get("statuses", {}).has(rule_id.status):
			errors.append("An environment rule references unknown status %s" % rule_id.status)
	for rule_id in content.get("damage_rules", []):
		if not types.has(rule_id.get("damage", "")) or not content.get("statuses", {}).has(rule_id.get("target_status", "")):
			errors.append("A damage rule has an invalid damage or status reference")
	for trigger_id in content.get("triggers", {}):
		var rule: Dictionary = content.triggers[trigger_id]
		if not ["OnCast", "OnHit", "OnKill", "OnMove", "OnDamaged", "OnBlock", "OnDodge", "OnCrit", "OnDeath", "OnTurn", "OnSummon", "OnStatusApplied", "OnTerrainEntered", "OnResourceSpent", "OnHeal", "OnEncounterStart", "OnEncounterComplete"].has(rule.get("event", "")):
			errors.append("%s has an unknown trigger event" % trigger_id)
		if rule.get("owner_type", "") == "artifact" and not content.get("artifacts", {}).has(rule.get("owner_id", "")):
			errors.append("%s refers to an unknown artifact" % trigger_id)
		for effect in rule.get("effects", []):
			if effect.get("type") == "status" and not content.get("statuses", {}).has(effect.get("id", "")):
				errors.append("%s trigger applies an unknown status" % trigger_id)
			if effect.get("type") == "summon" and not content.get("enemies", {}).has(effect.get("id", "")) and not content.get("summons", {}).has(effect.get("id", "")):
				errors.append("%s trigger summons an unknown creature" % trigger_id)
	return errors

func _duplicate_json_keys(source: String) -> Array[String]:
	var duplicates: Array[String] = []
	var object_stack: Array[Dictionary] = []
	var in_string := false
	var escaped := false
	var string_start := -1
	for index in range(source.length()):
		var character := source.substr(index, 1)
		if in_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == "\"":
				in_string = false
				var next_index := index + 1
				while next_index < source.length() and source.substr(next_index, 1) in [" ", "\t", "\r", "\n"]:
					next_index += 1
				if not object_stack.is_empty() and next_index < source.length() and source.substr(next_index, 1) == ":":
					var key := String(JSON.parse_string(source.substr(string_start, index - string_start + 1)))
					var scope: Dictionary = object_stack.back()
					if scope.has(key):
						duplicates.append(key)
					else:
						scope[key] = true
		else:
			if character == "\"":
				in_string = true
				string_start = index
			elif character == "{":
				object_stack.append({})
			elif character == "}" and not object_stack.is_empty():
				object_stack.pop_back()
	return duplicates

func start_run(seed_value: int, character_id: String) -> bool:
	if not content.get("characters", {}).has(character_id):
		return false
	_rng.seed = seed_value
	var definition: Dictionary = content.characters[character_id]
	var equipment := {"Weapon": definition.weapon, "Offhand": "", "Head": "", "Body": "", "Hands": "", "Feet": "", "Ring 1": "", "Ring 2": "", "Amulet": ""}
	var inventory: Array = ["healing_potion", "mana_potion", "bomb", "fireball_scroll", "leather_armor"]
	if character_id == "jim":
		inventory.append("iron_shield")
	if content.weapons[definition.weapon].hands == 2:
		equipment["Offhand"] = "occupied"
	run = {
		"version": 1, "seed": seed_value, "rng_state": str(_rng.state), "character_id": character_id,
		"character": definition.name, "aura": definition.aura, "discipline": definition.discipline,
		"schools": definition.schools.duplicate(), "attributes": definition.attributes.duplicate(true),
		"entities": {}, "grid": [], "visible": [], "explored": [], "objects": [], "corpses": [],
		"equipment": equipment, "inventory": inventory, "artifacts": [], "known": definition.known.duplicate(),
		"temporary_abilities": {}, "xp": 0, "level": 1, "skill_points": 0, "kills": 0,
		"time": 0, "turn": 0, "stage_index": 0, "encounters_completed": 0,
		"stage_id": "", "objective": {}, "stage_completed": false, "reward_choices": [],
		"route_choices": [], "route": ["ruined_village"], "outcome": "", "log": ["The March stirs beyond the gate."],
		"fire_cast_count": 0, "living_kills": 0, "boss_summoned": false, "discovered_books": [], "trigger_counts": {}
	}
	var player := {"id": "player", "name": definition.name, "kind": "player", "faction": "Adventurers", "pos": [12, 8], "hp": definition.resources.Health[0], "max_hp": definition.resources.Health[1], "resources": definition.resources.duplicate(true), "statuses": {}, "next_time": 0, "footprint": 1, "armor": 0, "alive": true, "sight": 10}
	run.entities["player"] = player
	_new_stage("ruined_village", false)
	_save_codex()
	return true

func resume_run() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (parsed is Dictionary) or int(parsed.get("version", 0)) != 1:
		return false
	run = _canonicalize(parsed)
	_rng.seed = int(run.get("seed", 1))
	_rng.state = int(run.get("rng_state", "1"))
	return true

func save_run() -> bool:
	if run.is_empty():
		return false
	run["rng_state"] = str(_rng.state)
	run = _canonicalize(run)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(run))
	file.close()
	_save_codex()
	return true

func has_saved_run() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_saved_run() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func get_player() -> Dictionary:
	return run.get("entities", {}).get("player", {})

func get_stage_name() -> String:
	return content.get("stages", {}).get(run.get("stage_id", ""), {}).get("name", "Graveyard")

func get_objective_text() -> String:
	var objective: Dictionary = run.get("objective", {})
	var kind: String = objective.get("kind", "Eliminate")
	if kind == "Eliminate":
		return "Clear the hostile creatures"
	if kind == "Boss":
		return "Defeat the Grave Tyrant"
	if kind == "Survive":
		return "Hold the ground · %d / %d turns" % [mini(int(run.get("turn", 0)), int(objective.get("turns", 6))), int(objective.get("turns", 6))]
	if kind == "Reach Exit":
		return "Reach the March road exit"
	if kind == "Destroy Targets":
		return "Destroy the ritual wards · %d remain" % _remaining_wards()
	return kind

func get_timeline(count: int = 6) -> Array:
	var entries: Array = []
	for entity_id in run.get("entities", {}):
		var entity: Dictionary = run.entities[entity_id]
		if entity.get("alive", true):
			entries.append({"id": entity_id, "name": entity.get("name", "Creature"), "time": int(entity.get("next_time", 0)), "faction": entity.get("faction", ""), "kind": entity.get("kind", "enemy")})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.time == b.time:
			return a.id < b.id
		return a.time < b.time
	)
	return entries.slice(0, mini(count, entries.size()))

func get_visible_entities() -> Array:
	var result: Array = []
	for entity_id in run.get("entities", {}):
		var entity: Dictionary = run.entities[entity_id]
		if entity.get("alive", true) and (entity_id == "player" or _cell_visible(_pos(entity))):
			result.append(entity)
	return result

func get_enemy_at(cell: Vector2i) -> Dictionary:
	var found_id := _occupant(cell)
	if found_id == "" or found_id == "player":
		return {}
	var entity: Dictionary = run.entities[found_id]
	if not _is_hostile("player", found_id):
		return {}
	return entity

func act(command: Dictionary) -> Dictionary:
	if run.is_empty() or run.get("outcome", "") != "":
		return {"ok": false, "message": "There is no active encounter."}
	var result := {"ok": false, "message": "That action is not available."}
	match String(command.get("type", "")):
		"move": result = _player_move(_as_cell(command.get("target", [0, 0])))
		"attack": result = _player_attack(_as_cell(command.get("target", [0, 0])))
		"cast": result = _cast(String(command.get("id", "")), _as_cell(command.get("target", [0, 0])))
		"wait": result = _spend_player_time(100, "You wait and watch the battlefield.")
		"use_item": result = use_item(int(command.get("index", -1)), _as_cell(command.get("target", [0, 0])))
		"interact": result = _interact(_as_cell(command.get("target", [0, 0])))
	if result.get("ok", false):
		_update_vision()
		save_run()
	return result

func learn_ability(ability_id: String) -> bool:
	if run.is_empty() or not content.abilities.has(ability_id) or run.known.has(ability_id) or int(run.skill_points) <= 0:
		return false
	var definition: Dictionary = content.abilities[ability_id]
	if definition.get("discovery_required", false) and not run.schools.has(definition.get("school", "")):
		return false
	for requirement in definition.get("requires", []):
		if not run.known.has(requirement):
			return false
	if definition.get("school", "") in ["Fire", "Frost", "Storm", "Nature", "Arcane", "Holy", "Shadow"] and not run.schools.has(definition.school) and run.get("character_id") != "jim":
		return false
	run.known.append(ability_id)
	run.skill_points -= 1
	_record_codex("abilities", ability_id)
	_add_log("Learned %s." % definition.name)
	save_run()
	return true

func claim_reward(index: int) -> bool:
	if run.is_empty() or not run.get("stage_completed", false) or index < 0 or index >= run.reward_choices.size():
		return false
	var reward: Dictionary = run.reward_choices[index]
	if reward.get("claimed", false):
		return false
	if reward.get("type") == "artifact":
		_acquire_artifact(String(reward.id))
		reward.claimed = true
	else:
		if run.inventory.size() >= 30:
			_add_log("Your pack is full. Discard an item before claiming this.")
			return false
		run.inventory.append(String(reward.id))
		_add_log("Packed %s." % content.items[reward.id].name)
		reward.claimed = true
	save_run()
	return true

func choose_route(stage_id: String) -> bool:
	if run.is_empty() or not run.get("stage_completed", false) or not run.route_choices.has(stage_id):
		return false
	if run.stage_index >= 4:
		return false
	if run.route.is_empty():
		run.route.append(run.stage_id)
	run.route.append(stage_id)
	run.stage_index += 1
	_new_stage(stage_id, false)
	save_run()
	return true

func start_boss() -> bool:
	if run.is_empty() or not run.get("stage_completed", false) or int(run.stage_index) != 4:
		return false
	run.stage_index = 5
	if run.route.is_empty():
		run.route.append(run.stage_id)
	run.route.append("grave_tyrant")
	_new_stage("graveyard", true)
	save_run()
	return true

func equip_item(index: int) -> bool:
	if index < 0 or index >= run.inventory.size():
		return false
	var item_id: String = run.inventory[index]
	var item: Dictionary = content.items.get(item_id, {})
	if item.get("type") != "equipment":
		return false
	var slot: String = item.get("slot", "")
	var old_weapon: String = run.equipment.get("Weapon", "")
	if slot == "Offhand" and old_weapon != "" and content.weapons[old_weapon].hands == 2:
		run.inventory.append(old_weapon)
		run.equipment.Weapon = ""
		run.equipment.Offhand = ""
		if index >= run.inventory.size() - 1:
			index = run.inventory.find(item_id)
	if slot == "Weapon":
		var weapon_definition: Dictionary = content.weapons.get(item.get("weapon", ""), {})
		if weapon_definition.is_empty():
			return false
		if weapon_definition.get("hands", 1) == 2 and run.equipment.get("Offhand", "") not in ["", "occupied"]:
			var old_offhand: String = run.equipment.Offhand
			run.equipment.Offhand = ""
			run.inventory.remove_at(index)
			run.inventory.append(item_id)
			run.inventory.append(old_offhand)
			index = run.inventory.size() - 2
		elif run.equipment.get("Offhand", "") == "occupied":
			run.equipment.Offhand = ""
	elif not run.equipment.has(slot):
		return false
	var displaced: String = run.equipment.get(slot, "")
	if displaced not in ["", "occupied"]:
		run.inventory.append(displaced)
	run.equipment[slot] = item_id
	if slot == "Weapon":
		if content.weapons[item.weapon].hands == 2:
			run.equipment.Offhand = "occupied"
		elif run.equipment.get("Offhand", "") == "occupied":
			run.equipment.Offhand = ""
	run.inventory.remove_at(index)
	if old_weapon == "" and slot != "Weapon":
		pass
	_recompute_armor()
	_add_log("Equipped %s." % item.name)
	save_run()
	return true

func discard_item(index: int) -> bool:
	if index < 0 or index >= run.inventory.size():
		return false
	run.inventory.remove_at(index)
	save_run()
	return true

func study_spellbook(index: int, ability_index: int = 0) -> bool:
	if index < 0 or index >= run.inventory.size():
		return false
	var item_id: String = run.inventory[index]
	var book: Dictionary = content.items.get(item_id, {})
	if book.get("type") != "spellbook":
		return false
	if ability_index < 0 or ability_index >= book.get("learns", []).size():
		return false
	if not run.schools.has(book.school):
		run.schools.append(book.school)
	var ability_id: String = book.learns[ability_index]
	if not run.known.has(ability_id):
		run.known.append(ability_id)
	run.discovered_books.append(item_id)
	_record_codex("spellbooks", item_id)
	_record_codex("schools", book.school)
	_record_codex("abilities", ability_id)
	_add_log("The Lesser Key reveals %s." % content.abilities[ability_id].name)
	save_run()
	return true

func get_available_abilities() -> Array:
	var result: Array = []
	for ability_id in run.get("known", []):
		if content.abilities.has(ability_id):
			result.append(ability_id)
	return result

func get_summary() -> Dictionary:
	return {"character": run.get("character", ""), "level": run.get("level", 1), "kills": run.get("kills", 0), "encounters": run.get("encounters_completed", 0), "time": run.get("time", 0), "outcome": run.get("outcome", "")}

func state_digest() -> String:
	if run.is_empty():
		return ""
	var player: Dictionary = get_player()
	return JSON.stringify({"seed": run.seed, "stage": run.stage_id, "time": run.time, "player_pos": player.pos, "hp": player.hp, "mana": player.resources.Mana, "stamina": player.resources.Stamina, "entities": run.entities, "grid": run.grid, "objects": run.objects, "known": run.known, "xp": run.xp, "level": run.level, "objective": run.objective})

func _new_stage(stage_id: String, is_boss: bool) -> void:
	var player: Dictionary = run.entities.get("player", {})
	if player.is_empty():
		return
	var stage: Dictionary = content.stages[stage_id]
	run.stage_id = stage_id
	run.entities = {"player": player}
	player.pos = [12, 8]
	player.next_time = int(run.get("time", 0))
	player.alive = true
	player.statuses = {}
	var command: Array = player.resources.get("Command", [0, 0])
	command[0] = 0
	player.resources["Command"] = command
	var mana: Array = player.resources.Mana
	mana[0] = mini(int(mana[1]), int(mana[0]) + 6)
	player.resources.Mana = mana
	var stamina: Array = player.resources.Stamina
	stamina[0] = mini(int(stamina[1]), int(stamina[0]) + 15)
	player.resources.Stamina = stamina
	player.hp = mini(int(player.max_hp), int(player.hp) + 6)
	run.objects = []
	run.corpses = []
	run.objective = {}
	run.stage_completed = false
	run.reward_choices = []
	run.boss_summoned = false
	run.turn = 0
	var terrain: Dictionary = stage.terrain
	run.grid = []
	for y in range(HEIGHT):
		var row: Array = []
		for x in range(WIDTH):
			var tile := "floor"
			if x == 0 or y == 0 or x == WIDTH - 1 or y == HEIGHT - 1:
				tile = "wall"
			else:
				var roll := _rng.randf()
				if roll < float(terrain.get("wall", 0.08)):
					tile = "wall"
				elif roll < float(terrain.get("wall", 0.08)) + float(terrain.get("water", 0.02)):
					tile = "water"
				elif roll < float(terrain.get("wall", 0.08)) + float(terrain.get("water", 0.02)) + float(terrain.get("fire", 0.0)):
					tile = "fire"
				elif roll < float(terrain.get("wall", 0.08)) + float(terrain.get("water", 0.02)) + float(terrain.get("fire", 0.0)) + float(terrain.get("blood", 0.02)):
					tile = "blood"
				elif roll < float(terrain.get("wall", 0.08)) + float(terrain.get("water", 0.02)) + float(terrain.get("fire", 0.0)) + float(terrain.get("blood", 0.02)) + float(terrain.get("vegetation", 0.04)):
					tile = "vegetation"
			row.append(tile)
		run.grid.append(row)
	# A broad central lane keeps every seeded layout traversable while side terrain remains variable.
	for x in range(1, WIDTH - 1):
		_set_grid(Vector2i(x, 8), "floor")
		if x % 4 == 0:
			_set_grid(Vector2i(x, 7), "floor")
	_set_grid(Vector2i(3, 8), "floor")
	_set_grid(Vector2i(21, 8), "floor")
	run.visible = _bool_grid(false)
	run.explored = _bool_grid(false)
	var objective_kind: String = "Boss" if is_boss else stage.objectives[_rng.randi_range(0, stage.objectives.size() - 1)]
	if is_boss:
		run.objective = {"kind": "Boss", "turns": 0}
		_spawn_enemy("grave_tyrant", Vector2i(19, 7), true)
		_add_log("The Grave Tyrant rises from the barrow.")
	else:
		run.objective = {"kind": objective_kind, "turns": 6}
		if objective_kind == "Reach Exit":
			run.objects.append({"id": "road_exit", "kind": "exit", "name": "March Road", "pos": [21, 8], "hp": 1, "max_hp": 1})
		if objective_kind == "Destroy Targets":
			run.objects.append({"id": "ward_a", "kind": "ward", "name": "Ritual Ward", "pos": [17, 5], "hp": 15, "max_hp": 15})
			run.objects.append({"id": "ward_b", "kind": "ward", "name": "Ritual Ward", "pos": [18, 11], "hp": 15, "max_hp": 15})
		var enemy_count := 3 + mini(int(run.stage_index), 2)
		for i in range(enemy_count):
			var enemy_pool: Array = stage.enemies
			var enemy_id: String = enemy_pool[_rng.randi_range(0, enemy_pool.size() - 1)]
			var position := _find_spawn(Vector2i(15 + (i % 3) * 2, 5 + int(i / 3) * 5))
			_spawn_enemy(enemy_id, position, false)
		run.route_choices = _make_route_choices(stage_id)
		_add_log("%s: %s." % [stage.name, get_objective_text()])
	run.explored = _bool_grid(false)
	_update_vision()
	_record_codex("creatures", "")
	_save_codex()
	_emit_trigger("OnEncounterStart", {"stage_id": stage_id, "objective": objective_kind})

func _make_route_choices(current_stage: String) -> Array:
	var pool := STAGE_ORDER.duplicate()
	pool.erase(current_stage)
	var choices: Array = []
	while choices.size() < 2 and not pool.is_empty():
		var selected: String = pool[_rng.randi_range(0, pool.size() - 1)]
		pool.erase(selected)
		choices.append(selected)
	return choices

func _make_rewards() -> void:
	var candidates: Array = []
	for item_id in content.items:
		var item: Dictionary = content.items[item_id]
		if item_id in ["healing_potion", "mana_potion", "bomb", "fireball_scroll", "lesser_key_of_ash", "sword", "dagger", "greatsword", "spear", "bow", "crossbow", "staff", "wand", "iron_shield", "copper_ring"]:
			var weight := 1.0
			var tags: Array = item.get("tags", [])
			if tags.has("martial") and run.discipline == "Swordsmanship":
				weight += 1.4
			if run.get("schools", []).has(item.get("school", "")) or tags.has(String(item.get("school", "")).to_lower()):
				weight += 1.0
			candidates.append({"type": "item", "id": item_id, "weight": weight, "claimed": false})
	for artifact_id in content.artifacts:
		if not run.artifacts.has(artifact_id):
			candidates.append({"type": "artifact", "id": artifact_id, "weight": 0.55, "claimed": false})
	run.reward_choices = []
	for choice_index in range(3):
		if candidates.is_empty():
			break
		var total_weight := 0.0
		for candidate in candidates:
			total_weight += float(candidate.weight)
		var roll := _rng.randf() * total_weight
		var selected_index := 0
		for candidate_index in range(candidates.size()):
			roll -= float(candidates[candidate_index].weight)
			if roll <= 0.0:
				selected_index = candidate_index
				break
		var selected: Dictionary = candidates.pop_at(selected_index)
		selected.erase("weight")
		run.reward_choices.append(selected)

func _spawn_enemy(enemy_id: String, cell: Vector2i, is_boss: bool) -> String:
	var definition: Dictionary = content.enemies.get(enemy_id, {})
	if definition.is_empty():
		return ""
	var id := "%s_%03d" % [enemy_id, run.entities.size()]
	var entity := definition.duplicate(true)
	entity["id"] = id
	entity["enemy_id"] = enemy_id
	entity["kind"] = "boss" if is_boss else "enemy"
	entity["pos"] = [cell.x, cell.y]
	entity["max_hp"] = int(entity.get("hp", 20))
	entity["statuses"] = {}
	entity["next_time"] = int(run.get("time", 0)) + _rng.randi_range(45, 140)
	entity["alive"] = true
	entity["footprint"] = int(entity.get("footprint", 1))
	entity["is_summon"] = false
	entity["armor"] = int(entity.get("armor", 0))
	entity["sight"] = 8
	run.entities[id] = entity
	_record_codex("creatures", enemy_id)
	return id

func _spawn_summon(summon_id: String, cell: Vector2i) -> bool:
	var player: Dictionary = get_player()
	var definition: Dictionary = content.get("summons", {}).get(summon_id, {})
	if definition.is_empty():
		definition = content.get("enemies", {}).get(summon_id, {}).duplicate(true)
		definition["summon_behavior"] = definition.get("behavior", "melee")
	if definition.is_empty():
		return false
	var cost := int(definition.get("command", 1))
	var command: Array = player.resources.get("Command", [0, 0])
	if int(command[0]) + cost > int(command[1]):
		return false
	var spawn_at := cell
	if definition.get("ethereal", false):
		spawn_at = _pos(player)
	else:
		spawn_at = _find_spawn(cell)
		if spawn_at == Vector2i(-1, -1):
			return false
	var id := "%s_%03d" % [summon_id, run.entities.size()]
	var entity := definition.duplicate(true)
	entity["id"] = id
	entity["enemy_id"] = summon_id
	entity["kind"] = "summon"
	entity["faction"] = "Adventurers"
	entity["pos"] = [spawn_at.x, spawn_at.y]
	entity["max_hp"] = int(entity.get("hp", 18))
	entity["statuses"] = {}
	entity["next_time"] = int(get_player().get("next_time", 0)) + 35
	entity["alive"] = true
	entity["footprint"] = 1
	entity["is_summon"] = true
	entity["owner"] = "player"
	entity["command_cost"] = cost
	entity["sight"] = 8
	run.entities[id] = entity
	command[0] = int(command[0]) + cost
	player.resources["Command"] = command
	_emit_trigger("OnResourceSpent", {"entity_id": "player", "resource": "Command", "amount": cost})
	_add_log("%s answers the call." % entity.get("name", "A summon"))
	_emit_trigger("OnSummon", {"entity_id": id, "summon_id": summon_id, "owner": "player", "pos": [spawn_at.x, spawn_at.y]})
	return true

func _player_move(target: Vector2i) -> Dictionary:
	var player: Dictionary = get_player()
	if not _inside(target) or _terrain_at(target) == "wall":
		return {"ok": false, "message": "That path is blocked."}
	if _dist(_pos(player), target) == 0:
		return {"ok": false, "message": "You are already there."}
	var occupant := _occupant(target)
	if occupant != "" and _is_hostile("player", occupant):
		return _player_attack(target)
	var next_step := _next_step(_pos(player), target, "player")
	if next_step == _pos(player):
		return {"ok": false, "message": "No open path reaches that tile."}
	var previous_pos := _pos(player)
	var stamina: Array = player.resources.Stamina
	if int(stamina[0]) < 3:
		return {"ok": false, "message": "You need 3 Stamina to move."}
	stamina[0] = int(stamina[0]) - 3
	player.resources.Stamina = stamina
	player.pos = [next_step.x, next_step.y]
	_emit_trigger("OnMove", {"entity_id": "player", "from": [previous_pos.x, previous_pos.y], "pos": [next_step.x, next_step.y]})
	_emit_trigger("OnTerrainEntered", {"entity_id": "player", "terrain": _terrain_at(next_step), "pos": [next_step.x, next_step.y]})
	if _terrain_at(next_step) == "water":
		_apply_status("player", "Wet", 1)
	if _terrain_at(next_step) == "fire":
		_damage("player", 5, "Fire", "the burning ground")
	_add_log("%s steps across the field." % player.name)
	_check_objective_at_player()
	var move_time := maxi(1, int(round(100.0 * float(_artifact_modifier("move_time_multiplier", 1.0)))))
	return _spend_player_time(move_time, "")

func _player_attack(target: Vector2i) -> Dictionary:
	var player: Dictionary = get_player()
	var target_id := _occupant(target)
	if target_id == "" or not _is_hostile("player", target_id):
		var object_index := _object_index_at(target)
		if object_index >= 0 and run.objects[object_index].get("kind") == "ward":
			return _attack_object(object_index)
		return {"ok": false, "message": "Select a visible enemy or ritual ward."}
	var weapon_id: String = run.equipment.get("Weapon", "sword")
	var weapon: Dictionary = content.weapons.get(weapon_id, content.weapons.sword)
	var distance := _distance_to_entity(_pos(player), run.entities[target_id])
	if distance > int(weapon.range) or not _line_of_sight(_pos(player), target):
		return {"ok": false, "message": "That target is beyond your weapon's reach."}
	var stamina: Array = player.resources.Stamina
	if int(stamina[0]) < int(weapon.stamina):
		return {"ok": false, "message": "You need more Stamina for that attack."}
	stamina[0] = int(stamina[0]) - int(weapon.stamina)
	player.resources.Stamina = stamina
	var damage := int(weapon.damage) + int(run.attributes.get("Might", 10)) / 4
	if _has_status("player", "Empowered"):
		damage += 8
		run.entities.player.statuses.erase("Empowered")
	_damage(target_id, damage, String(weapon.get("type", "Slashing")), player.name)
	if weapon.get("style") == "cleave":
		for adjacent in run.entities.keys():
			if adjacent != target_id and adjacent != "player" and run.entities[adjacent].get("alive", true) and _is_hostile("player", adjacent) and _dist(_pos(run.entities[target_id]), _pos(run.entities[adjacent])) <= 1:
				_damage(adjacent, int(damage * 0.65), String(weapon.get("type", "Slashing")), player.name)
	var time_cost := int(weapon.time)
	if _has_status("player", "Haste"):
		time_cost = int(time_cost * 0.8)
	_add_log("%s strikes with %s." % [player.name, weapon.name])
	_check_objective()
	return _spend_player_time(time_cost, "")

func _attack_object(object_index: int) -> Dictionary:
	var player: Dictionary = get_player()
	var object: Dictionary = run.objects[object_index]
	if _dist(_pos(player), Vector2i(int(object.pos[0]), int(object.pos[1]))) > 1:
		return {"ok": false, "message": "Move closer to the ritual ward."}
	var weapon: Dictionary = content.weapons.get(run.equipment.get("Weapon", "sword"), content.weapons.sword)
	var stamina: Array = player.resources.Stamina
	if int(stamina[0]) < int(weapon.stamina):
		return {"ok": false, "message": "You need more Stamina."}
	stamina[0] -= int(weapon.stamina)
	player.resources.Stamina = stamina
	object.hp -= int(weapon.damage)
	_add_log("The %s cracks under your strike." % object.name)
	if object.hp <= 0:
		_add_log("A ritual ward crumbles.")
	_check_objective()
	return _spend_player_time(int(weapon.time), "")

func _cast(ability_id: String, target: Vector2i) -> Dictionary:
	if not content.abilities.has(ability_id):
		return {"ok": false, "message": "That ability is unknown."}
	var ability: Dictionary = content.abilities[ability_id]
	var player: Dictionary = get_player()
	var temporary := int(run.temporary_abilities.get(ability_id, 0)) > 0
	if not run.known.has(ability_id) and not temporary:
		return {"ok": false, "message": "You have not learned %s." % ability.name}
	if ability.get("school", "") == "Demonology" and not run.schools.has("Demonology"):
		return {"ok": false, "message": "You have not discovered Demonology."}
	var target_mode: String = ability.get("target", "enemy")
	var origin := _pos(player)
	if target_mode == "self":
		target = origin
	else:
		if not _inside(target) or _dist(origin, target) > int(ability.get("range", 0)):
			return {"ok": false, "message": "That target is outside the ability's reach."}
		if not _cell_visible(target) or not _line_of_sight(origin, target):
			return {"ok": false, "message": "You cannot see a clear path to that target."}
		if target_mode == "enemy":
			var enemy_id := _occupant(target)
			if enemy_id == "" or not _is_hostile("player", enemy_id):
				return {"ok": false, "message": "Choose a visible hostile creature."}
		if target_mode == "tile" and _terrain_at(target) == "wall":
			return {"ok": false, "message": "That tile is blocked."}
	if not _can_pay(ability.get("costs", {})):
		return {"ok": false, "message": "You do not have the resources for %s." % ability.name}
	_pay(ability.get("costs", {}))
	var targets: Array = _targets_for_ability(ability, target)
	for effect in ability.get("effects", []):
		_apply_effect(effect, target, targets, ability)
	if temporary:
		run.temporary_abilities[ability_id] = maxi(0, int(run.temporary_abilities[ability_id]) - 1)
	_emit_trigger("OnCast", {"ability_id": ability_id, "targets": targets, "center": [target.x, target.y], "school": ability.get("school", "")})
	var time_cost := int(ability.get("time", 100))
	if _has_status("player", "Haste"):
		time_cost = int(time_cost * 0.8)
	_add_log("%s casts %s." % [player.name, ability.name])
	_check_objective()
	return _spend_player_time(time_cost, "")

func _targets_for_ability(ability: Dictionary, center: Vector2i) -> Array:
	var target_mode: String = ability.get("target", "enemy")
	var result: Array = []
	if target_mode == "self":
		return ["player"]
	var radius := int(ability.get("radius", 0))
	if target_mode == "enemy" and radius == 0:
		var enemy_id := _occupant(center)
		return [enemy_id] if enemy_id != "" else []
	for entity_id in run.entities:
		var entity: Dictionary = run.entities[entity_id]
		if not entity.get("alive", true):
			continue
		if _distance_to_entity(center, entity) <= radius:
			result.append(entity_id)
	return result

func _apply_effect(effect: Dictionary, center: Vector2i, targets: Array, ability: Dictionary) -> void:
	var effect_type: String = effect.get("type", "")
	match effect_type:
		"damage":
			for target_id in targets:
				for repeat_index in range(int(effect.get("repeats", 1))):
					_damage(String(target_id), int(effect.get("amount", 0)), String(effect.get("damage", "Arcane")), ability.get("name", "magic"))
		"status":
			for target_id in targets:
				_apply_status(String(target_id), String(effect.get("id", "")), int(effect.get("stacks", 1)), String(ability.get("name", "")))
		"heal":
			var player := get_player()
			var health_before := int(player.hp)
			player.hp = mini(int(player.max_hp), int(player.hp) + int(effect.get("amount", 0)))
			if int(player.hp) > health_before:
				_emit_trigger("OnHeal", {"target_id": "player", "source": ability.get("name", "magic"), "amount": int(player.hp) - health_before})
		"heal_on_hit":
			if not targets.is_empty():
				var heal_amount := int(effect.get("amount", 0)) + int(_artifact_modifier("blood_lance_heal_bonus", 0.0))
				var player := get_player()
				var health_before := int(player.hp)
				player.hp = mini(int(player.max_hp), int(player.hp) + heal_amount)
				if int(player.hp) > health_before:
					_emit_trigger("OnHeal", {"target_id": "player", "source": ability.get("name", "magic"), "amount": int(player.hp) - health_before})
		"terrain":
			var radius := int(ability.get("radius", 0))
			for y in range(maxi(1, center.y - radius), mini(HEIGHT - 1, center.y + radius + 1)):
				for x in range(maxi(1, center.x - radius), mini(WIDTH - 1, center.x + radius + 1)):
					if _dist(center, Vector2i(x, y)) <= radius + 1:
						_transform_terrain(Vector2i(x, y), String(effect.get("id", "floor")))
		"teleport":
			if _terrain_at(center) != "wall" and _occupant(center, "player") == "":
				var previous_pos := _pos(get_player())
				get_player().pos = [center.x, center.y]
				_emit_trigger("OnMove", {"entity_id": "player", "from": [previous_pos.x, previous_pos.y], "pos": [center.x, center.y]})
				_emit_trigger("OnTerrainEntered", {"entity_id": "player", "terrain": _terrain_at(center), "pos": [center.x, center.y]})
		"move":
			var player := get_player()
			var steps := int(effect.get("distance", 1))
			while steps > 0:
				var previous_pos := _pos(player)
				var step := _next_step(_pos(player), center, "player")
				if step == _pos(player):
					break
				player.pos = [step.x, step.y]
				_emit_trigger("OnMove", {"entity_id": "player", "from": [previous_pos.x, previous_pos.y], "pos": [step.x, step.y]})
				_emit_trigger("OnTerrainEntered", {"entity_id": "player", "terrain": _terrain_at(step), "pos": [step.x, step.y]})
				steps -= 1
		"summon":
			var count := int(effect.get("count", 1))
			for summon_index in range(count):
				if not _spawn_summon(String(effect.get("id", "")), center):
					_add_log("Command or space is insufficient for the summon.")
		"resource":
			var resource_name: String = effect.get("id", "")
			var values: Array = get_player().resources.get(resource_name, [0, 0])
			values[0] = clampi(int(values[0]) + int(effect.get("amount", 0)), 0, int(values[1]))
			get_player().resources[resource_name] = values

func _interact(target: Vector2i) -> Dictionary:
	var object_index := _object_index_at(target)
	if object_index < 0:
		return {"ok": false, "message": "There is nothing to interact with here."}
	var object: Dictionary = run.objects[object_index]
	if object.get("kind") == "exit":
		if _dist(_pos(get_player()), target) > 1:
			return {"ok": false, "message": "Move beside the road exit first."}
		get_player().pos = [target.x, target.y]
		_check_objective_at_player()
		return _spend_player_time(60, "You reach the March road.")
	return {"ok": false, "message": "That object cannot be used yet."}

func use_item(index: int, target: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if index < 0 or index >= run.inventory.size():
		return {"ok": false, "message": "That pack slot is empty."}
	var item_id: String = run.inventory[index]
	var item: Dictionary = content.items.get(item_id, {})
	if item.get("type") == "spellbook":
		return {"ok": false, "message": "Inspect the book and choose a spell to study."}
	if item.get("type") == "equipment":
		return {"ok": false, "message": "Equipment must be equipped from the inventory."}
	match String(item.get("effect", "")):
		"heal":
			var player := get_player()
			var health_before := int(player.hp)
			player.hp = mini(int(player.max_hp), int(player.hp) + int(item.amount))
			if int(player.hp) > health_before:
				_emit_trigger("OnHeal", {"target_id": "player", "source": item.name, "amount": int(player.hp) - health_before})
			_add_log("The Healing Draught restores your strength.")
		"mana":
			var mana: Array = get_player().resources.Mana
			mana[0] = mini(int(mana[1]), int(mana[0]) + int(item.amount))
			get_player().resources.Mana = mana
		"bomb":
			if target.x < 0:
				return {"ok": false, "message": "Choose a visible target for the bomb."}
			if _dist(_pos(get_player()), target) > 5 or not _cell_visible(target):
				return {"ok": false, "message": "That target is too far away."}
			for entity_id in run.entities.keys():
				if entity_id != "player" and run.entities[entity_id].get("alive", true) and _dist(_pos(run.entities[entity_id]), target) <= 1:
					_damage(entity_id, int(item.amount), "Fire", "the Cinder Bomb")
			_transform_terrain(target, "fire")
		"":
			if item.get("type") == "scroll":
				var ability_id: String = item.get("ability", "")
				run.temporary_abilities[ability_id] = int(run.temporary_abilities.get(ability_id, 0)) + 1
				var cast_result := _cast(ability_id, target)
				if not cast_result.get("ok", false):
					run.temporary_abilities[ability_id] = maxi(0, int(run.temporary_abilities[ability_id]) - 1)
					return cast_result
				run.inventory.remove_at(index)
				save_run()
				return cast_result
			return {"ok": false, "message": "That item cannot be used."}
	run.inventory.remove_at(index)
	var result := _spend_player_time(70, "")
	_update_vision()
	save_run()
	return result

func _can_pay(costs: Dictionary) -> bool:
	var player: Dictionary = get_player()
	for resource_id in costs:
		var values: Array = player.resources.get(resource_id, [0, 0])
		var amount := int(costs[resource_id])
		if resource_id == "Command":
			if int(values[0]) + amount > int(values[1]):
				return false
		elif resource_id == "Health":
			if int(values[0]) <= amount:
				return false
		elif int(values[0]) < amount:
			return false
	return true

func _pay(costs: Dictionary) -> void:
	var player: Dictionary = get_player()
	for resource_id in costs:
		var values: Array = player.resources[resource_id]
		if resource_id == "Command":
			continue
		values[0] = int(values[0]) - int(costs[resource_id])
		player.resources[resource_id] = values
		_emit_trigger("OnResourceSpent", {"entity_id": "player", "resource": resource_id, "amount": int(costs[resource_id])})

func _spend_player_time(cost: int, message: String) -> Dictionary:
	var player: Dictionary = get_player()
	var previous_time := int(player.next_time)
	var action_time := maxi(1, cost)
	if _has_status("player", "Slow"):
		action_time = int(action_time * 1.3)
	player.next_time = previous_time + action_time
	var safety := 0
	while safety < 1000:
		safety += 1
		var next_actor := _next_scheduled_actor()
		if next_actor == "" or int(run.entities[next_actor].next_time) > int(player.next_time):
			break
		var actor: Dictionary = run.entities[next_actor]
		run.time = int(actor.next_time)
		_tick_statuses(next_actor)
		if actor.get("alive", true):
			if _has_status(next_actor, "Frozen") or _has_status(next_actor, "Stunned"):
				_add_log("%s loses the moment." % actor.get("name", "A creature"))
			else:
				_enemy_turn(next_actor)
		if actor.get("alive", false):
			var actor_time := int(actor.get("time", 100))
			if _has_status(next_actor, "Haste"):
				actor_time = int(actor_time * 0.8)
			if _has_status(next_actor, "Slow"):
				actor_time = int(actor_time * 1.3)
			actor.next_time = int(actor.next_time) + maxi(35, actor_time)
			_check_objective()
		if run.get("outcome", "") != "" or _player_dead():
			break
		run.entities[next_actor] = actor
	if safety >= 1000:
		_add_log("The timeline paused after an unusually long chain of turns.")
	var elapsed := maxi(1, int(player.next_time) - previous_time)
	run.time = int(player.next_time)
	run.turn = int(run.get("turn", 0)) + 1
	_regenerate(elapsed)
	_tick_statuses("player")
	if message != "":
		_add_log(message)
	_check_objective()
	if _player_dead():
		run.outcome = "defeat"
		_add_log("The March closes over you.")
	if run.get("outcome", "") == "" and run.get("objective", {}).get("kind") == "Survive" and int(run.turn) >= int(run.objective.turns):
		_complete_stage()
	return {"ok": true, "message": ""}

func _next_scheduled_actor() -> String:
	var selected := ""
	for entity_id in run.entities:
		if entity_id == "player":
			continue
		var entity: Dictionary = run.entities[entity_id]
		if not entity.get("alive", true):
			continue
		if selected == "" or int(entity.next_time) < int(run.entities[selected].next_time) or (int(entity.next_time) == int(run.entities[selected].next_time) and entity_id < selected):
			selected = entity_id
	return selected

func _enemy_turn(actor_id: String) -> void:
	if not run.entities.has(actor_id) or not run.entities[actor_id].get("alive", true):
		return
	var actor: Dictionary = run.entities[actor_id]
	_emit_trigger("OnTurn", {"entity_id": actor_id, "faction": actor.get("faction", "")})
	var target_id := _choose_target(actor_id)
	if target_id == "":
		return
	var target: Dictionary = run.entities[target_id]
	var origin := _pos(actor)
	var target_pos := _pos(target)
	var distance := _distance_to_entity(origin, target)
	var behavior: String = actor.get("summon_behavior", actor.get("behavior", "melee"))
	if behavior == "boss":
		_enemy_boss_action(actor_id, target_id)
		return
	if behavior == "orbit_assault":
		if distance <= int(actor.get("range", 5)) and _line_of_sight(origin, target_pos):
			_damage(target_id, int(actor.get("damage", 8)), String(actor.get("damage_type", "Arcane")), actor.name)
			_add_log("The Phantom Blade darts at %s." % target.name)
		else:
			var owner_id: String = actor.get("owner", "player")
			if run.entities.has(owner_id):
				var step := _next_step(origin, _pos(run.entities[owner_id]), actor_id)
				if step != origin:
					actor.pos = [step.x, step.y]
		return
	var attack_range := int(actor.get("range", 1))
	if behavior == "melee":
		attack_range = 1
	if distance <= attack_range and _line_of_sight(origin, target_pos):
		var attack_damage := int(actor.get("damage", 5))
		_damage(target_id, attack_damage, String(actor.get("damage_type", "Blunt")), actor.name)
		if actor.get("damage_type") == "Fire" and _rng.randf() < 0.2:
			_apply_status(target_id, "Burning", 1, String(actor.get("name", "")))
		_add_log("%s attacks %s." % [actor.name, target.name])
		return
	if behavior == "summoner" and not bool(run.get("boss_summoned", false)):
		var spawn_at := _find_spawn(origin + Vector2i(1, 0))
		if spawn_at != Vector2i(-1, -1):
			_spawn_enemy("skeleton", spawn_at, false)
			_add_log("%s raises a skeleton." % actor.name)
			return
	if behavior == "ranged" or behavior == "caster":
		if distance <= 2:
			var retreat := _retreat_step(origin, target_pos, actor_id)
			if retreat != origin:
				var previous_pos := _pos(actor)
				actor.pos = [retreat.x, retreat.y]
				_emit_trigger("OnMove", {"entity_id": actor_id, "from": [previous_pos.x, previous_pos.y], "pos": [retreat.x, retreat.y]})
				_emit_trigger("OnTerrainEntered", {"entity_id": actor_id, "terrain": _terrain_at(retreat), "pos": [retreat.x, retreat.y]})
				return
	var step := _next_step(origin, target_pos, actor_id)
	if step != origin:
		actor.pos = [step.x, step.y]
		_emit_trigger("OnMove", {"entity_id": actor_id, "from": [origin.x, origin.y], "pos": [step.x, step.y]})
		_emit_trigger("OnTerrainEntered", {"entity_id": actor_id, "terrain": _terrain_at(step), "pos": [step.x, step.y]})
		if _terrain_at(step) == "water":
			_apply_status(actor_id, "Wet", 1)
		else:
			_add_log("%s advances." % actor.name)

func _enemy_boss_action(actor_id: String, target_id: String) -> void:
	var boss: Dictionary = run.entities[actor_id]
	var target: Dictionary = run.entities[target_id]
	var turn_count := int(boss.get("boss_turn", 0)) + 1
	boss.boss_turn = turn_count
	if turn_count % 3 == 0:
		var target_pos := _pos(target)
		_transform_terrain(target_pos, "blood")
		var minion_count := 0
		for entity_id in run.entities:
			var entity: Dictionary = run.entities[entity_id]
			if entity.get("alive", true) and entity.get("enemy_id") == "skeleton" and _is_hostile(actor_id, entity_id):
				minion_count += 1
		if minion_count < 3:
			var spawn_at := _find_spawn(_pos(boss) + Vector2i(2, 1))
			if spawn_at != Vector2i(-1, -1):
				_spawn_enemy("skeleton", spawn_at, false)
				_add_log("The Grave Tyrant hauls a skeleton from the soil.")
		else:
			_apply_status(target_id, "Bleeding", 1, boss.name)
			_add_log("The barrow splits beneath you.")
		return
	var distance := _distance_to_entity(_pos(boss), target)
	if distance <= 1:
		_damage(target_id, int(boss.damage), String(boss.damage_type), boss.name)
		_add_log("The Grave Tyrant strikes with a tombstone fist.")
	else:
		var step := _next_step(_pos(boss), _pos(target), actor_id)
		if step != _pos(boss):
			var previous_pos := _pos(boss)
			boss.pos = [step.x, step.y]
			_emit_trigger("OnMove", {"entity_id": actor_id, "from": [previous_pos.x, previous_pos.y], "pos": [step.x, step.y]})
			_emit_trigger("OnTerrainEntered", {"entity_id": actor_id, "terrain": _terrain_at(step), "pos": [step.x, step.y]})
			_add_log("The Grave Tyrant lumbers closer.")

func _choose_target(actor_id: String) -> String:
	var actor: Dictionary = run.entities[actor_id]
	var selected := ""
	var best_distance := 999
	for candidate_id in run.entities:
		if candidate_id == actor_id or not run.entities[candidate_id].get("alive", true) or not _is_hostile(actor_id, candidate_id):
			continue
		var candidate: Dictionary = run.entities[candidate_id]
		var distance := _distance_to_entity(_pos(actor), candidate)
		if distance > int(actor.get("sight", 8)) or not _line_of_sight(_pos(actor), _pos(candidate)):
			continue
		if distance < best_distance or (distance == best_distance and candidate_id < selected):
			selected = candidate_id
			best_distance = distance
	return selected

func _damage(target_id: String, raw_amount: int, damage_type: String, source: String) -> void:
	if not run.entities.has(target_id) or not run.entities[target_id].get("alive", true):
		return
	var target: Dictionary = run.entities[target_id]
	var amount := maxi(0, raw_amount)
	for rule in content.get("damage_rules", []):
		if rule.get("damage") == damage_type and _has_status(target_id, String(rule.get("target_status", ""))):
			amount = int(ceil(float(amount) * float(rule.get("multiplier", 1.0))))
			if rule.get("message", "") != "":
				_add_log(String(rule.message))
	var resistance: float = float(target.get("resist", {}).get(damage_type, 0.0))
	var vulnerability: float = float(target.get("vulnerable", {}).get(damage_type, 0.0))
	if resistance >= 1.0:
		amount = 0
	else:
		amount = maxi(0, int(round(float(amount) * (1.0 - resistance + vulnerability))))
	if int(target.get("armor", 0)) > 0 and damage_type in ["Slashing", "Piercing", "Blunt"]:
		amount = maxi(1, amount - int(target.armor))
	if _has_status(target_id, "Guard"):
		amount = int(ceil(float(amount) * 0.5))
		target.statuses.erase("Guard")
	target.hp = int(target.get("hp", 0)) - amount
	_emit_trigger("OnHit", {"target_id": target_id, "source": source, "amount": amount, "damage_type": damage_type})
	_emit_trigger("OnDamaged", {"target_id": target_id, "source": source, "amount": amount, "damage_type": damage_type})
	if target_id == "player":
		_add_log("%s deals %d damage." % [source, amount])
	else:
		_add_log("%s takes %d damage." % [target.get("name", "A creature"), amount])
	if int(target.hp) <= 0:
		_on_death(target_id, source)

func _on_death(entity_id: String, source: String) -> void:
	var entity: Dictionary = run.entities[entity_id]
	if not entity.get("alive", true):
		return
	entity.alive = false
	_emit_trigger("OnDeath", {"entity_id": entity_id, "faction": entity.get("faction", ""), "source": source, "pos": entity.get("pos", []).duplicate()})
	if entity_id == "player":
		entity.hp = 0
		return
	if entity.get("is_summon", false):
		var command: Array = get_player().resources.get("Command", [0, 0])
		command[0] = maxi(0, int(command[0]) - int(entity.get("command_cost", 1)))
		get_player().resources["Command"] = command
	else:
		var corpse_pos: Array = entity.pos.duplicate()
		run.corpses.append({"pos": corpse_pos, "faction": entity.faction, "name": entity.name})
		if entity.faction not in ["Undead", "Demons"]:
			_set_grid(_pos(entity), "blood")
		if _is_hostile("player", entity_id) and _is_player_source(source):
			run.kills = int(run.kills) + 1
			_award_xp(int(entity.get("xp", 10)))
			if entity.faction in ["Adventurers", "Beasts", "Goblinoids", "Bandits"]:
				run.living_kills = int(run.living_kills) + 1
			_emit_trigger("OnKill", {"entity_id": entity_id, "faction": entity.faction, "pos": entity.pos.duplicate()})
	_add_log("%s falls." % entity.get("name", "A creature"))
	if entity.get("kind") == "boss":
		run.outcome = "victory"
		_complete_stage()
		_add_log("The Grave Tyrant is defeated. The March is yours.")
	_check_objective()

func _award_xp(amount: int) -> void:
	run.xp = int(run.xp) + amount
	while int(run.xp) >= int(run.level) * 35:
		run.xp = int(run.xp) - int(run.level) * 35
		run.level = int(run.level) + 1
		run.skill_points = int(run.skill_points) + 1
		var player := get_player()
		player.max_hp = int(player.max_hp) + 2
		player.hp = mini(int(player.max_hp), int(player.hp) + 2)
		_add_log("Level %d · a new ability point is ready." % run.level)

func _is_player_source(source: String) -> bool:
	if source in [String(get_player().get("name", "")), "Cinder Bomb", "the Ossuary Bell", "Phantom Blade"]:
		return true
	for ability_id in content.get("abilities", {}):
		if content.abilities[ability_id].get("name", "") == source:
			return true
	return false

func _apply_status(entity_id: String, status_id: String, stacks: int, source: String = "") -> void:
	if not run.entities.has(entity_id) or not run.entities[entity_id].get("alive", true):
		return
	var definition: Dictionary = content.get("statuses", {}).get(status_id, {"max_stacks": 1, "duration": 1})
	var statuses: Dictionary = run.entities[entity_id].get("statuses", {})
	var current: Dictionary = statuses.get(status_id, {"stacks": 0, "duration": 0})
	current.stacks = mini(int(definition.get("max_stacks", 1)), int(current.get("stacks", 0)) + stacks)
	current.duration = maxi(int(current.get("duration", 0)), int(definition.get("duration", 1)))
	if source != "":
		current.source = source
	statuses[status_id] = current
	run.entities[entity_id].statuses = statuses
	_emit_trigger("OnStatusApplied", {"entity_id": entity_id, "status": status_id, "stacks": stacks, "source": source})

func _tick_statuses(entity_id: String) -> void:
	if not run.entities.has(entity_id) or not run.entities[entity_id].get("alive", true):
		return
	var entity: Dictionary = run.entities[entity_id]
	var statuses: Dictionary = entity.get("statuses", {})
	for status_id in statuses.keys():
		var status: Dictionary = statuses[status_id]
		var definition: Dictionary = content.get("statuses", {}).get(status_id, {})
		var tick_damage := int(definition.get("tick_damage", 0)) * int(status.get("stacks", 1))
		if tick_damage > 0:
			_damage(entity_id, tick_damage, String(definition.get("damage", "Arcane")), String(status.get("source", status_id)))
		if not run.entities[entity_id].get("alive", true):
			return
		status.duration = int(status.get("duration", 0)) - 1
		if int(status.duration) <= 0:
			statuses.erase(status_id)
		else:
			statuses[status_id] = status
	entity.statuses = statuses

func _has_status(entity_id: String, status_id: String) -> bool:
	return run.entities.has(entity_id) and run.entities[entity_id].get("statuses", {}).has(status_id)

func _regenerate(elapsed: int) -> void:
	var player: Dictionary = get_player()
	var mana: Array = player.resources.Mana
	var stamina: Array = player.resources.Stamina
	mana[0] = mini(int(mana[1]), int(mana[0]) + int(elapsed / 180))
	stamina[0] = mini(int(stamina[1]), int(stamina[0]) + int(elapsed / 55) * 2)
	player.resources.Mana = mana
	player.resources.Stamina = stamina
	var blood: Array = player.resources.get("Blood", [0, 0])
	blood[0] = mini(int(blood[1]), int(blood[0]) + int(elapsed / 160))
	player.resources["Blood"] = blood

func _check_objective() -> void:
	if run.get("stage_completed", false) or run.get("outcome", "") != "":
		return
	var objective: Dictionary = run.get("objective", {})
	if objective.get("kind") == "Eliminate" and _hostile_count() == 0:
		_complete_stage()
	elif objective.get("kind") == "Destroy Targets" and _remaining_wards() == 0:
		_complete_stage()
	elif objective.get("kind") == "Boss":
		var boss_alive := false
		for entity_id in run.entities:
			if run.entities[entity_id].get("kind") == "boss" and run.entities[entity_id].get("alive", false):
				boss_alive = true
		if not boss_alive:
			_complete_stage()

func _check_objective_at_player() -> void:
	if run.get("objective", {}).get("kind") != "Reach Exit":
		return
	var exit_index := -1
	for index in range(run.objects.size()):
		if run.objects[index].get("kind") == "exit":
			exit_index = index
			break
	if exit_index >= 0 and _pos(get_player()) == Vector2i(int(run.objects[exit_index].pos[0]), int(run.objects[exit_index].pos[1])):
		_complete_stage()

func _complete_stage() -> void:
	if run.get("stage_completed", false):
		return
	run.stage_completed = true
	run.encounters_completed = int(run.encounters_completed) + 1
	_add_log("Objective complete. You can keep exploring before you leave.")
	_make_rewards()
	_emit_trigger("OnEncounterComplete", {"stage_id": run.stage_id, "objective": run.objective.get("kind", "")})
	if run.get("outcome", "") == "victory":
		return

func _remaining_wards() -> int:
	var count := 0
	for object in run.get("objects", []):
		if object.get("kind") == "ward" and int(object.get("hp", 0)) > 0:
			count += 1
	return count

func _hostile_count() -> int:
	var count := 0
	for entity_id in run.entities:
		if entity_id != "player" and run.entities[entity_id].get("alive", true) and _is_hostile("player", entity_id):
			count += 1
	return count

func _acquire_artifact(artifact_id: String) -> void:
	if not content.artifacts.has(artifact_id) or run.artifacts.has(artifact_id):
		return
	run.artifacts.append(artifact_id)
	_record_codex("artifacts", artifact_id)
	var player := get_player()
	var acquisition: Dictionary = content.artifacts[artifact_id].get("on_acquire", {})
	player.max_hp = maxi(1, int(player.max_hp) + int(acquisition.get("max_health", 0)))
	player.hp = mini(int(player.hp), int(player.max_hp))
	if int(acquisition.get("command_capacity", 0)) != 0:
		var command: Array = player.resources.Command
		command[1] = maxi(0, int(command[1]) + int(acquisition.command_capacity))
		player.resources.Command = command
	for resource_id in acquisition.get("resources", {}):
		var values: Array = player.resources.get(resource_id, [0, 0])
		values[1] = maxi(0, int(values[1]) + int(acquisition.resources[resource_id]))
		player.resources[resource_id] = values
	_add_log("You claim %s." % content.artifacts[artifact_id].name)

func _transform_terrain(cell: Vector2i, target: String) -> void:
	if not _inside(cell):
		return
	var old := _terrain_at(cell)
	var result := target.to_lower()
	if old == "wall":
		return
	for rule in content.get("environment_rules", []):
		if rule.get("terrain") == old and rule.get("effect") == target:
			result = String(rule.get("result", result))
			var occupant := _occupant(cell)
			if occupant != "" and rule.has("status"):
				_apply_status(occupant, String(rule.status), 1)
			if rule.get("message", "") != "":
				_add_log(String(rule.message))
			break
	_set_grid(cell, result)

func _recompute_armor() -> void:
	var total := 0
	for slot in run.equipment:
		var item_id: String = run.equipment[slot]
		if item_id == "" or item_id == "occupied":
			continue
		total += int(content.items.get(item_id, {}).get("armor", 0))
	get_player().armor = total

func _find_spawn(preferred: Vector2i) -> Vector2i:
	var candidates := [preferred]
	for radius in range(1, 5):
		for y in range(maxi(1, preferred.y - radius), mini(HEIGHT - 1, preferred.y + radius + 1)):
			for x in range(maxi(1, preferred.x - radius), mini(WIDTH - 1, preferred.x + radius + 1)):
				if maxi(abs(x - preferred.x), abs(y - preferred.y)) == radius:
					candidates.append(Vector2i(x, y))
	for cell in candidates:
		if _inside(cell) and _terrain_at(cell) != "wall" and _occupant(cell) == "":
			return cell
	return Vector2i(-1, -1)

func _next_step(start: Vector2i, target: Vector2i, mover_id: String) -> Vector2i:
	if start == target:
		return start
	var candidates: Array[Vector2i] = []
	if _occupant(target, mover_id) == "" and _terrain_at(target) != "wall":
		candidates.append(target)
	else:
		for direction in DIRECTIONS:
			var adjacent: Vector2i = target + direction
			if _inside(adjacent) and _terrain_at(adjacent) != "wall" and _occupant(adjacent, mover_id) == "":
				candidates.append(adjacent)
	if candidates.is_empty():
		return start
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _dist(start, a) < _dist(start, b))
	var goal: Vector2i = candidates[0]
	var queue: Array[Vector2i] = [start]
	var previous := {_cell_key(start): _cell_key(start)}
	var visited := 0
	while not queue.is_empty() and visited < WIDTH * HEIGHT:
		var current: Vector2i = queue.pop_front()
		visited += 1
		if current == goal:
			break
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			var key := _cell_key(next)
			if not _inside(next) or previous.has(key) or _terrain_at(next) == "wall" or _occupant(next, mover_id) != "":
				continue
			previous[key] = _cell_key(current)
			queue.append(next)
	if not previous.has(_cell_key(goal)):
		return start
	var step := goal
	while previous[_cell_key(step)] != _cell_key(start) and step != start:
		step = _key_cell(String(previous[_cell_key(step)]))
	return step

func _retreat_step(start: Vector2i, threat: Vector2i, mover_id: String) -> Vector2i:
	var best := start
	var best_distance := _dist(start, threat)
	for direction in DIRECTIONS:
		var candidate: Vector2i = start + direction
		if not _inside(candidate) or _terrain_at(candidate) == "wall" or _occupant(candidate, mover_id) != "":
			continue
		var distance := _dist(candidate, threat)
		if distance > best_distance and _line_of_sight(candidate, threat):
			best = candidate
			best_distance = distance
	return best

func _occupant(cell: Vector2i, ignore_id: String = "") -> String:
	for entity_id in run.get("entities", {}):
		if entity_id == ignore_id:
			continue
		var entity: Dictionary = run.entities[entity_id]
		if not entity.get("alive", true) or entity.get("ethereal", false):
			continue
		var pos := _pos(entity)
		var size := int(entity.get("footprint", 1))
		if cell.x >= pos.x and cell.y >= pos.y and cell.x < pos.x + size and cell.y < pos.y + size:
			return entity_id
	return ""

func _object_index_at(cell: Vector2i) -> int:
	for index in range(run.get("objects", []).size()):
		var object: Dictionary = run.objects[index]
		if Vector2i(int(object.pos[0]), int(object.pos[1])) == cell and int(object.get("hp", 1)) > 0:
			return index
	return -1

func _distance_to_entity(from: Vector2i, entity: Dictionary) -> int:
	var pos := _pos(entity)
	var size := int(entity.get("footprint", 1))
	var dx := maxi(maxi(pos.x - from.x, 0), from.x - (pos.x + size - 1))
	var dy := maxi(maxi(pos.y - from.y, 0), from.y - (pos.y + size - 1))
	return maxi(dx, dy)

func _is_hostile(a_id: String, b_id: String) -> bool:
	if a_id == b_id or not run.entities.has(a_id) or not run.entities.has(b_id):
		return false
	var a_faction: String = run.entities[a_id].get("faction", "")
	var b_faction: String = run.entities[b_id].get("faction", "")
	if a_faction == b_faction:
		return false
	return true

func _line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var x0 := from.x
	var y0 := from.y
	var x1 := to.x
	var y1 := to.y
	var dx: int = abs(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -abs(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var error: int = dx + dy
	while true:
		if Vector2i(x0, y0) != from and Vector2i(x0, y0) != to and _terrain_at(Vector2i(x0, y0)) == "wall":
			return false
		if x0 == x1 and y0 == y1:
			return true
		var twice: int = 2 * error
		if twice >= dy:
			error += dy
			x0 += sx
		if twice <= dx:
			error += dx
			y0 += sy
	return true

func _update_vision() -> void:
	if run.is_empty() or run.get("visible", []).is_empty():
		return
	var player_pos := _pos(get_player())
	var sight := int(get_player().get("sight", 7))
	if int(_artifact_modifier("low_health_sight_bonus", 0.0)) > 0 and int(get_player().hp) * 2 < int(get_player().max_hp):
		sight += int(_artifact_modifier("low_health_sight_bonus", 0.0))
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell := Vector2i(x, y)
			var visible := _dist(player_pos, cell) <= sight and _line_of_sight(player_pos, cell)
			run.visible[y][x] = visible
			if visible:
				run.explored[y][x] = true

func _cell_visible(cell: Vector2i) -> bool:
	return _inside(cell) and not run.get("visible", []).is_empty() and bool(run.visible[cell.y][cell.x])

func _terrain_at(cell: Vector2i) -> String:
	if not _inside(cell) or run.get("grid", []).is_empty():
		return "wall"
	return String(run.grid[cell.y][cell.x])

func _set_grid(cell: Vector2i, terrain: String) -> void:
	if _inside(cell) and not run.get("grid", []).is_empty():
		run.grid[cell.y][cell.x] = terrain

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < WIDTH and cell.y < HEIGHT

func _bool_grid(value: bool) -> Array:
	var result: Array = []
	for y in range(HEIGHT):
		var row: Array = []
		for x in range(WIDTH):
			row.append(value)
		result.append(row)
	return result

func _is_player_dead() -> bool:
	return int(get_player().get("hp", 0)) <= 0

func _player_dead() -> bool:
	return not get_player().get("alive", true) or int(get_player().get("hp", 0)) <= 0

func _pos(entity: Dictionary) -> Vector2i:
	var position: Array = entity.get("pos", [0, 0])
	return Vector2i(int(position[0]), int(position[1]))

func _as_cell(value) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)

func _dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _key_cell(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func _add_log(message: String) -> void:
	if message == "":
		return
	var log: Array = run.get("log", [])
	log.append(message)
	while log.size() > 7:
		log.pop_front()
	run.log = log

func _record_codex(category: String, value: String) -> void:
	if value == "" or not codex.has(category):
		return
	if not codex[category].has(value):
		codex[category].append(value)

func _artifact_modifier(modifier_id: String, default_value: float) -> float:
	var total := 0.0
	var found := false
	for artifact_id in run.get("artifacts", []):
		var modifiers: Dictionary = content.artifacts.get(artifact_id, {}).get("modifiers", {})
		if modifiers.has(modifier_id):
			total += float(modifiers[modifier_id])
			found = true
	return total if found else default_value

func _emit_trigger(event_id: String, context: Dictionary) -> void:
	for trigger_id in content.get("triggers", {}):
		var rule: Dictionary = content.triggers[trigger_id]
		if rule.get("event") != event_id:
			continue
		var owner_type: String = rule.get("owner_type", "")
		var owner_id: String = rule.get("owner_id", "")
		if owner_type == "aura" and run.get("aura", "") != owner_id:
			continue
		if owner_type == "artifact" and not run.get("artifacts", []).has(owner_id):
			continue
		if owner_type == "ability" and not run.get("known", []).has(owner_id):
			continue
		var condition: Dictionary = rule.get("condition", {})
		if condition.has("school") and context.get("school", "") != condition.school:
			continue
		if condition.has("school_not") and context.get("school", "") == condition.school_not:
			continue
		if condition.has("faction_in") and not condition.faction_in.has(context.get("faction", "")):
			continue
		var every := int(condition.get("every", 1))
		if every > 1:
			var counts: Dictionary = run.get("trigger_counts", {})
			counts[trigger_id] = int(counts.get(trigger_id, 0)) + 1
			run.trigger_counts = counts
			if int(counts[trigger_id]) % every != 0:
				continue
		for effect in rule.get("effects", []):
			match String(effect.get("type", "")):
				"status":
					_apply_status(String(effect.get("target", "player")), String(effect.get("id", "")), int(effect.get("stacks", 1)), String(rule.get("source", "")))
				"repeat_cast_damage":
					var ability_id: String = context.get("ability_id", "")
					if content.abilities.has(ability_id):
						for ability_effect in content.abilities[ability_id].get("effects", []):
							if ability_effect.get("type") != "damage":
								continue
							for target_id in context.get("targets", []):
								_damage(String(target_id), int(round(float(ability_effect.amount) * float(effect.get("multiplier", 0.5)))), String(ability_effect.damage), String(rule.get("source", owner_id)))
					if rule.get("message", "") != "":
						_add_log(String(rule.message))
				"summon":
					var location := Vector2i(int(context.pos[0]), int(context.pos[1]))
					if _spawn_summon(String(effect.get("id", "")), location) and rule.get("message", "") != "":
						_add_log(String(rule.message))

func _load_codex() -> void:
	if not FileAccess.file_exists(CODEX_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CODEX_PATH))
	if parsed is Dictionary:
		for key in codex:
			codex[key] = parsed.get(key, []).duplicate()

func _save_codex() -> void:
	var file := FileAccess.open(CODEX_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(codex))
		file.close()

func _canonicalize(value):
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			result[key] = _canonicalize(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(_canonicalize(entry))
		return result
	if typeof(value) == TYPE_FLOAT:
		var integer_value := int(value)
		if is_equal_approx(float(integer_value), value):
			return integer_value
	return value
