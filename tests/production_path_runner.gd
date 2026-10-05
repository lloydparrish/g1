extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_flow")

func run_flow() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_check(main.page == "title" and not main.active_hits.is_empty(), "production scene draws the character selection screen")
	await _mouse_action(main, "select_character", "jim")
	_check(main.selected_character == "jim", "Windows mouse can select a character in the production UI")

	await _tap_action(main, "select_character", "aldren")
	_check(main.selected_character == "aldren", "character card is selected through the production input handler")
	await _touch(main, Vector2(635, 725))
	await process_frame
	_check(main.page == "battle" and main.sim.run.character_id == "aldren", "production start control enters a generated run")
	if not main.sim.run.has("entities"):
		print("TOUCH START DIAGNOSTIC page=%s overlay=%s selected=%s hits=%d" % [main.page, main.overlay, main.selected_character, main.active_hits.size()])
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
		return

	var start: Vector2i = main.sim._pos(main.sim.get_player())
	await _tap(main, Vector2(73, 713))
	await _touch(main, _cell_center(Vector2i(13, 8)))
	_check(main.sim._pos(main.sim.get_player()) == Vector2i(13, 8) and start != main.sim._pos(main.sim.get_player()), "production Move control and battlefield tap move one legal tile")

	for entity_id in main.sim.run.entities.keys():
		if entity_id != "player":
			main.sim.run.entities[entity_id].alive = false
	main.sim._set_grid(Vector2i(14, 8), "floor")
	main.sim._set_grid(Vector2i(13, 7), "floor")
	main.sim.run.objective = {"kind": "Eliminate", "turns": 0}
	main.sim.run.stage_completed = false
	var spell_target: String = main.sim._spawn_enemy("goblin", Vector2i(14, 8), false)
	var weapon_target: String = main.sim._spawn_enemy("goblin", Vector2i(13, 7), false)
	for enemy_id in [spell_target, weapon_target]:
		main.sim.run.entities[enemy_id].hp = 1
		main.sim.run.entities[enemy_id].max_hp = 1
		main.sim.run.entities[enemy_id].next_time = int(main.sim.get_player().next_time) + 100000
	await _tap_action(main, "ability", "arcane_bolt")
	await _tap(main, _cell_center(Vector2i(14, 8)))
	_check(not main.sim.run.entities[spell_target].alive and main.sim.run.entities[weapon_target].alive, "production ability button casts Arcane Bolt at the tapped target")
	await _tap_action(main, "target_mode", "attack")
	await _tap(main, _cell_center(Vector2i(13, 7)))
	_check(not main.sim.run.entities[weapon_target].alive and int(main.sim.run.kills) == 2, "production weapon target click kills an enemy and advances XP")
	_check(main.sim.run.stage_completed and main.overlay == "rewards", "the objective opens the production reward screen after combat")

	main.sim.run.reward_choices = [{"type": "item", "id": "scale_armor", "claimed": false}]
	await _tap(main, Vector2(330, 466))
	_check(main.sim.run.inventory.has("scale_armor"), "production reward control adds its item to the pack")
	await _tap(main, Vector2(1299, 94))
	await _tap_action(main, "overlay", "abilities")
	if not main.sim.get_progression_graph().any(func(node: Dictionary) -> bool: return String(node.id) == "blink"):
		_failures_hit("the opening build reveals Arcane mobility progression")
	await _tap_action(main, "web_filter", "Arcane")
	await _navigate_web_node(main, "blink")
	await _tap_action(main, "select_web_node", "blink")
	await _tap_action(main, "learn", "blink")
	_check(main.sim.run.known.has("blink") and int(main.sim.run.skill_points) == 0, "production progression screen spends the first encounter point on an ability-web choice")
	await _tap(main, Vector2(1299, 94))
	var armor_index: int = main.sim.run.inventory.size() - 1
	await _tap_action(main, "overlay", "inventory")
	await _tap_index_action(main, "select_item", armor_index)
	await _tap_action(main, "equip")
	_check(main.sim.run.equipment.get("Body", "") == "scale_armor", "production inventory equips the claimed armor")
	await _tap(main, Vector2(1299, 94))
	await _tap_action(main, "next_stage")
	_check(main.overlay == "map", "NEXT STAGE opens the production route map")
	var next_route: String = String(main.sim.run.route_choices[0])
	await _tap_action(main, "route", next_route)
	_check(main.sim.run.stage_index == 1 and main.sim.run.stage_id == next_route and not main.sim.get_visible_entities().is_empty(), "production route selection creates the later encounter")

	main.sim.run.stage_index = 4
	main.sim.run.stage_completed = true
	main.sim.run.route_choices = []
	await _tap_action(main, "next_stage")
	_check(main.overlay == "map", "the world map opens again through its action bar")
	await _tap_action(main, "boss")
	var tyrant_id := ""
	for entity_id in main.sim.run.entities:
		if main.sim.run.entities[entity_id].get("kind") == "boss":
			tyrant_id = String(entity_id)
	_check(main.sim.run.stage_id == "graveyard" and tyrant_id != "", "production route control enters the 2x2 Grave Tyrant encounter")
	if tyrant_id != "":
		main.sim._set_grid(Vector2i(14, 7), "floor")
		main.sim._set_grid(Vector2i(15, 7), "floor")
		main.sim._set_grid(Vector2i(14, 8), "floor")
		main.sim._set_grid(Vector2i(15, 8), "floor")
		main.sim.run.entities[tyrant_id].pos = [14, 7]
		main.sim.get_player().pos = [13, 8]
		main.sim.run.entities[tyrant_id].hp = 1
		main.sim.run.entities[tyrant_id].next_time = int(main.sim.get_player().next_time) + 100000
		await _tap_action(main, "target_mode", "attack")
		await _tap(main, _cell_center(Vector2i(14, 7)))
	_check(main.sim.run.outcome == "victory" and main.page == "outcome", "production weapon action wins the final boss and displays victory")

	await _tap_action(main, "title")
	await _tap(main, Vector2(635, 725))
	for entity_id in main.sim.run.entities.keys():
		if entity_id != "player":
			main.sim.run.entities[entity_id].alive = false
	var lethal_id: String = main.sim._spawn_enemy("goblin", Vector2i(13, 8), false)
	main.sim.run.entities[lethal_id].damage = 100
	main.sim.run.entities[lethal_id].next_time = 0
	main.sim.get_player().hp = 1
	await _tap_action(main, "wait")
	_check(main.sim.run.outcome == "defeat" and main.page == "outcome", "production End Turn resolves enemy attacks and the defeat screen")
	await _tap_action(main, "title")
	_check(main.page == "title", "the defeat screen returns to character selection")

	print("PRODUCTION FLOW %d · FAILURES %d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	main.queue_free()
	quit(1 if not failures.is_empty() else 0)

func _tap_action(main: Control, action_type: String, action_id: String = "") -> void:
	main.queue_redraw()
	await process_frame
	await process_frame
	for hit in main.active_hits:
		var action: Dictionary = hit.action
		if String(action.get("type", "")) != action_type:
			continue
		if action_id != "" and String(action.get("id", action.get("mode", action.get("school", "")))) != action_id:
			continue
		var rect: Rect2 = hit.rect
		await _tap(main, rect.get_center())
		return
	print("FLOW DIAGNOSTIC wanted=%s:%s page=%s overlay=%s stage_completed=%s hits=%s" % [action_type, action_id, main.page, main.overlay, main.sim.run.get("stage_completed", false), active_hit_types(main)])
	_failures_hit("production control is drawn: %s %s" % [action_type, action_id])

func _tap_delta_action(main: Control, action_type: String, delta: int) -> void:
	await process_frame
	for hit in main.active_hits:
		var action: Dictionary = hit.action
		if String(action.get("type", "")) == action_type and int(action.get("delta", 0)) == delta:
			var hit_rect: Rect2 = hit.rect
			await _tap(main, hit_rect.get_center())
			return
	_failures_hit("production paging control is drawn: %s %d" % [action_type, delta])

func active_hit_types(main: Control) -> Array[String]:
	var labels: Array[String] = []
	for hit in main.active_hits:
		labels.append(str(hit.action))
	return labels

func _tap_index_action(main: Control, action_type: String, action_index: int) -> void:
	main.queue_redraw()
	await process_frame
	await process_frame
	for hit in main.active_hits:
		var action: Dictionary = hit.action
		if String(action.get("type", "")) == action_type and int(action.get("index", -1)) == action_index:
			var rect: Rect2 = hit.rect
			await _tap(main, rect.get_center())
			return
	_failures_hit("production control is drawn: %s %d" % [action_type, action_index])

func _navigate_web_node(main: Control, ability_id: String) -> void:
	var target := {}
	for node in main.sim.get_progression_graph():
		if String(node.id) == ability_id:
			target = node
			break
	if target.is_empty():
		_failures_hit("progression graph reveals the expected ability: %s" % ability_id)
		return
	var graph_rect: Rect2 = main._ability_graph_rect()
	for _step in range(24):
		var node_screen: Vector2 = graph_rect.get_center() + (target.position - main.web_pan) * main.web_zoom
		var delta := graph_rect.get_center() - node_screen
		if delta.length() < 24.0:
			break
		await _touch_drag(main, graph_rect.get_center(), graph_rect.get_center() + delta.limit_length(120.0))
		main.queue_redraw()
		await process_frame

func _touch_drag(main: Control, start: Vector2, finish: Vector2) -> void:
	var start_view: Vector2 = main.draw_offset + start * main.draw_scale
	var finish_view: Vector2 = main.draw_offset + finish * main.draw_scale
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = start_view
	press.pressed = true
	main._input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = finish_view
	drag.relative = finish_view - start_view
	main._input(drag)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = finish_view
	release.pressed = false
	main._input(release)
	await process_frame

func _tap(main: Control, point: Vector2) -> void:
	await _touch(main, point)

func _mouse_tap(main: Control, point: Vector2) -> void:
	var viewport_point: Vector2 = main.draw_offset + point * main.draw_scale
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = viewport_point
	press.pressed = true
	main._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = viewport_point
	release.pressed = false
	main._gui_input(release)
	await process_frame

func _mouse_action(main: Control, action_type: String, action_id: String) -> void:
	await process_frame
	for hit in main.active_hits:
		var action: Dictionary = hit.action
		if String(action.get("type", "")) == action_type and String(action.get("id", "")) == action_id:
			var hit_rect: Rect2 = hit.rect
			await _mouse_tap(main, hit_rect.get_center())
			return
	_failures_hit("mouse action is drawn: %s %s" % [action_type, action_id])

func _touch(main: Control, point: Vector2) -> void:
	var viewport_point: Vector2 = main.draw_offset + point * main.draw_scale
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = viewport_point
	press.pressed = true
	main._input(press)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = viewport_point
	release.pressed = false
	main._input(release)
	await process_frame

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(250 + cell.x * 35 + 17.5, 62 + cell.y * 35 + 17.5)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _failures_hit(description: String) -> void:
	_check(false, description)
