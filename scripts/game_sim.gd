extends RefCounted
class_name ArcanistSim

const WIDTH := 25
const HEIGHT := 16
const SAVE_PATH := "user://run_save.json"
const CODEX_PATH := "user://codex.json"
const PROFILE_PATH := "user://profile.json"
const SAVE_VERSION := 4
const STAGE_ENTRY_HEAL_PERCENT := 0.05
const BASE_ENEMY_HEALTH_GROWTH := 0.12
const BASE_ENEMY_DAMAGE_GROWTH := 0.085
const BASE_ENEMY_ARMOR_GROWTH := 0.035
const LATE_ENEMY_COUNT_PER_LOG_DEPTH := 1.15
const MAX_SAFE_COMBAT_STAT := 1000000000000000.0
const ContentRegistry = preload("res://scripts/content_registry.gd")
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]
const STAGE_ORDER := ["ruined_village", "graveyard", "flooded_ruins", "goblin_warrens", "thornwood"]

var content: Dictionary = {}
var run: Dictionary = {}
var profile: Dictionary = {}
var content_registry
var package_load_errors: Array[String] = []
var codex: Dictionary = {"creatures": [], "abilities": [], "spellbooks": [], "artifacts": [], "schools": []}
var _rng := RandomNumberGenerator.new()
var _recording_presentation := false
var _action_presentation_events: Array = []
var _active_ability_id := ""
var _active_attack_tags: Array = []
var _action_movement_occurred := false
var _active_actor_id := "player"
var _current_action_kills: Array[String] = []
var _active_action_hit_ids: Array[String] = []
var _action_qualifying_technique_movement := false

func _init() -> void:
	content_registry = ContentRegistry.new()
	var loaded: Dictionary = content_registry.load_from_disk([])
	content = loaded.get("content", {})
	package_load_errors = loaded.get("errors", [])
	_load_profile()
	var enabled_packages: Array = profile.get("enabled_package_ids", [])
	if not enabled_packages.is_empty():
		loaded = content_registry.load_from_disk(enabled_packages)
		content = loaded.get("content", content)
		package_load_errors = loaded.get("errors", [])
	_load_profile()
	if not enabled_packages.is_empty():
		var package_content_errors := validate_content()
		if not package_content_errors.is_empty():
			var invalid_errors := package_content_errors.duplicate()
			loaded = content_registry.load_from_disk([])
			content = loaded.get("content", content)
			package_load_errors = invalid_errors
	_load_codex()

func _load_profile() -> void:
	profile = {"version": 1, "unlocked_character_ids": [], "pending_character_reveals": [], "enabled_package_ids": [], "last_run_summary": {}}
	if FileAccess.file_exists(PROFILE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
		if parsed is Dictionary:
			profile.merge(parsed, true)
	var starters: Array[String] = []
	for character_id in content.get("characters", {}):
		if bool(content.characters[character_id].get("starting", false)):
			starters.append(String(character_id))
	starters.sort()
	var unlocked: Array = profile.get("unlocked_character_ids", [])
	for character_id in starters:
		if not unlocked.has(character_id): unlocked.append(character_id)
	profile["unlocked_character_ids"] = unlocked
	profile["pending_character_reveals"] = profile.get("pending_character_reveals", [])
	profile["enabled_package_ids"] = profile.get("enabled_package_ids", [])

func save_profile() -> bool:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(profile))
	file.close()
	return true

func get_starting_character_ids() -> Array[String]:
	var result: Array[String] = []
	for character_id in content.get("characters", {}):
		if bool(content.characters[character_id].get("starting", false)):
			result.append(String(character_id))
	result.sort_custom(func(a: String, b: String) -> bool:
		return int(content.characters[a].get("selection_order", 99)) < int(content.characters[b].get("selection_order", 99))
	)
	return result

func get_unlocked_character_ids() -> Array[String]:
	var result: Array[String] = []
	for character_id in content.get("characters", {}):
		if is_character_unlocked(String(character_id)):
			result.append(String(character_id))
	result.sort_custom(func(a: String, b: String) -> bool:
		return int(content.characters[a].get("selection_order", 99)) < int(content.characters[b].get("selection_order", 99))
	)
	return result

func is_character_unlocked(character_id: String) -> bool:
	return profile.get("unlocked_character_ids", []).has(character_id) and content.get("characters", {}).has(character_id)

func unlock_character(character_id: String) -> bool:
	if not content.get("characters", {}).has(character_id): return false
	var unlocked: Array = profile.get("unlocked_character_ids", [])
	if unlocked.has(character_id): return false
	unlocked.append(character_id)
	profile["unlocked_character_ids"] = unlocked
	var reveals: Array = profile.get("pending_character_reveals", [])
	if not reveals.has(character_id): reveals.append(character_id)
	profile["pending_character_reveals"] = reveals
	save_profile()
	return true

func consume_character_reveal(character_id: String) -> void:
	var reveals: Array = profile.get("pending_character_reveals", [])
	reveals.erase(character_id)
	profile["pending_character_reveals"] = reveals
	save_profile()

func get_pending_character_reveal() -> String:
	var reveals: Array = profile.get("pending_character_reveals", [])
	for character_id in reveals:
		if is_character_unlocked(String(character_id)):
			return String(character_id)
	return ""

func get_character_unlock_requirement(character_id: String) -> String:
	var definition: Dictionary = content.get("characters", {}).get(character_id, {})
	var requirement := String(definition.get("unlock_requirement", "Not yet defined."))
	var unlock_id := String(definition.get("unlock_id", ""))
	var unlock_definition: Dictionary = content.get("unlocks", {}).get(unlock_id, {})
	var requirements: Dictionary = unlock_definition.get("requirements", definition.get("unlock", {}))
	for condition in requirements.get("conditions", []):
		if String(condition.get("type", "")) == "counter":
			var counter_id := String(condition.get("id", ""))
			var required := int(condition.get("minimum", 1))
			var current := int(run.get(counter_id, 0)) if not run.is_empty() else 0
			var action_name := "successful Parries" if counter_id == "successful_parries" else "successful technique moves"
			return "Perform %d %s in one run (%d/%d)." % [required, action_name, mini(current, required), required]
	return requirement

func try_unlock_character(character_id: String, requirements: Variant) -> Dictionary:
	if not content.get("characters", {}).has(character_id):
		return {"ok": false, "reason": "Unknown character."}
	var result: Dictionary = evaluate_prerequisites(requirements)
	if not result.eligible:
		return {"ok": false, "reason": String(result.get("reason", "Requirements are not met."))}
	var unlocked := unlock_character(character_id)
	return {"ok": unlocked, "reason": "" if unlocked else "Character is already unlocked."}

func check_authored_character_unlocks() -> Array[String]:
	var newly_unlocked: Array[String] = []
	if run.is_empty():
		return newly_unlocked
	for character_id in content.get("characters", {}):
		if is_character_unlocked(String(character_id)):
			continue
		var definition: Dictionary = content.characters[character_id]
		var unlock_id := String(definition.get("unlock_id", ""))
		var unlock_definition: Variant = content.get("unlocks", {}).get(unlock_id, {}).get("requirements", definition.get("unlock", {}))
		if unlock_definition is Dictionary and unlock_definition.is_empty():
			continue
		var result: Dictionary = evaluate_prerequisites(unlock_definition)
		if bool(result.get("eligible", false)) and unlock_character(String(character_id)):
			newly_unlocked.append(String(character_id))
	return newly_unlocked

func set_package_enabled(package_id: String, enabled: bool) -> Dictionary:
	var requested: Array = profile.get("enabled_package_ids", []).duplicate()
	if not enabled and _active_run_uses_package(package_id):
		return {"ok": false, "enabled": requested, "error": "Finish or discard the saved run before disabling content it uses."}
	var package_result: Dictionary = content_registry.get_package_enable_closure(package_id, requested) if enabled else content_registry.get_package_disable_closure(package_id, requested)
	if not bool(package_result.get("ok", false)):
		return package_result
	var loaded: Dictionary = content_registry.load_from_disk(package_result.get("enabled", []))
	if not loaded.get("errors", []).is_empty():
		return {"ok": false, "enabled": requested, "error": "Package validation failed. Review the development log for details."}
	var previous_content: Dictionary = content
	var previous_errors: Array[String] = package_load_errors
	content = loaded.get("content", {})
	package_load_errors = loaded.get("errors", [])
	var content_errors := validate_content()
	if not content_errors.is_empty():
		content = previous_content
		package_load_errors = previous_errors
		return {"ok": false, "enabled": requested, "error": "Package validation failed. Review the development log for details."}
	profile["enabled_package_ids"] = package_result.get("enabled", [])
	var unlocked_ids: Array = profile.get("unlocked_character_ids", [])
	for starter_id in _starting_ids_for(loaded.get("content", {})):
		if not unlocked_ids.has(starter_id): unlocked_ids.append(starter_id)
	profile["unlocked_character_ids"] = unlocked_ids
	save_profile()
	return {"ok": true, "enabled": profile.enabled_package_ids, "error": ""}

func _active_run_uses_package(package_id: String) -> bool:
	if not run.is_empty() and String(run.get("outcome", "")) != "defeat" and run.get("package_ids", []).has(package_id):
		return true
	_recover_interrupted_save()
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return saved is Dictionary and saved.get("package_ids", []).has(package_id) and String(saved.get("outcome", "")) != "defeat"

func _starting_ids_for(definitions: Dictionary) -> Array:
	var result: Array = []
	for character_id in definitions.get("characters", {}):
		if bool(definitions.characters[character_id].get("starting", false)): result.append(character_id)
	return result

func validate_content() -> Array:
	var errors: Array = []
	errors.append_array(package_load_errors)
	var types: Array = content.get("damage_types", [])
	var valid_slots := ["Weapon", "Offhand", "Head", "Body", "Hands", "Feet", "Ring 1", "Ring 2", "Amulet"]
	var valid_targets := ["self", "enemy", "area", "tile", "passive"]
	var valid_effects := ["damage", "heal", "heal_on_hit", "move", "approach", "status", "summon", "teleport", "terrain", "resource", "radial_damage", "wide_arc_damage", "line_damage", "execute_damage", "heavy_damage", "advance_if_vacated", "reposition", "retreat", "knockback", "charge_line", "sweep", "dance_route"]
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
	var ability_categories: Dictionary = content.get("ability_categories", {})
	if ability_categories.is_empty():
		errors.append("ability_categories must define at least one category")
	for category_id in ability_categories:
		if String(ability_categories[category_id].get("name", "")).strip_edges() == "":
			errors.append("ability category %s has no display name" % category_id)
	for ability_id in content.get("abilities", {}):
		var ability: Dictionary = content.abilities[ability_id]
		var category_ids: Array = ability.get("categories", [])
		if category_ids.is_empty():
			errors.append("%s has no ability category metadata" % ability_id)
		for category_id in category_ids:
			if not ability_categories.has(category_id):
				errors.append("%s uses unknown ability category %s" % [ability_id, category_id])
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
		for prerequisite in ability.get("requires", []):
			if not content.get("abilities", {}).has(prerequisite):
				errors.append("%s requires unknown ability %s" % [ability_id, prerequisite])
		if ability.has("evolution"):
			var evolution: Dictionary = ability.evolution
			if not content.get("abilities", {}).has(evolution.get("from", "")):
				errors.append("%s evolves from an unknown ability %s" % [ability_id, String(evolution.get("from", ""))])
			if int(evolution.get("min_level", 1)) < 1: errors.append("%s has an invalid evolution ability level" % ability_id)
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
		for technique_id in enemy.get("techniques", []):
			if not content.get("abilities", {}).has(String(technique_id)):
				errors.append("%s references unknown martial technique %s" % [enemy_id, String(technique_id)])
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
		var exploration: Dictionary = stage.get("exploration_loot", {})
		if int(exploration.get("min_count", 0)) < 0 or int(exploration.get("max_count", 0)) < int(exploration.get("min_count", 0)):
			errors.append("%s has invalid exploration loot counts" % stage_id)
		for loot_type in exploration.get("types", []):
			if String(loot_type) not in ["chest", "skill_book", "item"]: errors.append("%s uses invalid exploration loot type %s" % [stage_id, String(loot_type)])
	for map_id in content.get("maps", {}):
		var map_definition: Dictionary = content.maps[map_id]
		if String(map_definition.get("name", "")) == "" or map_definition.get("stage_templates", []).is_empty():
			errors.append("%s needs a display name and at least one stage template" % String(map_id))
		if float(map_definition.get("weight", 1.0)) <= 0.0 or int(map_definition.get("minimum_depth", 1)) < 1 or int(map_definition.get("maximum_depth", 9223372036854775807)) < int(map_definition.get("minimum_depth", 1)):
			errors.append("%s has invalid map selection weights or depth eligibility" % String(map_id))
		for stage_template_id in map_definition.get("stage_templates", []):
			if not content.get("stages", {}).has(String(stage_template_id)):
				errors.append("%s references unknown stage template %s" % [String(map_id), String(stage_template_id)])
	for boss_id in content.get("bosses", {}):
		var boss_definition: Dictionary = content.bosses[boss_id]
		if not content.get("enemies", {}).has(String(boss_definition.get("enemy_id", boss_id))):
			errors.append("%s references an unknown boss enemy" % String(boss_id))
		if int(boss_definition.get("stage_only", 6)) != 6 or float(boss_definition.get("weight", 1.0)) <= 0.0 or int(boss_definition.get("minimum_depth", 1)) < 1:
			errors.append("%s has invalid boss eligibility or weight" % String(boss_id))
		for theme_id in boss_definition.get("themes", []):
			if not content.get("maps", {}).has(String(theme_id)):
				errors.append("%s references unknown map theme %s" % [String(boss_id), String(theme_id)])
	for character_id in content.get("characters", {}):
		var character: Dictionary = content.characters[character_id]
		for school in character.get("schools", []):
			if not content.get("progression", {}).get("schools", []).has(school): errors.append("%s starts with unknown magic school %s" % [character_id, String(school)])
		for discipline in character.get("disciplines", []):
			if discipline != "" and not content.get("progression", {}).get("disciplines", []).has(discipline): errors.append("%s starts with unknown discipline %s" % [character_id, String(discipline)])
		for tag in character.get("affinities", {}):
			if not content.get("tag_registry", {}).has(String(tag)): errors.append("%s has an unknown affinity tag %s" % [character_id, String(tag)])
		if not content.weapons.has(character.get("weapon", "")):
			errors.append("%s starts with unknown weapon" % character_id)
		var portrait_path := String(character.get("portrait_path", ""))
		if portrait_path != "" and not FileAccess.file_exists(portrait_path) and not ResourceLoader.exists(portrait_path):
			errors.append("%s references missing portrait asset %s" % [character_id, portrait_path])
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
	errors.append_array(_validate_definition_metadata())
	return errors

func _validate_definition_metadata() -> Array[String]:
	var found: Array[String] = []
	for section_name in content:
		if String(section_name) in ["tag_registry", "progression"] or not content[section_name] is Dictionary:
			continue
		for definition_id in content[section_name]:
			var definition: Variant = content[section_name][definition_id]
			if not definition is Dictionary:
				found.append("%s has a malformed content definition in section %s" % [String(definition_id), String(section_name)])
				continue
			if definition.has("tags"):
				if not definition.tags is Array:
					found.append("%s has malformed content tags" % String(definition_id))
				else:
					for tag in definition.tags:
						if not content.get("tag_registry", {}).has(String(tag)):
							found.append("%s references unknown content tag %s" % [String(definition_id), String(tag)])
			for prerequisite_key in ["prerequisites", "unlock"]:
				if definition.has(prerequisite_key):
					found.append_array(_validate_prerequisite_definition(definition[prerequisite_key], String(definition_id)))
			if definition.has("evolution"):
				var evolution: Variant = definition.evolution
				if not evolution is Dictionary:
					found.append("%s has malformed evolution metadata" % String(definition_id))
				elif evolution.has("prerequisites"):
					found.append_array(_validate_prerequisite_definition(evolution.prerequisites, String(definition_id)))
	return found

func _validate_prerequisite_definition(requirements: Variant, owner_id: String) -> Array[String]:
	var found: Array[String] = []
	if requirements == null or (requirements is Dictionary and requirements.is_empty()): return found
	if not requirements is Dictionary:
		found.append("%s has malformed prerequisite metadata" % owner_id)
		return found
	for list_key in ["tags", "requires", "all_of", "any_of", "schools", "disciplines", "characters", "artifacts", "conditions"]:
		if requirements.has(list_key) and not requirements[list_key] is Array:
			found.append("%s has a malformed '%s' prerequisite list" % [owner_id, list_key])
	if not found.is_empty(): return found
	for dictionary_key in ["school_ranks", "discipline_ranks", "resources"]:
		if requirements.has(dictionary_key) and not requirements[dictionary_key] is Dictionary:
			found.append("%s has malformed '%s' prerequisite values" % [owner_id, dictionary_key])
			return found
	for tag in requirements.get("tags", []):
		if not content.get("tag_registry", {}).has(String(tag)):
			found.append("%s requires unknown content tag %s" % [owner_id, String(tag)])
	for ability_key in ["requires", "all_of", "any_of"]:
		for ability_id in requirements.get(ability_key, []):
			if not content.get("abilities", {}).has(ability_id):
				found.append("%s requires unknown ability %s" % [owner_id, String(ability_id)])
	var progression: Dictionary = content.get("progression", {})
	for school in requirements.get("schools", []):
		if not progression.get("schools", []).has(school): found.append("%s requires unknown magic school %s" % [owner_id, String(school)])
	for school in requirements.get("school_ranks", {}):
		if not progression.get("schools", []).has(school): found.append("%s has a rank requirement for unknown magic school %s" % [owner_id, String(school)])
	for discipline in requirements.get("disciplines", []):
		if not progression.get("disciplines", []).has(discipline): found.append("%s requires unknown discipline %s" % [owner_id, String(discipline)])
	for discipline in requirements.get("discipline_ranks", {}):
		if not progression.get("disciplines", []).has(discipline): found.append("%s has a rank requirement for unknown discipline %s" % [owner_id, String(discipline)])
	for rank in requirements.get("school_ranks", {}).values():
		if int(rank) < 1: found.append("%s has an invalid school rank requirement" % owner_id)
	for rank in requirements.get("discipline_ranks", {}).values():
		if int(rank) < 1: found.append("%s has an invalid discipline rank requirement" % owner_id)
	for character_id in requirements.get("characters", []):
		if not content.get("characters", {}).has(character_id): found.append("%s requires unknown character %s" % [owner_id, String(character_id)])
	for artifact_id in requirements.get("artifacts", []):
		if not content.get("artifacts", {}).has(artifact_id): found.append("%s requires unknown artifact %s" % [owner_id, String(artifact_id)])
	for resource_id in requirements.get("resources", {}):
		if not content.get("resources", []).has(resource_id): found.append("%s requires unknown resource %s" % [owner_id, String(resource_id)])
		elif int(requirements.resources[resource_id]) < 0: found.append("%s has an invalid amount for resource %s" % [owner_id, String(resource_id)])
	for condition in requirements.get("conditions", []):
		var condition_error := _validate_condition_definition(condition, owner_id)
		if condition_error != "": found.append(condition_error)
	return found

func _validate_condition_definition(condition: Variant, owner_id: String) -> String:
	if not condition is Dictionary:
		return "%s has a malformed prerequisite condition" % owner_id
	for operator in ["all", "any"]:
		if condition.has(operator):
			if not condition[operator] is Array: return "%s has a malformed '%s' prerequisite list" % [owner_id, operator]
			for nested in condition.get(operator, []):
				var nested_error := _validate_condition_definition(nested, owner_id)
				if nested_error != "": return nested_error
			return ""
	if condition.has("not"):
		return _validate_condition_definition(condition.get("not"), owner_id)
	var condition_type := String(condition.get("type", ""))
	var content_id := String(condition.get("id", ""))
	if condition_type == "tags":
		for tag in condition.get("ids", []):
			if not content.get("tag_registry", {}).has(String(tag)): return "%s requires unknown content tag %s" % [owner_id, String(tag)]
		return ""
	if condition_type == "owned_tags":
		if not condition.get("ids", []) is Array or condition.get("ids", []).is_empty(): return "%s has an empty owned-tag prerequisite" % owner_id
		for tag in condition.get("ids", []):
			if not content.get("tag_registry", {}).has(String(tag)): return "%s requires unknown content tag %s" % [owner_id, String(tag)]
		return ""
	if condition_type == "tag":
		return "" if content.get("tag_registry", {}).has(content_id) else "%s requires unknown content tag %s" % [owner_id, content_id]
	if condition_type == "ability" and not content.get("abilities", {}).has(content_id): return "%s requires unknown ability %s" % [owner_id, content_id]
	if condition_type in ["item", "equipment"] and not content.get("items", {}).has(content_id): return "%s requires unknown item %s" % [owner_id, content_id]
	if condition_type == "weapon" and not content.get("weapons", {}).has(content_id): return "%s requires unknown weapon %s" % [owner_id, content_id]
	if condition_type == "stat" and content_id not in ["Might", "Dexterity", "Vitality", "Intelligence", "Willpower", "Perception"]: return "%s requires unknown attribute %s" % [owner_id, content_id]
	if condition_type == "stat" and int(condition.get("minimum", condition.get("value", 0))) < 1: return "%s has an invalid stat threshold" % owner_id
	if condition_type == "summon_count":
		if int(condition.get("minimum", 0)) < 1: return "%s has an invalid summon-count threshold" % owner_id
		if String(condition.get("owner", "player")) not in ["player", "any"]: return "%s has an invalid summon owner prerequisite" % owner_id
		var required_faction := String(condition.get("faction", ""))
		if required_faction == "": return "%s has an empty summon faction prerequisite" % owner_id
		var faction_exists := false
		for creature in content.get("enemies", {}).values():
			if String(creature.get("faction", "")) == required_faction: faction_exists = true
		for creature in content.get("summons", {}).values():
			if String(creature.get("faction", "")) == required_faction: faction_exists = true
		if not faction_exists: return "%s requires unknown summon faction %s" % [owner_id, required_faction]
	if condition_type in ["artifact", "relic"] and not content.get("artifacts", {}).has(content_id): return "%s requires unknown artifact %s" % [owner_id, content_id]
	if condition_type == "character" and not content.get("characters", {}).has(content_id): return "%s requires unknown character %s" % [owner_id, content_id]
	if condition_type == "package" and not content_registry._package_is_available(content_id): return "%s requires unavailable package %s" % [owner_id, content_id]
	if condition_type == "school" and not content.get("progression", {}).get("schools", []).has(content_id): return "%s requires unknown magic school %s" % [owner_id, content_id]
	if condition_type == "discipline" and not content.get("progression", {}).get("disciplines", []).has(content_id): return "%s requires unknown discipline %s" % [owner_id, content_id]
	if condition_type == "resource" and not content.get("resources", []).has(content_id): return "%s requires unknown resource %s" % [owner_id, content_id]
	if condition_type == "level" and int(condition.get("value", condition.get("level", 1))) < 1: return "%s has an invalid level prerequisite" % owner_id
	if condition_type == "counter" and String(condition.get("id", "")) not in ["successful_parries", "technique_movement_actions"]: return "%s uses an unknown progression counter" % owner_id
	if condition_type == "counter" and int(condition.get("minimum", 0)) < 1: return "%s has an invalid progression counter threshold" % owner_id
	if condition_type == "boss_defeated" and not content.get("bosses", {}).has(content_id): return "%s requires unknown boss %s" % [owner_id, content_id]
	if condition_type == "resource" and int(condition.get("amount", condition.get("value", 1))) < 0: return "%s has an invalid resource prerequisite" % owner_id
	if condition_type == "discovery" and String(condition.get("id", "")).strip_edges() == "": return "%s has an empty discovery prerequisite" % owner_id
	if condition_type not in ["ability", "item", "equipment", "weapon", "stat", "stage_completed", "summon_count", "owned_tags", "artifact", "relic", "character", "package", "level", "school", "discipline", "discovery", "resource", "counter", "boss_defeated"]: return "%s uses unknown prerequisite type %s" % [owner_id, condition_type]
	return ""

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
	if not is_character_unlocked(character_id):
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
		"version": SAVE_VERSION, "seed": seed_value, "rng_state": str(_rng.state), "character_id": character_id,
		"character": definition.name, "aura": definition.aura, "discipline": definition.discipline,
		"schools": definition.schools.duplicate(), "disciplines": definition.get("disciplines", [definition.get("discipline", "")]).duplicate(),
		"discoveries": [], "school_ranks": {}, "discipline_ranks": {}, "attributes": definition.attributes.duplicate(true),
		"character_affinities": definition.get("affinities", {}).duplicate(true), "build_tag_counts": {},
		"entities": {}, "grid": [], "visible": [], "explored": [], "objects": [], "corpses": [],
		"equipment": equipment, "inventory": inventory, "artifacts": [], "relics": [], "known": definition.known.duplicate(),
		"temporary_abilities": {}, "xp": 0, "level": 1, "skill_points": 0, "kills": 0, "assists": 0,
		"growth_milestones": 0, "quickbar": [], "quickbar_customized": false,
		"combat_history": [], "combat_contributions": {}, "combat_event_sequence": 0,
		"time": 0, "turn": 0, "stage_index": 0, "map_depth": "1", "maps_completed": "0", "stages_completed": "0", "bosses_defeated": "0", "current_map_index": 0,
		"map_history": [], "current_map": {}, "next_map": {}, "map_reveal_pending": false, "map_reveal_index": -1, "map_complete_pending": false,
		"enemies_defeated": "0", "exploration_rewards_found": 0,
		"encounters_completed": 0,
		"stage_id": "", "objective": {}, "stage_completed": false, "stage_prompt_dismissed": false, "reward_choices": [], "reward_choice_resolved": false, "reward_chosen_index": -1,
		"pending_summon_transfers": [], "last_stage_heal_transition_key": "",
		"route_choices": [], "route": ["ruined_village"], "outcome": "", "log": ["The March stirs beyond the gate."],
		"fire_cast_count": 0, "living_kills": 0, "boss_summoned": false, "discovered_books": [], "spellbook_resolutions": {}, "trigger_counts": {}, "ability_states": {},
		"package_ids": content_registry.load_order.filter(func(package_id: String) -> bool: return package_id != "core"),
		"successful_parries": 0, "technique_movement_actions": 0, "player_action_count": 0,
		"berserker_power_used": false, "stage_technique_used": false, "encounter_technique_used": false,
		"weapon_state": {"unhurt_actions": 0, "precision": 0, "technique_kill_stacks": 0, "last_action_kind": "", "followup_basic": false},
		"last_player_action": {}, "boss_unlocks_awarded": []
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
	run.current_map = _generate_map(1, "", "ruined_village")
	run.map_history = [run.current_map.duplicate(true)]
	_new_stage(String(run.current_map.stage_templates[0]), false, true)
	_recompute_armor()
	_save_codex()
	save_profile()
	return true

func resume_run() -> bool:
	_recover_interrupted_save()
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (parsed is Dictionary) or int(parsed.get("version", 0)) not in [1, 2, 3, SAVE_VERSION]:
		return false
	run = _migrate_run_data(_canonicalize(parsed))
	var saved_character_id := String(run.get("character_id", "jim"))
	if content.get("characters", {}).has(saved_character_id):
		if not is_character_unlocked(saved_character_id):
			# Keep an existing expedition playable when an older save predates profile unlock data.
			unlock_character(saved_character_id)
		run["character"] = String(content.characters[saved_character_id].get("name", saved_character_id))
		run["character_affinities"] = content.characters[saved_character_id].get("affinities", {}).duplicate(true)
		if run.get("entities", {}).has("player"):
			run.entities.player["name"] = run.character
	run["build_tag_counts"] = run.get("build_tag_counts", {})
	run["character_affinities"] = run.get("character_affinities", content.get("characters", {}).get(saved_character_id, {}).get("affinities", {})).duplicate(true)
	run["stage_prompt_dismissed"] = bool(run.get("stage_prompt_dismissed", false))
	run["ability_states"] = run.get("ability_states", {})
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
	run["schools"] = run.get("schools", [])
	run["discoveries"] = run.get("discoveries", [])
	run["school_ranks"] = run.get("school_ranks", {})
	run["discipline_ranks"] = run.get("discipline_ranks", {})
	run["schools"].erase("Arcane")
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
	if String(run.get("outcome", "")) == "defeat":
		profile["last_run_summary"] = get_summary()
		save_profile()
		delete_saved_run()
		return true
	run["rng_state"] = str(_rng.state)
	run = _canonicalize(run)
	var temporary_path := SAVE_PATH + ".tmp"
	var backup_path := SAVE_PATH + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(run))
	file.close()
	var absolute_save := ProjectSettings.globalize_path(SAVE_PATH)
	var absolute_temp := ProjectSettings.globalize_path(temporary_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path): DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(SAVE_PATH) and DirAccess.rename_absolute(absolute_save, absolute_backup) != OK:
		DirAccess.remove_absolute(absolute_temp)
		return false
	if DirAccess.rename_absolute(absolute_temp, absolute_save) != OK:
		if FileAccess.file_exists(backup_path): DirAccess.rename_absolute(absolute_backup, absolute_save)
		return false
	if FileAccess.file_exists(backup_path): DirAccess.remove_absolute(absolute_backup)
	_save_codex()
	return true

func has_saved_run() -> bool:
	_recover_interrupted_save()
	return FileAccess.file_exists(SAVE_PATH)

func _recover_interrupted_save() -> void:
	var save_exists := FileAccess.file_exists(SAVE_PATH)
	var backup_path := SAVE_PATH + ".bak"
	var temp_path := SAVE_PATH + ".tmp"
	var backup_valid := _is_valid_run_file(backup_path)
	var save_valid := _is_valid_run_file(SAVE_PATH)
	if backup_valid and not save_valid:
		if save_exists: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(SAVE_PATH))
		return
	if not save_exists and _is_valid_run_file(temp_path):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(SAVE_PATH))
		return
	if save_valid and FileAccess.file_exists(backup_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
	if FileAccess.file_exists(temp_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))

func _is_valid_run_file(path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed is Dictionary and int(parsed.get("version", 0)) in [1, 2, 3, SAVE_VERSION] and parsed.has("entities")

func delete_saved_run() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	for suffix in [".tmp", ".bak"]:
		var path: String = SAVE_PATH + suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _migrate_run_data(saved_run: Dictionary) -> Dictionary:
	var migrated: Dictionary = saved_run.duplicate(true)
	var old_version := int(migrated.get("version", 1))
	if old_version <= 1:
		var old_route: Array = migrated.get("route", []).duplicate()
		var source_stage := String(migrated.get("stage_id", "ruined_village"))
		var normal_route: Array[String] = []
		for stage_id in old_route:
			if content.get("stages", {}).has(String(stage_id)) and String(stage_id) != "grave_tyrant":
				normal_route.append(String(stage_id))
		if normal_route.is_empty(): normal_route.append(source_stage if content.get("stages", {}).has(source_stage) else "ruined_village")
		var theme_id := normal_route[0]
		if not content.get("maps", {}).has(theme_id): theme_id = "ruined_village"
		_rng.seed = int(migrated.get("seed", 1))
		var migrated_map := _generate_map(1, "", theme_id)
		if migrated_map.is_empty(): migrated_map = _generate_map(1, "", "ruined_village")
		var stage_templates: Array = migrated_map.get("stage_templates", ["ruined_village"])
		for index in range(mini(5, normal_route.size())):
			stage_templates[index] = normal_route[index]
		for index in range(normal_route.size(), 5):
			stage_templates[index] = String(stage_templates[index - 1]) if index > 0 else theme_id
		migrated_map["stage_templates"] = stage_templates
		if int(migrated.get("stage_index", 0)) < 5:
			var current_index := clampi(int(migrated.get("stage_index", 0)), 0, 4)
			if content.get("stages", {}).has(source_stage): stage_templates[current_index] = source_stage
			var plans: Array = migrated_map.get("stage_plans", [])
			while plans.size() < 5: plans.append(_make_encounter_plan(String(stage_templates[plans.size()]), 1, plans.size()))
			plans[current_index] = _make_encounter_plan(String(stage_templates[current_index]), 1, current_index)
			migrated_map["stage_plans"] = plans
		migrated_map["boss_id"] = "grave_tyrant"
		migrated["current_map"] = migrated_map
		migrated["map_history"] = [migrated_map.duplicate(true)]
		migrated["current_map_index"] = 0
		migrated["map_depth"] = "1"
		migrated["maps_completed"] = "0"
		migrated["stages_completed"] = str(int(migrated.get("encounters_completed", 0)))
		migrated["bosses_defeated"] = "1" if String(migrated.get("outcome", "")) == "victory" else "0"
		migrated["enemies_defeated"] = str(int(migrated.get("kills", 0)))
		migrated["exploration_rewards_found"] = 0
		migrated["map_reveal_pending"] = false
		migrated["map_reveal_index"] = -1
		migrated["next_map"] = {}
		if String(migrated.get("outcome", "")) == "victory":
			migrated["outcome"] = ""
			migrated["stage_completed"] = true
			migrated["maps_completed"] = "1"
			migrated_map["completed"] = true
			migrated["current_map"] = migrated_map
			migrated["map_history"] = [migrated_map.duplicate(true)]
			migrated["map_complete_pending"] = true
		else:
			migrated["map_complete_pending"] = false
		migrated["version"] = SAVE_VERSION
	else:
		migrated["map_depth"] = _normalize_depth(migrated.get("map_depth", "1"))
		migrated["maps_completed"] = _normalize_counter(migrated.get("maps_completed", "0"))
		migrated["stages_completed"] = _normalize_counter(migrated.get("stages_completed", migrated.get("encounters_completed", 0)))
		migrated["bosses_defeated"] = _normalize_counter(migrated.get("bosses_defeated", 0))
		migrated["enemies_defeated"] = _normalize_counter(migrated.get("enemies_defeated", migrated.get("kills", 0)))
		migrated["exploration_rewards_found"] = int(migrated.get("exploration_rewards_found", 0))
		migrated["map_history"] = migrated.get("map_history", [])
		migrated["current_map_index"] = int(migrated.get("current_map_index", maxi(0, migrated.map_history.size() - 1)))
		migrated["map_reveal_pending"] = bool(migrated.get("map_reveal_pending", false))
		migrated["map_reveal_index"] = int(migrated.get("map_reveal_index", -1))
		migrated["next_map"] = migrated.get("next_map", {})
		migrated["map_complete_pending"] = bool(migrated.get("map_complete_pending", false))
		if migrated.get("current_map", {}).is_empty():
			var fallback_theme := String(migrated.get("stage_id", "ruined_village"))
			if not content.get("maps", {}).has(fallback_theme): fallback_theme = "ruined_village"
			migrated["current_map"] = _generate_map(migrated.map_depth, "", fallback_theme)
		if migrated.map_history.is_empty():
			migrated["map_history"] = [migrated.current_map.duplicate(true)]
	migrated["version"] = SAVE_VERSION
	migrated["package_ids"] = migrated.get("package_ids", profile.get("enabled_package_ids", []).duplicate()).duplicate()
	migrated["relics"] = migrated.get("relics", [])
	migrated["successful_parries"] = int(migrated.get("successful_parries", 0))
	migrated["technique_movement_actions"] = int(migrated.get("technique_movement_actions", 0))
	migrated["player_action_count"] = int(migrated.get("player_action_count", 0))
	migrated["berserker_power_used"] = bool(migrated.get("berserker_power_used", false))
	migrated["stage_technique_used"] = bool(migrated.get("stage_technique_used", false))
	migrated["encounter_technique_used"] = bool(migrated.get("encounter_technique_used", false))
	migrated["weapon_state"] = migrated.get("weapon_state", {"unhurt_actions": 0, "precision": 0, "technique_kill_stacks": 0, "last_action_kind": "", "followup_basic": false})
	migrated["last_player_action"] = migrated.get("last_player_action", {})
	migrated["boss_unlocks_awarded"] = migrated.get("boss_unlocks_awarded", [])
	migrated["pending_summon_transfers"] = migrated.get("pending_summon_transfers", [])
	migrated["last_stage_heal_transition_key"] = String(migrated.get("last_stage_heal_transition_key", ""))
	return migrated

func _format_map_number(map_number: Variant) -> String:
	return _normalize_depth(map_number)

func _normalize_depth(value: Variant) -> String:
	var digits := _normalize_counter(value)
	return "1" if digits == "0" else digits

func _normalize_counter(value: Variant) -> String:
	var digits := str(value).strip_edges()
	if digits.is_empty(): return "0"
	for character in digits:
		if not String(character) in "0123456789": return "0"
	var index := 0
	while index < digits.length() - 1 and digits.substr(index, 1) == "0": index += 1
	return digits.substr(index)

func _increment_decimal(value: String) -> String:
	var digits := _normalize_counter(value)
	var carry := 1
	for index in range(digits.length() - 1, -1, -1):
		var digit := int(digits.substr(index, 1)) + carry
		if digit >= 10:
			digits = digits.substr(0, index) + "0" + digits.substr(index + 1)
		else:
			digits = digits.substr(0, index) + str(digit) + digits.substr(index + 1)
			carry = 0
			break
	if carry == 1: digits = "1" + digits
	return digits

func _depth_log(depth_text: String) -> float:
	var digits := _normalize_depth(depth_text)
	var sample_length := mini(15, digits.length())
	var leading := float(digits.substr(0, sample_length))
	return log(maxf(1.0, leading)) + float(digits.length() - sample_length) * log(10.0)

func _depth_meets_minimum(depth_text: String, minimum: int) -> bool:
	return _compare_decimal(_normalize_depth(depth_text), str(maxi(1, minimum))) >= 0

func _depth_meets_maximum(depth_text: String, maximum: Variant) -> bool:
	if str(maximum).strip_edges() == "": return true
	return _compare_decimal(_normalize_depth(depth_text), _normalize_depth(maximum)) <= 0

func _compare_decimal(left: String, right: String) -> int:
	var a := _normalize_depth(left)
	var b := _normalize_depth(right)
	if a.length() < b.length(): return -1
	if a.length() > b.length(): return 1
	if a == b: return 0
	return -1 if a < b else 1

func get_player() -> Dictionary:
	return run.get("entities", {}).get("player", {})

func get_stage_name() -> String:
	return content.get("stages", {}).get(run.get("stage_id", ""), {}).get("name", "Graveyard")

func get_map_name() -> String:
	return String(run.get("current_map", {}).get("name", get_stage_name()))

func get_boss_name() -> String:
	var planned_boss := _get_map_boss_definition(run.get("current_map", {}))
	if planned_boss.is_empty():
		return "Boss"
	var boss: Dictionary = planned_boss.definition
	return String(boss.get("name", content.get("enemies", {}).get(String(planned_boss.enemy_id), {}).get("name", "Boss")))

func get_objective_text() -> String:
	var objective: Dictionary = run.get("objective", {})
	var kind: String = objective.get("kind", "Eliminate")
	if kind == "Eliminate":
		return "Clear the hostile creatures"
	if kind == "Boss":
		return "Defeat %s" % get_boss_name()
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
	var player_hp_before := int(get_player().get("hp", 0))
	_recording_presentation = true
	_action_presentation_events = []
	_action_movement_occurred = false
	_action_qualifying_technique_movement = false
	_current_action_kills = []
	_active_action_hit_ids = []
	var result := {"ok": false, "message": "That action is not available."}
	match String(command.get("type", "")):
		"move": result = _player_move(_as_cell(command.get("target", [0, 0])))
		"attack": result = _player_attack(_as_cell(command.get("target", [0, 0])))
		"cast": result = _cast(String(command.get("id", "")), _as_cell(command.get("target", [0, 0])))
		"berserker_pair": result = _resolve_berserker_pair(command.get("actions", []))
		"wait": result = _spend_player_time(100, "You wait and watch the battlefield.")
		"use_item": result = use_item(int(command.get("index", -1)), _as_cell(command.get("target", [0, 0])))
		"interact": result = _interact(_as_cell(command.get("target", [0, 0])))
	if result.get("ok", false):
		run["player_action_count"] = int(run.get("player_action_count", 0)) + 1
		if _action_qualifying_technique_movement:
			run["technique_movement_actions"] = int(run.get("technique_movement_actions", 0)) + 1
		if int(get_player().get("hp", 0)) >= player_hp_before:
			var weapon_state: Dictionary = run.get("weapon_state", {})
			weapon_state["unhurt_actions"] = int(weapon_state.get("unhurt_actions", 0)) + 1
			weapon_state["precision"] = mini(int(_run_modifier("precision_max_stacks", 0.0)), int(weapon_state.get("precision", 0)) + int(_run_modifier("precision_per_unhurt_action", 0.0)))
			run["weapon_state"] = weapon_state
		_update_vision()
		var newly_unlocked := check_authored_character_unlocks()
		if not newly_unlocked.is_empty():
			result["unlocked_characters"] = newly_unlocked
		save_run()
		result["presentation_before"] = display_before
		result["presentation_events"] = _action_presentation_events.duplicate(true)
	_recording_presentation = false
	_action_presentation_events = []
	return result

func is_berserker_offensive_action(action_type: String, action_id: String = "") -> bool:
	if action_type == "attack": return true
	if action_type != "cast" or not content.get("abilities", {}).has(action_id): return false
	var ability: Dictionary = content.abilities[action_id]
	if ability.get("kind", "active") == "passive" or ability.get("target", "enemy") == "passive": return false
	for effect in ability.get("effects", []):
		if String(effect.get("type", "")) in ["damage", "execute", "heavy_damage", "radial_damage", "wide_arc_damage", "line_damage", "sweep", "knockback", "charge_line", "dance_route", "status"]:
			if String(effect.get("type", "")) != "status" or String(ability.get("target", "enemy")) == "enemy": return true
	return false

func is_berserker_action_available(action_type: String, action_id: String = "") -> bool:
	if not is_berserker_offensive_action(action_type, action_id): return false
	if action_type == "attack": return bool(_targeting_definition("attack").get("available", false))
	var ability: Dictionary = content.abilities[action_id]
	if not run.get("known", []).has(action_id) and _ability_grant_source(action_id) == "" and int(run.get("temporary_abilities", {}).get(action_id, 0)) <= 0: return false
	var costs := _ability_effective_costs(action_id, ability)
	if not bool(get_cost_status(costs).get("affordable", false)) or _ability_cooldown_remaining(action_id) > 0: return false
	if String(ability.get("target", "enemy")) == "self": return true
	return bool(_targeting_definition(action_id).get("available", false))

func _berserker_action_target(action: Dictionary) -> Vector2i:
	return _as_cell(action.get("target", action.get("original_pos", [-1, -1])))

func _validate_berserker_pair_action(action: Dictionary, check_initial_position: bool = true) -> Dictionary:
	var action_type := String(action.get("type", ""))
	var action_id := String(action.get("id", "attack" if action_type == "attack" else ""))
	if not is_berserker_offensive_action(action_type, action_id): return {"ok": false, "message": "Choose two offensive actions."}
	var target_id := String(action.get("target_id", ""))
	if target_id == "" or not run.get("entities", {}).has(target_id) or not run.entities[target_id].get("alive", false) or not _is_hostile("player", target_id):
		return {"ok": false, "message": "The chosen foe is no longer available."}
	var current_pos := _pos(run.entities[target_id])
	var target_pos := _berserker_action_target(action)
	if check_initial_position and target_pos != current_pos:
		return {"ok": false, "message": "Choose the foe's current position."}
	var targeting_id := "attack" if action_type == "attack" else action_id
	if action_type == "cast" and String(content.abilities[action_id].get("target", "enemy")) == "self":
		var ability: Dictionary = content.abilities[action_id]
		var radius := int(ability.get("radius", 0))
		for effect in ability.get("effects", []): radius = maxi(radius, int(effect.get("radius", 0)))
		if radius <= 0 or _dist(_pos(get_player()), current_pos) > radius:
			return {"ok": false, "message": "That attack cannot reach its chosen foe."}
	elif not is_valid_target_cell(targeting_id, current_pos):
		return {"ok": false, "message": "That attack cannot reach its chosen foe."}
	return {"ok": true, "target_id": target_id, "target": current_pos, "type": action_type, "id": action_id}

func _resolve_berserker_pair(actions: Variant) -> Dictionary:
	if String(run.get("character_id", "")) != "berserker": return {"ok": false, "message": "Only the Berserker can unleash a paired attack."}
	if bool(run.get("berserker_power_used", false)): return {"ok": false, "message": "The Berserker's paired attack returns with the next map."}
	if not actions is Array or actions.size() != 2: return {"ok": false, "message": "Choose exactly two attacks."}
	var first: Dictionary = actions[0] if actions[0] is Dictionary else {}
	var second: Dictionary = actions[1] if actions[1] is Dictionary else {}
	var first_check := _validate_berserker_pair_action(first)
	if not first_check.ok: return first_check
	var second_check := _validate_berserker_pair_action(second)
	if not second_check.ok: return second_check
	if first.get("type", "") == "cast" and second.get("type", "") == "cast" and first.get("id", "") == second.get("id", ""):
		return {"ok": false, "message": "A technique can only be chosen once in the paired attack."}
	run["berserker_power_used"] = true
	var weapon: Dictionary = _equipped_weapon_definition()
	var first_time := int(weapon.get("time", 100)) if String(first.get("type", "")) == "attack" else int(content.abilities[String(first.get("id", ""))].get("time", 100))
	var second_time := int(weapon.get("time", 100)) if String(second.get("type", "")) == "attack" else int(content.abilities[String(second.get("id", ""))].get("time", 100))
	if _has_status("player", "Haste"):
		first_time = int(first_time * 0.8)
		second_time = int(second_time * 0.8)
	var first_result := _resolve_berserker_action(first_check)
	if not first_result.get("ok", false):
		return first_result
	var second_result := {"ok": false, "message": "The second strike has no valid target."}
	if not bool(run.get("stage_completed", false)):
		var target_id := String(second_check.target_id)
		var original_pos := _berserker_action_target(second)
		if run.get("entities", {}).has(target_id) and run.entities[target_id].get("alive", false) and _pos(run.entities[target_id]) == original_pos:
			second_result = _resolve_berserker_action(_validate_berserker_pair_action(second))
	if second_result.get("ok", false):
		_add_log("The Berserker completes the paired attack.")
	else:
		_add_log("The second strike is lost as its chosen target becomes unavailable.")
	var time_cost := maxi(first_time, second_time)
	var turn_result := _spend_player_time(time_cost, "")
	if not turn_result.get("ok", false): return turn_result
	return {"ok": true, "message": "", "second_action_resolved": bool(second_result.get("ok", false)), "second_action_message": String(second_result.get("message", ""))}

func _resolve_berserker_action(validated: Dictionary) -> Dictionary:
	var target: Vector2i = validated.target
	if String(validated.type) == "attack": return _player_attack(target, false)
	if String(content.abilities[String(validated.id)].get("target", "enemy")) == "self": target = _pos(get_player())
	return _cast(String(validated.id), target, false)

func learn_ability(ability_id: String) -> bool:
	if run.is_empty() or not content.abilities.has(ability_id) or int(run.skill_points) <= 0:
		return false
	var progression: Dictionary = get_ability_progress(ability_id)
	if not progression.get("learnable", false):
		return false
	var definition: Dictionary = content.abilities[ability_id]
	run.known.append(ability_id)
	_record_build_tags(definition.get("tags", []))
	run.skill_points -= 1
	_recompute_armor()
	_record_codex("abilities", ability_id)
	check_authored_character_unlocks()
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
	if bool(ability.get("combination", false)):
		var parents: Array = ability.get("prerequisites", {}).get("all_of", ability.get("requires", []))
		if parents.size() < 2 or not parents.all(func(parent: Variant) -> bool: return run.get("known", []).has(String(parent))):
			return {"visible": false, "learned": false, "learnable": false, "reason": "Both parent techniques must be owned."}
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
	var arcane_technique_known: bool = school == "Arcane" and run.get("known", []).any(func(known_id: String) -> bool: return content.get("abilities", {}).get(known_id, {}).get("tags", []).has("arcane"))
	var identity_known: bool = run.get("disciplines", [run.get("discipline", "")]).has(school) or is_discovered_school or arcane_technique_known
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
	for condition in prerequisites.get("conditions", []):
		var condition_result: Dictionary = _evaluate_condition(condition)
		if not condition_result.eligible:
			missing.append(String(condition_result.get("reason", "Additional requirements are unmet.")))
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

func _ability_grant_source(ability_id: String) -> String:
	for slot in run.get("equipment", {}):
		var equipped_id := String(run.equipment[slot])
		if equipped_id in ["", "occupied"]: continue
		var item: Dictionary = content.get("items", {}).get(equipped_id, {})
		var weapon_id := String(item.get("weapon", equipped_id)) if String(slot) == "Weapon" else ""
		var weapon: Dictionary = content.get("weapons", {}).get(weapon_id, {})
		if item.get("grants_abilities", []).has(ability_id) or weapon.get("grants_abilities", []).has(ability_id): return equipped_id
	return ""

func _ability_owned_or_granted(ability_id: String) -> bool:
	return run.get("known", []).has(ability_id) or int(run.get("temporary_abilities", {}).get(ability_id, 0)) > 0 or _ability_grant_source(ability_id) != ""

func _ability_cooldown_remaining(ability_id: String) -> int:
	return maxi(0, int(run.get("ability_cooldowns", {}).get(ability_id, 0)) - int(run.get("player_action_count", 0)))

func _ability_effective_costs(ability_id: String, ability: Dictionary) -> Dictionary:
	var costs: Dictionary = ability.get("costs", {}).duplicate(true)
	if not _is_swordplay_technique(ability): return costs
	var stamina_cost := int(costs.get("Stamina", 0))
	if stamina_cost <= 0: return costs
	var weapon := _equipped_weapon_definition()
	var weapon_modifiers: Dictionary = weapon.get("modifiers", {})
	if bool(ability.get("qualifying_movement", false)):
		stamina_cost -= int(weapon_modifiers.get("movement_technique_stamina_discount", 0))
	if not bool(run.get("stage_technique_used", false)):
		stamina_cost -= int(weapon_modifiers.get("first_technique_stamina_discount", 0))
		if float(_run_modifier("first_technique_stage_discount", 0.0)) > 0.0:
			stamina_cost -= int(_run_modifier("first_technique_stage_discount", 0.0))
		if float(_run_modifier("first_technique_free_per_stage", 0.0)) > 0.0:
			stamina_cost = 0
	var multiplier := _run_modifier("sword_technique_cost_multiplier", 1.0)
	stamina_cost = int(ceil(float(maxi(0, stamina_cost)) * maxf(0.0, multiplier)))
	costs["Stamina"] = maxi(0, stamina_cost)
	return costs

func _is_swordplay_technique(ability: Dictionary) -> bool:
	var tags: Array = ability.get("tags", [])
	return tags.has("technique") and (tags.has("sword") or tags.has("martial"))

func _equipped_weapon_definition() -> Dictionary:
	var weapon_id := String(run.get("equipment", {}).get("Weapon", "sword"))
	var item: Dictionary = content.get("items", {}).get(weapon_id, {})
	if item.has("weapon"): weapon_id = String(item.weapon)
	return content.get("weapons", {}).get(weapon_id, {})

func _run_modifier(modifier_id: String, default_value: float = 0.0) -> float:
	var total := _artifact_modifier(modifier_id, 0.0)
	for relic_id in run.get("relics", []):
		total += float(content.get("relics", {}).get(String(relic_id), {}).get("modifiers", {}).get(modifier_id, 0.0))
	total += float(_equipped_weapon_definition().get("modifiers", {}).get(modifier_id, 0.0))
	return total if total != 0.0 else default_value

func _actor_modifier(actor_id: String, modifier_id: String, default_value: float = 0.0) -> float:
	return _run_modifier(modifier_id, default_value) if actor_id == "player" else default_value

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

func get_visible_ability_categories() -> Array:
	var categories: Dictionary = content.get("ability_categories", {})
	var relevant: Dictionary = {}
	for ability_id in content.get("abilities", {}):
		var progress: Dictionary = get_ability_progress(String(ability_id))
		if not progress.get("visible", false):
			continue
		for category_id in content.abilities[ability_id].get("categories", []):
			if categories.has(category_id):
				relevant[String(category_id)] = categories[category_id]
	var result: Array = []
	for category_id in relevant:
		result.append({"id": String(category_id), "name": String(relevant[category_id].get("name", category_id)), "order": int(relevant[category_id].get("order", 99)), "glyph": String(relevant[category_id].get("glyph", "◇"))})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.order) == int(b.order):
			return String(a.id) < String(b.id)
		return int(a.order) < int(b.order)
	)
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
		_record_build_tags(content.get("artifacts", {}).get(String(reward.id), {}).get("tags", []))
		reward.claimed = true
	elif reward.get("type") == "relic":
		if not _acquire_relic(String(reward.id)): return false
		_record_build_tags(content.get("relics", {}).get(String(reward.id), {}).get("tags", []))
		reward.claimed = true
	else:
		if run.inventory.size() >= 30:
			_add_log("Your pack is full. Discard an item before claiming this.")
			return false
		run.inventory.append(String(reward.id))
		_record_build_tags(content.get("items", {}).get(String(reward.id), {}).get("tags", []))
		_add_log("Packed %s." % content.items[reward.id].name)
		reward.claimed = true
	run.reward_choice_resolved = true
	run.reward_chosen_index = index
	for choice_index in range(run.reward_choices.size()):
		var choice: Dictionary = run.reward_choices[choice_index]
		choice["available"] = false
		if choice_index == index:
			choice["claimed"] = true
	check_authored_character_unlocks()
	save_run()
	return true

func choose_route(stage_id: String) -> bool:
	# Compatibility entry point for older UI/tests. Route IDs now name a stage template
	# already selected by the current map plan; they no longer choose a new map.
	if run.is_empty() or not run.get("route_choices", []).has(stage_id):
		return false
	return advance_stage()

func start_boss() -> bool:
	# Compatibility entry point: the map plan, not the UI, decides the Stage 6 boss.
	if run.is_empty() or int(run.get("stage_index", 0)) != 4:
		return false
	return advance_stage()

func advance_stage() -> bool:
	if run.is_empty() or not run.get("stage_completed", false) or String(run.get("outcome", "")) != "":
		return false
	var stage_index := int(run.get("stage_index", 0))
	if stage_index >= 5:
		return reveal_next_map()
	if stage_index == 4 and _get_map_boss_definition(run.get("current_map", {})).is_empty():
		push_error("The current map has no valid eligible boss definition for Stage 6.")
		return false
	stage_index += 1
	run.stage_index = stage_index
	var current_map: Dictionary = run.get("current_map", {})
	var templates: Array = current_map.get("stage_templates", [])
	var template_index := mini(4, maxi(0, stage_index))
	var stage_id := String(templates[template_index]) if template_index < templates.size() else String(run.get("stage_id", "ruined_village"))
	if run.route.is_empty() or String(run.route.back()) != stage_id:
		run.route.append(stage_id)
	run.route_choices = [stage_id]
	_new_stage(stage_id, stage_index == 5, false, true)
	save_run()
	return true

func reveal_next_map() -> bool:
	if run.is_empty() or int(run.get("stage_index", 0)) != 5 or not run.get("stage_completed", false):
		return false
	if bool(run.get("map_reveal_pending", false)):
		return true
	var previous_theme := String(run.get("current_map", {}).get("theme_id", ""))
	var next_map := _generate_map(_increment_decimal(_normalize_depth(run.get("map_depth", "1"))), previous_theme)
	if next_map.is_empty():
		return false
	var history: Array = run.get("map_history", [])
	var current_index := int(run.get("current_map_index", history.size() - 1))
	if current_index >= 0 and current_index < history.size():
		history[current_index]["completed"] = true
		history[current_index]["current"] = false
		history[current_index]["revealed"] = true
	next_map["current"] = false
	next_map["completed"] = false
	next_map["revealed"] = true
	history.append(next_map.duplicate(true))
	run["map_history"] = history
	run["map_reveal_index"] = history.size() - 1
	run["map_reveal_pending"] = true
	run["next_map"] = next_map.duplicate(true)
	save_run()
	return true

func enter_next_map() -> bool:
	if run.is_empty() or not bool(run.get("map_reveal_pending", false)):
		return false
	var next_map: Dictionary = run.get("next_map", {}).duplicate(true)
	if next_map.is_empty(): return false
	var history: Array = run.get("map_history", [])
	var next_index := int(run.get("map_reveal_index", history.size() - 1))
	if next_index < 0 or next_index >= history.size(): return false
	next_map["current"] = true
	next_map["revealed"] = true
	next_map["completed"] = false
	history[next_index] = next_map.duplicate(true)
	run["map_history"] = history
	run["current_map_index"] = next_index
	run["current_map"] = next_map
	run["map_depth"] = _normalize_depth(next_map.get("map_number", _increment_decimal(_normalize_depth(run.get("map_depth", "1")))))
	run["stage_index"] = 0
	run["berserker_power_used"] = false
	run["weapon_state"] = {"unhurt_actions": 0, "precision": 0, "technique_kill_stacks": 0, "last_action_kind": "", "followup_basic": false}
	run["stage_technique_used"] = false
	run["encounter_technique_used"] = false
	run["route"] = []
	run["map_reveal_pending"] = false
	run["next_map"] = {}
	run["map_reveal_index"] = -1
	var templates: Array = next_map.get("stage_templates", [])
	if templates.is_empty(): return false
	var stage_id := String(templates[0])
	run.route = [stage_id]
	run.route_choices = [String(templates[1])] if templates.size() > 1 else [stage_id]
	_new_stage(stage_id, false, true, true)
	save_run()
	return true

func _generate_map(map_number: Variant, previous_theme_id: String, forced_theme_id: String = "") -> Dictionary:
	var depth_text := _normalize_depth(map_number)
	var eligible: Array[String] = []
	for theme_id in content.get("maps", {}):
		var theme: Dictionary = content.maps[theme_id]
		if not _depth_meets_minimum(depth_text, int(theme.get("minimum_depth", 1))) or not _depth_meets_maximum(depth_text, theme.get("maximum_depth", "")):
			continue
		var templates: Array = theme.get("stage_templates", [])
		if templates.is_empty() or not _content_prerequisites_met(theme.get("prerequisites", {})):
			continue
		var valid_templates := true
		for template_id in templates:
			if not content.get("stages", {}).has(String(template_id)):
				valid_templates = false
		if valid_templates and (forced_theme_id == "" or String(theme_id) == forced_theme_id):
			eligible.append(String(theme_id))
	if eligible.is_empty(): return {}
	if forced_theme_id == "" and eligible.size() > 1:
		eligible.erase(previous_theme_id)
		if eligible.is_empty():
			eligible.append(previous_theme_id)
	eligible.sort()
	var theme_candidates: Array = []
	for theme_id in eligible:
		var definition: Dictionary = content.maps[theme_id]
		theme_candidates.append({"id": theme_id, "weight": maxf(0.05, float(definition.get("weight", 1.0))) * maxf(0.05, get_content_weight(definition))})
	var selected_theme_id := forced_theme_id if forced_theme_id != "" else String(_pick_weighted_candidate(theme_candidates).get("id", eligible[0]))
	var theme: Dictionary = content.maps[selected_theme_id]
	var template_choices: Array = theme.get("stage_templates", []).duplicate()
	var template_ids: Array = []
	for stage_index in range(5):
		template_ids.append(String(template_choices[_rng.randi_range(0, template_choices.size() - 1)]))
	var boss_id := _select_map_boss(selected_theme_id, depth_text)
	if boss_id == "": return {}
	var stage_plans: Array = []
	for stage_index in range(5):
		stage_plans.append(_make_encounter_plan(String(template_ids[stage_index]), depth_text, stage_index))
	var map_data := {
		"map_number": depth_text, "theme_id": selected_theme_id,
		"name": String(theme.get("name", selected_theme_id.replace("_", " ").capitalize())),
		"subtitle": String(theme.get("subtitle", "A region of the Fractured March.")),
		"tags": theme.get("tags", []).duplicate(), "stage_templates": template_ids, "stage_plans": stage_plans,
		"boss_id": boss_id, "completed": false, "current": true, "revealed": true,
		"generation_seed_state": str(_rng.state)
	}
	return map_data

func _make_encounter_plan(stage_id: String, map_number: Variant, stage_index: int) -> Dictionary:
	var stage: Dictionary = content.get("stages", {}).get(stage_id, {})
	if stage.is_empty(): return {}
	var objectives: Array = stage.get("objectives", []).duplicate()
	if _normalize_depth(map_number) == "1":
		objectives = objectives.filter(func(value: Variant) -> bool: return String(value) in ["Eliminate", "Reach Exit"])
	if objectives.is_empty(): objectives = ["Eliminate"]
	var objective := String(objectives[_rng.randi_range(0, objectives.size() - 1)])
	var curve: Array = stage.get("enemy_count_curve", [2, 3, 4, 5, 5])
	var base_count := int(curve[mini(stage_index, curve.size() - 1)]) if not curve.is_empty() else 2
	var scaling := get_enemy_scaling(map_number)
	var enemy_count := base_count + int(scaling.get("extra_enemies", 0))
	var maximum_cells := maxi(1, (WIDTH - 2) * (HEIGHT - 2) - 35)
	enemy_count = mini(enemy_count, maximum_cells)
	var pool: Array[String] = []
	var weights: Array[float] = []
	for enemy_id in stage.get("enemies", []):
		var enemy: Dictionary = content.get("enemies", {}).get(enemy_id, {})
		var tier := int(enemy.get("tier", 0))
		if tier > int(scaling.get("tier_limit", 0)):
			continue
		pool.append(String(enemy_id))
		weights.append(1.0 + float(tier) * _depth_log(_normalize_depth(map_number)) * 0.2)
	var stage_factions: Array = stage.get("factions", [])
	for enemy_id in content.get("enemies", {}):
		var enemy: Dictionary = content.enemies[enemy_id]
		if stage.get("enemies", []).has(enemy_id) or not enemy.has("eligible_factions") or not _content_prerequisites_met(enemy.get("prerequisites", {})):
			continue
		var shares_faction: bool = enemy.get("eligible_factions", []).any(func(faction: Variant) -> bool: return stage_factions.has(String(faction)))
		if not shares_faction or float(enemy.get("spawn_weight", 0.0)) <= 0.0:
			continue
		var tier := int(enemy.get("tier", 0))
		if tier > int(scaling.get("tier_limit", 0)):
			continue
		pool.append(String(enemy_id))
		weights.append(float(enemy.get("spawn_weight", 1.0)) * (1.0 + float(tier) * _depth_log(_normalize_depth(map_number)) * 0.2))
	if pool.is_empty():
		pool.assign(stage.get("enemies", []))
	var selected_enemies: Array[String] = []
	for _index in range(enemy_count):
		selected_enemies.append(_pick_weighted_id(pool, weights))
	return {"stage_template_id": stage_id, "objective": objective, "enemy_ids": selected_enemies, "loot": stage.get("exploration_loot", {}).duplicate(true)}

func _pick_weighted_id(ids: Array[String], weights: Array[float]) -> String:
	if ids.is_empty(): return ""
	var total := 0.0
	for index in range(ids.size()): total += maxf(0.05, weights[index] if index < weights.size() else 1.0)
	var roll := _rng.randf() * total
	for index in range(ids.size()):
		roll -= maxf(0.05, weights[index] if index < weights.size() else 1.0)
		if roll <= 0.0: return ids[index]
	return ids.back()

func _select_map_boss(theme_id: String, map_number: Variant) -> String:
	var candidates := _get_eligible_boss_candidates(theme_id, map_number)
	return String(_pick_weighted_candidate(candidates).get("id", ""))

func _get_map_boss_definition(map_data: Dictionary) -> Dictionary:
	var boss_id := String(map_data.get("boss_id", ""))
	var boss: Dictionary = content.get("bosses", {}).get(boss_id, {})
	var enemy_id := String(boss.get("enemy_id", boss_id))
	if boss_id == "" or boss.is_empty() or not content.get("enemies", {}).has(enemy_id):
		return {}
	return {"id": boss_id, "definition": boss, "enemy_id": enemy_id}

func _get_eligible_boss_candidates(theme_id: String, map_number: Variant) -> Array:
	var candidates: Array = []
	var depth_text := _normalize_depth(map_number)
	for boss_id in content.get("bosses", {}):
		var boss: Dictionary = content.bosses[boss_id]
		var enemy_id := String(boss.get("enemy_id", boss_id))
		if not content.get("enemies", {}).has(enemy_id) or int(boss.get("stage_only", 6)) != 6:
			continue
		if not _depth_meets_minimum(depth_text, int(boss.get("minimum_depth", 1))) or not _depth_meets_maximum(depth_text, boss.get("maximum_depth", "")):
			continue
		var themes: Array = boss.get("themes", [])
		if not themes.is_empty() and not themes.has(theme_id):
			continue
		if not _content_prerequisites_met(boss.get("prerequisites", {})):
			continue
		candidates.append({"id": String(boss_id), "weight": get_boss_selection_weight(boss, depth_text)})
	return candidates

func get_boss_selection_weight(boss: Dictionary, map_number: Variant) -> float:
	var weight := maxf(0.05, float(boss.get("weight", 1.0)))
	var log_depth := _depth_log(_normalize_depth(map_number))
	if bool(boss.get("rare", false)):
		weight *= 1.0 + log_depth * float(boss.get("depth_weight_growth", 0.08))
	else:
		weight /= 1.0 + log_depth * float(boss.get("common_depth_decay", 0.015))
	return maxf(0.05, weight)

func get_enemy_scaling(map_number: Variant) -> Dictionary:
	var log_depth := _depth_log(_normalize_depth(map_number))
	var maximum_extra := (WIDTH - 2) * (HEIGHT - 2) - 35
	return {
		"health_multiplier": 1.0 + BASE_ENEMY_HEALTH_GROWTH * log_depth + 0.02 * log_depth * log_depth,
		"damage_multiplier": 1.0 + BASE_ENEMY_DAMAGE_GROWTH * log_depth + 0.012 * log_depth * log_depth,
		"armor_bonus": int(minf(MAX_SAFE_COMBAT_STAT, floor(BASE_ENEMY_ARMOR_GROWTH * log_depth))),
		"extra_enemies": int(minf(float(maximum_extra), floor(LATE_ENEMY_COUNT_PER_LOG_DEPTH * log_depth))),
		"tier_limit": int(minf(MAX_SAFE_COMBAT_STAT, floor(log_depth / log(2.0))))
	}

func equip_item(index: int) -> bool:
	if not can_equip_item(index):
		return false
	var item_id: String = run.inventory[index]
	var item: Dictionary = content.items.get(item_id, {})
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
	check_authored_character_unlocks()
	_add_log("Equipped %s." % item.name)
	save_run()
	return true

func can_equip_item(index: int, selected_slot: String = "") -> bool:
	if run.is_empty() or index < 0 or index >= run.get("inventory", []).size():
		return false
	var item_id := String(run.inventory[index])
	var item: Dictionary = content.items.get(item_id, {})
	if item.get("type", "") != "equipment":
		return false
	var item_slot := String(item.get("slot", ""))
	if item_slot == "" or not run.get("equipment", {}).has(item_slot):
		return false
	if selected_slot != "" and selected_slot != item_slot:
		return false
	if item_slot == "Weapon" and content.weapons.get(item.get("weapon", ""), {}).is_empty():
		return false
	return true

func get_equipment_item_stats(item_id: String) -> Dictionary:
	var item: Dictionary = content.items.get(item_id, {})
	if item.get("type", "") != "equipment":
		return {}
	var stats: Dictionary = {"name": String(item.get("name", item_id)), "slot": String(item.get("slot", "")), "armor": int(item.get("armor", 0)), "resist": item.get("resist", {}).duplicate(true), "modifiers": item.get("modifiers", {}).duplicate(true), "description": String(item.get("description", ""))}
	if item.has("weapon"):
		var weapon: Dictionary = content.weapons.get(String(item.weapon), {})
		if not weapon.is_empty():
			stats["damage"] = int(weapon.get("damage", 0))
			stats["damage_type"] = String(weapon.get("type", ""))
			stats["time"] = int(weapon.get("time", 0))
			stats["stamina"] = int(weapon.get("stamina", 0))
			stats["range"] = int(weapon.get("range", 0))
			stats["hands"] = int(weapon.get("hands", 1))
			stats["style"] = String(weapon.get("style", ""))
	return stats

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
	var immediate_contents: Array[String] = []
	if mode != "school_only":
		for ability_id in offered:
			immediate_contents.append(String(content.abilities.get(ability_id, {}).get("name", ability_id)))
	return {"id": item_id, "name": book.get("name", "Spellbook"), "school": book.get("school", ""), "description": book.get("description", ""), "contents": immediate_contents, "mode": mode, "choice_count": int(learning.get("choice_count", offered.size() if mode == "all" else 0)), "consume_on_study": bool(learning.get("consume_on_study", false)), "unlocks_school": bool(learning.get("unlocks_school", book.get("unlocks_school", false))), "resolved": not resolution.is_empty(), "chosen_abilities": resolution.get("abilities", []), "options": options}

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
		_record_build_tags(content.abilities[ability_id].get("tags", []))
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
	check_authored_character_unlocks()
	save_run()
	return true

func get_available_abilities() -> Array:
	var result: Array = []
	for ability_id in run.get("known", []):
		if content.abilities.has(ability_id) and content.abilities[ability_id].get("kind", "active") != "passive":
			result.append(ability_id)
	for ability_id in content.get("abilities", {}):
		if content.abilities[ability_id].get("kind", "active") != "passive" and _ability_grant_source(String(ability_id)) != "" and not result.has(ability_id):
			result.append(String(ability_id))
	result.sort()
	return result

func get_summary() -> Dictionary:
	var equipment: Array[String] = []
	for slot in run.get("equipment", {}):
		var item_id := String(run.equipment[slot])
		if item_id in ["", "occupied"]: continue
		equipment.append(String(content.get("items", {}).get(item_id, {}).get("name", item_id)))
	var abilities: Array[String] = []
	for ability_id in run.get("known", []):
		abilities.append(String(content.get("abilities", {}).get(ability_id, {}).get("name", ability_id)))
	var relics: Array[String] = []
	for relic_id in run.get("relics", []):
		relics.append(String(content.get("relics", {}).get(relic_id, {}).get("name", relic_id)))
	var artifacts: Array[String] = []
	for artifact_id in run.get("artifacts", []):
		artifacts.append(String(content.get("artifacts", {}).get(artifact_id, {}).get("name", artifact_id)))
	return {
		"character": run.get("character", ""), "character_id": run.get("character_id", ""),
		"level": int(run.get("level", 1)), "kills": int(run.get("kills", 0)),
		"enemies_defeated": _normalize_counter(run.get("enemies_defeated", run.get("kills", 0))),
		"bosses_defeated": _normalize_counter(run.get("bosses_defeated", 0)),
		"maps_completed": _normalize_counter(run.get("maps_completed", "0")),
		"stages_completed": _normalize_counter(run.get("stages_completed", run.get("encounters_completed", 0))),
		"deepest_map": _normalize_depth(run.get("map_depth", "1")), "stage_reached": int(run.get("stage_index", 0)) + 1,
		"encounters": int(run.get("encounters_completed", 0)), "time": int(run.get("time", 0)),
		"xp": int(run.get("xp", 0)), "abilities": abilities, "equipment": equipment,
		"relics": relics, "artifacts": artifacts, "outcome": run.get("outcome", "")
	}

func state_digest() -> String:
	if run.is_empty():
		return ""
	var player: Dictionary = get_player()
	return JSON.stringify({"seed": run.seed, "stage": run.stage_id, "time": run.time, "player_pos": player.pos, "hp": player.hp, "mana": player.resources.Mana, "stamina": player.resources.Stamina, "entities": run.entities, "pending_summon_transfers": run.get("pending_summon_transfers", []), "last_stage_heal_transition_key": run.get("last_stage_heal_transition_key", ""), "grid": run.grid, "objects": run.objects, "known": run.known, "schools": run.get("schools", []), "disciplines": run.get("disciplines", []), "discoveries": run.get("discoveries", []), "spellbook_resolutions": run.get("spellbook_resolutions", {}), "reward_choice_resolved": run.get("reward_choice_resolved", false), "reward_chosen_index": run.get("reward_chosen_index", -1), "reward_choices": run.get("reward_choices", []), "xp": run.xp, "level": run.level, "skill_points": run.skill_points, "objective": run.objective})

func _apply_stage_transition_heal(stage_id: String) -> void:
	var player: Dictionary = get_player()
	if player.is_empty(): return
	var transition_key := "%s:%s:%s:%s" % [String(run.get("stages_completed", "0")), String(run.get("map_depth", "1")), str(int(run.get("stage_index", 0))), stage_id]
	if String(run.get("last_stage_heal_transition_key", "")) == transition_key: return
	var maximum_health := maxi(1, int(player.get("max_hp", 1)))
	var healing := maxi(1, int(floor(float(maximum_health) * STAGE_ENTRY_HEAL_PERCENT)))
	player.hp = mini(maximum_health, int(player.get("hp", 0)) + healing)
	run["last_stage_heal_transition_key"] = transition_key

func _summon_transfer_is_eligible(entity: Dictionary) -> bool:
	if not bool(entity.get("is_summon", false)) or String(entity.get("kind", "")) != "summon": return false
	if String(entity.get("owner", "")) != "player" or not bool(entity.get("alive", false)) or int(entity.get("hp", 0)) <= 0 or bool(entity.get("dismissed", false)): return false
	if entity.has("remaining_duration") and int(entity.get("remaining_duration", 0)) <= 0: return false
	if entity.has("summon_duration_remaining") and int(entity.get("summon_duration_remaining", 0)) <= 0: return false
	if entity.has("expires_at") and int(entity.get("expires_at", 0)) <= int(run.get("time", 0)): return false
	if entity.has("summon_expires_at") and int(entity.get("summon_expires_at", 0)) <= int(run.get("time", 0)): return false
	return true

func _collect_transferable_summons() -> Array:
	var by_id: Dictionary = {}
	for snapshot_value in run.get("pending_summon_transfers", []):
		if not (snapshot_value is Dictionary): continue
		var snapshot: Dictionary = snapshot_value
		var snapshot_id := String(snapshot.get("id", ""))
		if snapshot_id != "" and _summon_transfer_is_eligible(snapshot) and not by_id.has(snapshot_id):
			by_id[snapshot_id] = snapshot.duplicate(true)
	for entity_id in run.get("entities", {}):
		var entity: Dictionary = run.entities[entity_id]
		var stable_id := String(entity.get("id", entity_id))
		if stable_id != "" and _summon_transfer_is_eligible(entity) and not by_id.has(stable_id):
			by_id[stable_id] = entity.duplicate(true)
	var result: Array = []
	var stable_ids: Array = by_id.keys()
	stable_ids.sort()
	for stable_id in stable_ids: result.append(by_id[stable_id])
	return result

func _summon_transfer_cell_is_clear(cell: Vector2i, summon: Dictionary) -> bool:
	if not _inside(cell): return false
	var footprint := maxi(1, int(summon.get("footprint", 1)))
	for y in range(cell.y, cell.y + footprint):
		for x in range(cell.x, cell.x + footprint):
			var occupied_cell := Vector2i(x, y)
			if not _inside(occupied_cell) or _terrain_at(occupied_cell) == "wall": return false
			for entity_id in run.get("entities", {}):
				if String(entity_id) == String(summon.get("id", "")): continue
				var other: Dictionary = run.entities[entity_id]
				if not bool(other.get("alive", false)): continue
				var other_pos := _pos(other)
				var other_size := maxi(1, int(other.get("footprint", 1)))
				if occupied_cell.x >= other_pos.x and occupied_cell.y >= other_pos.y and occupied_cell.x < other_pos.x + other_size and occupied_cell.y < other_pos.y + other_size:
					return false
			if _object_index_at(occupied_cell) >= 0: return false
	return true

func _find_summon_transfer_cell(summon: Dictionary, preferred: Vector2i) -> Vector2i:
	for radius in range(maxi(WIDTH, HEIGHT)):
		for y in range(1, HEIGHT - 1):
			for x in range(1, WIDTH - 1):
				var candidate := Vector2i(x, y)
				if _dist(preferred, candidate) == radius and _summon_transfer_cell_is_clear(candidate, summon):
					return candidate
	return Vector2i(-1, -1)

func _restore_transferred_summons(summons: Array) -> void:
	var pending: Array = []
	var owner_pos := _pos(get_player())
	var command_used := 0
	run["pending_summon_transfers"] = []
	for snapshot_value in summons:
		if not (snapshot_value is Dictionary): continue
		var summon: Dictionary = snapshot_value.duplicate(true)
		if not _summon_transfer_is_eligible(summon): continue
		var summon_id := String(summon.get("id", ""))
		if summon_id == "": continue
		command_used += maxi(0, int(summon.get("command_cost", 1)))
		if run.entities.has(summon_id):
			pending.append(summon)
			continue
		var cell := _find_summon_transfer_cell(summon, owner_pos)
		if cell == Vector2i(-1, -1):
			pending.append(summon)
			continue
		summon["pos"] = [cell.x, cell.y]
		run.entities[summon_id] = summon
	run["pending_summon_transfers"] = pending
	var command: Array = get_player().resources.get("Command", [0, 0])
	command[0] = command_used
	get_player().resources["Command"] = command

func _place_pending_summons() -> void:
	var pending: Array = run.get("pending_summon_transfers", [])
	if pending.is_empty(): return
	var remaining: Array = []
	var owner_pos := _pos(get_player())
	for snapshot_value in pending:
		if not (snapshot_value is Dictionary): continue
		var summon: Dictionary = snapshot_value.duplicate(true)
		if not _summon_transfer_is_eligible(summon): continue
		var summon_id := String(summon.get("id", ""))
		if summon_id == "" or run.entities.has(summon_id):
			remaining.append(summon)
			continue
		var cell := _find_summon_transfer_cell(summon, owner_pos)
		if cell == Vector2i(-1, -1):
			remaining.append(summon)
			continue
		summon["pos"] = [cell.x, cell.y]
		run.entities[summon_id] = summon
	run["pending_summon_transfers"] = remaining
	var command_used := 0
	for entity_id in run.entities:
		var entity: Dictionary = run.entities[entity_id]
		if _summon_transfer_is_eligible(entity): command_used += maxi(0, int(entity.get("command_cost", 1)))
	for snapshot_value in remaining:
		if snapshot_value is Dictionary:
			command_used += maxi(0, int(snapshot_value.get("command_cost", 1)))
	var command: Array = get_player().resources.get("Command", [0, 0])
	command[0] = command_used
	get_player().resources["Command"] = command

func _new_stage(stage_id: String, is_boss: bool, suppress_recovery: bool = false, apply_stage_transition_heal: bool = false) -> void:
	var player: Dictionary = run.entities.get("player", {})
	if player.is_empty():
		return
	if stage_id == "" or not content.get("stages", {}).has(stage_id):
		return
	var carried_summons := _collect_transferable_summons()
	var planned_boss: Dictionary = _get_map_boss_definition(run.get("current_map", {})) if is_boss else {}
	if is_boss and planned_boss.is_empty():
		push_error("Cannot start Stage 6 without its generated boss definition.")
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
	if not suppress_recovery:
		var mana: Array = player.resources.Mana
		mana[0] = mini(int(mana[1]), int(mana[0]) + 6)
		player.resources.Mana = mana
		var stamina: Array = player.resources.Stamina
		stamina[0] = mini(int(stamina[1]), int(stamina[0]) + 15)
		player.resources.Stamina = stamina
	if apply_stage_transition_heal and bool(run.get("stage_completed", false)):
		_apply_stage_transition_heal(stage_id)
	run.objects = []
	run.corpses = []
	run.objective = {}
	run.stage_completed = false
	run["stage_technique_used"] = false
	run["encounter_technique_used"] = false
	run.stage_prompt_dismissed = false
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
	_restore_transferred_summons(carried_summons)
	run.visible = _bool_grid(false)
	run.explored = _bool_grid(false)
	var current_map: Dictionary = run.get("current_map", {})
	var stage_plan: Dictionary = {}
	if not is_boss:
		var plans: Array = current_map.get("stage_plans", [])
		if int(run.get("stage_index", 0)) < plans.size(): stage_plan = plans[int(run.stage_index)]
	var objective_kind: String = "Boss" if is_boss else String(stage_plan.get("objective", stage.objectives[_rng.randi_range(0, stage.objectives.size() - 1)]))
	if is_boss:
		run.objective = {"kind": "Boss", "turns": 0}
		run["boss_id"] = String(planned_boss.id)
		var spawned_boss_id := _spawn_enemy(String(planned_boss.enemy_id), Vector2i(19, 7), true)
		if run.entities.has(spawned_boss_id):
			run.entities[spawned_boss_id]["boss_definition_id"] = String(planned_boss.id)
			run.entities[spawned_boss_id]["ai_mode"] = String(planned_boss.definition.get("ai_mode", ""))
		var boss: Dictionary = planned_boss.definition
		_add_log("A rare challenge: %s. %s" % [String(boss.get("name", content.get("enemies", {}).get(String(planned_boss.enemy_id), {}).get("name", "A boss"))), String(boss.get("description", ""))])
	else:
		run.objective = {"kind": objective_kind, "turns": 6}
		if objective_kind == "Reach Exit":
			run.objects.append({"id": "road_exit", "kind": "exit", "name": "March Road", "pos": [21, 8], "hp": 1, "max_hp": 1})
		if objective_kind == "Destroy Targets":
			run.objects.append({"id": "ward_a", "kind": "ward", "name": "Ritual Ward", "pos": [17, 5], "hp": 15, "max_hp": 15})
			run.objects.append({"id": "ward_b", "kind": "ward", "name": "Ritual Ward", "pos": [18, 11], "hp": 15, "max_hp": 15})
		var planned_enemy_ids: Array = stage_plan.get("enemy_ids", [])
		if planned_enemy_ids.is_empty():
			var fallback_plan := _make_encounter_plan(stage_id, run.get("map_depth", "1"), int(run.get("stage_index", 0)))
			planned_enemy_ids = fallback_plan.get("enemy_ids", [])
		for i in range(planned_enemy_ids.size()):
			var enemy_id: String = String(planned_enemy_ids[i])
			var position := _find_spawn(Vector2i(15 + (i % 3) * 2, 5 + int(i / 3) * 5))
			_spawn_enemy(enemy_id, position, false)
		var next_index := int(run.get("stage_index", 0)) + 1
		var templates: Array = current_map.get("stage_templates", [])
		run.route_choices = [String(templates[mini(4, next_index)])] if int(run.stage_index) < 4 and not templates.is_empty() else ["boss"] if int(run.stage_index) == 4 else []
		_add_log("%s: %s." % [stage.name, get_objective_text()])
	var planned_loot: Dictionary = stage_plan.get("loot", stage.get("exploration_loot", {}))
	_spawn_exploration_loot({"exploration_loot": planned_loot})
	run.explored = _bool_grid(false)
	_update_vision()
	_record_codex("creatures", "")
	_save_codex()
	_emit_trigger("OnEncounterStart", {"stage_id": stage_id, "objective": objective_kind, "map_number": _normalize_depth(run.get("map_depth", "1")), "stage_number": int(run.get("stage_index", 0)) + 1, "is_boss_stage": is_boss})

func _make_route_choices(current_stage: String) -> Array:
	var pool := STAGE_ORDER.duplicate()
	pool.erase(current_stage)
	var choices: Array = []
	while choices.size() < 2 and not pool.is_empty():
		var selected: String = pool[_rng.randi_range(0, pool.size() - 1)]
		pool.erase(selected)
		choices.append(selected)
	return choices

func _spawn_exploration_loot(stage: Dictionary) -> void:
	var settings: Dictionary = stage.get("exploration_loot", {})
	var minimum := maxi(0, int(settings.get("min_count", 0)))
	var maximum := maxi(minimum, int(settings.get("max_count", minimum)))
	var types: Array = settings.get("types", [])
	if types.is_empty() or maximum <= 0: return
	var count := _rng.randi_range(minimum, maximum)
	var spellbooks: Array = []
	for item_id in content.get("items", {}):
		if content.items[item_id].get("type", "") == "spellbook" and _content_prerequisites_met(content.items[item_id].get("prerequisites", {})):
			spellbooks.append(String(item_id))
	for index in range(count):
		var kind := String(types[_rng.randi_range(0, types.size() - 1)])
		if kind not in ["chest", "skill_book", "item"]: continue
		var item_id := ""
		if kind == "skill_book":
			if spellbooks.is_empty(): continue
			item_id = String(spellbooks[_rng.randi_range(0, spellbooks.size() - 1)])
		elif kind == "item":
			var ordinary_candidates := get_reward_candidates(false)
			if ordinary_candidates.is_empty(): continue
			item_id = String(_pick_weighted_candidate(ordinary_candidates).get("id", ""))
		var position := _find_spawn(Vector2i(3 + (index * 5) % 19, 3 + (index * 7) % 10))
		var attempts := 0
		while position.x >= 0 and _object_index_at(position) >= 0 and attempts < 25:
			position = _find_spawn(Vector2i(_rng.randi_range(2, WIDTH - 3), _rng.randi_range(2, HEIGHT - 3)))
			attempts += 1
		if position.x < 0 or _object_index_at(position) >= 0: continue
		var object_name := "Travel Chest" if kind == "chest" else "Skill Book" if kind == "skill_book" else "Field Supplies"
		var field_object := {"id": "exploration_%d_%d" % [run.objects.size(), index], "kind": kind, "name": object_name, "pos": [position.x, position.y], "hp": 1, "max_hp": 1}
		if item_id != "": field_object["item_id"] = item_id
		run.objects.append(field_object)

func _make_rewards() -> void:
	var candidates := get_reward_candidates(true)
	var guaranteed_reward := {}
	if int(run.get("stage_index", 0)) == 5:
		var boss_definition: Dictionary = content.get("bosses", {}).get(String(run.get("current_map", {}).get("boss_id", "")), {})
		var guaranteed_id := String(boss_definition.get("guaranteed_reward_id", ""))
		if guaranteed_id != "" and content.get("items", {}).has(guaranteed_id):
			guaranteed_reward = {"type": "item", "id": guaranteed_id, "claimed": false, "available": true}
	run.reward_choices = []
	run.reward_choice_resolved = false
	run.reward_chosen_index = -1
	if not guaranteed_reward.is_empty(): run.reward_choices.append(guaranteed_reward)
	for choice_index in range(3 - run.reward_choices.size()):
		if candidates.is_empty():
			break
		var selected: Dictionary = _pick_weighted_candidate(candidates)
		candidates.erase(selected)
		selected.erase("weight")
		selected["available"] = true
		run.reward_choices.append(selected)

func get_reward_candidates(include_artifacts: bool = true) -> Array:
	var candidates: Array = []
	for item_id in content.get("items", {}):
		var item: Dictionary = content.items[item_id]
		if item.get("type", "") not in ["consumable", "scroll", "spellbook", "equipment"]:
			continue
		if not _content_prerequisites_met(item.get("prerequisites", {})):
			continue
		candidates.append({"type": "item", "id": String(item_id), "weight": get_content_weight(item), "claimed": false})
	if include_artifacts:
		for artifact_id in content.get("artifacts", {}):
			var artifact: Dictionary = content.artifacts[artifact_id]
			if run.get("artifacts", []).has(artifact_id) or not _content_prerequisites_met(artifact.get("prerequisites", {})):
				continue
			candidates.append({"type": "artifact", "id": String(artifact_id), "weight": get_content_weight(artifact) * 0.55, "claimed": false})
		for relic_id in content.get("relics", {}):
			var relic: Dictionary = content.relics[relic_id]
			if run.get("relics", []).has(relic_id) or not _content_prerequisites_met(relic.get("prerequisites", {})):
				continue
			candidates.append({"type": "relic", "id": String(relic_id), "weight": get_content_weight(relic) * 0.65, "claimed": false})
	return candidates

func get_content_weight(definition: Dictionary) -> float:
	var weight := maxf(0.05, float(definition.get("drop_weight", 1.0)))
	var tags: Array = definition.get("tags", [])
	var affinities: Dictionary = run.get("character_affinities", {})
	var affinity_factor := 1.0
	for tag in tags:
		var affinity := float(affinities.get(String(tag), 1.0))
		affinity_factor = maxf(affinity_factor, 1.0 + maxf(0.0, affinity - 1.0) * 0.45)
	weight *= affinity_factor
	var build_bonus := 0.0
	var build_tags: Dictionary = run.get("build_tag_counts", {})
	for tag in tags:
		build_bonus += minf(0.18, float(build_tags.get(String(tag), 0)) * 0.035)
	weight *= 1.0 + minf(0.75, build_bonus)
	for relic_id in run.get("relics", []):
		var tag_weights: Dictionary = content.get("relics", {}).get(String(relic_id), {}).get("reward_weight_by_tag", {})
		for tag in tags:
			weight *= 1.0 + float(tag_weights.get(String(tag), 0.0))
	var rarity := String(definition.get("rarity", "Common")).to_lower()
	var rarity_rank := 0.0
	match rarity:
		"uncommon": rarity_rank = 1.0
		"rare": rarity_rank = 2.0
		"epic": rarity_rank = 3.0
		"legendary": rarity_rank = 4.0
	if rarity_rank > 0.0:
		weight *= 1.0 + 0.04 * _depth_log(_normalize_depth(run.get("map_depth", "1"))) * rarity_rank
	return maxf(0.05, weight)

func _pick_weighted_candidate(candidates: Array) -> Dictionary:
	if candidates.is_empty(): return {}
	var total_weight := 0.0
	for candidate in candidates: total_weight += maxf(0.05, float(candidate.get("weight", 1.0)))
	var roll := _rng.randf() * total_weight
	for candidate in candidates:
		roll -= maxf(0.05, float(candidate.get("weight", 1.0)))
		if roll <= 0.0: return candidate.duplicate(true)
	return candidates.back().duplicate(true)

func _acquire_relic(relic_id: String) -> bool:
	if not content.get("relics", {}).has(relic_id) or run.get("relics", []).has(relic_id): return false
	run["relics"].append(relic_id)
	_record_codex("relics", relic_id)
	_add_log("You claim %s." % String(content.relics[relic_id].get("name", relic_id)))
	return true

func _record_build_tags(tags: Array, count: int = 1) -> void:
	if run.is_empty(): return
	var counts: Dictionary = run.get("build_tag_counts", {})
	for tag in tags:
		var tag_id := String(tag)
		if tag_id != "": counts[tag_id] = int(counts.get(tag_id, 0)) + count
	run["build_tag_counts"] = counts

func evaluate_prerequisites(requirements: Variant) -> Dictionary:
	if requirements == null or (requirements is Dictionary and requirements.is_empty()):
		return {"eligible": true, "reason": ""}
	if not requirements is Dictionary:
		return {"eligible": false, "reason": "Prerequisites must be a content condition object."}
	var conditions: Array = requirements.get("conditions", []).duplicate()
	for ability_id in requirements.get("requires", []):
		conditions.append({"type": "ability", "id": String(ability_id)})
	for ability_id in requirements.get("all_of", []):
		conditions.append({"type": "ability", "id": String(ability_id)})
	if not requirements.get("any_of", []).is_empty():
		conditions.append({"any": requirements.get("any_of", []).map(func(value: Variant) -> Dictionary: return {"type": "ability", "id": String(value)})})
	if not requirements.get("tags", []).is_empty():
		conditions.append({"type": "tags", "ids": requirements.get("tags", [])})
	for condition in conditions:
		var result: Dictionary = _evaluate_condition(condition)
		if not bool(result.get("eligible", false)):
			return result
	return {"eligible": true, "reason": ""}

func _content_prerequisites_met(requirements: Variant) -> bool:
	if requirements is Dictionary and not requirements.has("conditions") and requirements.keys().all(func(key: Variant) -> bool: return key in ["tags", "requires", "all_of", "any_of"]):
		return bool(evaluate_prerequisites(requirements).get("eligible", false))
	return bool(evaluate_prerequisites(requirements).get("eligible", false))

func _evaluate_condition(condition: Variant) -> Dictionary:
	if not condition is Dictionary:
		return {"eligible": false, "reason": "A prerequisite condition is malformed."}
	if condition.has("all"):
		for nested in condition.get("all", []):
			var nested_result: Dictionary = _evaluate_condition(nested)
			if not nested_result.eligible: return nested_result
		return {"eligible": true, "reason": ""}
	if condition.has("any"):
		var reasons: Array[String] = []
		for nested in condition.get("any", []):
			var nested_result: Dictionary = _evaluate_condition(nested)
			if nested_result.eligible: return nested_result
			reasons.append(String(nested_result.get("reason", "")))
		return {"eligible": false, "reason": "Requires one of: " + "; ".join(reasons)}
	if condition.has("not"):
		var nested_result: Dictionary = _evaluate_condition(condition.get("not"))
		return {"eligible": not bool(nested_result.eligible), "reason": "A conflicting prerequisite is present." if nested_result.eligible else ""}
	var condition_type := String(condition.get("type", ""))
	var content_id := String(condition.get("id", ""))
	var eligible := false
	var reason := ""
	match condition_type:
		"tag":
			eligible = int(run.get("build_tag_counts", {}).get(content_id, 0)) > 0
			reason = "Requires the %s tag." % content_id
		"tags":
			var missing: Array[String] = []
			for tag in condition.get("ids", []):
				if int(run.get("build_tag_counts", {}).get(String(tag), 0)) <= 0: missing.append(String(tag))
			eligible = missing.is_empty()
			reason = "Requires tags: %s." % ", ".join(missing)
		"owned_tags":
			var owned_tags := _owned_content_tag_counts()
			var missing_owned: Array[String] = []
			for tag in condition.get("ids", []):
				if int(owned_tags.get(String(tag), 0)) <= 0: missing_owned.append(String(tag))
			eligible = missing_owned.is_empty()
			reason = "Requires owned content with tags: %s." % ", ".join(missing_owned)
		"ability":
			eligible = run.get("known", []).has(content_id)
			reason = "Requires ability %s." % content.get("abilities", {}).get(content_id, {}).get("name", content_id)
		"item", "equipment":
			eligible = run.get("inventory", []).has(content_id) or run.get("equipment", {}).values().has(content_id)
			reason = "Requires item %s." % content.get("items", {}).get(content_id, {}).get("name", content_id)
		"weapon":
			eligible = String(run.get("equipment", {}).get("Weapon", "")) == content_id
			reason = "Requires an equipped %s." % content.get("weapons", {}).get(content_id, {}).get("name", content_id)
		"stat":
			var attribute_value := int(run.get("attributes", {}).get(content_id, 0))
			var minimum := int(condition.get("minimum", condition.get("value", 0)))
			eligible = attribute_value >= minimum
			reason = "Requires %s %d." % [content_id, minimum]
		"stage_completed":
			eligible = bool(run.get("stage_completed", false))
			reason = "Requires a completed stage."
		"summon_count":
			var required_count := int(condition.get("minimum", 1))
			var actual_count := _count_controlled_summons(String(condition.get("faction", "")), String(condition.get("owner", "player")))
			eligible = actual_count >= required_count
			reason = "Requires control of %d living %s summons at once." % [required_count, String(condition.get("faction", "summoned")).to_lower()]
		"artifact", "relic":
			if condition_type == "artifact":
				eligible = run.get("artifacts", []).has(content_id)
				reason = "Requires %s." % content.get("artifacts", {}).get(content_id, {}).get("name", content_id)
			else:
				eligible = run.get("relics", []).has(content_id)
				reason = "Requires %s." % content.get("relics", {}).get(content_id, {}).get("name", content_id)
		"counter":
			var counter_id := String(condition.get("id", ""))
			var counter_value := int(run.get(counter_id, 0))
			var counter_minimum := int(condition.get("minimum", 1))
			eligible = counter_value >= counter_minimum
			reason = "Requires %d successful %s." % [counter_minimum, counter_id.replace("_", " ")]
		"boss_defeated":
			eligible = run.get("defeated_boss_ids", []).has(content_id)
			reason = "Requires victory over %s." % content.get("bosses", {}).get(content_id, {}).get("name", content_id)
		"character":
			eligible = String(run.get("character_id", "")) == content_id
			reason = "Requires a different character."
		"package":
			eligible = content_registry.load_order.has(content_id)
			reason = "Requires the %s content package." % content_id
		"level":
			var required_level := int(condition.get("value", condition.get("level", 1)))
			eligible = int(run.get("level", 1)) >= required_level
			reason = "Requires level %d." % required_level
		"school":
			eligible = run.get("schools", []).has(content_id)
			reason = "Requires %s knowledge." % content_id
		"discipline":
			eligible = run.get("disciplines", []).has(content_id)
			reason = "Requires %s training." % content_id
		"discovery":
			eligible = run.get("discoveries", []).has(content_id)
			reason = "Requires a discovery."
		"resource":
			var resource_values: Array = get_player().get("resources", {}).get(content_id, [0, 0])
			var required_amount := int(condition.get("amount", condition.get("value", 1)))
			eligible = int(resource_values[0]) >= required_amount
			reason = "Requires %d %s." % [required_amount, content_id]
		_:
			return {"eligible": false, "reason": "Unknown prerequisite type '%s'." % condition_type}
	return {"eligible": eligible, "reason": "" if eligible else reason}

func _owned_content_tag_counts() -> Dictionary:
	var counts: Dictionary = {}
	if run.is_empty():
		return counts
	for ability_id in run.get("known", []):
		_add_tags_to_count(counts, content.get("abilities", {}).get(String(ability_id), {}).get("tags", []))
	for item_id in run.get("inventory", []):
		_add_tags_to_count(counts, content.get("items", {}).get(String(item_id), {}).get("tags", []))
	for artifact_id in run.get("artifacts", []):
		_add_tags_to_count(counts, content.get("artifacts", {}).get(String(artifact_id), {}).get("tags", []))
	for relic_id in run.get("relics", []):
		_add_tags_to_count(counts, content.get("relics", {}).get(String(relic_id), {}).get("tags", []))
	for slot in run.get("equipment", {}):
		var equipped_id := String(run.equipment[slot])
		if equipped_id in ["", "occupied"]:
			continue
		if String(slot) == "Weapon":
			_add_tags_to_count(counts, content.get("weapons", {}).get(equipped_id, {}).get("tags", []))
		else:
			_add_tags_to_count(counts, content.get("items", {}).get(equipped_id, {}).get("tags", []))
	return counts

func _add_tags_to_count(counts: Dictionary, tags: Array) -> void:
	for tag in tags:
		var tag_id := String(tag)
		if tag_id != "":
			counts[tag_id] = int(counts.get(tag_id, 0)) + 1

func _count_controlled_summons(faction: String, owner: String) -> int:
	var count := 0
	for entity in run.get("entities", {}).values():
		if not entity is Dictionary or String(entity.get("kind", "")) != "summon" or not bool(entity.get("is_summon", false)) or not bool(entity.get("alive", false)):
			continue
		if owner != "any" and String(entity.get("owner", "")) != owner:
			continue
		var summon_id := String(entity.get("enemy_id", ""))
		var definition: Dictionary = content.get("enemies", {}).get(summon_id, content.get("summons", {}).get(summon_id, {}))
		if faction == "" or String(definition.get("faction", "")) == faction:
			count += 1
	return count

func get_evolution_eligibility(ability_id: String) -> Dictionary:
	var ability: Dictionary = content.get("abilities", {}).get(ability_id, {})
	var evolution: Dictionary = ability.get("evolution", {})
	if ability.is_empty() or evolution.is_empty():
		return {"eligible": false, "reason": "This ability has no evolution definition."}
	var base_id := String(evolution.get("from", ""))
	if base_id == "" or not run.get("known", []).has(base_id):
		return {"eligible": false, "reason": "Requires the base ability."}
	var required_level := int(evolution.get("min_level", 1))
	if int(run.get("ability_states", {}).get(base_id, {}).get("level", 1)) < required_level:
		return {"eligible": false, "reason": "Requires base ability level %d." % required_level}
	var result: Dictionary = evaluate_prerequisites(evolution.get("prerequisites", {}))
	return {"eligible": bool(result.eligible), "reason": String(result.get("reason", ""))}

func evolve_ability(ability_id: String) -> bool:
	var eligibility: Dictionary = get_evolution_eligibility(ability_id)
	if not eligibility.eligible: return false
	var evolution: Dictionary = content.abilities[ability_id].evolution
	var base_id := String(evolution.from)
	run.known.erase(base_id)
	if not run.known.has(ability_id): run.known.append(ability_id)
	var states: Dictionary = run.get("ability_states", {})
	states[ability_id] = {"state": "evolved", "from": base_id, "level": 1}
	run["ability_states"] = states
	_record_build_tags(content.abilities[ability_id].get("tags", []))
	run["quickbar"] = _normalize_quickbar(run.get("quickbar", []))
	save_run()
	return true

func _next_entity_id(prefix: String) -> String:
	var suffix := maxi(0, run.get("entities", {}).size())
	var pending_ids: Dictionary = {}
	for snapshot_value in run.get("pending_summon_transfers", []):
		if snapshot_value is Dictionary:
			var pending_id := String(snapshot_value.get("id", ""))
			if pending_id != "": pending_ids[pending_id] = true
	var candidate := "%s_%03d" % [prefix, suffix]
	while run.get("entities", {}).has(candidate) or pending_ids.has(candidate):
		suffix += 1
		candidate = "%s_%03d" % [prefix, suffix]
	return candidate

func _spawn_enemy(enemy_id: String, cell: Vector2i, is_boss: bool) -> String:
	var definition: Dictionary = content.enemies.get(enemy_id, {})
	if definition.is_empty():
		return ""
	var id := _next_entity_id(enemy_id)
	var entity := definition.duplicate(true)
	var scaling := get_enemy_scaling(run.get("map_depth", "1"))
	entity["hp"] = _scaled_combat_stat(int(entity.get("hp", 20)), float(scaling.get("health_multiplier", 1.0)))
	entity["damage"] = _scaled_combat_stat(int(entity.get("damage", 5)), float(scaling.get("damage_multiplier", 1.0)))
	entity["armor"] = _scaled_combat_stat(int(entity.get("armor", 0)) + int(scaling.get("armor_bonus", 0)), 1.0)
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

func _scaled_combat_stat(base_value: int, multiplier: float) -> int:
	if base_value <= 0: return maxi(0, base_value)
	var scaled := float(base_value) * maxf(1.0, multiplier)
	return int(minf(MAX_SAFE_COMBAT_STAT, maxf(1.0, floor(scaled))))

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
	var id := _next_entity_id(summon_id)
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
	if not _cell_visible(target):
		return {"ok": false, "message": "That tile is still hidden by fog of war."}
	if not _inside(target) or _terrain_at(target) == "wall":
		return {"ok": false, "message": "That path is blocked."}
	if _dist(_pos(player), target) == 0:
		return {"ok": false, "message": "You are already there."}
	var occupant := _occupant(target)
	if occupant != "" and _is_hostile("player", occupant):
		return _player_attack(target)
	var path: Array[Vector2i] = get_movement_path(target, "player")
	var next_step := path[0] if not path.is_empty() else _pos(player)
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
	return _spend_player_time(_movement_step_time_cost("player"), "")

func _player_attack(target: Vector2i, spend_turn: bool = true) -> Dictionary:
	var player: Dictionary = get_player()
	var target_id := _occupant(target)
	if target_id == "" or not _is_hostile("player", target_id):
		var object_index := _object_index_at(target)
		if object_index >= 0 and run.objects[object_index].get("kind") == "ward" and is_valid_target_cell("attack", target):
			return _attack_object(object_index)
		return {"ok": false, "message": "Select a visible enemy or ritual ward."}
	var weapon: Dictionary = _equipped_weapon_definition()
	if weapon.is_empty(): weapon = content.weapons.get("sword", {})
	if not is_valid_target_cell("attack", target):
		return {"ok": false, "message": "That target is beyond your weapon's reach."}
	run["last_player_action"] = {"type": "attack", "target_id": target_id, "action_count": int(run.get("player_action_count", 0))}
	var stamina: Array = player.resources.Stamina
	if int(stamina[0]) < int(weapon.stamina):
		return {"ok": false, "message": "You need more Stamina for that attack."}
	stamina[0] = int(stamina[0]) - int(weapon.stamina)
	player.resources.Stamina = stamina
	_emit_combat_event("ResourceSpent", "player", "player", {"resource": "Stamina", "amount": int(weapon.stamina)})
	var damage := int(weapon.damage) + int(run.attributes.get("Might", 10)) / 4 + int(round(get_passive_modifier("weapon_damage_bonus")))
	var weapon_state: Dictionary = run.get("weapon_state", {})
	if weapon_state.get("followup_basic", false):
		damage += int(_equipped_weapon_definition().get("modifiers", {}).get("followup_basic_damage_bonus", 0))
		weapon_state["followup_basic"] = false
	if weapon_state.get("last_action_kind", "") == "technique": damage += int(_run_modifier("alternating_attack_damage_bonus", 0.0))
	damage += int(_run_modifier("precision_damage_per_stack", 0.0)) * int(weapon_state.get("precision", 0))
	if String(run.entities[target_id].get("faction", "")) == "Goblinoids": damage += int(weapon.get("modifiers", {}).get("damage_vs_goblinoids", 0))
	if _has_status(target_id, "Unbalanced") or _has_status(target_id, "OffBalance"): damage += int(weapon.get("modifiers", {}).get("bonus_damage_vs_displaced", 0))
	damage += int(weapon.get("modifiers", {}).get("ordinary_attack_damage_penalty", 0))
	if _has_status("player", "Empowered"):
		damage += 8
		run.entities.player.statuses.erase("Empowered")
	_active_actor_id = "player"
	_active_attack_tags = weapon.get("tags", []).duplicate()
	if not _active_attack_tags.has("melee"): _active_attack_tags.append("melee")
	_emit_combat_event("Attack", "player", target_id, {"style": String(weapon.get("style", "melee")), "damage_type": String(weapon.get("type", "Slashing"))})
	_damage(target_id, damage, String(weapon.get("type", "Slashing")), player.name, "player", int(weapon.get("modifiers", {}).get("armor_penetration_bonus", 0)))
	var offhand_id := String(run.equipment.get("Offhand", ""))
	var offhand_item: Dictionary = content.items.get(offhand_id, {})
	var offhand_weapon: Dictionary = content.weapons.get(String(offhand_item.get("weapon", "")), {})
	if not offhand_weapon.is_empty() and offhand_id != "occupied":
		var stamina_after_main: Array = player.resources.get("Stamina", [0, 0])
		var offhand_cost := int(offhand_weapon.get("stamina", 0))
		if int(stamina_after_main[0]) >= offhand_cost:
			stamina_after_main[0] -= offhand_cost
			player.resources["Stamina"] = stamina_after_main
			_damage(target_id, maxi(1, int(floor(float(offhand_weapon.get("damage", 1)) / 2.0))), String(offhand_weapon.get("type", "Slashing")), player.name, "player")
			_emit_combat_event("Attack", "player", target_id, {"style": "offhand", "damage_type": String(offhand_weapon.get("type", "Slashing"))})
	if weapon.get("style") == "cleave":
		for adjacent in run.entities.keys():
			if adjacent != target_id and adjacent != "player" and run.entities[adjacent].get("alive", true) and _is_hostile("player", adjacent) and _dist(_pos(run.entities[target_id]), _pos(run.entities[adjacent])) <= 1:
				_damage(adjacent, int(damage * 0.65), String(weapon.get("type", "Slashing")), player.name, "player")
	var time_cost := int(weapon.time)
	if not offhand_weapon.is_empty() and offhand_id != "occupied": time_cost = int(ceil(float(time_cost) * 1.25))
	if _has_status("player", "Haste"):
		time_cost = int(time_cost * 0.8)
	_add_log("%s strikes with %s." % [player.name, weapon.name])
	weapon_state["last_action_kind"] = "basic"
	weapon_state["followup_basic"] = false
	run["weapon_state"] = weapon_state
	_active_attack_tags = []
	_check_objective()
	return _spend_player_time(time_cost, "") if spend_turn else {"ok": true, "message": ""}

func _attack_object(object_index: int) -> Dictionary:
	var player: Dictionary = get_player()
	var object: Dictionary = run.objects[object_index]
	if _dist(_pos(player), Vector2i(int(object.pos[0]), int(object.pos[1]))) > 1:
		return {"ok": false, "message": "Move closer to the ritual ward."}
	var weapon: Dictionary = _equipped_weapon_definition()
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

func _cast(ability_id: String, target: Vector2i, spend_turn: bool = true) -> Dictionary:
	if not content.abilities.has(ability_id):
		return {"ok": false, "message": "That ability is unknown."}
	var ability: Dictionary = content.abilities[ability_id]
	if ability.get("kind", "active") == "passive":
		return {"ok": false, "message": "That is a passive ability."}
	var player: Dictionary = get_player()
	var temporary := int(run.temporary_abilities.get(ability_id, 0)) > 0
	var granted := _ability_grant_source(ability_id)
	if not run.known.has(ability_id) and not temporary and granted == "":
		return {"ok": false, "message": "You have not learned %s." % ability.name}
	if bool(ability.get("combination", false)):
		var parents: Array = ability.get("prerequisites", {}).get("all_of", ability.get("requires", []))
		if parents.size() < 2 or not parents.all(func(parent: Variant) -> bool: return run.get("known", []).has(String(parent))):
			return {"ok": false, "message": "Both parent techniques must be owned to use this combination."}
	if ability.get("discovery_required", false) and not run.schools.has(ability.get("school", "")):
		return {"ok": false, "message": "You have not discovered %s." % ability.get("school", "that school")}
	var cooldown := _ability_cooldown_remaining(ability_id)
	if cooldown > 0:
		return {"ok": false, "message": "%s is recovering for %d action%s." % [ability.name, cooldown, "" if cooldown == 1 else "s"]}
	var effective_costs := _ability_effective_costs(ability_id, ability)
	var cost_status := get_cost_status(effective_costs)
	if not cost_status.affordable:
		return {"ok": false, "message": "Requires %s. %s" % [get_cost_summary(effective_costs), "; ".join(cost_status.issues)]}
	var target_mode: String = ability.get("target", "enemy")
	var origin := _pos(player)
	if target_mode == "self":
		target = origin
	elif not is_valid_target_cell(ability_id, target):
		return {"ok": false, "message": _targeting_failure_message(ability_id, target)}
	run["last_player_action"] = {"type": "ability", "ability_id": ability_id, "target_id": _occupant(target), "action_count": int(run.get("player_action_count", 0))}
	_pay(effective_costs)
	var targets: Array = _targets_for_ability(ability, target)
	_active_ability_id = ability_id
	_active_attack_tags = ability.get("tags", []).duplicate()
	_active_actor_id = "player"
	_emit_combat_event("Cast", "player", _occupant(target), {"ability": String(ability.name), "school": String(ability.get("school", "")), "pos": [target.x, target.y]})
	for effect in ability.get("effects", []):
		_apply_effect(effect, target, targets, ability, "player")
	var cooldown_actions := int(ability.get("cooldown", 0))
	if cooldown_actions > 0:
		var cooldowns: Dictionary = run.get("ability_cooldowns", {})
		cooldowns[ability_id] = int(run.get("player_action_count", 0)) + cooldown_actions + 1
		run["ability_cooldowns"] = cooldowns
	if _is_swordplay_technique(ability):
		run["stage_technique_used"] = true
		run["encounter_technique_used"] = true
	if temporary:
		run.temporary_abilities[ability_id] = maxi(0, int(run.temporary_abilities[ability_id]) - 1)
	_emit_trigger("OnCast", {"ability_id": ability_id, "targets": targets, "center": [target.x, target.y], "school": ability.get("school", "")})
	var weapon_state: Dictionary = run.get("weapon_state", {})
	if _is_swordplay_technique(ability) and int(_equipped_weapon_definition().get("modifiers", {}).get("followup_basic_damage_bonus", 0)) > 0:
		weapon_state["followup_basic"] = true
	if ability.get("qualifying_movement", false) and _action_movement_occurred:
		_action_qualifying_technique_movement = true
		if float(_run_modifier("stamina_after_movement_technique", 0.0)) > 0.0: _restore_resource("Stamina", int(_run_modifier("stamina_after_movement_technique", 0.0)), "successful movement technique")
	if _active_action_hit_ids.size() >= 2:
		var restoration := int(_run_modifier("stamina_per_additional_technique_target", 0.0)) * (_active_action_hit_ids.size() - 1)
		if restoration > 0: _restore_resource("Stamina", restoration, "Swordplay technique momentum")
	if weapon_state.get("last_action_kind", "") == "basic" and _is_swordplay_technique(ability):
		weapon_state["alternating_bonus"] = int(_run_modifier("alternating_attack_damage_bonus", 0.0))
	weapon_state["last_action_kind"] = "technique" if _is_swordplay_technique(ability) else "ability"
	run["weapon_state"] = weapon_state
	_active_ability_id = ""
	_active_attack_tags = []
	var time_cost := int(ability.get("time", 100))
	if _has_status("player", "Haste"):
		time_cost = int(time_cost * 0.8)
	_add_log("%s casts %s." % [player.name, ability.name])
	_check_objective()
	return _spend_player_time(time_cost, "") if spend_turn else {"ok": true, "message": ""}

func get_targeting_preview(action_id: String) -> Dictionary:
	var range_cells: Array[Vector2i] = []
	var valid_cells: Array[Vector2i] = []
	var definition := _targeting_definition(action_id)
	if definition.is_empty() or not bool(definition.get("available", false)):
		return {"available": false, "range_cells": range_cells, "valid_cells": valid_cells}
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell := Vector2i(x, y)
			if not _targeting_cell_in_range(action_id, cell, definition):
				continue
			range_cells.append(cell)
			if _targeting_cell_is_valid(action_id, cell, definition):
				valid_cells.append(cell)
	return {"available": true, "range_cells": range_cells, "valid_cells": valid_cells}

func is_valid_target_cell(action_id: String, cell: Vector2i) -> bool:
	var definition := _targeting_definition(action_id)
	return not definition.is_empty() and bool(definition.get("available", false)) and _targeting_cell_is_valid(action_id, cell, definition)

func _targeting_definition(action_id: String) -> Dictionary:
	if action_id == "attack":
		var weapon: Dictionary = _equipped_weapon_definition()
		return {"kind": "attack", "range": int(weapon.get("range", 1)), "available": not weapon.is_empty() and int(get_player().get("resources", {}).get("Stamina", [0, 0])[0]) >= int(weapon.get("stamina", 0))}
	if action_id.begins_with("item:"):
		var index := int(action_id.trim_prefix("item:"))
		if index < 0 or index >= run.get("inventory", []).size():
			return {}
		var item: Dictionary = content.items.get(String(run.inventory[index]), {})
		if item.get("effect", "") == "bomb":
			return {"kind": "bomb", "range": 5, "available": true}
		if item.get("type", "") == "scroll":
			var ability_id := String(item.get("ability", ""))
			var scroll_ability: Dictionary = content.abilities.get(ability_id, {})
			if scroll_ability.is_empty() or scroll_ability.get("target", "enemy") in ["self", "passive"]:
				return {}
			var scroll_cost: Dictionary = get_cost_status(scroll_ability.get("costs", {}))
			return {"kind": "ability", "ability_id": ability_id, "target": String(scroll_ability.get("target", "enemy")), "range": int(scroll_ability.get("range", 0)), "available": bool(scroll_cost.get("affordable", false))}
		return {}
	if not content.get("abilities", {}).has(action_id):
		return {}
	var ability: Dictionary = content.abilities[action_id]
	var target_kind := String(ability.get("target", "enemy"))
	if target_kind in ["self", "passive"] or ability.get("kind", "active") == "passive":
		return {}
	var temporary: bool = int(run.get("temporary_abilities", {}).get(action_id, 0)) > 0
	var known: bool = run.get("known", []).has(action_id) or temporary or _ability_grant_source(action_id) != ""
	if bool(ability.get("combination", false)):
		var parents: Array = ability.get("prerequisites", {}).get("all_of", ability.get("requires", []))
		if parents.size() < 2 or not parents.all(func(parent: Variant) -> bool: return run.get("known", []).has(String(parent))): known = false
	var discovered: bool = not ability.get("discovery_required", false) or run.get("schools", []).has(ability.get("school", ""))
	var effective_costs := _ability_effective_costs(action_id, ability)
	var affordable := bool(get_cost_status(effective_costs).get("affordable", false)) and _ability_cooldown_remaining(action_id) == 0
	var target_range := int(ability.get("range", 0)) + int(_run_modifier("thrust_reach_bonus", 0.0)) if ability.get("tags", []).has("piercing") else int(ability.get("range", 0))
	return {"kind": "ability", "ability_id": action_id, "target": target_kind, "range": target_range, "available": known and discovered and affordable}

func _targeting_cell_in_range(action_id: String, cell: Vector2i, definition: Dictionary) -> bool:
	if not _inside(cell) or not _cell_visible(cell):
		return false
	var origin := _pos(get_player())
	var kind := String(definition.get("kind", ""))
	if kind == "bomb":
		return _dist(origin, cell) <= int(definition.get("range", 0))
	if kind == "attack":
		var target_id := _occupant(cell)
		if target_id != "" and _is_hostile("player", target_id):
			return _distance_to_entity(origin, run.entities[target_id]) <= int(definition.get("range", 0)) and _line_of_sight(origin, cell)
		var object_index := _object_index_at(cell)
		if object_index >= 0 and run.objects[object_index].get("kind", "") == "ward":
			return _dist(origin, cell) <= 1
		return _dist(origin, cell) <= int(definition.get("range", 0)) and _line_of_sight(origin, cell)
	return _dist(origin, cell) <= int(definition.get("range", 0)) and _line_of_sight(origin, cell)

func _targeting_cell_is_valid(action_id: String, cell: Vector2i, definition: Dictionary = {}) -> bool:
	if definition.is_empty():
		definition = _targeting_definition(action_id)
	if definition.is_empty() or not bool(definition.get("available", false)) or not _targeting_cell_in_range(action_id, cell, definition):
		return false
	var kind := String(definition.get("kind", ""))
	if kind == "bomb":
		return true
	if kind == "attack":
		var target_id := _occupant(cell)
		if target_id != "" and _is_hostile("player", target_id):
			return true
		var object_index := _object_index_at(cell)
		return object_index >= 0 and run.objects[object_index].get("kind", "") == "ward" and _dist(_pos(get_player()), cell) <= 1
	var ability: Dictionary = content.abilities.get(String(definition.get("ability_id", action_id)), {})
	if ability.get("effects", []).any(func(effect: Variant) -> bool: return effect is Dictionary and String(effect.get("type", "")) == "line_damage"):
		var delta := cell - _pos(get_player())
		if delta == Vector2i.ZERO or (delta.x != 0 and delta.y != 0 and abs(delta.x) != abs(delta.y)): return false
	match String(definition.get("target", ability.get("target", "enemy"))):
		"enemy":
			var enemy_id := _occupant(cell)
			return enemy_id != "" and _is_hostile("player", enemy_id)
		"tile": return _terrain_at(cell) != "wall"
		"area": return true
	return false

func _targeting_failure_message(action_id: String, cell: Vector2i) -> String:
	if not _inside(cell) or not _cell_visible(cell):
		return "You cannot target a hidden tile."
	var definition := _targeting_definition(action_id)
	var kind := String(definition.get("kind", ""))
	if kind == "attack":
		return "That target is beyond your weapon's reach or blocked from view."
	var target_kind := String(definition.get("target", "enemy"))
	if target_kind == "enemy" and _occupant(cell) == "":
		return "Choose a visible hostile creature."
	if target_kind == "tile" and _terrain_at(cell) == "wall":
		return "That tile is blocked."
	if not _line_of_sight(_pos(get_player()), cell):
		return "You cannot see a clear path to that target."
	return "That target is outside the ability's reach."

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

func _apply_effect(effect: Dictionary, center: Vector2i, targets: Array, ability: Dictionary, actor_id: String = "player") -> void:
	var effect_type := String(effect.get("type", ""))
	var source_name := String(ability.get("name", "an attack"))
	match effect_type:
		"damage", "execute_damage", "heavy_damage":
			for target_value in targets:
				var target_id := String(target_value)
				if not run.get("entities", {}).has(target_id) or not run.entities[target_id].get("alive", true) or not _is_hostile(actor_id, target_id): continue
				var amount := int(effect.get("amount", 0))
				var armor_penetration := int(effect.get("armor_penetration", 0))
				if effect_type == "execute_damage":
					var threshold := float(effect.get("threshold", 0.0)) + _actor_modifier(actor_id, "execute_threshold_bonus", 0.0)
					if float(run.entities[target_id].get("hp", 0)) / maxf(1.0, float(run.entities[target_id].get("max_hp", 1))) <= threshold:
						amount += int(effect.get("bonus", 0))
				if effect_type == "heavy_damage":
					armor_penetration += int(_actor_modifier(actor_id, "armor_penetration_bonus", 0.0))
					amount += int(run.entities[target_id].get("armor", 0)) * int(effect.get("bonus_per_armor", 0))
				if actor_id == "player" and _has_status(target_id, "Exposed") and (_active_attack_tags.has("sword") or _active_attack_tags.has("technique")):
					amount = int(ceil(float(amount) * 1.35))
					run.entities[target_id].statuses.erase("Exposed")
				var weapon_state: Dictionary = run.get("weapon_state", {})
				if actor_id == "player":
					amount += int(weapon_state.get("precision", 0)) * int(_run_modifier("precision_damage_per_stack", 0.0))
					if weapon_state.get("last_action_kind", "") == "basic" and _is_swordplay_technique(ability): amount += int(_run_modifier("alternating_attack_damage_bonus", 0.0))
					amount += int(weapon_state.get("technique_kill_stacks", 0)) * int(_equipped_weapon_definition().get("modifiers", {}).get("technique_kill_stack_bonus", 0))
				var repetitions := maxi(1, int(effect.get("repeats", 1)))
				for _repeat_index in range(repetitions):
					_damage(target_id, amount, String(effect.get("damage", "Slashing")), source_name, actor_id, armor_penetration)
					if actor_id == "player" and run.entities.get(target_id, {}).get("alive", false):
						if not _active_action_hit_ids.has(target_id): _active_action_hit_ids.append(target_id)
					if not run.entities.get(target_id, {}).get("alive", false) and actor_id == "player" and not _current_action_kills.has(target_id):
						_current_action_kills.append(target_id)
				if actor_id == "player":
					weapon_state["alternating_bonus"] = 0
					run["weapon_state"] = weapon_state
		"radial_damage":
			var radius := int(effect.get("radius", 1))
			for candidate_id in run.entities.keys():
				if candidate_id != actor_id and run.entities[candidate_id].get("alive", false) and _is_hostile(actor_id, String(candidate_id)) and _dist(_pos(run.entities[actor_id]), _pos(run.entities[candidate_id])) <= radius:
					_apply_effect({"type": "damage", "amount": effect.get("amount", 0), "damage": effect.get("damage", "Slashing")}, center, [candidate_id], ability, actor_id)
		"wide_arc_damage":
			var arc_targets := _targets_in_forward_arc(actor_id, center, maxi(1, int(effect.get("radius", 2))))
			for candidate_id in arc_targets:
				_apply_effect({"type": "damage", "amount": effect.get("amount", 0), "damage": effect.get("damage", "Slashing")}, center, [candidate_id], ability, actor_id)
		"line_damage":
			var max_targets := int(effect.get("max_targets", 1))
			if actor_id == "player": max_targets += int(_equipped_weapon_definition().get("modifiers", {}).get("line_extra_targets", 0))
			var line_targets := _hostiles_on_line(actor_id, center, int(ability.get("range", 1)) + int(_actor_modifier(actor_id, "thrust_reach_bonus", 0.0)), max_targets)
			for candidate_id in line_targets:
				_apply_effect({"type": "damage", "amount": effect.get("amount", 0), "damage": effect.get("damage", "Piercing"), "armor_penetration": effect.get("armor_penetration", 0)}, center, [candidate_id], ability, actor_id)
		"status":
			var status_target_mode := String(effect.get("target", "self" if String(ability.get("target", "enemy")) == "self" else ""))
			var status_targets: Array = [actor_id] if status_target_mode == "self" else targets
			for target_id in status_targets:
				_apply_status(String(target_id), String(effect.get("id", "")), int(effect.get("stacks", 1)), source_name, actor_id)
		"heal":
			var heal_target := String(targets[0]) if not targets.is_empty() else actor_id
			var target_entity: Dictionary = run.entities.get(heal_target, {})
			var health_before := int(target_entity.get("hp", 0))
			target_entity["hp"] = mini(int(target_entity.get("max_hp", health_before)), health_before + int(effect.get("amount", 0)))
			if int(target_entity.get("hp", 0)) > health_before:
				_emit_combat_event("Heal", actor_id, heal_target, {"amount": int(target_entity.hp) - health_before})
				_emit_trigger("OnHeal", {"target_id": heal_target, "source": source_name, "amount": int(target_entity.hp) - health_before})
		"heal_on_hit":
			if not targets.is_empty() and actor_id == "player":
				_restore_resource("Health", 0, source_name)
				var player := get_player()
				var health_before := int(player.hp)
				player.hp = mini(int(player.max_hp), int(player.hp) + int(effect.get("amount", 0)) + int(_artifact_modifier("blood_lance_heal_bonus", 0.0)))
				if int(player.hp) > health_before: _emit_combat_event("Heal", actor_id, actor_id, {"amount": int(player.hp) - health_before})
		"terrain":
			var radius := int(ability.get("radius", 0))
			for y in range(maxi(1, center.y - radius), mini(HEIGHT - 1, center.y + radius + 1)):
				for x in range(maxi(1, center.x - radius), mini(WIDTH - 1, center.x + radius + 1)):
					if _dist(center, Vector2i(x, y)) <= radius + 1: _transform_terrain(Vector2i(x, y), String(effect.get("id", "floor")))
		"teleport":
			if _movement_cell_passable(center, actor_id): _move_actor_to(actor_id, center, "teleport")
		"move":
			var steps := int(effect.get("distance", 1))
			while steps > 0:
				var step := _next_step(_pos(run.entities[actor_id]), center, actor_id)
				if step == _pos(run.entities[actor_id]): break
				if _move_actor_to(actor_id, step, "technique"): steps -= 1
		"approach":
			for _step_index in range(maxi(1, int(effect.get("distance", 1)))):
				var next_step := _next_step(_pos(run.entities[actor_id]), center, actor_id)
				if next_step == _pos(run.entities[actor_id]) or _dist(next_step, center) >= _dist(_pos(run.entities[actor_id]), center): break
				if not _move_actor_to(actor_id, next_step, "lunge"): break
		"advance_if_vacated":
			var target_id := _occupant(center)
			if target_id == "" and not targets.is_empty(): target_id = String(targets[0])
			if target_id != "" and run.entities.has(target_id):
				var vacated := _pos(run.entities[target_id])
				if (not run.entities[target_id].get("alive", false) or vacated != center) and _movement_cell_passable(vacated, actor_id): _move_actor_to(actor_id, vacated, "advance")
		"reposition":
			var threat := _pos(run.entities[String(targets[0])]) if not targets.is_empty() and run.entities.has(String(targets[0])) else center
			for _step_index in range(maxi(1, int(effect.get("distance", 1)))):
				var retreat := _retreat_step(_pos(run.entities[actor_id]), threat, actor_id)
				if retreat == _pos(run.entities[actor_id]): break
				_move_actor_to(actor_id, retreat, "reposition")
		"retreat":
			var threat := _pos(run.entities[String(targets[0])]) if not targets.is_empty() and run.entities.has(String(targets[0])) else center
			var distance := int(effect.get("distance", 1)) + int(_actor_modifier(actor_id, "forced_movement_bonus", 0.0))
			for _step_index in range(maxi(1, distance)):
				var retreat := _retreat_step(_pos(run.entities[actor_id]), threat, actor_id)
				if retreat == _pos(run.entities[actor_id]): break
				_move_actor_to(actor_id, retreat, "retreat")
		"knockback":
			for target_value in targets:
				_knockback(String(target_value), actor_id, int(effect.get("distance", 1)), int(effect.get("collision_damage", 0)), int(effect.get("collision_stun", 0)))
		"sweep":
			var sweep_targets := _targets_in_forward_arc(actor_id, center, 1)
			for candidate_id in sweep_targets:
				_apply_effect({"type": "damage", "amount": effect.get("amount", 0), "damage": effect.get("damage", "Slashing")}, center, [candidate_id], ability, actor_id)
			for candidate_id in sweep_targets:
				_knockback(String(candidate_id), actor_id, int(effect.get("knockback", 1)) + int(_actor_modifier(actor_id, "forced_movement_bonus", 0.0)), int(effect.get("collision_damage", 0)) + int(_actor_modifier(actor_id, "collision_damage_bonus", 0.0)), int(effect.get("collision_stun", 0)))
		"charge_line":
			_resolve_charge_line(actor_id, center, effect, ability)
		"dance_route":
			_resolve_dance_route(actor_id, center, effect, ability)
		"summon":
			for _summon_index in range(int(effect.get("count", 1))):
				if not _spawn_summon(String(effect.get("id", "")), center): _add_log("Command or space is insufficient for the summon.")
		"resource":
			if actor_id == "player": _restore_resource(String(effect.get("id", "")), int(effect.get("amount", 0)), source_name)

func _restore_resource(resource_id: String, amount: int, source: String = "") -> void:
	if amount <= 0 or not run.get("entities", {}).has("player"): return
	var values: Array = get_player().resources.get(resource_id, [0, 0])
	var before := int(values[0])
	values[0] = clampi(before + amount, 0, int(values[1]))
	get_player().resources[resource_id] = values
	if int(values[0]) > before:
		_emit_combat_event("ResourceGained", "player", "player", {"resource": resource_id, "amount": int(values[0]) - before, "source": source})

func _move_actor_to(actor_id: String, destination: Vector2i, style: String) -> bool:
	if not run.get("entities", {}).has(actor_id) or not _movement_cell_passable(destination, actor_id): return false
	var actor: Dictionary = run.entities[actor_id]
	var previous := _pos(actor)
	if previous == destination: return false
	actor["pos"] = [destination.x, destination.y]
	_emit_combat_event("Move", actor_id, "", {"from": [previous.x, previous.y], "to": [destination.x, destination.y], "style": style})
	_emit_trigger("OnMove", {"entity_id": actor_id, "from": [previous.x, previous.y], "pos": [destination.x, destination.y]})
	_emit_trigger("OnTerrainEntered", {"entity_id": actor_id, "terrain": _terrain_at(destination), "pos": [destination.x, destination.y]})
	if actor_id == "player": _action_movement_occurred = true
	if _terrain_at(destination) == "water": _apply_status(actor_id, "Wet", 1)
	if _terrain_at(destination) == "fire": _damage(actor_id, 5, "Fire", "the burning ground")
	_check_objective_at_player() if actor_id == "player" else null
	_place_pending_summons()
	return true

func _hostiles_on_line(actor_id: String, aim: Vector2i, maximum_distance: int, maximum_targets: int) -> Array[String]:
	var result: Array[String] = []
	if maximum_targets <= 0: return result
	var origin := _pos(run.entities[actor_id])
	var delta := aim - origin
	var direction := Vector2i(signi(delta.x), signi(delta.y))
	if direction == Vector2i.ZERO or (delta.x != 0 and delta.y != 0 and abs(delta.x) != abs(delta.y)): return result
	for distance in range(1, maxi(1, maximum_distance) + 1):
		var cell := origin + direction * distance
		if not _inside(cell) or _terrain_at(cell) == "wall": break
		var occupant := _occupant(cell)
		if occupant != "" and _is_hostile(actor_id, occupant) and not result.has(occupant):
			result.append(occupant)
			if result.size() >= maximum_targets: break
	return result

func _targets_in_forward_arc(actor_id: String, aim: Vector2i, radius: int) -> Array[String]:
	var result: Array[String] = []
	if not run.get("entities", {}).has(actor_id): return result
	var origin := _pos(run.entities[actor_id])
	var facing := Vector2i(signi(aim.x - origin.x), signi(aim.y - origin.y))
	if facing == Vector2i.ZERO: facing = Vector2i(1, 0)
	for candidate_id in run.entities.keys():
		if String(candidate_id) == actor_id or not run.entities[candidate_id].get("alive", false) or not _is_hostile(actor_id, String(candidate_id)): continue
		var pos := _pos(run.entities[candidate_id])
		var delta := pos - origin
		if _dist(origin, pos) > radius or (delta.x * facing.x + delta.y * facing.y) < 0: continue
		if _line_of_sight(origin, pos): result.append(String(candidate_id))
	result.sort()
	return result

func _knockback(target_id: String, source_id: String, distance: int, collision_damage: int, collision_stun: int) -> void:
	if not run.get("entities", {}).has(target_id) or not run.entities[target_id].get("alive", false) or not run.entities.has(source_id): return
	var direction_delta := _pos(run.entities[target_id]) - _pos(run.entities[source_id])
	var direction := Vector2i(signi(direction_delta.x), signi(direction_delta.y))
	if direction == Vector2i.ZERO: return
	var steps := maxi(1, distance + int(_actor_modifier(source_id, "forced_movement_bonus", 0.0)))
	var collided := false
	for _step_index in range(steps):
		var current := _pos(run.entities[target_id])
		var next := current + direction
		if not _inside(next) or _terrain_at(next) == "wall":
			collided = true
			break
		var blocker := _occupant(next, target_id)
		if blocker != "":
			collided = true
			if _is_hostile(source_id, blocker):
				var impact := maxi(1, int(collision_damage) + int(_actor_modifier(source_id, "collision_damage_bonus", 0.0)))
				_damage(blocker, impact, "Blunt", "the collision", source_id)
				if collision_stun > 0: _apply_status(blocker, "Stunned", collision_stun, "the collision", source_id)
			break
		if not _move_actor_to(target_id, next, "forced"): collided = true; break
	if collided and run.entities.get(target_id, {}).get("alive", false):
		var impact_damage := maxi(1, int(collision_damage) + int(_actor_modifier(source_id, "collision_damage_bonus", 0.0)))
		_damage(target_id, impact_damage, "Blunt", "the collision", source_id)
		if collision_stun > 0: _apply_status(target_id, "Stunned", collision_stun, "the collision", source_id)

func _resolve_charge_line(actor_id: String, aim: Vector2i, effect: Dictionary, ability: Dictionary) -> void:
	var origin := _pos(run.entities[actor_id])
	var delta := aim - origin
	var direction := Vector2i(signi(delta.x), signi(delta.y))
	if direction == Vector2i.ZERO or (delta.x != 0 and delta.y != 0 and abs(delta.x) != abs(delta.y)): return
	var max_distance := mini(int(effect.get("distance", 1)), _dist(origin, aim))
	var continue_through_kills := bool(effect.get("continue_through_kills", false))
	var max_targets := int(effect.get("max_targets", 1))
	if max_targets <= 0: max_targets = 1
	var hit_count := 0
	for _step_index in range(max_distance):
		var next := _pos(run.entities[actor_id]) + direction
		if not _inside(next) or _terrain_at(next) == "wall": break
		var occupant := _occupant(next, actor_id)
		if occupant != "" and _is_hostile(actor_id, occupant):
			_apply_effect({"type": "damage", "amount": effect.get("amount", 0), "damage": effect.get("damage", "Slashing")}, next, [occupant], ability, actor_id)
			hit_count += 1
			if not run.entities.get(occupant, {}).get("alive", false):
				if continue_through_kills and _movement_cell_passable(next, actor_id): _move_actor_to(actor_id, next, "charge")
				else: break
			else: break
		elif occupant != "": break
		elif not _move_actor_to(actor_id, next, "charge"):
			break
		if hit_count >= max_targets: break

func _resolve_dance_route(actor_id: String, aim: Vector2i, effect: Dictionary, ability: Dictionary) -> void:
	var origin := _pos(run.entities[actor_id])
	var path := _find_movement_path(origin, aim, actor_id)
	var distance := mini(int(effect.get("distance", 1)), path.size())
	if distance <= 0: return
	var visited: Array[String] = []
	for step_index in range(distance):
		var step: Vector2i = path[step_index]
		if not _move_actor_to(actor_id, step, "dance"): break
		var nearby: Array[String] = []
		for candidate_id in run.entities.keys():
			if String(candidate_id) != actor_id and run.entities[candidate_id].get("alive", false) and _is_hostile(actor_id, String(candidate_id)) and _dist(step, _pos(run.entities[candidate_id])) <= int(effect.get("radius", 1)) and not visited.has(String(candidate_id)):
				nearby.append(String(candidate_id))
		nearby.sort()
		for candidate_id in nearby:
			visited.append(candidate_id)
			_apply_effect({"type": "damage", "amount": effect.get("amount", 0), "damage": effect.get("damage", "Slashing")}, step, [candidate_id], ability, actor_id)

func _interact(target: Vector2i) -> Dictionary:
	var object_index := _object_index_at(target)
	if object_index < 0:
		return {"ok": false, "message": "There is nothing to interact with here."}
	var object: Dictionary = run.objects[object_index]
	if _dist(_pos(get_player()), target) > 1:
		return {"ok": false, "message": "Move beside it first."}
	if object.get("kind") == "exit":
		get_player().pos = [target.x, target.y]
		_check_objective_at_player()
		return _spend_player_time(60, "You reach the March road.")
	if object.get("kind") == "chest":
		var candidates := get_reward_candidates(true)
		if candidates.is_empty(): return {"ok": false, "message": "The chest is empty."}
		var reward := _pick_weighted_candidate(candidates)
		if reward.get("type") == "item" and run.inventory.size() >= 30:
			return {"ok": false, "message": "Your pack is full. Make room before opening the chest."}
		run["exploration_rewards_found"] = int(run.get("exploration_rewards_found", 0)) + 1
		run.objects[object_index]["contents"] = {"type": reward.type, "id": reward.id}
		run.objects[object_index]["opened"] = true
		run.objects[object_index]["hp"] = 0
		if reward.type == "artifact":
			_acquire_artifact(String(reward.id))
			_record_build_tags(content.artifacts[reward.id].get("tags", []))
			_add_log("The chest yields %s." % content.artifacts[reward.id].name)
		elif reward.type == "relic":
			_acquire_relic(String(reward.id))
			_record_build_tags(content.relics[reward.id].get("tags", []))
			_add_log("The chest yields %s." % content.relics[reward.id].name)
		else:
			run.inventory.append(String(reward.id))
			_record_build_tags(content.items[reward.id].get("tags", []))
			_add_log("The chest yields %s." % content.items[reward.id].name)
		return _spend_player_time(60, "You open the chest.")
	if object.get("kind") in ["skill_book", "item", "loot"]:
		if run.inventory.size() >= 30:
			return {"ok": false, "message": "Your pack is full. Discard an item before picking this up."}
		var item_id := String(object.get("item_id", ""))
		if not content.get("items", {}).has(item_id): return {"ok": false, "message": "This loot has no valid item."}
		run.inventory.append(item_id)
		run["exploration_rewards_found"] = int(run.get("exploration_rewards_found", 0)) + 1
		run.objects[object_index]["hp"] = 0
		_record_build_tags(content.items[item_id].get("tags", []))
		_add_log("Picked up %s." % content.items[item_id].get("name", item_id))
		return _spend_player_time(45, "You collect the field loot.")
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
	actor["technique_turn_count"] = int(actor.get("technique_turn_count", 0)) + 1
	_emit_combat_event("ActorTurnStarted", actor_id, "", {})
	_emit_trigger("OnTurn", {"entity_id": actor_id, "faction": actor.get("faction", "")})
	if bool(actor.get("follow_owner", false)):
		_companion_turn(actor_id)
		return
	var behavior: String = actor.get("summon_behavior", actor.get("behavior", "melee"))
	var target_id := _choose_target(actor_id)
	if target_id == "":
		return
	var target: Dictionary = run.entities[target_id]
	var origin := _pos(actor)
	var target_pos := _pos(target)
	var distance := _distance_to_entity(origin, target)
	if _enemy_tactical_ability(actor_id, target_id):
		return
	if behavior == "boss" and String(actor.get("enemy_id", "")) == "grave_tyrant":
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

func _choose_companion_target(actor_id: String, owner_id: String) -> String:
	if not run.entities.has(actor_id) or not run.entities.has(owner_id): return ""
	var actor: Dictionary = run.entities[actor_id]
	var owner_position := _pos(run.entities[owner_id])
	var selected := ""
	var selected_owner_distance := 2147483647
	var selected_actor_distance := 2147483647
	var leash := maxi(0, int(actor.get("companion_engage_distance", 4)))
	var sight := maxi(0, int(actor.get("sight", 8)))
	for candidate_id in run.entities:
		if candidate_id == actor_id or not run.entities[candidate_id].get("alive", false) or not _is_hostile(actor_id, String(candidate_id)): continue
		var candidate: Dictionary = run.entities[candidate_id]
		var owner_distance := _distance_to_entity(owner_position, candidate)
		var actor_distance := _distance_to_entity(_pos(actor), candidate)
		if owner_distance > leash or actor_distance > sight or not _line_of_sight(_pos(actor), _pos(candidate)): continue
		if owner_distance < selected_owner_distance or (owner_distance == selected_owner_distance and (actor_distance < selected_actor_distance or (actor_distance == selected_actor_distance and String(candidate_id) < selected))):
			selected = String(candidate_id)
			selected_owner_distance = owner_distance
			selected_actor_distance = actor_distance
	return selected

func _companion_turn(actor_id: String) -> void:
	var actor: Dictionary = run.entities.get(actor_id, {})
	var owner_id := String(actor.get("owner", ""))
	if actor.is_empty() or not run.entities.has(owner_id) or not run.entities[owner_id].get("alive", false): return
	var origin := _pos(actor)
	var owner_position := _pos(run.entities[owner_id])
	var owner_distance := _dist(origin, owner_position)
	var return_distance := maxi(3, int(actor.get("companion_return_distance", 4)))
	var minimum_distance := maxi(1, int(actor.get("companion_min_follow_distance", 1)))
	var preferred_distance := maxi(1, int(actor.get("companion_follow_distance", 2)))
	if owner_distance > return_distance:
		_companion_follow_owner(actor_id, owner_position)
		return
	var target_id := _choose_companion_target(actor_id, owner_id)
	if target_id != "":
		var target: Dictionary = run.entities[target_id]
		var target_distance := _distance_to_entity(origin, target)
		var attack_range := maxi(0, int(actor.get("range", 1)))
		if target_distance <= attack_range and _line_of_sight(origin, _pos(target)):
			_emit_combat_event("Attack", actor_id, target_id, {"style": "projectile" if String(actor.get("summon_behavior", "")) == "orbit_assault" else "melee", "damage_type": String(actor.get("damage_type", "Blunt"))})
			_damage(target_id, int(actor.get("damage", 5)), String(actor.get("damage_type", "Blunt")), String(actor.get("name", "A companion")), actor_id)
			_add_log("%s attacks %s." % [String(actor.get("name", "A companion")), String(target.get("name", "a foe"))])
			return
		var step := _next_step(origin, _pos(target), actor_id)
		if step != origin:
			_move_actor_to(actor_id, step, "companion")
			return
	if owner_distance < minimum_distance or owner_distance > preferred_distance:
		_companion_follow_owner(actor_id, owner_position)

func _companion_follow_owner(actor_id: String, owner_position: Vector2i) -> void:
	var origin := _pos(run.entities[actor_id])
	if origin == owner_position:
		for direction in DIRECTIONS:
			var candidate: Vector2i = owner_position + direction
			if _movement_cell_passable(candidate, actor_id):
				_move_actor_to(actor_id, candidate, "follow")
				return
		return
	var step := _next_step(origin, owner_position, actor_id)
	if step != origin:
		_move_actor_to(actor_id, step, "follow")

func _enemy_tactical_ability(actor_id: String, target_id: String) -> bool:
	var actor: Dictionary = run.entities.get(actor_id, {})
	var technique_ids: Array = actor.get("techniques", [])
	if technique_ids.is_empty(): return false
	var target: Dictionary = run.entities.get(target_id, {})
	var distance := _distance_to_entity(_pos(actor), target)
	var last_action: Dictionary = run.get("last_player_action", {})
	var candidates: Array = []
	for ability_id_value in technique_ids:
		var ability_id := String(ability_id_value)
		var ability: Dictionary = content.get("abilities", {}).get(ability_id, {})
		if ability.is_empty() or ability.get("kind", "active") == "passive": continue
		var cooldowns: Dictionary = actor.get("technique_cooldowns", {})
		if int(cooldowns.get(ability_id, 0)) > int(actor.get("technique_turn_count", 0)): continue
		var ai: Dictionary = ability.get("ai", {})
		var role := String(ai.get("role", "attack"))
		var target_mode := String(ability.get("target", "enemy"))
		var ability_range := int(ability.get("range", 1))
		var in_range := distance <= ability_range
		var usable := false
		match role:
			"parry":
				usable = String(last_action.get("target_id", "")) == actor_id and distance <= 1 and not _has_status(actor_id, "Parrying") and not _has_status(actor_id, "PerfectParrying")
			"gap_close":
				usable = distance > 1 and distance <= ability_range and _line_of_sight(_pos(actor), _pos(target))
			"execute":
				var threshold := float(ai.get("target_health_below", 0.35))
				usable = in_range and float(target.hp) / maxf(1.0, float(target.get("max_hp", 1))) <= threshold
			"area":
				var radius := int(ability.get("radius", 1))
				for effect in ability.get("effects", []): radius = maxi(radius, int(effect.get("radius", radius)))
				var area_targets: Array[String] = []
				if target_mode == "self":
					for candidate_id in run.entities:
						if candidate_id != actor_id and run.entities[candidate_id].get("alive", false) and _is_hostile(actor_id, String(candidate_id)) and _dist(_pos(actor), _pos(run.entities[candidate_id])) <= radius:
							area_targets.append(String(candidate_id))
				else:
					area_targets = _targets_in_forward_arc(actor_id, _pos(target), radius)
				usable = area_targets.size() >= int(ai.get("min_targets", 2))
			"line":
				var line_target_count := int(ability.get("effects", [{}])[0].get("max_targets", 1))
				usable = distance <= ability_range and _hostiles_on_line(actor_id, _pos(target), ability_range, maxi(1, line_target_count)).has(target_id)
			"retreat":
				usable = in_range and distance <= 1 and _retreat_step(_pos(actor), _pos(target), actor_id) != _pos(actor)
			"reposition":
				usable = distance <= 1 and float(actor.hp) / maxf(1.0, float(actor.get("max_hp", 1))) < 0.65 and _retreat_step(_pos(actor), _pos(target), actor_id) != _pos(actor)
			"setup":
				usable = in_range and not _has_status(target_id, "Exposed")
			"knockback":
				usable = in_range and distance <= 1
			"heavy":
				usable = in_range and (int(target.get("armor", 0)) > 0 or bool(actor.get("elite", false)) or bool(actor.get("kind", "") == "boss"))
			"advance":
				usable = in_range and distance <= 1
			_:
				usable = in_range
		if target_mode == "self":
			if role == "parry": usable = String(last_action.get("target_id", "")) == actor_id and distance <= 1 and not _has_status(actor_id, "Parrying") and not _has_status(actor_id, "PerfectParrying")
			elif role != "area": usable = false
		if not usable: continue
		var effects: Array = ability.get("effects", [])
		if effects.any(func(effect: Variant) -> bool: return effect is Dictionary and String(effect.get("type", "")) == "line_damage"):
			var delta := _pos(target) - _pos(actor)
			if (delta.x != 0 and delta.y != 0 and abs(delta.x) != abs(delta.y)) or delta == Vector2i.ZERO: continue
		if not _line_of_sight(_pos(actor), _pos(target)) and target_mode != "self": continue
		candidates.append({"id": ability_id, "priority": int(ai.get("priority", 1)), "ability": ability})
	if candidates.is_empty(): return false
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.priority) != int(b.priority): return int(a.priority) > int(b.priority)
		return String(a.id) < String(b.id)
	)
	var selected: Dictionary = candidates[0]
	var ability_id := String(selected.id)
	var ability: Dictionary = selected.ability
	var center := _pos(actor) if String(ability.get("target", "enemy")) == "self" else _pos(target)
	var effect_targets: Array = [target_id] if String(ability.get("target", "enemy")) == "enemy" else []
	_active_actor_id = actor_id
	_active_ability_id = ability_id
	_active_attack_tags = ability.get("tags", []).duplicate()
	_emit_combat_event("Cast", actor_id, target_id, {"ability": String(ability.get("name", ability_id)), "school": String(ability.get("school", "")), "pos": [center.x, center.y]})
	for effect in ability.get("effects", []): _apply_effect(effect, center, effect_targets, ability, actor_id)
	var cooldowns: Dictionary = actor.get("technique_cooldowns", {})
	var cooldown_turns := int(ability.get("cooldown", 0))
	if cooldown_turns > 0: cooldowns[ability_id] = int(actor.get("technique_turn_count", 0)) + cooldown_turns + 1
	actor["technique_cooldowns"] = cooldowns
	_emit_trigger("OnCast", {"ability_id": ability_id, "targets": effect_targets, "center": [center.x, center.y], "school": ability.get("school", "")})
	_add_log("%s uses %s." % [String(actor.get("name", "The foe")), String(ability.get("name", ability_id))])
	_active_actor_id = "player"
	_active_ability_id = ""
	_active_attack_tags = []
	return true

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

func _damage(target_id: String, raw_amount: int, damage_type: String, source: String, source_id: String = "", armor_penetration: int = 0) -> void:
	if not run.entities.has(target_id) or not run.entities[target_id].get("alive", true):
		return
	var target: Dictionary = run.entities[target_id]
	var amount := maxi(0, raw_amount)
	var is_physical := damage_type in ["Slashing", "Piercing", "Blunt"]
	var melee_attack := is_physical and _is_melee_attack(source_id, target_id)
	var fully_negated := false
	if melee_attack and amount > 0 and (_has_status(target_id, "Parrying") or _has_status(target_id, "PerfectParrying")):
		var player_parry_bonus := target_id == "player"
		var perfect := _has_status(target_id, "PerfectParrying") or player_parry_bonus and float(_run_modifier("parry_full_negate", 0.0)) > 0.0
		fully_negated = perfect
		var reduction_bonus := float(_run_modifier("parry_reduction_bonus", 0.0)) if player_parry_bonus else 0.0
		var reduction := clampf(0.75 + reduction_bonus, 0.0, 1.0)
		amount = 0 if perfect else int(ceil(float(amount) * (1.0 - reduction)))
		target.statuses.erase("Parrying")
		target.statuses.erase("PerfectParrying")
		_emit_combat_event("Parry", target_id, source_id, {"perfect": perfect, "negated": perfect, "reduction": reduction})
		if target_id == "player":
			run["successful_parries"] = int(run.get("successful_parries", 0)) + 1
			if float(_run_modifier("stamina_on_parry", 0.0)) > 0.0: _restore_resource("Stamina", int(_run_modifier("stamina_on_parry", 0.0)), "successful Parry")
			if float(_run_modifier("guard_after_parry", 0.0)) > 0.0: _apply_status("player", "Guard", 1, "a successful Parry", "player")
		if perfect and source_id != "" and collision_source_exists(source_id):
			if float(_run_modifier("parry_stun", 1.0)) > 0.0: _apply_status(source_id, "Stunned", 1, "a Perfect Parry", target_id)
		_add_log("%s turns aside the melee strike." % String(target.get("name", "The defender")))
	if _has_status(target_id, "OffBalance") and is_physical:
		amount = int(ceil(float(amount) * 1.25))
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
	if not fully_negated and int(target.get("armor", 0)) > 0 and damage_type in ["Slashing", "Piercing", "Blunt"]:
		amount = maxi(1, amount - maxi(0, int(target.armor) - maxi(0, armor_penetration)))
	if target_id == "player" and amount > 0:
		amount = maxi(1, int(round(float(amount) * (1.0 - clampf(get_passive_modifier("damage_reduction"), 0.0, 0.6)))))
	if not fully_negated and _has_status(target_id, "Guard"):
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
		if amount > 0:
			var weapon_state: Dictionary = run.get("weapon_state", {})
			weapon_state["unhurt_actions"] = 0
			weapon_state["precision"] = 0
			run["weapon_state"] = weapon_state
	else:
		_add_log("%s takes %d damage." % [target.get("name", "A creature"), amount])
		if source_id == "player" and amount > 0 and not _active_action_hit_ids.has(target_id): _active_action_hit_ids.append(target_id)
	if int(target.hp) <= 0:
		_on_death(target_id, source, source_id)

func _is_melee_attack(source_id: String, target_id: String) -> bool:
	if source_id == "": return _active_attack_tags.has("melee") or _active_attack_tags.has("technique")
	if source_id == "player": return _active_attack_tags.has("melee") or _active_attack_tags.has("technique") or _active_ability_id != ""
	if not run.get("entities", {}).has(source_id) or not run.get("entities", {}).has(target_id): return false
	if _active_actor_id == source_id and (_active_attack_tags.has("melee") or _active_attack_tags.has("technique")): return true
	var attacker: Dictionary = run.entities[source_id]
	var behavior := String(attacker.get("behavior", "melee"))
	return behavior not in ["ranged", "caster", "orbit_assault"] and _distance_to_entity(_pos(attacker), run.entities[target_id]) <= 1

func collision_source_exists(source_id: String) -> bool:
	return run.get("entities", {}).has(source_id) and run.entities[source_id].get("alive", false)

func _on_death(entity_id: String, source: String, source_id: String = "") -> void:
	var entity: Dictionary = run.entities[entity_id]
	if not entity.get("alive", true):
		return
	entity.alive = false
	_emit_combat_event("Death", "", entity_id, {"name": String(entity.get("name", "Creature")), "pos": entity.get("pos", []).duplicate()})
	_emit_trigger("OnDeath", {"entity_id": entity_id, "faction": entity.get("faction", ""), "source": source, "pos": entity.get("pos", []).duplicate()})
	if entity_id == "player":
		entity.hp = 0
		run["outcome"] = "defeat"
		run["run_summary"] = get_summary()
		return
	if source_id == "player" and not _current_action_kills.has(entity_id): _current_action_kills.append(entity_id)
	if source_id == "player" and not _current_action_kills.has(entity_id): _current_action_kills.append(entity_id)
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
				var wielded_weapon := _equipped_weapon_definition()
				var weapon_modifiers: Dictionary = wielded_weapon.get("modifiers", {})
				if entity.get("faction", "") == "Goblinoids" and int(weapon_modifiers.get("cooldown_reduction_on_kill", 0)) > 0:
					_reduce_sword_technique_cooldowns(int(weapon_modifiers.cooldown_reduction_on_kill))
				if _active_ability_id != "" and content.get("abilities", {}).has(_active_ability_id):
					var active_ability: Dictionary = content.abilities[_active_ability_id]
					if _is_swordplay_technique(active_ability):
						var gained_stacks := int(weapon_modifiers.get("technique_kill_stack_bonus", 0))
						if gained_stacks > 0:
							var weapon_state: Dictionary = run.get("weapon_state", {})
							weapon_state["technique_kill_stacks"] = mini(int(weapon_modifiers.get("technique_kill_stack_max", 99)), int(weapon_state.get("technique_kill_stacks", 0)) + gained_stacks)
							run["weapon_state"] = weapon_state
						var on_kill: Dictionary = active_ability.get("on_kill", {})
						var restore_values: Dictionary = on_kill.get("restore", on_kill.get("resources", {}))
						for resource_id in restore_values: _restore_resource(String(resource_id), int(restore_values[resource_id]), String(active_ability.get("name", "technique")))
						var cooldown_refund := int(on_kill.get("cooldown_reduction", on_kill.get("cooldown_refund", 0)))
						if cooldown_refund > 0:
							var cooldowns: Dictionary = run.get("ability_cooldowns", {})
							cooldowns[_active_ability_id] = maxi(int(run.get("player_action_count", 0)), int(cooldowns.get(_active_ability_id, 0)) - cooldown_refund)
							run["ability_cooldowns"] = cooldowns
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
	if entity.get("kind", "") == "boss":
		run["bosses_defeated"] = _increment_decimal(_normalize_counter(run.get("bosses_defeated", "0")))
		var defeated_boss_ids: Array = run.get("defeated_boss_ids", [])
		var defeated_boss_id := String(run.get("current_map", {}).get("boss_id", ""))
		if defeated_boss_id != "" and not defeated_boss_ids.has(defeated_boss_id): defeated_boss_ids.append(defeated_boss_id)
		run["defeated_boss_ids"] = defeated_boss_ids
		var boss_definition: Dictionary = content.get("bosses", {}).get(defeated_boss_id, {})
		var unlock_character_id := String(boss_definition.get("unlock_character_id", ""))
		if unlock_character_id != "" and not run.get("boss_unlocks_awarded", []).has(defeated_boss_id):
			unlock_character(unlock_character_id)
			var awarded_bosses: Array = run.get("boss_unlocks_awarded", [])
			awarded_bosses.append(defeated_boss_id)
			run["boss_unlocks_awarded"] = awarded_bosses
		if source_id == "player" and not _current_action_kills.has(entity_id): _current_action_kills.append(entity_id)
	if _is_hostile("player", entity_id):
		run["enemies_defeated"] = _increment_decimal(_normalize_counter(run.get("enemies_defeated", run.get("kills", 0))))
	if not entity.get("is_summon", false) and entity.get("kind", "enemy") != "boss" and _rng.randf() < 0.12:
		var loot_candidates := get_reward_candidates(false)
		if not loot_candidates.is_empty():
			var dropped: Dictionary = _pick_weighted_candidate(loot_candidates)
			var drop_pos := _pos(entity)
			if _object_index_at(drop_pos) >= 0:
				drop_pos = _find_spawn(drop_pos)
			if drop_pos.x >= 0 and _object_index_at(drop_pos) < 0:
				run.objects.append({"id": "enemy_loot_%03d" % run.objects.size(), "kind": "loot", "name": "Dropped Loot", "item_id": String(dropped.get("id", "")), "pos": [drop_pos.x, drop_pos.y], "hp": 1, "max_hp": 1, "marker": "star"})
				_add_log("A star marks a useful drop nearby.")
	if entity.get("kind") == "boss":
		_complete_stage()
		_add_log("The boss falls. The run continues beyond this map.")
	_check_objective()
	_place_pending_summons()

func _reduce_sword_technique_cooldowns(amount: int) -> void:
	if amount <= 0: return
	var cooldowns: Dictionary = run.get("ability_cooldowns", {})
	for ability_id in cooldowns.keys():
		var ability: Dictionary = content.get("abilities", {}).get(String(ability_id), {})
		if _is_swordplay_technique(ability): cooldowns[ability_id] = maxi(int(run.get("player_action_count", 0)), int(cooldowns[ability_id]) - amount)
	run["ability_cooldowns"] = cooldowns

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
	run.stage_prompt_dismissed = false
	run["stages_completed"] = _increment_decimal(_normalize_counter(run.get("stages_completed", "0")))
	check_authored_character_unlocks()
	_emit_combat_event("EncounterComplete", "player", "", {"stage": String(run.get("stage_id", ""))})
	run.encounters_completed = int(run.encounters_completed) + 1
	if int(run.get("stage_index", 0)) == 5:
		run["maps_completed"] = _increment_decimal(_normalize_counter(run.get("maps_completed", "0")))
		run.current_map["completed"] = true
		var history: Array = run.get("map_history", [])
		var current_index := int(run.get("current_map_index", history.size() - 1))
		if current_index >= 0 and current_index < history.size():
			history[current_index]["completed"] = true
			history[current_index]["current"] = true
			run["map_history"] = history
		_add_log("Map %s is complete. A new region waits beyond the unknown path." % _format_map_number(run.get("map_depth", "1")))
	var clear_xp := 15 + mini(int(run.stage_index), 4) * 3
	_award_xp(clear_xp)
	_add_log("The route rewards %d experience." % clear_xp)
	_add_log("Objective complete. You can keep exploring before you leave.")
	_make_rewards()
	_emit_trigger("OnEncounterComplete", {"stage_id": run.stage_id, "objective": run.objective.get("kind", "")})
	if run.get("outcome", "") != "":
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
	var path: Array[Vector2i] = _find_movement_path(start, target, mover_id)
	return path[0] if not path.is_empty() else start

func get_movement_path(target: Vector2i, mover_id: String = "player") -> Array[Vector2i]:
	if not run.get("entities", {}).has(mover_id):
		return []
	return _find_movement_path(_pos(run.entities[mover_id]), target, mover_id)

func get_movement_path_cost(target: Vector2i, mover_id: String = "player") -> Dictionary:
	var path := get_movement_path(target, mover_id)
	var per_step_time := _movement_step_time_cost(mover_id)
	var per_step_stamina := 3 if mover_id == "player" else 0
	return {"reachable": not path.is_empty(), "steps": path.size(), "time": path.size() * per_step_time, "stamina": path.size() * per_step_stamina}

func _movement_step_time_cost(mover_id: String) -> int:
	if mover_id != "player":
		return 100
	var passive_move := maxf(0.4, 1.0 - get_passive_modifier("move_time_reduction"))
	return maxi(1, int(round(100.0 * passive_move * float(_artifact_modifier("move_time_multiplier", 1.0)))))

func _find_movement_path(start: Vector2i, target: Vector2i, mover_id: String) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if start == target or not _inside(start) or not _inside(target):
		return empty
	var goals: Array[Vector2i] = []
	if _movement_cell_passable(target, mover_id):
		goals.append(target)
	else:
		for direction in DIRECTIONS:
			var adjacent: Vector2i = target + direction
			if _movement_cell_passable(adjacent, mover_id):
				goals.append(adjacent)
	if goals.is_empty():
		return empty
	var start_key := _cell_key(start)
	var distance_by_key: Dictionary = {start_key: 0}
	var previous_by_key: Dictionary = {}
	var open: Array[Vector2i] = [start]
	while not open.is_empty():
		var best_index := 0
		for index in range(1, open.size()):
			var candidate_key := _cell_key(open[index])
			var best_key := _cell_key(open[best_index])
			if int(distance_by_key[candidate_key]) < int(distance_by_key[best_key]):
				best_index = index
		var current: Vector2i = open.pop_at(best_index)
		var current_key := _cell_key(current)
		for direction in _ordered_movement_directions(current, target):
			var next: Vector2i = current + direction
			if not _movement_cell_passable(next, mover_id):
				continue
			var next_key := _cell_key(next)
			var candidate_cost := int(distance_by_key[current_key]) + _movement_step_time_cost(mover_id)
			if distance_by_key.has(next_key) and candidate_cost >= int(distance_by_key[next_key]):
				continue
			distance_by_key[next_key] = candidate_cost
			previous_by_key[next_key] = current_key
			if not open.has(next):
				open.append(next)
	var selected_goal := Vector2i(-1, -1)
	var selected_cost := 2147483647
	for goal in goals:
		var goal_key := _cell_key(goal)
		if distance_by_key.has(goal_key) and int(distance_by_key[goal_key]) < selected_cost:
			selected_goal = goal
			selected_cost = int(distance_by_key[goal_key])
	if selected_goal == Vector2i(-1, -1):
		return empty
	var reverse_path: Array[Vector2i] = []
	var cursor := selected_goal
	while cursor != start:
		reverse_path.append(cursor)
		var cursor_key := _cell_key(cursor)
		if not previous_by_key.has(cursor_key):
			return empty
		cursor = _key_cell(String(previous_by_key[cursor_key]))
	reverse_path.reverse()
	return reverse_path

func _ordered_movement_directions(from: Vector2i, target: Vector2i) -> Array:
	var delta := target - from
	var preferred_x := signi(delta.x)
	var preferred_y := signi(delta.y)
	var ordered: Array = DIRECTIONS.duplicate()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_distance := _dist(from + a, target)
		var b_distance := _dist(from + b, target)
		if a_distance != b_distance:
			return a_distance < b_distance
		var a_rank := _movement_direction_tie_rank(a, preferred_x, preferred_y)
		var b_rank := _movement_direction_tie_rank(b, preferred_x, preferred_y)
		if a_rank != b_rank:
			return a_rank < b_rank
		return DIRECTIONS.find(a) < DIRECTIONS.find(b)
	)
	return ordered

func _movement_direction_tie_rank(direction: Vector2i, preferred_x: int, preferred_y: int) -> int:
	if preferred_y == 0:
		if direction == Vector2i(preferred_x, 0): return 0
		if direction.x == preferred_x: return 1
	elif preferred_x == 0:
		if direction == Vector2i(0, preferred_y): return 0
		if direction.y == preferred_y: return 1
	else:
		if direction == Vector2i(preferred_x, preferred_y): return 0
		if direction == Vector2i(preferred_x, 0): return 1
		if direction == Vector2i(0, preferred_y): return 2
	return 3

func _movement_cell_passable(cell: Vector2i, mover_id: String) -> bool:
	if not _inside(cell):
		return false
	if mover_id == "player" and not _cell_was_explored(cell):
		return false
	var mover: Dictionary = run.get("entities", {}).get(mover_id, {})
	var footprint := maxi(1, int(mover.get("footprint", 1)))
	for y in range(cell.y, cell.y + footprint):
		for x in range(cell.x, cell.x + footprint):
			var footprint_cell := Vector2i(x, y)
			if not _inside(footprint_cell) or _terrain_at(footprint_cell) == "wall" or _occupant(footprint_cell, mover_id) != "":
				return false
	return true

func _cell_was_explored(cell: Vector2i) -> bool:
	return _inside(cell) and not run.get("explored", []).is_empty() and bool(run.explored[cell.y][cell.x])

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
