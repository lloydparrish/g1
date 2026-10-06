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
var _recording_presentation := false
var _action_presentation_events: Array = []

func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	if parsed is Dictionary:
		content = parsed
	_load_codex()

func validate_content() -> Array:
	var errors: Array = []
	var types: Array = content.get("damage_types", [])
	var valid_slots := ["Weapon", "Offhand", "Head", "Body", "Hands", "Feet", "Ring 1", "Ring 2", "Amulet"]
	var valid_targets := ["self", "enemy", "area", "tile", "passive"]
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
		if String(ability.get("description", "")).strip_edges() == "":
			errors.append("%s has no player-facing description" % ability_id)
		var is_passive: bool = ability.get("kind", "active") == "passive"
		if not valid_targets.has(ability.get("target", "")) or (is_passive and ability.get("target", "") != "passive") or (not is_passive and ability.get("target", "") == "passive"):
			errors.append("%s has an invalid target type" % ability_id)
		if (not is_passive and int(ability.get("range", -1)) < 0) or int(ability.get("time", 0)) < 0 or (not is_passive and int(ability.get("time", 0)) == 0):
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
		var all_prerequisites: Array = ability.get("requires", []).duplicate()
		all_prerequisites.append_array(ability.get("prerequisites", {}).get("all_of", []))
		all_prerequisites.append_array(ability.get("prerequisites", {}).get("any_of", []))
		for prerequisite in all_prerequisites:
			if not content.get("abilities", {}).has(prerequisite):
				errors.append("%s requires unknown ability %s" % [ability_id, prerequisite])
		for modifier_id in ability.get("modifiers", {}):
			if not (ability.modifiers[modifier_id] is int or ability.modifiers[modifier_id] is float):
				errors.append("%s has a non-numeric passive modifier %s" % [ability_id, modifier_id])
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
			var learning: Dictionary = item.get("learning", {})
			var offered: Array = learning.get("abilities", item.get("learns", []))
			for learned_ability in offered:
				if not content.get("abilities", {}).has(learned_ability):
					errors.append("%s teaches unknown ability %s" % [item_id, learned_ability])
			if learning.get("mode", "all") == "choose" and (int(learning.get("choice_count", 0)) < 1 or int(learning.choice_count) > offered.size()):
				errors.append("%s has an invalid spellbook choice count" % item_id)
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
	for slot in definition.get("starting_equipment", {}):
		equipment[slot] = definition.starting_equipment[slot]
	var inventory: Array = ["healing_potion", "mana_potion", "bomb", "fireball_scroll"]
	if content.weapons[definition.weapon].hands == 2:
		equipment["Offhand"] = "occupied"
	run = {
		"version": 1, "seed": seed_value, "rng_state": str(_rng.state), "character_id": character_id,
		"character": definition.name, "aura": definition.aura, "discipline": definition.discipline,
		"schools": definition.schools.duplicate(), "disciplines": definition.get("disciplines", [definition.get("discipline", "")]).duplicate(),
		"discoveries": [], "school_ranks": {}, "discipline_ranks": {}, "attributes": definition.attributes.duplicate(true),
		"entities": {}, "grid": [], "visible": [], "explored": [], "objects": [], "corpses": [],
		"equipment": equipment, "inventory": inventory, "artifacts": [], "known": definition.known.duplicate(),
		"temporary_abilities": {}, "xp": 0, "level": 1, "skill_points": 0, "kills": 0, "assists": 0,
		"growth_milestones": 0, "quickbar": [], "quickbar_customized": false,
		"combat_history": [], "combat_contributions": {}, "combat_event_sequence": 0,
		"time": 0, "turn": 0, "stage_index": 0, "encounters_completed": 0,
		"stage_id": "", "objective": {}, "stage_completed": false, "reward_choices": [], "reward_choice_resolved": false, "reward_chosen_index": -1,
		"route_choices": [], "route": ["ruined_village"], "outcome": "", "log": ["The March stirs beyond the gate."],
		"fire_cast_count": 0, "living_kills": 0, "boss_summoned": false, "discovered_books": [], "spellbook_resolutions": {}, "trigger_counts": {}
	}
	for ability_id in definition.known:
		if content.abilities.get(ability_id, {}).get("kind", "active") != "passive" and run.quickbar.size() < 8:
			run.quickbar.append({"type": "ability", "id": ability_id})
	for item_id in inventory:
		if run.quickbar.size() >= 8:
			break
		if content.items.get(item_id, {}).get("type", "") in ["consumable", "scroll"]:
			run.quickbar.append({"type": "item", "id": item_id})
	while run.quickbar.size() < 8:
		run.quickbar.append({"type": "empty", "id": ""})
	var player := {"id": "player", "name": definition.name, "kind": "player", "faction": "Adventurers", "pos": [12, 8], "hp": definition.resources.Health[0], "max_hp": definition.resources.Health[1], "resources": definition.resources.duplicate(true), "statuses": {}, "next_time": 0, "footprint": 1, "armor": 0, "alive": true, "sight": 10}
	run.entities["player"] = player
	_new_stage("ruined_village", false)
	_recompute_armor()
	_save_codex()
	return true

func resume_run() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (parsed is Dictionary) or int(parsed.get("version", 0)) != 1:
		return false
	run = _canonicalize(parsed)
	run["assists"] = int(run.get("assists", 0))
	run["growth_milestones"] = int(run.get("growth_milestones", maxi(0, int((int(run.get("level", 1)) - 1) / 2))))
	if not (run.get("quickbar", []) is Array) or run.get("quickbar", []).is_empty():
		run["quickbar"] = _default_quickbar()
	run["quickbar"] = _normalize_quickbar(run.get("quickbar", []))
	run["quickbar_customized"] = bool(run.get("quickbar_customized", false))
	run["combat_history"] = run.get("combat_history", [])
	run["combat_contributions"] = run.get("combat_contributions", {})
	run["combat_event_sequence"] = int(run.get("combat_event_sequence", 0))
	run["disciplines"] = run.get("disciplines", [run.get("discipline", "")])
	run["discoveries"] = run.get("discoveries", [])
	run["school_ranks"] = run.get("school_ranks", {})
	run["discipline_ranks"] = run.get("discipline_ranks", {})
	run["spellbook_resolutions"] = run.get("spellbook_resolutions", {})
	for book_id in run.get("discovered_books", []):
		if not run.spellbook_resolutions.has(book_id):
			run.spellbook_resolutions[book_id] = {"abilities": [], "migrated": true}
	var claimed_index := -1
	for reward_index in range(run.get("reward_choices", []).size()):
		if run.reward_choices[reward_index].get("claimed", false):
			claimed_index = reward_index
			break
	run["reward_choice_resolved"] = bool(run.get("reward_choice_resolved", claimed_index >= 0))
	run["reward_chosen_index"] = int(run.get("reward_chosen_index", claimed_index))
	for reward_index in range(run.reward_choices.size()):
		var reward: Dictionary = run.reward_choices[reward_index]
		reward["available"] = not run.reward_choice_resolved or (reward_index == run.reward_chosen_index and not reward.get("claimed", false))
	_rng.seed = int(run.get("seed", 1))
	_rng.state = int(run.get("rng_state", "1"))
	_recompute_armor()
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

func get_entity_presentation(entity_id: String) -> Dictionary:
	var entity: Dictionary = run.get("entities", {}).get(entity_id, {})
	if entity.is_empty():
		return {"id": entity_id, "name": "Creature", "symbol": "?", "faction": "", "kind": "enemy", "color_key": "neutral"}
	var creature_id := String(entity.get("enemy_id", entity_id))
	var definition: Dictionary = content.get("summons", {}).get(creature_id, content.get("enemies", {}).get(creature_id, {}))
	var faction := String(entity.get("faction", ""))
	var color_key := "player" if entity_id == "player" else "ally" if faction == "Adventurers" else "hostile" if faction in ["Undead", "Demons"] else "other"
	var symbol := String(entity.get("symbol", definition.get("symbol", "?")))
	if entity_id == "player":
		symbol = "@"
	return {"id": entity_id, "name": String(entity.get("name", definition.get("name", "Creature"))), "symbol": symbol, "faction": faction, "kind": String(entity.get("kind", "enemy")), "color_key": color_key}

func get_timeline(count: int = 6) -> Array:
	var entries: Array = []
	for entity_id in run.get("entities", {}):
		var entity: Dictionary = run.entities[entity_id]
		if entity.get("alive", true):
			var presentation := get_entity_presentation(String(entity_id))
			presentation["time"] = int(entity.get("next_time", 0))
			entries.append(presentation)
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

func _capture_display_state() -> Dictionary:
	var visible_entities: Dictionary = {}
	for entity_id in run.get("entities", {}):
		if _can_perceive_entity(String(entity_id)):
			visible_entities[entity_id] = run.entities[entity_id].duplicate(true)
	var visible_objects: Array = []
	for object in run.get("objects", []):
		if _event_cell_visible(_pos(object)):
			visible_objects.append(object.duplicate(true))
	return {"grid": run.get("grid", []).duplicate(true), "visible": run.get("visible", []).duplicate(true),
		"explored": run.get("explored", []).duplicate(true), "entities": visible_entities,
		"objects": visible_objects, "corpses": run.get("corpses", []).duplicate(true),
		"stage_id": run.get("stage_id", ""), "stage_index": int(run.get("stage_index", 0)),
		"time": int(run.get("time", 0)), "turn": int(run.get("turn", 0)), "xp": int(run.get("xp", 0)),
		"level": int(run.get("level", 1)), "skill_points": int(run.get("skill_points", 0)),
		"attributes": run.get("attributes", {}).duplicate(true), "combat_history": run.get("combat_history", []).duplicate(true)}

func _event_cell_visible(cell: Vector2i) -> bool:
	if not _inside(cell) or run.get("entities", {}).is_empty():
		return false
	var player: Dictionary = get_player()
	if player.is_empty() or not player.get("alive", true):
		return false
	var origin := _pos(player)
	return _dist(origin, cell) <= int(player.get("sight", 8)) and _line_of_sight(origin, cell)

func _can_perceive_entity(entity_id: String) -> bool:
	if entity_id == "player":
		return true
	var entity: Dictionary = run.get("entities", {}).get(entity_id, {})
	return not entity.is_empty() and _event_cell_visible(_pos(entity))

func _presentation_entity_patch(entity_id: String) -> Dictionary:
	if entity_id == "" or not run.get("entities", {}).has(entity_id):
		return {}
	var entity: Dictionary = run.entities[entity_id]
	return entity.duplicate(true) if _can_perceive_entity(entity_id) else {"id": entity_id, "alive": false, "hidden": true}

func _emit_combat_event(event_type: String, actor_id: String = "", target_id: String = "", details: Dictionary = {}) -> void:
	if run.is_empty():
		return
	var actor_visible := actor_id != "" and _can_perceive_entity(actor_id)
	var target_visible := target_id != "" and _can_perceive_entity(target_id)
	var cell_visible := details.has("pos") and _event_cell_visible(_as_cell(details.pos))
	var from_visible := details.has("from") and _event_cell_visible(_as_cell(details.from))
	var to_visible := details.has("to") and _event_cell_visible(_as_cell(details.to))
	if target_id != "" and target_id != "player" and not target_visible and event_type in ["Attack", "Damage", "Death", "StatusApplied", "KillCredit"]:
		return
	if actor_id != "" and not actor_visible and not (target_id == "player" and event_type == "Damage") and not (event_type == "Move" and from_visible):
		return
	if not actor_visible and not target_visible and not cell_visible:
		return
	var actor_name := String(run.entities.get(actor_id, {}).get("name", "")) if actor_visible else ""
	var target_name := String(run.entities.get(target_id, {}).get("name", "")) if target_visible else ""
	var safe_type := event_type
	var safe_details := details.duplicate(true)
	if target_id != "" and not target_visible:
		safe_details.erase("name")
		safe_details.erase("pos")
	if event_type == "Move" and actor_id != "" and not from_visible and to_visible:
		safe_type = "Spotted"
		actor_name = String(run.entities.get(actor_id, {}).get("name", "Creature"))
	elif event_type == "Move" and actor_id != "" and from_visible and not to_visible:
		safe_type = "LeavesSight"
		actor_name = String(run.entities.get(actor_id, {}).get("name", "Creature"))
	if target_id == "player" and not actor_visible and event_type == "Damage":
		safe_type = "UnseenImpact"
		safe_details = {"message": "An unseen attack strikes you."}
	if safe_details.has("from") and not _event_cell_visible(_as_cell(safe_details.from)):
		safe_details.erase("from")
	if safe_details.has("to") and not _event_cell_visible(_as_cell(safe_details.to)):
		safe_details.erase("to")
	if safe_details.has("pos") and not _event_cell_visible(_as_cell(safe_details.pos)):
		safe_details.erase("pos")
	var visible_actor_id := actor_id if actor_visible or event_type == "Move" and from_visible else ""
	var visible_target_id := target_id if target_visible else ""
	var event := {"type": safe_type, "actor_id": visible_actor_id, "target_id": visible_target_id,
		"actor_name": actor_name, "target_name": target_name, "details": safe_details,
		"patches": []}
	for participant_id in [actor_id, target_id]:
		if participant_id == "" or not run.entities.has(participant_id):
			continue
		var patch: Dictionary = _presentation_entity_patch(participant_id)
		if not patch.is_empty():
			event.patches.append(patch)
	run["combat_event_sequence"] = int(run.get("combat_event_sequence", 0)) + 1
	var history_event := {"sequence": int(run.combat_event_sequence), "type": safe_type,
		"actor_name": actor_name, "target_name": target_name, "details": safe_details.duplicate(true)}
	if _is_meaningful_combat_event(history_event):
		var history: Array = run.get("combat_history", [])
		history.append(history_event)
		if history.size() > 100:
			history = history.slice(history.size() - 100)
		run["combat_history"] = history
	if _recording_presentation:
		_action_presentation_events.append(event)

func _is_meaningful_combat_event(event: Dictionary) -> bool:
	var event_type := String(event.get("type", ""))
	if event_type in ["ActorTurnStarted", "ResourceSpent"]:
		return false
	if event_type == "XPGranted" and String(event.get("details", {}).get("reason", "")) in ["kill", "assist"]:
		return false
	return event_type in ["Move", "Spotted", "LeavesSight", "Attack", "Cast", "Damage", "UnseenImpact", "Heal", "StatusApplied", "StatusRemoved", "StatusTick", "Summon", "Death", "KillCredit", "XPGranted", "LevelUp", "TerrainChanged", "EncounterComplete"]

func _default_quickbar() -> Array:
	var result: Array = []
	var character: Dictionary = content.get("characters", {}).get(run.get("character_id", ""), {})
	for ability_id in character.get("known", []):
		if content.get("abilities", {}).get(ability_id, {}).get("kind", "active") != "passive" and result.size() < 8:
			result.append({"type": "ability", "id": ability_id})
	for item_id in run.get("inventory", []):
		if result.size() >= 8: break
		if content.get("items", {}).get(item_id, {}).get("type", "") in ["consumable", "scroll"]:
			result.append({"type": "item", "id": item_id})
	while result.size() < 8: result.append({"type": "empty", "id": ""})
	return result

func _normalize_quickbar(value: Array) -> Array:
	var result: Array = []
	for slot in value:
		var normalized := {"type": String(slot.get("type", "empty")), "id": String(slot.get("id", ""))}
		if normalized.type == "ability" and (not content.get("abilities", {}).has(normalized.id) or content.abilities[normalized.id].get("kind", "active") == "passive" or not run.get("known", []).has(normalized.id)):
			normalized = {"type": "empty", "id": ""}
		elif normalized.type == "item" and not content.get("items", {}).has(normalized.id):
			normalized = {"type": "empty", "id": ""}
		elif normalized.type not in ["ability", "item"]:
			normalized = {"type": "empty", "id": ""}
		result.append(normalized)
		if result.size() == 8: break
	while result.size() < 8: result.append({"type": "empty", "id": ""})
	return result

func assign_quickbar(slot_index: int, action_type: String, action_id: String) -> bool:
	if slot_index < 0 or slot_index >= 8 or run.is_empty(): return false
	var assignment := {"type": action_type, "id": action_id}
	if action_type == "empty":
		assignment = {"type": "empty", "id": ""}
	elif action_type == "ability":
		if not run.get("known", []).has(action_id) or not content.get("abilities", {}).has(action_id) or content.abilities[action_id].get("kind", "active") == "passive": return false
		for index in range(8):
			if index != slot_index and run.quickbar[index].get("type") == "ability" and run.quickbar[index].get("id") == action_id:
				run.quickbar[index] = {"type": "empty", "id": ""}
	elif action_type == "item":
		if not content.get("items", {}).has(action_id) or content.items[action_id].get("type", "") not in ["consumable", "scroll"]: return false
	else:
		return false
	run.quickbar[slot_index] = assignment
	run.quickbar_customized = true
	save_run()
	return true

func use_quickbar(slot_index: int, target: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if slot_index < 0 or slot_index >= run.get("quickbar", []).size(): return {"ok": false, "message": "That action slot is empty."}
	var assignment: Dictionary = run.quickbar[slot_index]
	if assignment.get("type") == "ability":
		return act({"type": "cast", "id": assignment.id, "target": [target.x, target.y] if target.x >= 0 else _pos(get_player())})
	if assignment.get("type") == "item":
		var index := int(run.get("inventory", []).find(String(assignment.id)))
		if index < 0: return {"ok": false, "message": "You have none of that item."}
		return act({"type": "use_item", "index": index, "target": [target.x, target.y]})
	return {"ok": false, "message": "That action slot is empty."}

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
	var display_before := _capture_display_state()
	_recording_presentation = true
	_action_presentation_events = []
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
		result["presentation_before"] = display_before
		result["presentation_events"] = _action_presentation_events.duplicate(true)
	_recording_presentation = false
	_action_presentation_events = []
	return result

func learn_ability(ability_id: String) -> bool:
	if run.is_empty() or not content.abilities.has(ability_id) or int(run.skill_points) <= 0:
		return false
	var progression: Dictionary = get_ability_progress(ability_id)
	if not progression.get("learnable", false):
		return false
	var definition: Dictionary = content.abilities[ability_id]
	run.known.append(ability_id)
	run.skill_points -= 1
	_recompute_armor()
	_record_codex("abilities", ability_id)
	_add_log("Learned %s." % definition.name)
	save_run()
	return true

func get_school_rank(school: String) -> int:
	var rank := int(run.get("school_ranks", {}).get(school, 0))
	if run.get("schools", []).has(school):
		rank = maxi(rank, 1)
	for ability_id in run.get("known", []):
		if content.get("abilities", {}).has(ability_id) and content.abilities[ability_id].get("school", "") == school:
			rank += 1
	return rank

func get_discipline_rank(discipline: String) -> int:
	var rank := int(run.get("discipline_ranks", {}).get(discipline, 0))
	if run.get("disciplines", [run.get("discipline", "")]).has(discipline):
		rank = maxi(rank, 1)
	for ability_id in run.get("known", []):
		if content.get("abilities", {}).has(ability_id) and content.abilities[ability_id].get("school", "") == discipline:
			rank += 1
	return rank

func get_ability_progress(ability_id: String) -> Dictionary:
	if not content.get("abilities", {}).has(ability_id):
		return {"visible": false, "learned": false, "learnable": false, "reason": "Unknown ability."}
	var ability: Dictionary = content.abilities[ability_id]
	var school := String(ability.get("school", ""))
	var prerequisites: Dictionary = ability.get("prerequisites", {})
	var all_of: Array = ability.get("requires", []).duplicate()
	all_of.append_array(prerequisites.get("all_of", []))
	var any_of: Array = prerequisites.get("any_of", [])
	var learned: bool = run.get("known", []).has(ability_id)
	var missing: Array[String] = []
	var discoveries: Array = run.get("discoveries", [])
	for discovery in prerequisites.get("discoveries", []):
		if not discoveries.has(discovery):
			return {"visible": false, "learned": learned, "learnable": false, "reason": "Undiscovered knowledge."}
	var is_discovered_school: bool = run.get("schools", []).has(school)
	var learned_parent := false
	for prerequisite in all_of:
		if run.get("known", []).has(prerequisite):
			learned_parent = true
		else:
			missing.append(String(content.abilities.get(prerequisite, {}).get("name", prerequisite)))
	var any_parent := any_of.is_empty()
	if not any_of.is_empty():
		for prerequisite in any_of:
			if run.get("known", []).has(prerequisite):
				any_parent = true
				learned_parent = true
				break
		if not any_parent:
			missing.append("one of %s" % ", ".join(any_of.map(func(value: String) -> String: return String(content.abilities.get(value, {}).get("name", value)))))
	var identity_known: bool = run.get("disciplines", [run.get("discipline", "")]).has(school) or is_discovered_school
	var visible: bool = learned or (identity_known or learned_parent) and not (ability.get("discovery_required", false) and not is_discovered_school)
	for required_school in prerequisites.get("schools", []):
		if not run.get("schools", []).has(required_school):
			visible = learned
	if ability.get("discovery_required", false) and not is_discovered_school:
		visible = learned
	for required_school in prerequisites.get("schools", []):
		if not run.get("schools", []).has(required_school):
			missing.append("%s knowledge" % required_school)
	for required_discipline in prerequisites.get("disciplines", []):
		if not run.get("disciplines", [run.get("discipline", "")]).has(required_discipline):
			missing.append("%s training" % required_discipline)
	for rank_school in prerequisites.get("school_ranks", {}):
		if get_school_rank(rank_school) < int(prerequisites.school_ranks[rank_school]):
			missing.append("%s rank %d" % [rank_school, int(prerequisites.school_ranks[rank_school])])
	for rank_discipline in prerequisites.get("discipline_ranks", {}):
		if get_discipline_rank(rank_discipline) < int(prerequisites.discipline_ranks[rank_discipline]):
			missing.append("%s rank %d" % [rank_discipline, int(prerequisites.discipline_ranks[rank_discipline])])
	for required_character in prerequisites.get("characters", []):
		if run.get("character_id", "") != required_character:
			missing.append("a different character")
	if int(run.get("level", 1)) < int(prerequisites.get("minimum_level", 1)):
		missing.append("level %d" % int(prerequisites.minimum_level))
	for artifact in prerequisites.get("artifacts", []):
		if not run.get("artifacts", []).has(artifact):
			missing.append("%s artifact" % content.get("artifacts", {}).get(artifact, {}).get("name", artifact))
	for resource_name in prerequisites.get("resources", {}):
		var resource: Array = get_player().get("resources", {}).get(resource_name, [0, 0])
		if int(resource[0]) < int(prerequisites.resources[resource_name]):
			missing.append("%d %s" % [int(prerequisites.resources[resource_name]), resource_name])
	if not visible:
		return {"visible": false, "learned": learned, "learnable": false, "reason": "Knowledge has not been discovered."}
	if learned:
		return {"visible": true, "learned": true, "learnable": false, "reason": "Learned."}
	if not identity_known and not learned_parent:
		missing.append("%s knowledge" % school)
	if int(run.get("skill_points", 0)) <= 0:
		missing.append("an ability point")
	var learnable: bool = missing.is_empty()
	return {"visible": true, "learned": false, "learnable": learnable, "reason": "Ready to learn." if learnable else "Requires " + ", ".join(missing) + "."}

func get_progression_graph() -> Array:
	var ids: Array = content.get("abilities", {}).keys()
	ids.sort()
	var visible_ids: Array[String] = []
	var visible_schools: Array[String] = []
	var progress_by_id: Dictionary = {}
	for ability_id in ids:
		var progress: Dictionary = get_ability_progress(ability_id)
		if not progress.visible:
			continue
		visible_ids.append(String(ability_id))
		progress_by_id[ability_id] = progress
		var school := String(content.abilities[ability_id].get("school", ""))
		if school != "" and not visible_schools.has(school):
			visible_schools.append(school)
	var school_order: Array = []
	for school in content.get("progression", {}).get("disciplines", []) + content.get("progression", {}).get("schools", []):
		if visible_schools.has(school):
			school_order.append(school)
	var extras: Array[String] = []
	for school in visible_schools:
		if not school_order.has(school):
			extras.append(school)
	extras.sort()
	school_order.append_array(extras)
	var layout := _radial_progression_layout(visible_ids, school_order)
	var result: Array = []
	for ability_id in visible_ids:
		var progress: Dictionary = progress_by_id[ability_id]
		var ability: Dictionary = content.abilities[ability_id]
		var school := String(ability.get("school", ""))
		var position: Vector2 = layout.positions.get(ability_id, Vector2.ZERO)
		var parents := _ability_parent_ids(ability)
		result.append({"id": ability_id, "ability": ability, "school": school, "position": position, "parents": parents, "root_id": layout.roots.get(ability_id, ability_id), "root": bool(layout.root_nodes.get(ability_id, false)), "depth": int(layout.depths.get(ability_id, 0)), "learned": progress.learned, "learnable": progress.learnable, "reason": progress.reason})
	return result

func _ability_parent_ids(ability: Dictionary) -> Array:
	var parents: Array = ability.get("requires", []).duplicate()
	parents.append_array(ability.get("prerequisites", {}).get("all_of", []))
	parents.append_array(ability.get("prerequisites", {}).get("any_of", []))
	return parents

func _radial_progression_layout(visible_ids: Array, school_order: Array) -> Dictionary:
	var nodes_by_school: Dictionary = {}
	var roots_by_school: Dictionary = {}
	var depths: Dictionary = {}
	var root_for: Dictionary = {}
	var root_nodes: Dictionary = {}
	var local_points: Dictionary = {}
	var root_radii: Dictionary = {}
	var maximum_cluster_radius := 180.0
	for school in school_order:
		var school_ids: Array[String] = []
		for ability_id in visible_ids:
			if String(content.abilities[ability_id].get("school", "")) == String(school):
				school_ids.append(String(ability_id))
		nodes_by_school[school] = school_ids
		var roots: Array[String] = []
		for ability_id in school_ids:
			var ability: Dictionary = content.abilities[ability_id]
			var parents := _ability_parent_ids(ability)
			if bool(ability.get("web_root", false)) or parents.is_empty():
				roots.append(ability_id)
		if roots.is_empty() and not school_ids.is_empty():
			roots.append(school_ids[0])
		roots_by_school[school] = roots
		root_radii[school] = 0.0 if roots.size() <= 1 else maxf(96.0, float(roots.size()) * 56.0)
		for root_id in roots:
			root_for[root_id] = root_id
			depths[root_id] = 0
			root_nodes[root_id] = true
		var unresolved := school_ids.size()
		while unresolved > 0:
			var assigned_this_pass := false
			for ability_id in school_ids:
				if depths.has(ability_id):
					continue
				var ability: Dictionary = content.abilities[ability_id]
				var candidate_parent := ""
				var candidate_depth := 2147483647
				for parent_id in _ability_parent_ids(ability):
					if String(content.abilities.get(parent_id, {}).get("school", "")) != String(school) or not depths.has(parent_id):
						continue
					if int(depths[parent_id]) < candidate_depth:
						candidate_parent = String(parent_id)
						candidate_depth = int(depths[parent_id])
				if candidate_parent != "":
					root_for[ability_id] = root_for[candidate_parent]
					depths[ability_id] = candidate_depth + 1
					assigned_this_pass = true
			if not assigned_this_pass:
				for ability_id in school_ids:
					if depths.has(ability_id):
						continue
					var root_id := String(roots[0]) if not roots.is_empty() else String(ability_id)
					root_for[ability_id] = root_id
					depths[ability_id] = 1
					assigned_this_pass = true
				break
			if not assigned_this_pass:
				break
			unresolved = 0
			for ability_id in school_ids:
				if not depths.has(ability_id): unresolved += 1
		var local_max_depth := 0
		for ability_id in school_ids:
			local_max_depth = maxi(local_max_depth, int(depths.get(ability_id, 0)))
		maximum_cluster_radius = maxf(maximum_cluster_radius, float(root_radii[school]) + 74.0 + float(local_max_depth) * 178.0)
		for root_index in range(roots.size()):
			var root_id: String = roots[root_index]
			var root_angle := TAU * float(root_index) / maxf(1.0, float(roots.size()))
			var root_children: Dictionary = {}
			for ability_id in school_ids:
				if root_for.get(ability_id, "") == root_id:
					var depth := int(depths.get(ability_id, 0))
					if not root_children.has(depth): root_children[depth] = []
					root_children[depth].append(String(ability_id))
			for depth in root_children:
				var members: Array = root_children[depth]
				members.sort()
				var ring_radius := float(root_radii[school]) if depth == 0 else float(root_radii[school]) + 154.0 + float(depth - 1) * 178.0
				var sector_width := TAU / maxf(1.0, float(roots.size()))
				for member_index in range(members.size()):
					var angle := root_angle
					if depth > 0 and members.size() > 1:
						var fraction := float(member_index) / float(members.size() - 1)
						angle += lerpf(-sector_width * 0.38, sector_width * 0.38, fraction)
					local_points[members[member_index]] = Vector2(cos(angle), sin(angle)) * ring_radius
	var anchor_radius := 0.0
	if school_order.size() > 1:
		anchor_radius = (maximum_cluster_radius * 2.0 + 260.0) / (2.0 * sin(PI / float(school_order.size())))
	var positions: Dictionary = {}
	for school_index in range(school_order.size()):
		var school: String = school_order[school_index]
		var angle := TAU * float(school_index) / float(school_order.size())
		var anchor := Vector2(cos(angle), sin(angle)) * anchor_radius
		for ability_id in nodes_by_school.get(school, []):
			positions[ability_id] = anchor + local_points.get(ability_id, Vector2.ZERO)
	return {"positions": positions, "roots": root_for, "root_nodes": root_nodes, "depths": depths}

func get_progression_root_id(school: String) -> String:
	var graph := get_progression_graph()
	for node in graph:
		if String(node.school) == school and bool(node.root):
			return String(node.id)
	for node in graph:
		if String(node.school) == school:
			return String(node.id)
	return ""

func get_progression_focus_id(school: String) -> String:
	for index in range(run.get("known", []).size() - 1, -1, -1):
		var ability_id: String = run.known[index]
		if content.get("abilities", {}).has(ability_id) and String(content.abilities[ability_id].get("school", "")) == school:
			return ability_id
	return get_progression_root_id(school)

func get_progression_graph_bounds(nodes: Array = []) -> Rect2:
	var graph_nodes := nodes if not nodes.is_empty() else get_progression_graph()
	if graph_nodes.is_empty():
		return Rect2()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for node in graph_nodes:
		var position: Vector2 = node.position
		minimum.x = minf(minimum.x, position.x)
		minimum.y = minf(minimum.y, position.y)
		maximum.x = maxf(maximum.x, position.x + 176.0)
		maximum.y = maxf(maximum.y, position.y + 78.0)
	return Rect2(minimum, maximum - minimum)

func get_passive_modifier(modifier_id: String) -> float:
	var total := 0.0
	for ability_id in run.get("known", []):
		var ability: Dictionary = content.get("abilities", {}).get(ability_id, {})
		if ability.get("kind", "active") == "passive":
			total += float(ability.get("modifiers", {}).get(modifier_id, 0.0))
	return total

func claim_reward(index: int) -> bool:
	if run.is_empty() or not run.get("stage_completed", false) or run.get("reward_choice_resolved", false) or index < 0 or index >= run.reward_choices.size():
		return false
	var reward: Dictionary = run.reward_choices[index]
	if reward.get("claimed", false) or not reward.get("available", true):
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
	run.reward_choice_resolved = true
	run.reward_chosen_index = index
	for choice_index in range(run.reward_choices.size()):
		var choice: Dictionary = run.reward_choices[choice_index]
		choice["available"] = false
		if choice_index == index:
			choice["claimed"] = true
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
		var learned_discipline := _weapon_discipline(String(item.get("weapon", "")))
		if learned_discipline != "" and not run.get("disciplines", []).has(learned_discipline):
			run.disciplines.append(learned_discipline)
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

func unequip_item(slot: String) -> bool:
	if not run.get("equipment", {}).has(slot) or run.inventory.size() >= 30:
		return false
	var item_id: String = run.equipment.get(slot, "")
	if item_id in ["", "occupied"]:
		return false
	run.inventory.append(item_id)
	run.equipment[slot] = ""
	if slot == "Weapon" and run.equipment.get("Offhand", "") == "occupied":
		run.equipment["Offhand"] = ""
	_recompute_armor()
	_add_log("Unequipped %s." % content.items.get(item_id, {}).get("name", item_id))
	save_run()
	return true

func _weapon_discipline(weapon_id: String) -> String:
	match weapon_id:
		"sword": return "Swordsmanship"
		"greatsword": return "Heavy Weapons"
		"spear": return "Polearms"
		"dagger": return "Daggers"
		"bow": return "Archery"
		"crossbow": return "Crossbows"
		_: return ""

func discard_item(index: int) -> bool:
	if index < 0 or index >= run.inventory.size():
		return false
	run.inventory.remove_at(index)
	save_run()
	return true

func get_spellbook_options(index: int) -> Dictionary:
	if index < 0 or index >= run.inventory.size():
		return {}
	var item_id: String = run.inventory[index]
	var book: Dictionary = content.items.get(item_id, {})
	if book.get("type") != "spellbook":
		return {}
	var learning: Dictionary = book.get("learning", {})
	var mode := String(learning.get("mode", "choose"))
	var offered: Array = learning.get("abilities", book.get("learns", [])).duplicate()
	var resolution: Dictionary = run.get("spellbook_resolutions", {}).get(item_id, {})
	var options: Array = []
	for ability_id in offered:
		var ability: Dictionary = content.abilities.get(ability_id, {})
		options.append({"id": ability_id, "name": ability.get("name", "Unknown ability"), "description": ability.get("description", ""), "learned": run.get("known", []).has(ability_id)})
	return {"id": item_id, "name": book.get("name", "Spellbook"), "school": book.get("school", ""), "description": book.get("description", ""), "contents": book.get("contents", []), "mode": mode, "choice_count": int(learning.get("choice_count", offered.size() if mode == "all" else 0)), "consume_on_study": bool(learning.get("consume_on_study", false)), "unlocks_school": bool(learning.get("unlocks_school", book.get("unlocks_school", false))), "resolved": not resolution.is_empty(), "chosen_abilities": resolution.get("abilities", []), "options": options}

func study_spellbook(index: int, choice_indices: Variant = null) -> bool:
	if index < 0 or index >= run.inventory.size():
		return false
	var item_id: String = run.inventory[index]
	var book: Dictionary = content.items.get(item_id, {})
	if book.get("type") != "spellbook" or run.get("spellbook_resolutions", {}).has(item_id):
		return false
	var learning: Dictionary = book.get("learning", {})
	var mode := String(learning.get("mode", "choose"))
	var offered: Array = learning.get("abilities", book.get("learns", [])).duplicate()
	var chosen_indices: Array = []
	if choice_indices is Array:
		chosen_indices = choice_indices.duplicate()
	elif choice_indices != null:
		chosen_indices = [int(choice_indices)]
	var granted: Array = []
	if mode == "all":
		if not chosen_indices.is_empty():
			return false
		granted = offered.duplicate()
	elif mode == "choose":
		var count := int(learning.get("choice_count", 0))
		if count < 1 or chosen_indices.size() != count:
			return false
		for choice_index in chosen_indices:
			var option_index := int(choice_index)
			if option_index < 0 or option_index >= offered.size() or chosen_indices.count(choice_index) != 1:
				return false
			var ability_id: String = offered[option_index]
			if run.known.has(ability_id):
				return false
			granted.append(ability_id)
	elif mode != "school_only" or not chosen_indices.is_empty():
		return false
	for ability_id in granted:
		if not content.abilities.has(ability_id) or run.known.has(ability_id):
			return false
	var school := String(book.get("school", ""))
	var unlocks_school := bool(learning.get("unlocks_school", book.get("unlocks_school", false)))
	if unlocks_school and school != "" and not run.schools.has(school):
		run.schools.append(school)
	var discoveries: Array = run.get("discoveries", [])
	var recorded_discoveries: Array = ["spellbook:" + item_id]
	if unlocks_school and school != "":
		recorded_discoveries.append("school:" + school)
	for discovery in recorded_discoveries:
		if not discoveries.has(discovery):
			discoveries.append(discovery)
	run.discoveries = discoveries
	for ability_id in granted:
		run.known.append(ability_id)
	if not run.discovered_books.has(item_id):
		run.discovered_books.append(item_id)
	run.spellbook_resolutions[item_id] = {"abilities": granted.duplicate(), "mode": mode, "choice_count": granted.size()}
	_record_codex("spellbooks", item_id)
	if unlocks_school and school != "":
		_record_codex("schools", school)
	for ability_id in granted:
		_record_codex("abilities", ability_id)
	var learned_names: Array[String] = []
	for ability_id in granted:
		learned_names.append(String(content.abilities[ability_id].name))
	var result_text := "unlocks %s knowledge" % school if mode == "school_only" else "reveals %s" % ", ".join(learned_names)
	_add_log("%s %s." % [book.get("name", "The spellbook"), result_text])
	var consume_on_study := bool(learning.get("consume_on_study", false))
	if consume_on_study:
		run.inventory.remove_at(index)
	save_run()
	return true

func get_available_abilities() -> Array:
	var result: Array = []
	for ability_id in run.get("known", []):
		if content.abilities.has(ability_id) and content.abilities[ability_id].get("kind", "active") != "passive":
			result.append(ability_id)
	return result

func get_summary() -> Dictionary:
	return {"character": run.get("character", ""), "level": run.get("level", 1), "kills": run.get("kills", 0), "encounters": run.get("encounters_completed", 0), "time": run.get("time", 0), "outcome": run.get("outcome", "")}

func state_digest() -> String:
	if run.is_empty():
		return ""
	var player: Dictionary = get_player()
	return JSON.stringify({"seed": run.seed, "stage": run.stage_id, "time": run.time, "player_pos": player.pos, "hp": player.hp, "mana": player.resources.Mana, "stamina": player.resources.Stamina, "entities": run.entities, "grid": run.grid, "objects": run.objects, "known": run.known, "schools": run.get("schools", []), "disciplines": run.get("disciplines", []), "discoveries": run.get("discoveries", []), "spellbook_resolutions": run.get("spellbook_resolutions", {}), "reward_choice_resolved": run.get("reward_choice_resolved", false), "reward_chosen_index": run.get("reward_chosen_index", -1), "reward_choices": run.get("reward_choices", []), "xp": run.xp, "level": run.level, "skill_points": run.skill_points, "objective": run.objective})

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
	run.reward_choice_resolved = false
	run.reward_chosen_index = -1
	run.boss_summoned = false
	run.turn = 0
	run.combat_contributions = {}
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
		var enemy_curve: Array = stage.get("enemy_count_curve", [2, 3, 4, 5, 5])
		var enemy_count: int = int(enemy_curve[clampi(int(run.stage_index), 0, enemy_curve.size() - 1)])
		var maximum_tier := 0 if int(run.stage_index) == 0 else 1 if int(run.stage_index) <= 2 else 2
		var enemy_pool: Array = []
		for candidate_id in stage.enemies:
			if int(content.enemies.get(candidate_id, {}).get("tier", 0)) <= maximum_tier:
				enemy_pool.append(candidate_id)
		if enemy_pool.is_empty():
			enemy_pool = stage.enemies.duplicate()
		for i in range(enemy_count):
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
		if item_id in ["healing_potion", "mana_potion", "bomb", "fireball_scroll", "lesser_key_of_ash", "cinder_primer", "storm_ledger", "sword", "dagger", "greatsword", "spear", "bow", "crossbow", "staff", "wand", "iron_shield", "leather_armor", "scale_armor", "copper_ring"]:
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
	run.reward_choice_resolved = false
	run.reward_chosen_index = -1
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
		selected["available"] = true
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
	_emit_combat_event("Summon", "player", id, {"name": String(entity.get("name", "Summon")), "pos": [spawn_at.x, spawn_at.y]})
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
	_emit_combat_event("ResourceSpent", "player", "player", {"resource": "Stamina", "amount": 3})
	player.pos = [next_step.x, next_step.y]
	_emit_combat_event("Move", "player", "", {"from": [previous_pos.x, previous_pos.y], "to": [next_step.x, next_step.y]})
	_emit_trigger("OnMove", {"entity_id": "player", "from": [previous_pos.x, previous_pos.y], "pos": [next_step.x, next_step.y]})
	_emit_trigger("OnTerrainEntered", {"entity_id": "player", "terrain": _terrain_at(next_step), "pos": [next_step.x, next_step.y]})
	if _terrain_at(next_step) == "water":
		_apply_status("player", "Wet", 1)
	if _terrain_at(next_step) == "fire":
		_damage("player", 5, "Fire", "the burning ground")
	_add_log("%s steps across the field." % player.name)
	_check_objective_at_player()
	var passive_move := maxf(0.4, 1.0 - get_passive_modifier("move_time_reduction"))
	var move_time := maxi(1, int(round(100.0 * passive_move * float(_artifact_modifier("move_time_multiplier", 1.0)))))
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
	_emit_combat_event("ResourceSpent", "player", "player", {"resource": "Stamina", "amount": int(weapon.stamina)})
	var damage := int(weapon.damage) + int(run.attributes.get("Might", 10)) / 4 + int(round(get_passive_modifier("weapon_damage_bonus")))
	if _has_status("player", "Empowered"):
		damage += 8
		run.entities.player.statuses.erase("Empowered")
	_emit_combat_event("Attack", "player", target_id, {"style": String(weapon.get("style", "melee")), "damage_type": String(weapon.get("type", "Slashing"))})
	_damage(target_id, damage, String(weapon.get("type", "Slashing")), player.name, "player")
	if weapon.get("style") == "cleave":
		for adjacent in run.entities.keys():
			if adjacent != target_id and adjacent != "player" and run.entities[adjacent].get("alive", true) and _is_hostile("player", adjacent) and _dist(_pos(run.entities[target_id]), _pos(run.entities[adjacent])) <= 1:
				_damage(adjacent, int(damage * 0.65), String(weapon.get("type", "Slashing")), player.name, "player")
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
	if ability.get("kind", "active") == "passive":
		return {"ok": false, "message": "That is a passive ability."}
	var player: Dictionary = get_player()
	var temporary := int(run.temporary_abilities.get(ability_id, 0)) > 0
	if not run.known.has(ability_id) and not temporary:
		return {"ok": false, "message": "You have not learned %s." % ability.name}
	if ability.get("discovery_required", false) and not run.schools.has(ability.get("school", "")):
		return {"ok": false, "message": "You have not discovered %s." % ability.get("school", "that school")}
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
	var cost_status := get_cost_status(ability.get("costs", {}))
	if not cost_status.affordable:
		return {"ok": false, "message": "Requires %s. %s" % [get_cost_summary(ability.get("costs", {})), "; ".join(cost_status.issues)]}
	_pay(ability.get("costs", {}))
	var targets: Array = _targets_for_ability(ability, target)
	_emit_combat_event("Cast", "player", _occupant(target), {"ability": String(ability.name), "school": String(ability.get("school", "")), "pos": [target.x, target.y]})
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
					_damage(String(target_id), int(effect.get("amount", 0)), String(effect.get("damage", "Arcane")), ability.get("name", "magic"), "player")
		"status":
			for target_id in targets:
				_apply_status(String(target_id), String(effect.get("id", "")), int(effect.get("stacks", 1)), String(ability.get("name", "")), "player")
		"heal":
			var player := get_player()
			var health_before := int(player.hp)
			player.hp = mini(int(player.max_hp), int(player.hp) + int(effect.get("amount", 0)))
			if int(player.hp) > health_before:
				_emit_combat_event("Heal", "player", "player", {"amount": int(player.hp) - health_before})
				_emit_trigger("OnHeal", {"target_id": "player", "source": ability.get("name", "magic"), "amount": int(player.hp) - health_before})
		"heal_on_hit":
			if not targets.is_empty():
				var heal_amount := int(effect.get("amount", 0)) + int(_artifact_modifier("blood_lance_heal_bonus", 0.0))
				var player := get_player()
				var health_before := int(player.hp)
				player.hp = mini(int(player.max_hp), int(player.hp) + heal_amount)
				if int(player.hp) > health_before:
					_emit_combat_event("Heal", "player", "player", {"amount": int(player.hp) - health_before})
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
				_emit_combat_event("Move", "player", "", {"from": [previous_pos.x, previous_pos.y], "to": [center.x, center.y], "style": "teleport"})
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
				_emit_combat_event("Move", "player", "", {"from": [previous_pos.x, previous_pos.y], "to": [step.x, step.y]})
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
				_emit_combat_event("Heal", "player", "player", {"amount": int(player.hp) - health_before})
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
					_damage(entity_id, int(item.amount), "Fire", "the Cinder Bomb", "player")
			_emit_combat_event("Cast", "player", "", {"ability": String(item.get("name", "Cinder Bomb")), "school": "Fire", "pos": [target.x, target.y]})
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

func get_cost_summary(costs: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in costs:
		var amount := int(costs[resource_id])
		if resource_id == "Command":
			parts.append("%d free Command" % amount)
		else:
			parts.append("%d %s" % [amount, resource_id])
	return " and ".join(parts) if not parts.is_empty() else "no resources"

func get_cost_status(costs: Dictionary) -> Dictionary:
	var player: Dictionary = get_player()
	var issues: Array[String] = []
	for resource_id in costs:
		var values: Array = player.resources.get(resource_id, [0, 0])
		var amount := int(costs[resource_id])
		if resource_id == "Command":
			if int(values[0]) + amount > int(values[1]):
				issues.append("Command capacity full — %d / %d occupied; %d free required." % [int(values[0]), int(values[1]), amount])
		elif resource_id == "Health":
			if int(values[0]) <= amount:
				issues.append("Not enough Health — %d / %d; keep at least 1." % [int(values[0]), amount + 1])
		elif int(values[0]) < amount:
			issues.append("Not enough %s — %d / %d." % [resource_id, int(values[0]), amount])
	return {"affordable": issues.is_empty(), "issues": issues}

func _can_pay(costs: Dictionary) -> bool:
	return bool(get_cost_status(costs).affordable)

func _pay(costs: Dictionary) -> void:
	var player: Dictionary = get_player()
	for resource_id in costs:
		var values: Array = player.resources[resource_id]
		if resource_id == "Command":
			continue
		values[0] = int(values[0]) - int(costs[resource_id])
		player.resources[resource_id] = values
		_emit_combat_event("ResourceSpent", "player", "player", {"resource": resource_id, "amount": int(costs[resource_id])})
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
	_emit_combat_event("ActorTurnStarted", actor_id, "", {})
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
			_emit_combat_event("Attack", actor_id, target_id, {"style": "projectile", "damage_type": String(actor.get("damage_type", "Arcane"))})
			_damage(target_id, int(actor.get("damage", 8)), String(actor.get("damage_type", "Arcane")), actor.name, actor_id)
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
		_emit_combat_event("Attack", actor_id, target_id, {"style": "projectile" if behavior in ["ranged", "caster"] else "melee", "damage_type": String(actor.get("damage_type", "Blunt"))})
		_damage(target_id, attack_damage, String(actor.get("damage_type", "Blunt")), actor.name, actor_id)
		if actor.get("damage_type") == "Fire" and _rng.randf() < 0.2:
			_apply_status(target_id, "Burning", 1, String(actor.get("name", "")), actor_id)
		_add_log("%s attacks %s." % [actor.name, target.name])
		return
	if behavior == "summoner" and not bool(run.get("boss_summoned", false)):
		var spawn_at := _find_spawn(origin + Vector2i(1, 0))
		if spawn_at != Vector2i(-1, -1):
			var summoned_id := _spawn_enemy("skeleton", spawn_at, false)
			_emit_combat_event("Summon", actor_id, summoned_id, {"name": String(run.entities.get(summoned_id, {}).get("name", "Skeleton")), "pos": [spawn_at.x, spawn_at.y]})
			_add_log("%s raises a skeleton." % actor.name)
			return
	if behavior == "ranged" or behavior == "caster":
		if distance <= 2:
			var retreat := _retreat_step(origin, target_pos, actor_id)
			if retreat != origin:
				var previous_pos := _pos(actor)
				actor.pos = [retreat.x, retreat.y]
				_emit_combat_event("Move", actor_id, "", {"from": [previous_pos.x, previous_pos.y], "to": [retreat.x, retreat.y]})
				_emit_trigger("OnMove", {"entity_id": actor_id, "from": [previous_pos.x, previous_pos.y], "pos": [retreat.x, retreat.y]})
				_emit_trigger("OnTerrainEntered", {"entity_id": actor_id, "terrain": _terrain_at(retreat), "pos": [retreat.x, retreat.y]})
				return
	var step := _next_step(origin, target_pos, actor_id)
	if step != origin:
		actor.pos = [step.x, step.y]
		_emit_combat_event("Move", actor_id, "", {"from": [origin.x, origin.y], "to": [step.x, step.y]})
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
				var summoned_id := _spawn_enemy("skeleton", spawn_at, false)
				_emit_combat_event("Summon", actor_id, summoned_id, {"name": String(run.entities.get(summoned_id, {}).get("name", "Skeleton")), "pos": [spawn_at.x, spawn_at.y]})
				_add_log("The Grave Tyrant hauls a skeleton from the soil.")
		else:
			_apply_status(target_id, "Bleeding", 1, boss.name, actor_id)
			_add_log("The barrow splits beneath you.")
		return
	var distance := _distance_to_entity(_pos(boss), target)
	if distance <= 1:
		_emit_combat_event("Attack", actor_id, target_id, {"style": "melee", "damage_type": String(boss.damage_type)})
		_damage(target_id, int(boss.damage), String(boss.damage_type), boss.name, actor_id)
		_add_log("The Grave Tyrant strikes with a tombstone fist.")
	else:
		var step := _next_step(_pos(boss), _pos(target), actor_id)
		if step != _pos(boss):
			var previous_pos := _pos(boss)
			boss.pos = [step.x, step.y]
			_emit_combat_event("Move", actor_id, "", {"from": [previous_pos.x, previous_pos.y], "to": [step.x, step.y]})
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

func _damage(target_id: String, raw_amount: int, damage_type: String, source: String, source_id: String = "") -> void:
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
	if target_id == "player" and amount > 0:
		amount = maxi(1, int(round(float(amount) * (1.0 - clampf(get_passive_modifier("damage_reduction"), 0.0, 0.6)))))
	if _has_status(target_id, "Guard"):
		amount = int(ceil(float(amount) * 0.5))
		target.statuses.erase("Guard")
	target.hp = int(target.get("hp", 0)) - amount
	if source_id == "" and source == String(get_player().get("name", "")):
		source_id = "player"
	var credit_owner := _credit_owner(source_id)
	if credit_owner == "player" and target_id != "player" and _is_hostile("player", target_id) and amount > 0:
		var contributions: Dictionary = run.get("combat_contributions", {})
		contributions[target_id] = int(contributions.get(target_id, 0)) + amount
		run.combat_contributions = contributions
	_emit_combat_event("Damage", source_id, target_id, {"amount": amount, "damage_type": damage_type})
	_emit_trigger("OnHit", {"target_id": target_id, "source": source, "amount": amount, "damage_type": damage_type})
	_emit_trigger("OnDamaged", {"target_id": target_id, "source": source, "amount": amount, "damage_type": damage_type})
	if target_id == "player":
		_add_log("%s deals %d damage." % [source, amount])
	else:
		_add_log("%s takes %d damage." % [target.get("name", "A creature"), amount])
	if int(target.hp) <= 0:
		_on_death(target_id, source, source_id)

func _on_death(entity_id: String, source: String, source_id: String = "") -> void:
	var entity: Dictionary = run.entities[entity_id]
	if not entity.get("alive", true):
		return
	entity.alive = false
	_emit_combat_event("Death", "", entity_id, {"name": String(entity.get("name", "Creature")), "pos": entity.get("pos", []).duplicate()})
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
		if _is_hostile("player", entity_id):
			var killing_owner := _credit_owner(source_id)
			if killing_owner == "" and _is_player_source(source): killing_owner = "player"
			var contribution: int = int(run.get("combat_contributions", {}).get(entity_id, 0))
			if killing_owner == "player":
				run.kills = int(run.kills) + 1
				_award_xp(int(entity.get("xp", 10)), "kill")
				_emit_combat_event("KillCredit", "player", entity_id, {"xp": int(entity.get("xp", 10)), "credit": "full"})
				if entity.faction in ["Adventurers", "Beasts", "Goblinoids", "Bandits"]:
					run.living_kills = int(run.living_kills) + 1
				_emit_trigger("OnKill", {"entity_id": entity_id, "faction": entity.faction, "pos": entity.pos.duplicate()})
			elif contribution > 0:
				var assist_xp := maxi(1, int(floor(float(entity.get("xp", 10)) * 0.5)))
				run.assists = int(run.get("assists", 0)) + 1
				_award_xp(assist_xp, "assist")
				_emit_combat_event("KillCredit", "player", entity_id, {"xp": assist_xp, "credit": "assist"})
			else:
				_emit_combat_event("KillCredit", "", entity_id, {"xp": 0, "credit": "none"})
		var contributions_after_kill: Dictionary = run.get("combat_contributions", {})
		contributions_after_kill.erase(entity_id)
		run.combat_contributions = contributions_after_kill
	_add_log("%s falls." % entity.get("name", "A creature"))
	if entity.get("kind") == "boss":
		run.outcome = "victory"
		_complete_stage()
		_add_log("The Grave Tyrant is defeated. The March is yours.")
	_check_objective()

func _award_xp(amount: int, reason: String = "encounter") -> void:
	if amount <= 0:
		return
	run.xp = int(run.xp) + amount
	_emit_combat_event("XPGranted", "player", "", {"amount": amount, "reason": reason})
	while int(run.xp) >= int(run.level) * 35:
		run.xp = int(run.xp) - int(run.level) * 35
		run.level = int(run.level) + 1
		run.skill_points = int(run.skill_points) + 1
		var player := get_player()
		player.max_hp = int(player.max_hp) + 2
		player.hp = mini(int(player.max_hp), int(player.hp) + 2)
		var growth: Dictionary = _apply_automatic_growth()
		_emit_combat_event("LevelUp", "player", "", {"level": int(run.level), "xp": int(run.xp), "max_hp": 2, "skill_points": 1, "attribute": growth.get("attribute", ""), "attribute_value": growth.get("value", 0)})
		_add_log("Level %d · +2 Max Health · 1 ability point%s." % [run.level, " · +1 %s" % growth.attribute if growth.get("attribute", "") != "" else ""])

func _apply_automatic_growth() -> Dictionary:
	if int(run.level) % 2 != 0:
		return {}
	var profile: Array = content.get("characters", {}).get(run.get("character_id", ""), {}).get("growth_profile", [])
	if profile.is_empty():
		return {}
	var milestone := int(run.get("growth_milestones", 0))
	var attribute := String(profile[milestone % profile.size()])
	if not run.get("attributes", {}).has(attribute):
		return {}
	run.attributes[attribute] = int(run.attributes[attribute]) + 1
	run.growth_milestones = milestone + 1
	return {"attribute": attribute, "value": int(run.attributes[attribute])}

func _credit_owner(source_id: String) -> String:
	if source_id == "player": return "player"
	var entity: Dictionary = run.get("entities", {}).get(source_id, {})
	if entity.get("owner", "") == "player": return "player"
	return ""

func _is_player_source(source: String) -> bool:
	if source in [String(get_player().get("name", "")), "Cinder Bomb", "the Ossuary Bell", "Phantom Blade"]:
		return true
	for ability_id in content.get("abilities", {}):
		if content.abilities[ability_id].get("name", "") == source:
			return true
	return false

func _apply_status(entity_id: String, status_id: String, stacks: int, source: String = "", source_id: String = "") -> void:
	if not run.entities.has(entity_id) or not run.entities[entity_id].get("alive", true):
		return
	var definition: Dictionary = content.get("statuses", {}).get(status_id, {"max_stacks": 1, "duration": 1})
	var statuses: Dictionary = run.entities[entity_id].get("statuses", {})
	var current: Dictionary = statuses.get(status_id, {"stacks": 0, "duration": 0})
	current.stacks = mini(int(definition.get("max_stacks", 1)), int(current.get("stacks", 0)) + stacks)
	current.duration = maxi(int(current.get("duration", 0)), int(definition.get("duration", 1)))
	if source != "":
		current.source = source
	if source_id != "":
		current.source_actor_id = source_id
	statuses[status_id] = current
	run.entities[entity_id].statuses = statuses
	_emit_combat_event("StatusApplied", source_id, entity_id, {"status": status_id, "stacks": stacks})
	if definition.get("harmful", false) and _credit_owner(source_id) == "player" and entity_id != "player" and _is_hostile("player", entity_id):
		var contributions: Dictionary = run.get("combat_contributions", {})
		contributions[entity_id] = int(contributions.get(entity_id, 0)) + 1
		run.combat_contributions = contributions
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
			_emit_combat_event("StatusTick", String(status.get("source_actor_id", "")), entity_id, {"status": status_id})
			_damage(entity_id, tick_damage, String(definition.get("damage", "Arcane")), String(status.get("source", status_id)), String(status.get("source_actor_id", "")))
		if not run.entities[entity_id].get("alive", true):
			return
		status.duration = int(status.get("duration", 0)) - 1
		if int(status.duration) <= 0:
			statuses.erase(status_id)
			_emit_combat_event("StatusRemoved", "", entity_id, {"status": status_id})
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
	stamina[0] = mini(int(stamina[1]), int(stamina[0]) + int(elapsed / 55) * (2 + int(round(get_passive_modifier("stamina_regen_bonus")))))
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
	_emit_combat_event("EncounterComplete", "player", "", {"stage": String(run.get("stage_id", ""))})
	run.encounters_completed = int(run.encounters_completed) + 1
	var clear_xp := 15 + mini(int(run.stage_index), 4) * 3
	_award_xp(clear_xp)
	_add_log("The route rewards %d experience." % clear_xp)
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
	_emit_combat_event("TerrainChanged", "", "", {"pos": [cell.x, cell.y], "terrain": result})

func _recompute_armor() -> void:
	var total := 0
	for slot in run.equipment:
		var item_id: String = run.equipment[slot]
		if item_id == "" or item_id == "occupied":
			continue
		total += int(content.items.get(item_id, {}).get("armor", 0))
	get_player().armor = total + int(round(get_passive_modifier("armor_bonus")))

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
					_apply_status(String(effect.get("target", "player")), String(effect.get("id", "")), int(effect.get("stacks", 1)), String(rule.get("source", "")), "player" if owner_type in ["aura", "artifact", "ability"] else "")
				"repeat_cast_damage":
					var ability_id: String = context.get("ability_id", "")
					if content.abilities.has(ability_id):
						for ability_effect in content.abilities[ability_id].get("effects", []):
							if ability_effect.get("type") != "damage":
								continue
							for target_id in context.get("targets", []):
								_damage(String(target_id), int(round(float(ability_effect.amount) * float(effect.get("multiplier", 0.5)))), String(ability_effect.damage), String(rule.get("source", owner_id)), "player")
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
