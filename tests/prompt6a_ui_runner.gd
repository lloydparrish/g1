extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	var desktop = MainScene.instantiate()
	desktop.playback_mode = "Instant"
	root.add_child(desktop)
	await process_frame
	await process_frame
	desktop.sim.start_run(60261006, "jim")
	desktop.page = "battle"
	desktop.queue_redraw()
	await process_frame
	await process_frame
	_check(not desktop.mobile_layout_override and not desktop.ui_state.lower_dock_expanded, "desktop opens with its persistent lower panels visible")
	_check(desktop.ui_state.inventory_tab == "Inventory", "Inventory is the default collection tab")
	var desktop_sections := 0
	var inventory_tabs: Array[String] = []
	var visible_inventory_slots := 0
	var desktop_dpad := false
	for hit in desktop.active_hits:
		var action: Dictionary = hit.action
		if action.get("type", "") == "lower_panel": desktop_sections += 1
		if action.get("type", "") == "lower_inventory_tab": inventory_tabs.append(String(action.get("id", "")))
		if action.get("type", "") == "select_item": visible_inventory_slots += 1
		if action.get("type", "") == "dpad": desktop_dpad = true
	_check(desktop_sections == 4 and visible_inventory_slots == desktop.sim.run.inventory.size(), "desktop keeps all four panels and the inventory grid available together")
	_check(inventory_tabs == ["Inventory", "Equipment", "Artifacts", "Spellbooks"], "inventory sub-tabs use the requested order")
	_check(not desktop_dpad, "desktop omits the touch movement D-pad")
	var all_abilities: int = desktop.sim.content.abilities.size()
	_check(all_abilities == 32 and desktop.sim.validate_content().is_empty() and desktop.sim.content.abilities.values().all(func(ability: Dictionary) -> bool: return not ability.get("categories", []).is_empty()), "every authored ability has validated category metadata")
	_check(desktop.sim.content.ability_categories.has("pyromancy") and desktop.sim.content.ability_categories.has("mobility") and desktop.sim.content.ability_categories.has("nature"), "category registry includes core and authored-school groups")
	desktop._handle_action({"type": "select_ability_category", "id": "arcane"})
	desktop.queue_redraw()
	await process_frame
	var filtered_arcane := false
	var filtered_fire := false
	for hit in desktop.active_hits:
		if hit.action.get("type", "") == "select_lower_ability":
			filtered_arcane = filtered_arcane or String(hit.action.get("id", "")) == "arcane_bolt"
			filtered_fire = filtered_fire or String(hit.action.get("id", "")) == "firebolt"
	_check(filtered_arcane and not filtered_fire, "the selected ability category filters from definition metadata")
	var ability_action := {"type": "select_lower_ability", "id": "arcane_bolt"}
	var ability_tooltip: Array[String] = desktop._tooltip_lines_for_action(ability_action)
	_check(ability_tooltip.size() >= 3 and ability_tooltip[2] == String(desktop.sim.content.abilities.arcane_bolt.description), "ability hover details come from authored ability data")

	var initial_equipped := String(desktop.sim.run.equipment.get("Body", ""))
	desktop.sim.run.inventory.append("scale_armor")
	desktop._handle_action({"type": "lower_inventory_tab", "id": "Equipment"})
	desktop._handle_action({"type": "select_equipment_slot", "slot": "Body"})
	desktop._handle_action({"type": "select_item", "index": desktop.sim.run.inventory.size() - 1})
	_check(String(desktop.sim.run.equipment.get("Body", "")) == initial_equipped, "selecting gear and equipment slots does not equip or unequip it")
	desktop.queue_redraw()
	await process_frame
	_check(desktop.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") == "equip"), "selected gear exposes a separate explicit Equip action")
	desktop._handle_action({"type": "equip"})
	_check(String(desktop.sim.run.equipment.get("Body", "")) == "scale_armor", "the explicit Equip action uses the existing simulation rule")
	desktop._handle_action({"type": "select_equipment_slot", "slot": "Body"})
	_check(String(desktop.sim.run.equipment.get("Body", "")) == "scale_armor", "selecting an occupied equipment slot only inspects it")
	desktop._handle_action({"type": "unequip", "slot": "Body"})
	_check(String(desktop.sim.run.equipment.get("Body", "")) == "", "unequip remains a distinct explicit action")

	var actual_choices: Array = desktop.sim.run.get("route_choices", []).duplicate()
	desktop.sim.run.stage_completed = false
	desktop.queue_redraw()
	await process_frame
	_check(not desktop.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") == "route"), "uncompleted encounters cannot travel through hidden route choices")
	desktop.sim.run.stage_completed = true
	desktop.queue_redraw()
	await process_frame
	var displayed_routes: Array[String] = []
	for hit in desktop.active_hits:
		if hit.action.get("type", "") == "select_map_node": displayed_routes.append(String(hit.action.get("id", "")))
	_check(not actual_choices.is_empty() and displayed_routes.size() == actual_choices.size(), "the map displays only this run's connected destinations")
	var stage_before_select := String(desktop.sim.run.stage_id)
	var route_id := String(actual_choices[0])
	desktop._handle_action({"type": "select_map_node", "id": route_id})
	_check(String(desktop.sim.run.stage_id) == stage_before_select, "choosing a map node does not travel until the explicit control is used")
	desktop._handle_action({"type": "route", "id": route_id})
	_check(String(desktop.sim.run.stage_id) == route_id, "explicit map travel advances through the authoritative route API")

	var visible_enemy: Dictionary = {}
	for entity in desktop.sim.get_visible_entities():
		if String(entity.id) != "player":
			visible_enemy = entity
			break
	if not visible_enemy.is_empty():
		desktop._handle_action({"type": "inspect_entity", "id": String(visible_enemy.id)})
		desktop.queue_redraw()
		await process_frame
		_check(desktop.selected_enemy == String(visible_enemy.id) and desktop.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") == "clear_inspection"), "selected enemy details take priority and expose a clear-selection control")
		desktop._handle_action({"type": "clear_inspection"})
		_check(desktop.selected_enemy == "" and desktop.selected_object_index == -1, "clearing an enemy selection restores Field Intelligence state")
	else:
		_check(false, "the generated opening encounter provides a visible enemy to inspect")

	var mobile = MainScene.instantiate()
	mobile.playback_mode = "Instant"
	mobile.mobile_layout_override = true
	root.add_child(mobile)
	await process_frame
	mobile.sim.start_run(60261006, "jim")
	mobile.page = "battle"
	mobile.queue_redraw()
	await process_frame
	var compact_headers := 0
	for hit in mobile.active_hits:
		if hit.action.get("type", "") == "lower_panel": compact_headers += 1
	_check(mobile._is_mobile_layout() and compact_headers == 4 and not mobile.ui_state.lower_dock_expanded, "mobile keeps four contextual section headers collapsed by default")
	mobile._handle_action({"type": "lower_panel", "id": "inventory"})
	mobile.queue_redraw()
	await process_frame
	_check(mobile.ui_state.lower_dock_expanded and mobile.ui_state.active_lower_panel == "inventory" and mobile.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") == "select_item"), "mobile opens one contextual inventory section with touch item slots")
	_check(mobile.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") == "dpad"), "mobile presentation includes its movement D-pad")
	var body_before := String(mobile.sim.run.equipment.get("Body", ""))
	var armor_index: int = mobile.sim.run.inventory.size()
	mobile.sim.run.inventory.append("scale_armor")
	await _touch_action(mobile, "lower_inventory_tab", "Equipment")
	await _touch_action(mobile, "select_equipment_slot", "Body")
	await _touch_action(mobile, "select_item", str(armor_index))
	_check(String(mobile.sim.run.equipment.get("Body", "")) == body_before, "mobile item and slot selection never equips gear implicitly")
	await _touch_action(mobile, "equip")
	_check(String(mobile.sim.run.equipment.get("Body", "")) == "scale_armor", "mobile gear requires the explicit Equip touch action")
	await _touch_action(mobile, "select_equipment_slot", "Body")
	_check(String(mobile.sim.run.equipment.get("Body", "")) == "scale_armor", "mobile selection of an occupied slot only inspects it")
	await _touch_action(mobile, "unequip", "Body")
	_check(String(mobile.sim.run.equipment.get("Body", "")) == "", "mobile gear removal uses the separate Unequip action")
	var route_choices: Array = mobile.sim.run.route_choices.duplicate()
	mobile.sim.run.stage_completed = true
	await _touch_action(mobile, "lower_panel", "world_map")
	var mobile_stage_before := String(mobile.sim.run.stage_id)
	var mobile_route := String(route_choices[0]) if not route_choices.is_empty() else ""
	if mobile_route != "": await _touch_action(mobile, "select_map_node", mobile_route)
	_check(mobile_route != "" and String(mobile.sim.run.stage_id) == mobile_stage_before, "mobile destination selection does not travel implicitly")
	if mobile_route != "": await _touch_action(mobile, "route", mobile_route)
	_check(String(mobile.sim.run.stage_id) == mobile_route and not mobile.ui_state.lower_dock_expanded and mobile.ui_state.active_lower_panel == "world_map", "mobile travel uses the explicit control and returns the dock to its compact state")

	desktop.queue_free()
	mobile.queue_free()
	print("PROMPT 6A UI %d · FAILURES %d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(1 if not failures.is_empty() else 0)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _touch_action(main: Control, action_type: String, action_value: String = "") -> void:
	main.queue_redraw()
	await process_frame
	await process_frame
	for hit in main.active_hits:
		var action: Dictionary = hit.action
		var value := str(action.get("id", action.get("index", action.get("slot", ""))))
		if String(action.get("type", "")) == action_type and value == action_value:
			var rect: Rect2 = hit.rect
			var point: Vector2 = main.draw_offset + rect.get_center() * main.draw_scale
			var press := InputEventScreenTouch.new()
			press.index = 0
			press.position = point
			press.pressed = true
			main._input(press)
			var release := InputEventScreenTouch.new()
			release.index = 0
			release.position = point
			release.pressed = false
			main._input(release)
			await process_frame
			return
		if String(action.get("type", "")) == action_type and action_value == "" and not action.has("id") and not action.has("index") and not action.has("slot"):
			var empty_rect: Rect2 = hit.rect
			var empty_point: Vector2 = main.draw_offset + empty_rect.get_center() * main.draw_scale
			var empty_press := InputEventScreenTouch.new()
			empty_press.index = 0
			empty_press.position = empty_point
			empty_press.pressed = true
			main._input(empty_press)
			var empty_release := InputEventScreenTouch.new()
			empty_release.index = 0
			empty_release.position = empty_point
			empty_release.pressed = false
			main._input(empty_release)
			await process_frame
			return
	_check(false, "mobile touch control is drawn: %s %s" % [action_type, action_value])
