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

	await _tap(main, Vector2(710, 435))
	_check(main.selected_character == "aldren", "character card is selected through the production input handler")
	await _touch(main, Vector2(635, 725))
	await process_frame
	_check(main.page == "battle" and main.sim.run.character_id == "aldren", "production start control enters a generated run")

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

	main.sim.run.reward_choices = [{"type": "item", "id": "leather_armor", "claimed": false}]
	await _tap(main, Vector2(330, 466))
	_check(main.sim.run.inventory.has("leather_armor"), "production reward control adds its item to the pack")
	await _tap(main, Vector2(1299, 94))
	await _tap(main, Vector2(884, 713))
	var armor_index: int = main.sim.run.inventory.size() - 1
	await _tap(main, Vector2(514 + (armor_index % 6) * 142, 213 + int(armor_index / 6) * 65))
	await _tap(main, Vector2(1100, 592))
	_check(main.sim.run.equipment.get("Body", "") == "leather_armor", "production inventory equips the claimed armor")
	await _tap(main, Vector2(1299, 94))
	await _tap(main, Vector2(1286, 574))
	_check(main.overlay == "map", "NEXT STAGE opens the production route map")
	var next_route: String = String(main.sim.run.route_choices[0])
	await _tap(main, Vector2(415, 560))
	_check(main.sim.run.stage_index == 1 and main.sim.run.stage_id == next_route and not main.sim.get_visible_entities().is_empty(), "production route selection creates the later encounter")

	main.sim.run.stage_index = 4
	main.sim.run.stage_completed = true
	main.sim.run.route_choices = []
	await _tap(main, Vector2(1080, 713))
	_check(main.overlay == "map", "the world map opens again through its action bar")
	await _tap(main, Vector2(405, 520))
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
	await _tap(main, Vector2(1320, 713))
	_check(main.sim.run.outcome == "defeat" and main.page == "outcome", "production End Turn resolves enemy attacks and the defeat screen")
	await _tap_action(main, "title")
	_check(main.page == "title", "the defeat screen returns to character selection")

	print("PRODUCTION FLOW %d · FAILURES %d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	main.queue_free()
	quit(1 if not failures.is_empty() else 0)

func _tap_action(main: Control, action_type: String, action_id: String = "") -> void:
	await process_frame
	for hit in main.active_hits:
		var action: Dictionary = hit.action
		if String(action.get("type", "")) != action_type:
			continue
		if action_id != "" and String(action.get("id", action.get("mode", ""))) != action_id:
			continue
		var rect: Rect2 = hit.rect
		await _tap(main, rect.get_center())
		return
	_failures_hit("production control is drawn: %s %s" % [action_type, action_id])

func _tap(main: Control, point: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.pressed = true
	main._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = point
	release.pressed = false
	main._gui_input(release)
	await process_frame

func _touch(main: Control, point: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = point
	press.pressed = true
	main._gui_input(press)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = point
	release.pressed = false
	main._gui_input(release)
	await process_frame

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(250 + cell.x * 35 + 17.5, 62 + cell.y * 35 + 17.5)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _failures_hit(description: String) -> void:
	_check(false, description)
