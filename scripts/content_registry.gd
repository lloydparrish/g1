extends RefCounted
class_name ArcanistContentRegistry

const CORE_MANIFEST_PATH := "res://data/core_manifest.json"
const OFFICIAL_ROOT := "res://data/packages/official"
const USER_MOD_ROOT := "user://mods"
const MERGEABLE_DICTIONARIES := ["characters", "weapons", "ability_categories", "abilities", "passives", "enemies", "bosses", "summons", "stages", "maps", "events", "items", "equipment", "relics", "artifacts", "evolutions", "unlocks", "visual_assets", "statuses", "triggers", "tag_registry"]
const MERGEABLE_ARRAYS := ["damage_types", "resources", "environment_rules", "damage_rules"]

var content: Dictionary = {}
var available_packages: Array = []
var load_order: Array[String] = []
var content_sources: Dictionary = {}
var errors: Array[String] = []

func load_from_disk(enabled_package_ids: Array) -> Dictionary:
	errors.clear()
	var core_manifest: Dictionary = _read_json(CORE_MANIFEST_PATH)
	var core_content: Dictionary = {}
	if core_manifest.is_empty():
		core_manifest = {"id": "core", "name": "Core", "version": "1.0.0", "kind": "core", "dependencies": [], "content_file": "content.json", "assets": []}
		core_content = _read_json("res://data/content.json")
	else:
		var core_path := "res://data/" + String(core_manifest.get("content_file", "content.json"))
		core_content = _read_json(core_path)
	var package_specs: Array = []
	package_specs.append_array(_scan_root(OFFICIAL_ROOT, "official"))
	package_specs.append_array(_scan_root(USER_MOD_ROOT, "mod"))
	var scan_errors := errors.duplicate()
	var result := assemble(core_manifest, core_content, package_specs, enabled_package_ids)
	result.errors.append_array(scan_errors)
	errors = result.errors.duplicate()
	return result

func assemble(core_manifest: Dictionary, core_content: Dictionary, package_specs: Array, enabled_package_ids: Array) -> Dictionary:
	content = {}
	available_packages = []
	load_order.clear()
	content_sources.clear()
	errors.clear()
	var package_map: Dictionary = {}
	var normalized_specs: Array = package_specs.duplicate(true)
	normalized_specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("manifest", {}).get("id", "")) < String(b.get("manifest", {}).get("id", ""))
	)
	package_map["core"] = {"manifest": core_manifest.duplicate(true), "definitions": core_content.duplicate(true), "directory": "res://data", "origin": "core"}
	for spec in normalized_specs:
		var manifest: Dictionary = spec.get("manifest", {})
		var package_id := String(manifest.get("id", ""))
		if package_id == "" or package_id == "core":
			errors.append("A content package is missing a valid stable package ID.")
			continue
		if package_map.has(package_id):
			errors.append("Duplicate package ID '%s'." % package_id)
			continue
		var package_entry: Dictionary = spec.duplicate(true)
		package_entry["origin"] = String(spec.get("origin", manifest.get("kind", "mod")))
		package_map[package_id] = package_entry
	for package_id in package_map:
		var manifest: Dictionary = package_map[package_id].manifest
		_validate_manifest(String(package_id), manifest, String(package_map[package_id].get("origin", "")))
	_validate_dependency_cycles(package_map)
	var enabled: Dictionary = {"core": true}
	for package_id in enabled_package_ids:
		enabled[String(package_id)] = true
	var order: Array[String] = []
	var visit_state: Dictionary = {}
	var selected_ids: Array = enabled.keys()
	selected_ids.sort()
	for package_id in selected_ids:
		if not package_map.has(package_id):
			errors.append("Enabled package '%s' is not installed." % String(package_id))
			continue
		_visit_enabled(String(package_id), package_map, enabled, visit_state, order)
	for package_id in order:
		if not package_map.has(package_id):
			continue
		var entry: Dictionary = package_map[package_id]
		var local_errors: Array[String] = _validate_package_assets(package_id, entry)
		local_errors.append_array(_validate_fragment(String(package_id), entry.get("definitions", {})))
		if local_errors.is_empty():
			local_errors.append_array(_merge_fragment(String(package_id), entry.get("definitions", {})))
		if not local_errors.is_empty():
			errors.append_array(local_errors)
			continue
		load_order.append(package_id)
	for package_id in package_map:
		var entry: Dictionary = package_map[package_id]
		var manifest: Dictionary = entry.manifest
		available_packages.append({
			"id": String(package_id), "name": String(manifest.get("name", package_id)),
			"version": String(manifest.get("version", "")), "kind": String(entry.get("origin", manifest.get("kind", "mod"))),
			"description": String(manifest.get("description", "")), "dependencies": manifest.get("dependencies", []).duplicate(),
			"enabled": bool(enabled.get(package_id, false)) and order.has(String(package_id)), "required": package_id == "core"
		})
	available_packages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.required) != bool(b.required): return bool(a.required)
		if String(a.kind) != String(b.kind): return String(a.kind) < String(b.kind)
		return String(a.name).to_lower() < String(b.name).to_lower()
	)
	return {"content": content, "available_packages": available_packages, "load_order": load_order.duplicate(), "content_sources": content_sources.duplicate(true), "errors": errors.duplicate()}

func get_package_enable_closure(package_id: String, requested_enabled: Array) -> Dictionary:
	var package: Dictionary = {}
	for candidate in available_packages:
		if String(candidate.id) == package_id:
			package = candidate
			break
	if package.is_empty() or bool(package.get("required", false)):
		return {"ok": false, "enabled": requested_enabled.duplicate(), "error": "This package cannot be changed."}
	var result: Array = requested_enabled.duplicate()
	if not result.has(package_id): result.append(package_id)
	var pending: Array = [package_id]
	while not pending.is_empty():
		var current_id := String(pending.pop_back())
		var current: Dictionary = {}
		for candidate in available_packages:
			if String(candidate.id) == current_id:
				current = candidate
				break
		if current.is_empty():
			return {"ok": false, "enabled": requested_enabled.duplicate(), "error": "Package '%s' is not installed." % current_id}
		for dependency in current.get("dependencies", []):
			var dependency_id := String(dependency)
			if not _package_is_available(dependency_id):
				return {"ok": false, "enabled": requested_enabled.duplicate(), "error": "Package '%s' requires missing package '%s'." % [current_id, dependency_id]}
			if not result.has(dependency_id): result.append(dependency_id)
			if not pending.has(dependency_id): pending.append(dependency_id)
	result.sort()
	return {"ok": true, "enabled": result, "error": ""}

func get_package_disable_closure(package_id: String, requested_enabled: Array) -> Dictionary:
	for candidate in available_packages:
		if String(candidate.id) == package_id and bool(candidate.get("required", false)):
			return {"ok": false, "enabled": requested_enabled.duplicate(), "error": "Core content is required."}
	var result: Array = requested_enabled.duplicate()
	result.erase(package_id)
	var removed := true
	while removed:
		removed = false
		for candidate in available_packages:
			var candidate_id := String(candidate.id)
			if result.has(candidate_id):
				for dependency in candidate.get("dependencies", []):
					if String(dependency) == package_id or not result.has(String(dependency)):
						result.erase(candidate_id)
						removed = true
						break
	result.sort()
	return {"ok": true, "enabled": result, "error": ""}

func _scan_root(root: String, origin: String) -> Array:
	var result: Array = []
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root)):
		return result
	var directories: PackedStringArray = DirAccess.get_directories_at(root)
	directories.sort()
	for directory_name in directories:
		var directory := root.rstrip("/") + "/" + String(directory_name)
		var manifest: Dictionary = _read_json(directory + "/manifest.json")
		if manifest.is_empty():
			errors.append("Package folder '%s' has no readable manifest.json." % directory)
			continue
		var content_path := directory + "/" + String(manifest.get("content_file", "content.json"))
		var definitions: Dictionary = _read_json(content_path)
		if definitions.is_empty():
			errors.append("Package '%s' has no readable content definitions at %s." % [String(manifest.get("id", directory_name)), content_path])
			continue
		result.append({"manifest": manifest, "definitions": definitions, "directory": directory, "origin": origin})
	return result

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _validate_manifest(package_id: String, manifest: Dictionary, origin: String) -> void:
	if not _is_package_id(package_id): errors.append("Invalid stable package ID '%s'." % package_id)
	var name := String(manifest.get("name", "")).strip_edges()
	if name == "": errors.append("Package '%s' has no display name." % package_id)
	if not _is_semver(String(manifest.get("version", ""))): errors.append("Package '%s' must declare a semantic version." % package_id)
	var expected_kind := "core" if package_id == "core" else origin
	var actual_kind := String(manifest.get("kind", expected_kind))
	if actual_kind != expected_kind:
		errors.append("Package '%s' has kind '%s' in a %s location." % [package_id, actual_kind, expected_kind])
	if String(manifest.get("content_file", "")) == "" or String(manifest.get("content_file", "")).contains("..") or String(manifest.get("content_file", "")).begins_with("/"):
		errors.append("Package '%s' has an unsafe or missing content_file path." % package_id)
	var seen_dependencies: Dictionary = {}
	for dependency in manifest.get("dependencies", []):
		var dependency_id := String(dependency)
		if dependency_id == package_id:
			errors.append("Package '%s' cannot depend on itself." % package_id)
		if seen_dependencies.has(dependency_id):
			errors.append("Package '%s' lists dependency '%s' more than once." % [package_id, dependency_id])
		seen_dependencies[dependency_id] = true

func _validate_package_assets(package_id: String, entry: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var directory := String(entry.get("directory", ""))
	for asset in entry.get("manifest", {}).get("assets", []):
		var relative := String(asset)
		if relative == "" or relative.contains("..") or relative.begins_with("/"):
			found.append("Package '%s' declares an unsafe asset path '%s'." % [package_id, relative])
			continue
		var asset_path := directory.rstrip("/") + "/" + relative
		if not FileAccess.file_exists(asset_path) and not ResourceLoader.exists(asset_path):
			found.append("Package '%s' references missing asset '%s'." % [package_id, relative])
	return found

func _validate_fragment(package_id: String, definitions: Variant) -> Array[String]:
	var found: Array[String] = []
	if not definitions is Dictionary:
		found.append("Package '%s' definitions must be a JSON object." % package_id)
		return found
	for key in definitions:
		if key in MERGEABLE_DICTIONARIES:
			if not definitions[key] is Dictionary:
				found.append("Package '%s' content section '%s' must be an object." % [package_id, String(key)])
			else:
				for content_id in definitions[key]:
					if not definitions[key][content_id] is Dictionary:
						found.append("Package '%s' definition '%s' in section '%s' must be an object." % [package_id, String(content_id), String(key)])
		elif key in MERGEABLE_ARRAYS:
			if not definitions[key] is Array:
				found.append("Package '%s' content section '%s' must be an array." % [package_id, String(key)])
		elif key == "progression":
			if not definitions[key] is Dictionary:
				found.append("Package '%s' content section 'progression' must be an object." % package_id)
		else:
			found.append("Package '%s' uses unsupported content section '%s'." % [package_id, String(key)])
	return found

func _merge_fragment(package_id: String, definitions: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for key in definitions:
		if key in MERGEABLE_DICTIONARIES:
			for content_id in definitions[key]:
				if content.get(key, {}).has(content_id):
					found.append("Duplicate stable content ID '%s' in section '%s' (already owned by %s)." % [String(content_id), String(key), String(content_sources.get(String(key), {}).get(String(content_id), "Core"))])
		if key in MERGEABLE_ARRAYS:
			var seen: Dictionary = {}
			for old_value in content.get(key, []): seen[old_value] = true
			for new_value in definitions[key]:
				if seen.has(new_value):
					found.append("Duplicate registered value '%s' in section '%s'." % [new_value, String(key)])
				seen[new_value] = true
	if not found.is_empty():
		return found
	for key in definitions:
		if key in MERGEABLE_DICTIONARIES:
			if not content.has(key): content[key] = {}
			if not content_sources.has(String(key)): content_sources[String(key)] = {}
			for content_id in definitions[key]:
				content[key][content_id] = definitions[key][content_id].duplicate(true) if definitions[key][content_id] is Dictionary else definitions[key][content_id]
				content_sources[String(key)][String(content_id)] = package_id
		elif key in MERGEABLE_ARRAYS:
			if not content.has(key): content[key] = []
			content[key].append_array(definitions[key].duplicate(true))
		elif key == "progression":
			if not content.has("progression"): content["progression"] = {}
			for progression_key in definitions[key]:
				if definitions[key][progression_key] is Array:
					if not content.progression.has(progression_key): content.progression[progression_key] = []
					for value in definitions[key][progression_key]:
						if not content.progression[progression_key].has(value): content.progression[progression_key].append(value)
				else:
					content.progression[progression_key] = definitions[key][progression_key]
		else:
			if not content.has(String(key)): content[String(key)] = definitions[key].duplicate(true)
	return found

func _visit_enabled(package_id: String, packages: Dictionary, enabled: Dictionary, state: Dictionary, order: Array[String]) -> void:
	var visit := int(state.get(package_id, 0))
	if visit in [2, 3]:
		return
	if visit == 1:
		errors.append("Package dependency cycle reaches '%s'." % package_id)
		return
	state[package_id] = 1
	var dependencies: Array = packages[package_id].get("manifest", {}).get("dependencies", []).duplicate()
	dependencies.sort()
	var dependencies_valid := true
	for dependency in dependencies:
		var dependency_id := String(dependency)
		if not packages.has(dependency_id):
			errors.append("Package '%s' requires missing package '%s'." % [package_id, dependency_id])
			dependencies_valid = false
		elif not bool(enabled.get(dependency_id, false)):
			errors.append("Package '%s' requires '%s' to be enabled." % [package_id, dependency_id])
			dependencies_valid = false
		else:
			_visit_enabled(dependency_id, packages, enabled, state, order)
			if int(state.get(dependency_id, 0)) != 2 or not order.has(dependency_id): dependencies_valid = false
	state[package_id] = 2 if dependencies_valid else 3
	if dependencies_valid and not order.has(package_id): order.append(package_id)

func _validate_dependency_cycles(packages: Dictionary) -> void:
	var state: Dictionary = {}
	var ids: Array = packages.keys()
	ids.sort()
	for package_id in ids:
		_visit_cycle(String(package_id), packages, state, [])

func _visit_cycle(package_id: String, packages: Dictionary, state: Dictionary, stack: Array[String]) -> void:
	if int(state.get(package_id, 0)) == 2: return
	if int(state.get(package_id, 0)) == 1:
		var cycle_start := stack.find(package_id)
		var cycle := stack.slice(maxi(0, cycle_start))
		cycle.append(package_id)
		var message := "Package dependency cycle: %s." % " -> ".join(cycle)
		if not errors.has(message): errors.append(message)
		return
	state[package_id] = 1
	var next_stack := stack.duplicate()
	next_stack.append(package_id)
	var dependencies: Array = packages.get(package_id, {}).get("manifest", {}).get("dependencies", [])
	for dependency in dependencies:
		if packages.has(String(dependency)):
			_visit_cycle(String(dependency), packages, state, next_stack)
	state[package_id] = 2

func _package_is_available(package_id: String) -> bool:
	for candidate in available_packages:
		if String(candidate.id) == package_id: return true
	return false

func _is_package_id(value: String) -> bool:
	if value == "" or value != value.to_lower(): return false
	for character in value:
		if not String(character) in "abcdefghijklmnopqrstuvwxyz0123456789-_.": return false
	return true

func _is_semver(value: String) -> bool:
	var parts := value.split(".")
	if parts.size() != 3: return false
	for part in parts:
		if not String(part).is_valid_int() or int(part) < 0: return false
	return true
