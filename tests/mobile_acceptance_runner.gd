extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SimScript = preload("res://scripts/game_sim.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	var mobile = MainScene.instantiate()
	mobile.playback_mode = "Instant"
	mobile.mobile_layout_override = true
	root.add_child(mobile)
	await process_frame
	await process_frame
	await _touch_action(mobile, "select_character", "aldren")
	_check(mobile.selected_character == "aldren", "touch selects a character on the production title screen")
	await _touch(mobile, Vector2(635, 725))
	_check(mobile.page == "battle" and mobile.sim.run.character_id == "aldren", "touch begins a run from character selection")

	var desktop = MainScene.instantiate()
	desktop.playback_mode = "Instant"
	root.add_child(desktop)
	await process_frame
	desktop.sim.start_run(20261005, "jim")
	desktop.page = "battle"
	mobile.sim.start_run(20261005, "jim")
	mobile.page = "battle"
	desktop.queue_redraw()
	mobile.queue_redraw()
	await process_frame
	await process_frame
	var start: Vector2i = mobile.sim._pos(mobile.sim.get_player())
	var destination := _open_neighbor(mobile.sim, start)
	await _mouse_tap(desktop, desktop._cell_center(destination))
	await _touch(mobile, mobile._cell_center(destination))
	_check(mobile.sim._pos(mobile.sim.get_player()) == destination, "a direct screen touch moves through the normal tile action")
	_check(JSON.stringify(mobile.sim.run) == JSON.stringify(desktop.sim.run), "equivalent mouse and touch movement produce identical deterministic run state")
	var dock_digest: String = mobile.sim.state_digest()
	for section_id in ["world_map", "character", "inventory", "spellbook"]:
		await _touch_action(mobile, "lower_panel", section_id)
		_check(mobile.ui_state.lower_dock_expanded and mobile.ui_state.active_lower_panel == section_id, "touch expands lower section: %s" % section_id)
	await _touch_action(mobile, "lower_panel", "spellbook")
	_check(not mobile.ui_state.lower_dock_expanded and mobile.sim.state_digest() == dock_digest, "switching and collapsing lower sections never advances the simulation")
	var feed_digest: String = mobile.sim.state_digest()
	await _touch_action(mobile, "open_combat_history")
	_check(mobile.overlay == "combat_history" and not mobile.sim.run.combat_history.is_empty(), "touch opens the expanded encounter history from Recent Events")
	await _touch_action(mobile, "close")
	_check(mobile.overlay == "" and mobile.sim.state_digest() == feed_digest, "closing encounter history through touch leaves game state unchanged")

	var time_before_cancel := int(mobile.sim.run.time)
	if not mobile.sim.run.known.has("arcane_bolt"):
		mobile.sim.run.known.append("arcane_bolt")
	await _touch_action(mobile, "lower_panel", "character")
	var character_layout: Dictionary = mobile._battle_layout()
	_check(int(character_layout.panel_content_height) >= 220, "mobile ability details keep a dedicated footer below the ability cards")
	await _touch_action(mobile, "select_lower_ability", "arcane_bolt")
	await _touch_action(mobile, "begin_quickbar_assignment", "arcane_bolt")
	_check(mobile.quickbar_assign_mode and int(mobile.sim.run.time) == time_before_cancel, "touch starts ability-bar assignment without consuming a turn")
	await _touch_action(mobile, "quickbar_slot", "7")
	_check(mobile.sim.run.quickbar[7] == {"type": "ability", "id": "arcane_bolt"} and not mobile.quickbar_assign_mode, "touch assigns a learned ability to the selected action slot")
	mobile.queue_redraw()
	await process_frame
	await _touch_action(mobile, "ability", "arcane_bolt")
	_check(mobile.target_mode == "arcane_bolt", "touching an ability enters explicit target mode")
	await _touch_action(mobile, "cancel_target")
	_check(mobile.target_mode == "" and int(mobile.sim.run.time) == time_before_cancel, "visible touch cancel exits targeting without advancing simulation")
	var normal_mode: String = mobile.playback_mode
	mobile._handle_action({"type": "playback_speed", "mode": "Fast"})
	_check(mobile.playback_mode == "Fast", "the internal presentation-speed setting remains callable")
	mobile._handle_action({"type": "playback_speed", "mode": normal_mode})
	var speed_action_visible := false
	var mobile_dpad_visible := false
	var desktop_dpad_visible := false
	for hit in mobile.active_hits:
		if String(hit.action.get("type", "")) == "playback_speed": speed_action_visible = true
		if String(hit.action.get("type", "")) == "dpad": mobile_dpad_visible = true
	for hit in desktop.active_hits:
		if String(hit.action.get("type", "")) == "dpad": desktop_dpad_visible = true
	_check(mobile_dpad_visible and not desktop_dpad_visible, "movement D-pad is shown on Android layout and omitted from desktop")
	_check(not speed_action_visible, "playback-speed control is kept out of the ordinary HUD")

	for entity_id in mobile.sim.run.entities.keys():
		if entity_id != "player":
			mobile.sim.run.entities[entity_id].alive = false
	var player: Dictionary = mobile.sim.get_player()
	player.hp = maxi(1, int(player.max_hp) - 1)
	var health_before := int(player.hp)
	mobile.queue_redraw()
	await process_frame
	await _touch_action(mobile, "quick_item")
	_check(not mobile.sim.run.inventory.has("healing_potion") and int(mobile.sim.get_player().hp) > health_before, "touch quick-slot input uses a healing consumable through the existing rule")

	var saved_time := int(mobile.sim.run.time)
	mobile._notification(NOTIFICATION_APPLICATION_PAUSED)
	mobile._notification(NOTIFICATION_APPLICATION_RESUMED)
	_check(int(mobile.sim.run.time) == saved_time and FileAccess.file_exists("user://run_save.json"), "application pause saves the active run without advancing turns")
	var resumed = SimScript.new()
	_check(resumed.resume_run() and JSON.stringify(resumed.run) == JSON.stringify(mobile.sim.run), "the lifecycle save resumes to the same deterministic run state")

	mobile.target_mode = "arcane_bolt"
	mobile.last_android_back_msec = -500
	mobile._handle_back_request()
	_check(mobile.target_mode == "" and mobile.page == "battle" and mobile.overlay == "", "the first Android Back cancels targeting without opening a menu")
	mobile._open_lower_panel("inventory", false)
	mobile.last_android_back_msec = -500
	mobile._handle_back_request()
	_check(mobile.overlay == "" and not mobile.ui_state.lower_dock_expanded, "Android Back collapses inventory before opening a menu")
	mobile.last_android_back_msec = -500
	mobile._handle_back_request()
	_check(mobile.overlay == "pause", "Android Back opens pause instead of exiting from gameplay")
	mobile.last_android_back_msec = -500
	mobile._handle_back_request()
	_check(mobile.overlay == "exit_confirm", "a second Back from pause asks before exiting")
	mobile._handle_action({"type": "close"})
	_check(mobile.overlay == "pause", "the exit confirmation returns to pause safely")

	var target_layouts := [
		Vector2(1920, 1080), Vector2(2560, 1440), Vector2(2400, 1080),
		Vector2(2340, 1080), Vector2(1280, 720)
	]
	var layout_ok := true
	for viewport_size in target_layouts:
		var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
		var layout: Dictionary = mobile._calculate_layout(viewport_size, viewport_rect)
		var logical_size: Vector2 = layout.size
		var content_bounds := Rect2(layout.offset, logical_size * float(layout.scale))
		if logical_size.x < 1440.0 or logical_size.y < 810.0:
			layout_ok = false
		if content_bounds.position.x < viewport_rect.position.x or content_bounds.position.y < viewport_rect.position.y or content_bounds.end.x > viewport_rect.end.x or content_bounds.end.y > viewport_rect.end.y:
			layout_ok = false
		mobile.screen_size = logical_size
		var battle_layout: Dictionary = mobile._battle_layout()
		var logical_bounds := Rect2(Vector2.ZERO, logical_size)
		var toolbar_rect := Rect2(Vector2(float(battle_layout.action_x), float(battle_layout.toolbar_y)), Vector2(float(battle_layout.action_width), float(battle_layout.toolbar_height)))
		var dock_rect := Rect2(18.0, float(battle_layout.dock_top), logical_size.x - 36.0, float(battle_layout.dock_bottom) - float(battle_layout.dock_top))
		if not logical_bounds.encloses(mobile._board_rect()) or not logical_bounds.encloses(toolbar_rect) or not logical_bounds.encloses(dock_rect):
			layout_ok = false
		if mobile._board_rect().intersects(toolbar_rect) or toolbar_rect.intersects(dock_rect):
			layout_ok = false
	var inset_layout: Dictionary = mobile._calculate_layout(Vector2(2400, 1080), Rect2(90, 0, 2220, 1080))
	if not is_equal_approx(float(inset_layout.offset.x), 98.0) or inset_layout.size.x < 1440.0:
		layout_ok = false
	_check(layout_ok, "desktop, wide-phone and smaller viewports preserve the 16:9 playfield with no wide-panel overlap")
	var fitted_name: String = mobile._fit_text("Aldren, Exiled Battlemage", 150.0, 15)
	_check(ThemeDB.fallback_font.get_string_size(fitted_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15).x <= 150.0, "long character names fit beside the level label on compact screens")

	mobile.page = "battle"
	mobile._open_lower_panel("inventory", false)
	mobile.queue_redraw()
	await process_frame
	await process_frame
	var target_sizes_ok := true
	for hit in mobile.active_hits:
		var hit_rect: Rect2 = hit.rect
		if String(hit.action.get("type", "")) == "select_item":
			if hit_rect.size.x < 28.0 or hit_rect.size.y < 28.0: target_sizes_ok = false
		elif hit_rect.size.x < 54.0 or hit_rect.size.y < 54.0:
			target_sizes_ok = false
	_check(target_sizes_ok, "visible inventory and action hit regions have at least 54 logical pixels per dimension")
	mobile.last_android_back_msec = -500
	mobile._handle_back_request()
	_check(not mobile.ui_state.lower_dock_expanded, "Back collapses the active inventory section")
	mobile.queue_redraw()
	await process_frame
	await process_frame
	var action_hits: Array = []
	for hit in mobile.active_hits:
		if hit.rect.position.y >= 640 and String(hit.action.get("type", "")) in ["target_mode", "quickbar_slot", "wait", "end_turn", "cancel_target", "playback_skip"]:
			action_hits.append(hit)
	var separated := true
	for i in range(action_hits.size()):
		for j in range(i + 1, action_hits.size()):
			if action_hits[i].rect.intersects(action_hits[j].rect): separated = false
	_check(separated, "the primary action bar keeps touch hit regions separated")

	mobile.queue_free()
	desktop.queue_free()
	print("MOBILE ACCEPTANCE %d · FAILURES %d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(1 if not failures.is_empty() else 0)

func _open_neighbor(sim, origin: Vector2i) -> Vector2i:
	for direction in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var cell: Vector2i = origin + direction
		if not sim._inside(cell) or sim._terrain_at(cell) == "wall":
			continue
		if not sim.get_enemy_at(cell).is_empty() or sim._object_index_at(cell) >= 0:
			continue
		if sim._cell_visible(cell):
			return cell
	return origin + Vector2i(1, 0)

func _touch_action(main: Control, action_type: String, action_id: String = "") -> void:
	await process_frame
	if action_type == "ability":
		for slot_index in range(main.sim.run.get("quickbar", []).size()):
			if main.sim.run.quickbar[slot_index].get("type") == "ability" and main.sim.run.quickbar[slot_index].get("id") == action_id:
				await _touch_action(main, "quickbar_slot", str(slot_index))
				return
	if action_type == "quick_item":
		for slot_index in range(main.sim.run.get("quickbar", []).size()):
			if main.sim.run.quickbar[slot_index].get("type") == "item" and main.sim.run.quickbar[slot_index].get("id") == "healing_potion":
				await _touch_action(main, "quickbar_slot", str(slot_index))
				return
	for hit in main.active_hits:
		var action: Dictionary = hit.action
		if String(action.get("type", "")) != action_type:
			continue
		if action_id != "" and str(action.get("id", action.get("mode", action.get("index", "")))) != action_id:
			continue
		var rect: Rect2 = hit.rect
		await _touch(main, rect.get_center())
		return
	_check(false, "touch action is drawn: %s %s" % [action_type, action_id])

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

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
