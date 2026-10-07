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
	_check(desktop_sections == 3 and visible_inventory_slots == desktop.sim.run.inventory.size(), "desktop keeps exactly three persistent panels and the inventory grid available together")
	_check(inventory_tabs == ["Inventory", "Equipment", "Artifacts", "Spellbooks"], "inventory sub-tabs use the requested order")
	_check(not desktop_dpad, "desktop omits the touch movement D-pad")
	var all_abilities: int = desktop.sim.content.abilities.size()
	_check(all_abilities == 32 and desktop.sim.validate_content().is_empty() and desktop.sim.content.abilities.values().all(func(ability: Dictionary) -> bool: return not ability.get("categories", []).is_empty()), "every authored ability has validated category metadata")
	_check(desktop.sim.content.ability_categories.has("pyromancy") and desktop.sim.content.ability_categories.has("mobility") and desktop.sim.content.ability_categories.has("nature"), "category registry includes core and authored-school groups")
	var jim_category_ids: Array[String] = []
	for category in desktop.sim.get_visible_ability_categories(): jim_category_ids.append(String(category.id))
	_check(not jim_category_ids.has("arcane") and not jim_category_ids.has("pyromancy"), "the category list hides schools Jim has not entered")
	desktop.sim.run.schools.append("Arcane")
	desktop.queue_redraw()
	await process_frame
	_check(desktop.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") == "select_ability_category" and hit.action.get("id", "") == "arcane"), "discovering a school adds its category from run state")
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
	var long_action_names := ["MARCHER'S SWORD", "Healing Draught", "Blueglass Tonic", "Scroll of Fireball"]
	var action_names_wrap := true
	for action_name in long_action_names:
		var wrapped_name: Array[String] = desktop._wrap_text_to_width(String(action_name), 58.0, 8, 2)
		var measured_ok := wrapped_name.all(func(line: String) -> bool: return ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, desktop._physical_font_size(8)).x <= 58.0 * desktop.draw_scale)
		action_names_wrap = action_names_wrap and wrapped_name.size() == 2 and " ".join(wrapped_name) == String(action_name) and measured_ok and not wrapped_name.back().contains("…")
	_check(action_names_wrap, "long combat action names wrap to two measured lines before any ellipsis")
	var action_detail_lines: Array[String] = desktop._action_detail_lines("STA 4 · BLOOD 3\n115T", 50.0)
	var action_detail_fits: bool = action_detail_lines.size() == 3 and action_detail_lines.back() == "115T" and action_detail_lines.all(func(line: String) -> bool: return ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1.0, desktop._physical_font_size(7)).x <= 50.0 * desktop.draw_scale)
	_check(action_detail_fits, "multi-resource costs wrap across aligned rows and preserve the action time cost")
	_check(desktop._quickbar_item_detail(desktop.sim.content.items.healing_potion, 2) == "×2\n70T" and desktop._quickbar_item_detail(desktop.sim.content.items.fireball_scroll, 1) == "×1\n115T", "item action cards retain quantity and the authoritative consumable or scroll time cost")
	var long_tooltip_source: Array[String] = desktop._tooltip_lines_for_action({"type": "select_lower_ability", "id": "demonic_gateway"})
	var long_tooltip: Dictionary = desktop._tooltip_layout(long_tooltip_source)
	var short_tooltip_source: Array[String] = ["Potion", "Consumable", "Restore 24 Health."]
	var short_tooltip: Dictionary = desktop._tooltip_layout(short_tooltip_source)
	var tooltip_lines_fit: bool = Array(long_tooltip.lines).all(func(line: String) -> bool: return ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1.0, desktop._physical_font_size(8)).x <= float(long_tooltip.text_width) * desktop.draw_scale)
	var tooltip_position: Vector2 = desktop._tooltip_position(Vector2(desktop.screen_size.x - 1.0, desktop.screen_size.y - 1.0), Vector2(float(long_tooltip.width), float(long_tooltip.height)))
	_check(long_tooltip.lines.size() > long_tooltip_source.size() and float(long_tooltip.height) > float(short_tooltip.height) and float(long_tooltip.width) <= 300.0 and tooltip_lines_fit, "long tooltip copy wraps to content-driven height within a bounded measured width")
	_check(tooltip_position.x >= 8.0 and tooltip_position.y >= 8.0 and tooltip_position.x + float(long_tooltip.width) <= desktop.screen_size.x - 8.0 and tooltip_position.y + float(long_tooltip.height) <= desktop.screen_size.y - 8.0, "tooltip placement keeps its complete border inside the viewport")

	var initial_equipped := String(desktop.sim.run.equipment.get("Body", ""))
	desktop.sim.run.inventory.append("scale_armor")
	desktop._handle_action({"type": "lower_inventory_tab", "id": "Equipment"})
	desktop._handle_action({"type": "select_equipment_slot", "slot": "Head"})
	desktop.queue_redraw()
	await process_frame
	_check(desktop.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") == "select_equipment_slot" and hit.action.get("slot", "") == "Head") and not desktop.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") == "select_item"), "Head selection filters out every incompatible carried item and retains the slot controls")
	desktop._handle_action({"type": "select_equipment_slot", "slot": "Body"})
	desktop.queue_redraw()
	await process_frame
	var body_items: Array[int] = []
	for hit in desktop.active_hits:
		if hit.action.get("type", "") == "select_item": body_items.append(int(hit.action.index))
	_check(not body_items.is_empty() and body_items.all(func(index: int) -> bool: return desktop.sim.can_equip_item(index, "Body")), "Body selection exposes only actual body-slot gear")
	desktop._handle_action({"type": "select_equipment_slot", "slot": "Body"})
	desktop._handle_action({"type": "select_item", "index": desktop.sim.run.inventory.size() - 1})
	_check(String(desktop.sim.run.equipment.get("Body", "")) == initial_equipped, "selecting gear and equipment slots does not equip or unequip it")
	desktop.queue_redraw()
	await process_frame
	_check(desktop.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") == "equip"), "selected gear exposes a separate explicit Equip action")
	desktop._handle_action({"type": "equip"})
	_check(String(desktop.sim.run.equipment.get("Body", "")) == "scale_armor", "the explicit Equip action uses the existing simulation rule")
	var armor_item_stats: Dictionary = desktop.sim.get_equipment_item_stats("scale_armor")
	_check(int(armor_item_stats.get("armor", 0)) == int(desktop.sim.content.items.scale_armor.armor), "equipment inspection reads the item's authored armor value")
	desktop.sim.run.inventory.append("dagger")
	desktop.sim.run.inventory.append("greatsword")
	desktop._handle_action({"type": "select_equipment_slot", "slot": "Weapon"})
	desktop.queue_redraw()
	await process_frame
	var weapon_items: Array[int] = []
	for hit in desktop.active_hits:
		if hit.action.get("type", "") == "select_item": weapon_items.append(int(hit.action.index))
	_check(weapon_items.size() == 2 and weapon_items.all(func(index: int) -> bool: return desktop.sim.can_equip_item(index, "Weapon")), "Weapon selection filters the equipment grid to compatible weapons")
	var dagger_stats: Dictionary = desktop.sim.get_equipment_item_stats("dagger")
	_check(int(dagger_stats.get("damage", 0)) == int(desktop.sim.content.weapons.dagger.damage) and String(dagger_stats.get("damage_type", "")) == String(desktop.sim.content.weapons.dagger.type) and desktop._tooltip_lines_for_action({"type": "select_item", "index": desktop.sim.run.inventory.find("dagger")}).any(func(line: String) -> bool: return line.contains("Damage")), "weapon detail and tooltip expose authored combat stats")
	desktop._handle_action({"type": "select_equipment_slot", "slot": "Body"})
	_check(String(desktop.sim.run.equipment.get("Body", "")) == "scale_armor", "selecting an occupied equipment slot only inspects it")
	desktop._handle_action({"type": "unequip", "slot": "Body"})
	_check(String(desktop.sim.run.equipment.get("Body", "")) == "", "unequip remains a distinct explicit action")

	var actual_choices: Array = desktop.sim.run.get("route_choices", []).duplicate()
	desktop.sim.run.stage_completed = false
	desktop.queue_redraw()
	await process_frame
	_check(not desktop.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") in ["route", "boss", "destination_route", "select_map_node"]), "the persistent World Map never exposes travel or future-node inspection controls")
	var map_before_choice: Dictionary = desktop.lower_dock._persistent_journey()
	var map_before_ids: Array[String] = []
	for entry in map_before_choice.entries:
		if not bool(entry.get("unknown", false)): map_before_ids.append(String(entry.id))
	_check(map_before_ids == desktop.sim.run.route and bool(map_before_choice.has_unknown) and bool(map_before_choice.entries.back().unknown), "the persistent World Map shows authoritative visited history followed by an unknown next node")
	_check(not actual_choices.any(func(choice: String) -> bool: return map_before_ids.has(choice)) and not desktop.active_hits.any(func(hit: Dictionary) -> bool: return actual_choices.has(String(hit.action.get("id", "")))), "generated future destinations are not exposed through persistent map labels or controls")
	desktop.sim.run.stage_completed = true
	desktop.queue_redraw()
	await process_frame
	var completed_map: Dictionary = desktop.lower_dock._persistent_journey()
	_check(not actual_choices.is_empty() and bool(completed_map.has_unknown) and not desktop.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") in ["select_map_node", "destination_route"]), "completing the objective does not reveal branches in the persistent journey map")
	var route_id := String(actual_choices[0])
	desktop._handle_action({"type": "next_stage"})
	desktop.queue_redraw()
	await process_frame
	var picker_routes: Array[String] = []
	for hit in desktop.active_hits:
		if hit.action.get("type", "") == "destination_route": picker_routes.append(String(hit.action.get("id", "")))
	_check(desktop.overlay == "destinations" and picker_routes.size() == actual_choices.size(), "encounter completion opens a dedicated picker populated from the authoritative route state")
	desktop._handle_action({"type": "destination_route", "id": route_id})
	var map_after_choice: Dictionary = desktop.lower_dock._persistent_journey()
	var chosen_history: Array = map_after_choice.history
	_check(String(desktop.sim.run.stage_id) == route_id and String(chosen_history.back()) == route_id and not chosen_history.has(String(actual_choices[1])), "the chosen destination joins the authoritative journey while its rejected branch stays hidden")

	var targeting = MainScene.instantiate()
	targeting.playback_mode = "Instant"
	root.add_child(targeting)
	await process_frame
	targeting.sim.start_run(60261007, "sylvi")
	targeting.page = "battle"
	var target_player: Dictionary = targeting.sim.get_player()
	var target_origin: Vector2i = targeting.sim._pos(target_player)
	for y in range(targeting.sim.HEIGHT):
		for x in range(targeting.sim.WIDTH):
			targeting.sim._set_grid(Vector2i(x, y), "floor")
	targeting.sim.run.equipment.Weapon = "bow"
	var visible_target_id: String = targeting.sim._spawn_enemy("goblin", target_origin + Vector2i(4, 0), false)
	var hidden_target_id: String = targeting.sim._spawn_enemy("goblin", Vector2i(24, 15), false)
	targeting.sim._update_vision()
	targeting._handle_action({"type": "target_mode", "mode": "attack"})
	targeting.queue_redraw()
	await process_frame
	var target_preview: Dictionary = targeting.sim.get_targeting_preview("attack")
	var valid_target_cell: Vector2i = targeting.sim._pos(targeting.sim.run.entities[visible_target_id])
	var hidden_target_cell: Vector2i = targeting.sim._pos(targeting.sim.run.entities[hidden_target_id])
	_check(target_preview.get("available", false) and target_preview.valid_cells.has(valid_target_cell) and targeting.sim.is_valid_target_cell("attack", valid_target_cell), "weapon range overlay and legal attack validation share the simulation targeting query")
	_check(not target_preview.range_cells.has(hidden_target_cell) and not target_preview.valid_cells.has(hidden_target_cell), "targeting preview does not expose a hidden enemy")
	_check(targeting._cell_is_legal_target(valid_target_cell) and not targeting._cell_is_legal_target(hidden_target_cell), "battlefield target cells match authoritative legality under fog")
	targeting._handle_action({"type": "cancel_target"})
	_check(targeting.target_mode == "", "cancelling targeting clears the battlefield range overlay")
	targeting._handle_action({"type": "target_mode", "mode": "attack"})
	var resolved_attack: Dictionary = targeting.sim.act({"type": "attack", "target": [valid_target_cell.x, valid_target_cell.y]})
	targeting._commit_action(resolved_attack)
	_check(resolved_attack.get("ok", false) and targeting.target_mode == "", "a resolved attack clears its range overlay")

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

	for _transition in range(3):
		desktop.sim.run.stage_completed = true
		var next_stage_id := String(desktop.sim.run.route_choices[0])
		_check(desktop.sim.choose_route(next_stage_id), "authoritative route selection advances the journey")
	var fifth_map: Dictionary = desktop.lower_dock._persistent_journey()
	_check(int(desktop.sim.run.stage_index) == 4 and fifth_map.history == desktop.sim.run.route and bool(fifth_map.has_unknown) and String(fifth_map.history.back()) == String(desktop.sim.run.stage_id), "the 5/6 journey keeps every chosen map in order and leaves the next location unknown")
	desktop.sim.run.stage_completed = true
	_check(desktop.sim.start_boss(), "the final destination opens through the authoritative boss progression API")
	var sixth_map: Dictionary = desktop.lower_dock._persistent_journey()
	_check(int(desktop.sim.run.stage_index) == 5 and sixth_map.history.size() == 6 and sixth_map.history == desktop.sim.run.route and not bool(sixth_map.has_unknown) and String(sixth_map.history.back()) == String(desktop.sim.run.stage_id), "the 6/6 map shows the ordered chosen route and omits an inappropriate unknown node")

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
	_check(mobile._is_mobile_layout() and compact_headers == 3 and not mobile.ui_state.lower_dock_expanded, "mobile keeps three contextual section headers collapsed by default")
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
	var mobile_route := String(route_choices[0]) if not route_choices.is_empty() else ""
	_check(mobile_route != "" and not mobile.active_hits.any(func(hit: Dictionary) -> bool: return hit.action.get("type", "") in ["select_map_node", "destination_route"]), "mobile persistent map hides future destinations until the destination picker opens")
	if mobile_route != "":
		await _touch_action(mobile, "next_stage")
		_check(mobile.overlay == "destinations", "mobile objective completion opens the dedicated destination picker")
		await _touch_action(mobile, "destination_route", mobile_route)
	_check(String(mobile.sim.run.stage_id) == mobile_route and not mobile.ui_state.lower_dock_expanded and mobile.overlay == "", "mobile destination choice travels through the dedicated picker")

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
